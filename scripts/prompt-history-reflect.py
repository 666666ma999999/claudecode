#!/usr/bin/env python3
# prompt-history-reflect.py — 受領票を vault queue へ転送し (全ホスト)、
# writer ホストのみ各 INBOX の 🧾 節へ日次反映する。
# 設計 SSoT: ~/.claude/docs/prompt-history-design.md (v3 Codex GO)
#
# 不変条件:
# - INBOX の既存内容 (📒 記録・🔵 投函・✅ 裁定ログ) は 1 バイトも変えない。
#   触るのは <!-- prompt-history:begin/end --> マーカー間への挿入と、
#   マーカー節が無い場合のファイル末尾への新設のみ
# - 冪等台帳 (reflected-ledger) の更新は INBOX 書込→fsync→再読検証の後 (台帳先行禁止)
# - git 操作はしない (同期は既存 Obsidian Git に相乗り)
# - 自前 stdout は要約のみ (hook からバックグラウンド起動されログに落ちる)

import fcntl
import json
import os
import re
import sys
import tempfile
from datetime import datetime, timedelta

HOME = os.path.expanduser("~")
# テストは PROMPT_HISTORY_STATE / PROMPT_HISTORY_VAULT / PROMPT_HISTORY_CONFIG で全て差し替える
# (実 state を偽 vault に対して進めてしまう事故の再発防止・2026-07-14)
BASE = os.environ.get("PROMPT_HISTORY_STATE") or os.path.join(
    HOME, ".claude", "state", "prompt-history")
CONFIG = os.environ.get("PROMPT_HISTORY_CONFIG") or os.path.join(
    HOME, ".claude", "config", "prompt-history-routing.json")
BEGIN = "<!-- prompt-history:begin -->"
END = "<!-- prompt-history:end -->"
SECTION_HEADER = "## 🧾 Claude Code 実行履歴（自動・秘密値伏字）"
RECEIPT_RETENTION_DAYS = 30
INBOX_SIZE_WARN = 2 * 1024 * 1024


def load_config():
    with open(CONFIG) as f:
        return json.load(f)


def vault_root(cfg):
    v = os.environ.get("PROMPT_HISTORY_VAULT") or cfg.get("vault_root", "~/Documents/Obsidian Vault")
    return os.path.expanduser(v)


def queue_root(cfg):
    return os.path.join(vault_root(cfg), "03_ClaudeEnv", "prompts", ".queue")


def read_host_uuid():
    with open(os.path.join(BASE, "host-uuid")) as f:
        return f.read().strip()


def locked_append(path, lines):
    """専用 .lock を flock して append (posttooluse-edit-history.py の型)。"""
    lock_fd = os.open(path + ".lock", os.O_CREAT | os.O_RDWR, 0o600)
    try:
        fcntl.flock(lock_fd, fcntl.LOCK_EX)
        with open(path, "a") as f:
            f.writelines(lines)
            f.flush()
            os.fsync(f.fileno())
    finally:
        try:
            fcntl.flock(lock_fd, fcntl.LOCK_UN)
        except Exception:
            pass
        os.close(lock_fd)


# ---------- Step A: 受領票 → vault queue 転送 (全ホスト) ----------

def transfer(cfg, host_uuid):
    receipts_dir = os.path.join(BASE, "receipts")
    qdir = os.path.join(queue_root(cfg), host_uuid)
    os.makedirs(qdir, exist_ok=True)
    cursor_path = os.path.join(BASE, "transfer-cursor.json")
    try:
        with open(cursor_path) as f:
            cursor = json.load(f)
    except Exception:
        cursor = {}

    moved = 0
    for name in sorted(os.listdir(receipts_dir)) if os.path.isdir(receipts_dir) else []:
        if not re.fullmatch(r"\d{4}-\d{2}-\d{2}\.jsonl", name):
            continue
        src = os.path.join(receipts_dir, name)
        with open(src) as f:
            lines = f.readlines()
        done = cursor.get(name, 0)
        new = lines[done:]
        if new:
            locked_append(os.path.join(qdir, name), new)
            cursor[name] = len(lines)
            moved += len(new)

    tmp = tempfile.NamedTemporaryFile(mode="w", dir=BASE, delete=False)
    json.dump(cursor, tmp)
    tmp.flush()
    os.fsync(tmp.fileno())
    tmp.close()
    os.replace(tmp.name, cursor_path)

    # heartbeat (同期停止の相互監視用・Codex 条件5)
    with open(os.path.join(qdir, "heartbeat"), "w") as f:
        f.write(datetime.now().astimezone().isoformat(timespec="seconds") + "\n")

    # 転送済み + 30 日超の受領票を purge (queue=vault git が耐久正本になった後のみ)
    cutoff = (datetime.now() - timedelta(days=RECEIPT_RETENTION_DAYS)).strftime("%Y-%m-%d")
    purged = 0
    for name in list(cursor.keys()):
        if name[:10] < cutoff:
            src = os.path.join(receipts_dir, name)
            if os.path.exists(src):
                with open(src) as f:
                    n_lines = len(f.readlines())
                if cursor.get(name, 0) >= n_lines:
                    os.unlink(src)
                    for suf in (".lock",):
                        try:
                            os.unlink(src + suf)
                        except FileNotFoundError:
                            pass
                    purged += 1
    print(f"[transfer] host={host_uuid[:8]} moved={moved} purged={purged}")
    return moved


# ---------- Step B: queue → INBOX 反映 (writer のみ) ----------

def fence_for(text):
    longest = max((len(m.group(0)) for m in re.finditer(r"`+", text)), default=0)
    return "`" * max(4, longest + 1)


def sanitize_body(text):
    """マーカー偽装の無害化 (ZWSP 挿入)。捕捉 hook でも実施済みだが、
    hook 修正前の旧受領票・queue 改ざんに備え reflect 側でも必ず通す (多層防御)。"""
    text = re.sub(r"<!--(\s*(?:prompt-history|evt:))", "<!--​\\1", text)
    text = re.sub(r"(?m)^(\s*event_id\s*:)", "​\\1", text)
    return text


def render_event(r):
    ts = r.get("ts", "")
    hhmm = ts[11:16] if len(ts) >= 16 else "??:??"
    route = r.get("route", "?")
    label = route[len("unrouted:"):] if route.startswith("unrouted:") else route
    held = r.get("held")
    out = [f"> <!-- evt:{r['event_id']} -->\n",
           f"> **{hhmm}** `{label}`\n"]
    if held or r.get("prompt") is None:
        out.append("> （本文なし・マスク保留 — 原文はローカル transcript）\n")
    else:
        body = sanitize_body(r["prompt"])
        fence = fence_for(body)
        out.append(f"> {fence}text\n")
        for line in body.splitlines() or [""]:
            out.append(f"> {line}\n" if line else ">\n")
        out.append(f"> {fence}\n")
    out.append(">\n")
    return out


def find_markers(text):
    """行全体一致のマーカーを厳密に探す (本文中の部分文字列を拾わない・Codex 指摘)。
    返り値: (begin_line_start, end_line_start) / 異常 (欠落・重複・逆順) は None。"""
    b = [m.start() for m in re.finditer(r"(?m)^" + re.escape(BEGIN) + r"[ \t]*$", text)]
    e = [m.start() for m in re.finditer(r"(?m)^" + re.escape(END) + r"[ \t]*$", text)]
    if len(b) == 0 and len(e) == 0:
        return None  # 節なし → 新設対象
    if len(b) == 1 and len(e) == 1 and b[0] < e[0]:
        return (b[0], e[0])
    return "invalid"


def ensure_section(text):
    """マーカー節が無ければ末尾に新設。異常マーカーは (None, "invalid") を返し呼び元で skip。"""
    m = find_markers(text)
    if m == "invalid":
        return None, "invalid"
    if m is not None:
        return text, False
    if not text.endswith("\n"):
        text += "\n"
    text += (f"\n---\n\n{SECTION_HEADER}\n\n"
             "> ⚙️ **自動生成の生ログ**（新しい順・全数・秘密値伏字済み）。清書済みの正式記録は上の 📒 が正。"
             "残す価値がある件は「これを 📒 に転記して」と言えば AI が〈いつ・なぜ・結果〉付きで昇格させる。\n\n"
             f"{BEGIN}\n{END}\n")
    return text, True


UUID_RE = re.compile(r"[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[0-9a-f]{4}-[0-9a-f]{12}")
TS_RE = re.compile(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}")


def valid_record(r):
    """queue レコードの構造検証 (改ざん queue からの構造注入・writer 停止を防ぐ・Codex 指摘)。"""
    if not isinstance(r, dict):
        return False
    if not (isinstance(r.get("event_id"), str) and UUID_RE.fullmatch(r["event_id"])):
        return False
    if not (isinstance(r.get("ts"), str) and TS_RE.match(r["ts"])):
        return False
    route = r.get("route")
    if not (isinstance(route, str) and 0 < len(route) < 512 and "\n" not in route):
        return False
    p = r.get("prompt")
    if p is not None and not isinstance(p, str):
        return False
    return True


def reflect(cfg, host_uuid):
    if cfg.get("writer_host_uuid") != host_uuid:
        print("[reflect] not writer — skip Step B")
        return

    qroot = queue_root(cfg)
    ledger_path = os.path.join(BASE, "reflected-ledger.jsonl")
    ledger = set()
    try:
        with open(ledger_path) as f:
            ledger = {l.strip() for l in f if l.strip()}
    except FileNotFoundError:
        pass

    # 全ホストの queue を読む
    events = []
    invalid = 0
    for host in sorted(os.listdir(qroot)) if os.path.isdir(qroot) else []:
        hdir = os.path.join(qroot, host)
        if not os.path.isdir(hdir):
            continue
        for name in sorted(os.listdir(hdir)):
            if not re.fullmatch(r"\d{4}-\d{2}-\d{2}\.jsonl", name):
                continue
            with open(os.path.join(hdir, name)) as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        r = json.loads(line)
                    except Exception:
                        invalid += 1
                        continue
                    if not valid_record(r):
                        invalid += 1
                        continue
                    if r["event_id"] not in ledger:
                        events.append(r)

    if invalid:
        print(f"[reflect] WARN 構造不正の queue レコード {invalid} 件を隔離 (未処理)")

    # dedupe (queue 二重転送耐性) + 時刻順
    seen = set()
    uniq = []
    for r in sorted(events, key=lambda x: x.get("ts", "")):
        if r["event_id"] in seen:
            continue
        seen.add(r["event_id"])
        uniq.append(r)
    if not uniq:
        print("[reflect] no new events")
        _stamp_success(cfg)
        return

    routes = cfg.get("routes", {})
    prefixes = cfg.get("cwd_prefixes", {})
    vroot = vault_root(cfg)

    def re_resolve(route):
        """unrouted:<cwd> を現在の住所録で再解決 (捕捉後に住所録へ追記した分を過去にも効かせる)。"""
        if not route.startswith("unrouted:"):
            return route
        p = route[len("unrouted:"):]
        best = None
        for prefix, name in prefixes.items():
            if p == prefix or p.startswith(prefix.rstrip("/") + "/"):
                if best is None or len(prefix) > len(best[0]):
                    best = (prefix, name)
        return best[1] if best else route

    # inbox ファイル → (date → [events]) にグループ化
    groups = {}
    for r in uniq:
        route = re_resolve(r.get("route", ""))
        r["route"] = route
        key = route if route in routes else "general"
        inbox = os.path.join(vroot, routes.get(key, routes["general"]))
        date = (r.get("ts") or "????-??-??")[:10]
        groups.setdefault(inbox, {}).setdefault(date, []).append(r)

    reflected_ids = []
    for inbox, by_date in sorted(groups.items()):
        if not os.path.exists(inbox):
            print(f"[reflect] WARN inbox missing: {inbox} — {sum(len(v) for v in by_date.values())} 件スキップ (台帳未登録・次回再試行)")
            continue
        st0 = os.stat(inbox)
        with open(inbox, encoding="utf-8") as f:
            orig = f.read()
        text, created = ensure_section(orig)
        if created == "invalid":
            print(f"[reflect] WARN {os.path.basename(inbox)}: マーカーが欠落/重複/逆順 — 書込み中止 (手で修復を)")
            continue

        # クラッシュ窓の修復 (Codex 指摘): 台帳未登録でも INBOX に既にアンカーが
        # あるイベントは再追記せず台帳側を修復する
        block_lines = []
        ids_here = []
        repaired = []
        # 並びは 📒 と同じ「新しいものが上」(日付降順・日内も新しい時刻が上・D案 2026-07-14)
        for date in sorted(by_date, reverse=True):
            evs = []
            for r in by_date[date]:
                if f"<!-- evt:{r['event_id']} -->" in orig:
                    repaired.append(r["event_id"])
                else:
                    evs.append(r)
            if not evs:
                continue
            evs.sort(key=lambda x: x.get("ts", ""), reverse=True)
            block_lines.append(f"> [!note]- {date}（{len(evs)}件・自動記録）\n")
            for r in evs:
                block_lines.extend(render_event(r))
                ids_here.append(r["event_id"])
            block_lines.append("\n")
        if repaired:
            print(f"[reflect] {os.path.basename(inbox)}: 台帳修復 {len(repaired)} 件 (前回クラッシュ分)")
            reflected_ids.extend(repaired)
        if not block_lines:
            continue

        # BEGIN マーカー行 (行全体一致) の直後へ挿入 = 新しい反映が常に上に積まれる (D案)
        m = find_markers(text)
        if m is None or m == "invalid":
            print(f"[reflect] WARN {os.path.basename(inbox)}: マーカー異常 — 書込み中止")
            continue
        idx = text.index("\n", m[0]) + 1
        text = text[:idx] + "".join(block_lines) + text[idx:]

        # テスト用: 読込→置換の競合窓を意図的に広げる (Obsidian 同時編集テスト)
        if os.environ.get("PROMPT_HISTORY_TEST_SLEEP"):
            import time
            time.sleep(float(os.environ["PROMPT_HISTORY_TEST_SLEEP"]))

        # Obsidian 同時編集ガード (Codex 指摘): 読込時点から実ファイルが変わっていたら中止
        st1 = os.stat(inbox)
        if (st1.st_mtime_ns, st1.st_size) != (st0.st_mtime_ns, st0.st_size):
            print(f"[reflect] WARN {os.path.basename(inbox)}: 読込後に外部編集を検知 — 中止 (次回再試行)")
            continue

        tmp = tempfile.NamedTemporaryFile(mode="w", dir=os.path.dirname(inbox),
                                          delete=False, encoding="utf-8")
        tmp.write(text)
        tmp.flush()
        os.fsync(tmp.fileno())
        tmp.close()
        os.replace(tmp.name, inbox)

        # 再読検証 → 合格分のみ台帳へ (Codex 条件6: 台帳先行禁止)
        with open(inbox, encoding="utf-8") as f:
            back = f.read()
        ok = [i for i in ids_here if f"<!-- evt:{i} -->" in back]
        missing = set(ids_here) - set(ok)
        if missing:
            print(f"[reflect] WARN verify failed {len(missing)} 件 in {os.path.basename(inbox)}")
        reflected_ids.extend(ok)
        size = os.path.getsize(inbox)
        note = " (🧾節を新設)" if created else ""
        print(f"[reflect] {os.path.basename(inbox)}: +{len(ok)} 件{note}")
        if size > INBOX_SIZE_WARN:
            print(f"[reflect] ⚠️ {os.path.basename(inbox)} が {size//1024}KB — 肥大の運用変更をユーザーに相談すること (無断処理禁止)")

    if reflected_ids:
        locked_append(ledger_path, [i + "\n" for i in reflected_ids])
    print(f"[reflect] total reflected={len(reflected_ids)}")

    # queue/ledger の肥大監視 (削除はユーザー承認制・警告のみ)
    try:
        qsize = sum(os.path.getsize(os.path.join(dp, fn))
                    for dp, _, fns in os.walk(qroot) for fn in fns)
        lsize = os.path.getsize(ledger_path) if os.path.exists(ledger_path) else 0
        if qsize > 5 * 1024 * 1024 or lsize > 5 * 1024 * 1024:
            print(f"[reflect] ⚠️ queue={qsize//1024}KB ledger={lsize//1024}KB — 圧縮/整理をユーザーに相談すること")
    except Exception:
        pass
    _stamp_success(cfg)


def _stamp_success(cfg):
    """writer の INBOX 反映成功スタンプ (vault 内 = 両 Mac に同期・相互監視用)。"""
    try:
        with open(os.path.join(queue_root(cfg), "writer-last-success"), "w") as f:
            f.write(datetime.now().astimezone().isoformat(timespec="seconds") + "\n")
    except Exception:
        pass


def _stamp_local_success():
    """hook の 20h guard 用ローカル成功スタンプ (試行スタンプと分離・非 writer 機も書く)。"""
    try:
        with open(os.path.join(BASE, "reflect-last-success"), "w") as f:
            f.write(datetime.now().astimezone().isoformat(timespec="seconds") + "\n")
    except Exception:
        pass


def main():
    os.umask(0o077)
    os.makedirs(BASE, exist_ok=True)
    # 単一インスタンス (非ブロッキング)
    run_lock = os.open(os.path.join(BASE, "reflect.lock"), os.O_CREAT | os.O_RDWR, 0o600)
    try:
        fcntl.flock(run_lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        print("[reflect] already running — skip")
        return 0

    cfg = load_config()
    host_uuid = read_host_uuid()
    if not os.path.isdir(vault_root(cfg)):
        print(f"[reflect] ERROR vault not found: {vault_root(cfg)}")
        return 1
    transfer(cfg, host_uuid)
    reflect(cfg, host_uuid)
    _stamp_local_success()
    return 0


if __name__ == "__main__":
    sys.exit(main())
