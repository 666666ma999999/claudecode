#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""wiki_ingest_apply.py — 第二の脳 v3 の「柵の実体」（適用装置）。

無人（launchd）で走る headless claude が生成した result md から、単一の
```json wiki-ingest-patch``` フェンスを読み、機械適用する。無人 AI 書込を
「既存ファイルへの追記のみ・固定着地点のみ・allowlist 先のみ」に物理的に限定する。

決定正本: vault `wiki/meta/decisions.md` 2026-07-06「無人AI書込はハブ追記型」。
設計正本: vault `03_ClaudeEnv/ClaudeEnv-secondbrain-v2-plan.md`（§v3 追補）。

python3 標準ライブラリのみ（MASA.local は 3.9.6 で実確認・2026-07-21）。任意コマンド実行なし・
target は下記 ALLOWLIST にハードコード（vault md の frontmatter から経路を作らせない）。

usage: wiki_ingest_apply.py <result-md-path>

Codex GO-WITH-CHANGES の 10 点を全実装（各所に [C#] で対応を明記）。
"""

import sys
import os
import re
import json
import time
import errno
import hashlib
import unicodedata
import subprocess
import fcntl
import tempfile

HOME = os.path.expanduser("~")
VAULT = os.path.join(HOME, "Documents", "Obsidian Vault")
STATE_DIR = os.path.join(HOME, ".claude", "state")
APPLY_LOG = os.path.join(STATE_DIR, "wiki-ingest-apply.jsonl")   # [C4] dedupe 正本（applier 専用）
LOCK_PATH = os.path.join(STATE_DIR, "wiki-ingest-apply.lock")    # [C7] flock

# --- [allowlist] target key -> 絶対パス（ハードコード・realpath 完全一致で照合） ---
# ハブ5枚（`## AI追記` 節末尾へ追記）+ log（末尾追記・applier 自動）+ queue（AI ゾーン内追記）。
HUBS = {
    "AI活用と自動化":   os.path.join(VAULT, "wiki", "concepts", "AI活用と自動化.md"),
    "広告・マーケティング": os.path.join(VAULT, "wiki", "concepts", "広告・マーケティング.md"),
    "占いビジネス":     os.path.join(VAULT, "wiki", "concepts", "占いビジネス.md"),
    "投資":            os.path.join(VAULT, "wiki", "concepts", "投資.md"),
    "事業戦略":         os.path.join(VAULT, "wiki", "concepts", "事業戦略.md"),
}
LOG_PATH = os.path.join(VAULT, "wiki", "log.md")
QUEUE_PATH = os.path.join(VAULT, "wiki", "meta", "wiki-ingest-queue.md")

# 適用対象になりうる全パス（realpath 完全一致 + symlink 拒否で守る）
ALLOWLIST_PATHS = set(HUBS.values()) | {LOG_PATH, QUEUE_PATH}

# サイズ上限（1 ハブ 4KB / 1 日=1 run 合計 12KB）
PER_HUB_LIMIT = 4 * 1024
TOTAL_LIMIT = 12 * 1024

# ハブ `## AI追記` 見出し（着地点・固定） / queue の AI ゾーン marker
HUB_ZONE_HEADING = "## AI追記"
AI_START = "<!-- AI_QUEUE:START -->"
AI_END = "<!-- AI_QUEUE:END -->"
HUMAN_START = "<!-- HUMAN_QUEUE:START -->"
HUMAN_END = "<!-- HUMAN_QUEUE:END -->"

# [C2/C9] 秘密 9 種（hooks/_archive/security-scan.sh の正規集合を継承・9 個ちょうど）
SECRET_PATTERNS = [
    r"AKIA[0-9A-Z]{16}",                                  # 1 AWS Access Key
    r"sk-ant-[a-zA-Z0-9-]{20,}",                          # 2 Anthropic API Key
    r"sk-[a-zA-Z0-9]{20,}",                               # 3 OpenAI 系 API Key
    r"gh[pousr]_[A-Za-z0-9]{30,}",                        # 4 GitHub token (ghp_/gho_/ghu_/ghs_/ghr_)
    r"xox[baprs]-[0-9a-zA-Z-]{10,}",                      # 5 Slack token
    r"AIza[0-9A-Za-z_\-]{35}",                            # 6 Google API Key
    r"-----BEGIN (?:RSA |DSA |EC |OPENSSH )?PRIVATE KEY", # 7 Private key block
    r"(?:password|passwd|secret|api[_-]?key|token)\s*[:=]\s*[\"']?[^\s\"']{6,}",  # 8 credential 代入
    r"eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.",   # 9 JWT
]
SECRET_RE = [re.compile(p, re.IGNORECASE) for p in SECRET_PATTERNS]

# ゾーンマーカー断片（空白除去・小文字化ビューで照合） [C2]
MARKER_FRAGMENTS = ["<!--ai_queue", "<!--human_queue", "<!--now:"]

# result md 中の patch フェンス [C1]
FENCE_OPEN_RE = re.compile(r"^```json[ \t]+wiki-ingest-patch\b", re.MULTILINE)
FENCE_FULL_RE = re.compile(
    r"^```json[ \t]+wiki-ingest-patch[ \t]*\r?\n(.*?)\r?\n```[ \t]*$",
    re.DOTALL | re.MULTILINE,
)


def notify(msg):
    """Mac 通知（runner と同型・失敗しても握りつぶす）。 [C6]"""
    try:
        subprocess.run(
            ["osascript", "-e",
             'display notification "%s" with title "wiki 日次取り込み"' % msg.replace('"', "'")],
            check=False, capture_output=True, timeout=10,
        )
    except Exception:
        pass


def now_iso():
    return time.strftime("%Y-%m-%dT%H:%M:%S%z")


def today():
    return time.strftime("%Y-%m-%d")


def log_jsonl(record):
    """apply-log（dedupe 正本）へ 1 行 append + fsync。 [C4/C5]"""
    record = dict(record)
    record.setdefault("ts", now_iso())
    line = json.dumps(record, ensure_ascii=False)
    with open(APPLY_LOG, "a", encoding="utf-8") as f:
        f.write(line + "\n")
        f.flush()
        os.fsync(f.fileno())


def load_seen_hashes():
    """apply-log から (target, sha256) の既処理集合を作る（pending も done も skip）。 [C5]"""
    seen = set()
    if not os.path.exists(APPLY_LOG):
        return seen
    with open(APPLY_LOG, "r", encoding="utf-8") as f:
        for ln in f:
            ln = ln.strip()
            if not ln:
                continue
            try:
                r = json.loads(ln)
            except Exception:
                continue
            if r.get("state") in ("pending", "done") and r.get("target") and r.get("sha256"):
                seen.add((r["target"], r["sha256"]))
    return seen


def ensure_init_note():
    """[C10] 初回実行時、apply-log 先頭に例外承認の 1 行を記録。"""
    if os.path.exists(APPLY_LOG) and os.path.getsize(APPLY_LOG) > 0:
        return
    log_jsonl({
        "state": "init",
        "note": "初期ハブ5枚は 2026-07-06 ユーザー承認の例外として作成（以後の新規ファイルは人間✅ゲート）",
    })


def sanitize_view(s):
    """[C2] NFKC 正規化 + Unicode カテゴリ C*（制御・ゼロ幅・書式・bidi）を全除去。
    改行(\\n=Cc) も除去されるため結果は「行結合ビュー」になる。"""
    s = unicodedata.normalize("NFKC", s)
    return "".join(ch for ch in s if unicodedata.category(ch)[0] != "C")


def scan_secrets(text):
    """text（複数行可）に秘密パターンが出るか。raw と行結合ビューの両方で照合。 [C2/C9]"""
    views = [text, sanitize_view(text)]
    for v in views:
        for rx in SECRET_RE:
            if rx.search(v):
                return rx.pattern
    return None


def validate_content(content):
    """content の内容検査。問題があれば reason 文字列、無ければ None。 [C2/C3]

    raw と「NFKC + 制御/ゼロ幅除去 + 行結合ビュー」の両方で:
      - ゾーンマーカー断片を含む → reject
      - 行頭 `---`（YAML/hr 区切り）を含む → reject
      - 行頭 `# ` / `## `（着地点=H2 を割る見出し）を含む → reject
      - 秘密 9 種を含む → reject
    """
    if not isinstance(content, str) or content.strip() == "":
        return "content が空"

    joined = sanitize_view(content)
    nows = re.sub(r"\s+", "", joined).lower()   # 空白除去+小文字（マーカー偽装対策）

    for frag in MARKER_FRAGMENTS:
        if frag in nows:
            return "ゾーンマーカー断片を含む (%s)" % frag

    # 行頭 --- / 見出し H1・H2（raw と sanitize 済み各行の両方でチェック）
    for line in content.splitlines():
        for probe in (line, sanitize_view(line)):
            st = probe.strip()
            if st == "---" or st == "***" or st == "___":
                return "行頭区切り(--- 等)を含む"
            if probe.lstrip().startswith("---"):
                return "行頭 --- を含む"
            if re.match(r"^\s{0,3}#{1,2}\s", probe):
                return "行頭 H1/H2 見出しを含む（着地点を割る）"

    sec = scan_secrets(content)
    if sec:
        return "秘密パターンを含む (%s)" % sec

    return None


def realpath_ok(path):
    """[allowlist] realpath 完全一致 + symlink 拒否。"""
    if os.path.islink(path):
        return False
    try:
        rp = os.path.realpath(path)
    except OSError:
        return False
    # allowlist 側も realpath 化して完全一致を要求
    for allowed in ALLOWLIST_PATHS:
        if os.path.realpath(allowed) == rp and os.path.abspath(path) == os.path.abspath(allowed):
            return not os.path.islink(allowed)
    return False


def atomic_replace_write(path, new_text):
    """temp file + os.replace で原子的に差し替え。 [C5]"""
    d = os.path.dirname(path)
    fd, tmp = tempfile.mkstemp(dir=d, prefix=".wiki-ingest-", suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(new_text)
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp, path)
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def build_hub_block(section_title, content, source):
    """ハブ `## AI追記` へ追記するブロック（section_title は表示ラベルのみ）。 [C3]"""
    lines = ["", "### %s — %s" % (today(), section_title.strip()), content.rstrip()]
    if source:
        lines.append("")
        lines.append("出所: %s" % source.strip())
    lines.append("")
    return "\n".join(lines)


def append_to_hub(path, block):
    """ハブの `## AI追記` 節の末尾へ挿入（次の H2 or EOF の直前）。 [C3]"""
    with open(path, "r", encoding="utf-8") as f:
        text = f.read()
    lines = text.split("\n")
    # `## AI追記` 見出し行を探す
    h_idx = None
    for i, ln in enumerate(lines):
        if ln.strip() == HUB_ZONE_HEADING:
            h_idx = i
            break
    if h_idx is None:
        raise RuntimeError("着地見出し '%s' が無い: %s" % (HUB_ZONE_HEADING, path))
    # 次の H2 (## ) を探す（無ければ EOF）
    end_idx = len(lines)
    for j in range(h_idx + 1, len(lines)):
        if re.match(r"^##\s", lines[j]):
            end_idx = j
            break
    # end_idx の直前へ block を挿入
    before = "\n".join(lines[:end_idx]).rstrip("\n")
    after = "\n".join(lines[end_idx:])
    new_text = before + "\n\n" + block.strip("\n") + "\n"
    if after.strip():
        new_text += "\n" + after
    if not new_text.endswith("\n"):
        new_text += "\n"
    atomic_replace_write(path, new_text)


def append_to_log(entries):
    """wiki/log.md 末尾へ run サマリーを 1 ブロック append（人間可読ログ・別経路）。 [C4]"""
    with open(LOG_PATH, "r", encoding="utf-8") as f:
        text = f.read()
    block = ["", "## [%s] wiki-ingest-apply（無人・日次）" % today()]
    for e in entries:
        block.append("- %s ｜ %s" % (e["target"], e["section_title"]))
    block.append("")
    new_text = text.rstrip("\n") + "\n" + "\n".join(block) + "\n"
    atomic_replace_write(LOG_PATH, new_text)


def append_to_queue(content):
    """[C8] queue の AI_QUEUE ゾーン内側の末尾のみへ追記。HUMAN ゾーンに触れたら abort。"""
    with open(QUEUE_PATH, "r", encoding="utf-8") as f:
        text = f.read()
    if AI_START not in text or AI_END not in text:
        raise RuntimeError("queue に AI_QUEUE marker が無い")
    if HUMAN_START not in text or HUMAN_END not in text:
        raise RuntimeError("queue に HUMAN_QUEUE marker が無い")

    human_before = text[text.index(HUMAN_START):text.index(HUMAN_END) + len(HUMAN_END)]

    i = text.index(AI_START) + len(AI_START)
    j = text.index(AI_END)
    if not (i <= j):
        raise RuntimeError("AI_QUEUE marker の順序が不正")
    ai_zone = text[i:j]
    new_ai_zone = ai_zone.rstrip("\n") + "\n" + content.rstrip("\n") + "\n"
    new_text = text[:i] + new_ai_zone + text[j:]

    # HUMAN ゾーンが 1 byte でも変われば abort（書かない） [C8]
    human_after = new_text[new_text.index(HUMAN_START):new_text.index(HUMAN_END) + len(HUMAN_END)]
    if human_before != human_after:
        raise RuntimeError("HUMAN ゾーンが変化する—abort")

    atomic_replace_write(QUEUE_PATH, new_text)


def fail(reason, code=1):
    """構造違反・全滅時の終了。 [C6]"""
    log_jsonl({"state": "abort", "reason": reason})
    notify("取り込み中止: %s" % reason[:80])
    sys.stderr.write("[wiki_ingest_apply] ABORT: %s\n" % reason)
    sys.exit(code)


def main():
    if len(sys.argv) != 2:
        sys.stderr.write("usage: wiki_ingest_apply.py <result-md-path>\n")
        sys.exit(2)
    result_path = sys.argv[1]

    os.makedirs(STATE_DIR, exist_ok=True)

    # [C7] flock — 取れなければ skip + 通知 + exit 0
    lock_fd = open(LOCK_PATH, "w")
    try:
        fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError as e:
        if e.errno in (errno.EACCES, errno.EAGAIN):
            notify("別プロセスが実行中のため skip")
            sys.stderr.write("[wiki_ingest_apply] lock busy -> skip\n")
            sys.exit(0)
        raise

    try:
        ensure_init_note()  # [C10]

        if not os.path.isfile(result_path):
            fail("result md が無い: %s" % result_path)
        with open(result_path, "r", encoding="utf-8") as f:
            result = f.read()

        # [C9] apply 前に result md 全体へ秘密スキャン → ヒットで全中止
        sec = scan_secrets(result)
        if sec:
            fail("result 全体に秘密パターン (%s) — apply 全中止" % sec)

        # [C1] フェンスちょうど 1 個
        opens = FENCE_OPEN_RE.findall(result)
        blocks = FENCE_FULL_RE.findall(result)
        if len(opens) != 1 or len(blocks) != 1:
            fail("patch フェンスが 1 個でない (open=%d closed=%d)" % (len(opens), len(blocks)))

        try:
            patch = json.loads(blocks[0])
        except Exception as e:
            fail("patch JSON パース失敗: %s" % e)
        if not isinstance(patch, list):
            fail("patch が JSON 配列でない")
        if len(patch) > 10:
            fail("patch items>10 (%d)" % len(patch))

        seen = load_seen_hashes()
        applied = []      # (target, section_title) 成功
        rejected = []     # (target, reason)
        per_target_bytes = {}
        total_bytes = 0

        for idx, item in enumerate(patch):
            if not isinstance(item, dict):
                rejected.append(("<item %d>" % idx, "dict でない"))
                continue
            target = item.get("target", "")
            section_title = str(item.get("section_title", "") or "")
            content = item.get("content", "")
            source = str(item.get("source", "") or "")

            # target の allowlist 照合（キー）
            if target in HUBS:
                path = HUBS[target]
                kind = "hub"
            elif target == "queue":
                path = QUEUE_PATH
                kind = "queue"
            else:
                rejected.append((str(target), "allowlist 外 target"))
                continue

            # realpath + symlink 検査
            if not realpath_ok(path):
                rejected.append((str(target), "realpath/symlink 検査に失敗"))
                continue

            # 内容検査（content は必須・queue は section_title もラベルとして content に合流させない）
            reason = validate_content(content)
            if reason is None and source:
                reason = validate_content_source(source)
            if reason is not None:
                rejected.append((str(target), reason))
                continue

            # 追記ブロックを組み立て
            if kind == "hub":
                block = build_hub_block(section_title, content, source)
            else:  # queue proposal（新規ファイル提案・適用はされない・候補として転記のみ）
                label = section_title.strip() or "候補"
                src = (" ｜ " + source.strip()) if source else ""
                block = "- [ ] %s ｜ %s%s" % (label, content.strip(), src)

            nb = len(block.encode("utf-8"))
            # サイズ上限
            if kind == "hub":
                cur = per_target_bytes.get(target, 0)
                if cur + nb > PER_HUB_LIMIT:
                    rejected.append((str(target), "ハブ 4KB/run 上限超過"))
                    continue
            if total_bytes + nb > TOTAL_LIMIT:
                rejected.append((str(target), "合計 12KB/run 上限超過"))
                continue

            # [C4/C5] dedupe: (target, sha256(content)) が既処理なら skip
            h = hashlib.sha256(content.encode("utf-8")).hexdigest()
            if (target, h) in seen:
                continue  # 冪等 skip（reject でも apply でもない）

            # [C5] 順序: ①pending 記録 → ②atomic 追記 → ③done 記録
            log_jsonl({"state": "pending", "target": target, "sha256": h, "kind": kind})
            try:
                if kind == "hub":
                    append_to_hub(path, block)
                else:
                    append_to_queue(block)
            except Exception as e:
                # 追記失敗: pending のまま（rerun で skip される=二重追記防止）。reject 計上。
                log_jsonl({"state": "apply_error", "target": target, "sha256": h, "error": str(e)})
                rejected.append((str(target), "追記失敗: %s" % e))
                continue
            log_jsonl({"state": "done", "target": target, "sha256": h, "kind": kind})
            seen.add((target, h))
            applied.append({"target": target, "section_title": section_title, "kind": kind})
            per_target_bytes[target] = per_target_bytes.get(target, 0) + nb
            total_bytes += nb

        # 人間可読ログ（適用があった時のみ・別経路 append） [C4]
        hub_applied = [a for a in applied if a["kind"] == "hub"]
        if hub_applied and realpath_ok(LOG_PATH):
            try:
                append_to_log(hub_applied)
            except Exception as e:
                log_jsonl({"state": "log_error", "error": str(e)})

        # reject を jsonl に記録 [C6]
        for tgt, reason in rejected:
            log_jsonl({"state": "reject", "target": tgt, "reason": reason})

        # [C6] 終了設計
        if not applied and rejected:
            fail("全 %d 件 reject（適用 0）" % len(rejected))
        if not applied and not rejected:
            # 空 patch（[]）: 取り込むもの無し = 正常
            notify("本日は取り込み対象なし（適用0）")
            print("[wiki_ingest_apply] no items to apply (empty patch)")
            sys.exit(0)

        # 適用あり（一部 reject 含みうる）= exit 0
        msg = "適用 %d 件" % len(applied) + (" / reject %d 件" % len(rejected) if rejected else "")
        notify(msg)
        print("[wiki_ingest_apply] " + msg)
        for a in applied:
            print("  applied: %s ｜ %s (%s)" % (a["target"], a["section_title"], a["kind"]))
        for tgt, reason in rejected:
            print("  reject : %s ｜ %s" % (tgt, reason))
        sys.exit(0)

    finally:
        try:
            fcntl.flock(lock_fd, fcntl.LOCK_UN)
            lock_fd.close()
        except Exception:
            pass


def validate_content_source(source):
    """source（出所文字列）にも同じ内容検査を掛ける（秘密・マーカー混入対策）。"""
    # source は 1 行想定。行頭見出し等の構造チェックは緩め、秘密とマーカーのみ厳格に。
    joined = sanitize_view(source)
    nows = re.sub(r"\s+", "", joined).lower()
    for frag in MARKER_FRAGMENTS:
        if frag in nows:
            return "source にゾーンマーカー断片"
    sec = scan_secrets(source)
    if sec:
        return "source に秘密パターン (%s)" % sec
    return None


if __name__ == "__main__":
    main()
