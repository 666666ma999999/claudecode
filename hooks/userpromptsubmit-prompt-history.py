#!/usr/bin/env -S python3 -I
# userpromptsubmit-prompt-history.py — UserPromptSubmit hook (Phase 1: ローカル捕捉+伏字のみ)
#
# 目的: 全実行プロンプトを伏字済み受領票として state/prompt-history/receipts/ に記録する。
#       Phase 2 (vault INBOX への日次反映) の上流。設計 SSoT: docs/prompt-history-design.md
#
# 設計上の絶対条件 (Codex 敵対レビュー v3 GO 条件):
# - vault には 1 バイトも書かない (Phase 1)
# - 生プロンプトを受領票に残さない: 多層マスキング後のみ保存。マスカー例外時は
#   held:true で本文を保存しない (原文の正本はローカル transcript にある = lossy-safe)
# - fail-open: あらゆる例外で exit 0。プロンプト送信を絶対に阻害しない
# - stdout に何も出さない (注入なし・headless 安全)
# - 排他は hook-development-guide ⑥: 専用 .lock を flock(LOCK_EX)。日別ファイルなので rotate 不要
# - host 識別は hostname でなく初回生成の host_uuid (state/prompt-history/host-uuid)

import sys

REDACTED = "[REDACTED:%s]"


def shannon_entropy(s):
    import math

    if not s:
        return 0.0
    freq = {}
    for c in s:
        freq[c] = freq.get(c, 0) + 1
    n = len(s)
    return -sum((v / n) * math.log2(v / n) for v in freq.values())


def mask_secrets(text):
    """3層マスキング。返り値 (masked_text, hits:list[str])。過剰伏字は許容。"""
    import re

    hits = []

    def sub(pattern, kind, repl=None, flags=0):
        nonlocal text
        new = re.sub(pattern, repl or REDACTED % kind, text, flags=flags)
        if new != text:
            hits.append(kind)
            text = new

    # --- 層1: 既知形式 ---
    # PEM ブロック全体 (BEGIN...END を貪欲でなく最短で)
    sub(r"-----BEGIN [A-Z0-9 ]+-----.*?(-----END [A-Z0-9 ]+-----|\Z)", "PEM", flags=re.S)
    # JWT (3 セグメント)
    sub(r"\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\b", "JWT")
    # 既知プレフィクスのキー (Anthropic/OpenAI/AWS/GitHub/Slack/Google)
    sub(r"\bsk-[A-Za-z0-9_-]{16,}\b", "API_KEY")
    sub(r"\b(AKIA|ASIA)[A-Z0-9]{16}\b", "AWS_KEY")
    sub(r"\b(ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{20,}\b", "GITHUB_TOKEN")
    sub(r"\bgithub_pat_[A-Za-z0-9_]{20,}\b", "GITHUB_TOKEN")
    sub(r"\bxox[baprs]-[A-Za-z0-9-]{10,}\b", "SLACK_TOKEN")
    sub(r"\bAIza[A-Za-z0-9_-]{30,}\b", "GOOGLE_KEY")
    sub(r"\bya29\.[A-Za-z0-9_-]{30,}\b", "GOOGLE_TOKEN")
    # URL 埋込認証 scheme://user:pass@
    sub(r"(?<=://)[^\s/:@]{1,64}:[^\s/@]{1,256}(?=@)", "URL_CRED")
    # Authorization / Cookie / X-Api-Key ヘッダ行 (値部のみ伏字)
    sub(
        r"(?im)^([ \t>]*(?:authorization|cookie|set-cookie|x-api-key)\s*[:=][ \t]*).+$",
        "AUTH_HEADER",
        repl=r"\1" + REDACTED % "AUTH_HEADER",
    )

    # --- 層2: 汎用 key=value / .env 形式 (値部のみ伏字・キーは残す) ---
    # 値は引用符囲み (空白含む全体) or 非空白連。長さ下限なし (短い秘密も伏字・Codex NO-GO 対応)
    sub(
        r"(?i)((?:\b(?:password|passwd|pwd|secret|token|api[_-]?key|apikey|"
        r"access[_-]?key|client[_-]?secret|private[_-]?key|credentials?)"
        r"[A-Za-z0-9_-]*|パスワード|APIキー|認証トークン|秘密鍵)"
        r"[ \t]*[:=：][ \t]*)(\"[^\"\n]+\"|'[^'\n]+'|[^\s\"',;、。]+)",
        "CREDENTIAL",
        repl=r"\1" + REDACTED % "CREDENTIAL",
    )
    # .env 形式行 (大文字 KEY=値)。非秘密キー (許可リスト) の bool/数値のみ残す。
    # 長さ下限なし: PIN_PASSWORD=123456 等の短い秘密も伏字 (Codex NO-GO 対応)
    NONSECRET_KEY = r"(?:PORT|DEBUG|TIMEOUT|RETRY|RETRIES|WORKERS|VERBOSE|LOG_LEVEL|LANG|LC_ALL|TZ|NODE_ENV|ENV|MODE|VERSION|LIMIT|MAX|MIN)[A-Z0-9_]*"

    def env_repl(m):
        key, val = m.group(1), m.group(2)
        if val.lower() in ("true", "false") or (
            val.isdigit() and _re.fullmatch(NONSECRET_KEY + "=", key)
        ):
            return m.group(0)
        hits.append("ENV_VALUE")
        return key + REDACTED % "ENV_VALUE"

    import re as _re

    new = _re.sub(r"(?m)^([A-Z][A-Z0-9_]{2,}=)(\S+)$", env_repl, text)
    text = new

    # --- 層3: 高エントロピー token (20字以上・英数字混在・entropy>3.7) ---
    # 例外: 純 16 進 40 字以下 (git SHA) と UUID は識別子として残す (設計判断)
    def entropy_repl(m):
        tok = m.group(0)
        if _re.fullmatch(r"[0-9a-fA-F]{1,40}", tok):
            return tok
        if _re.fullmatch(r"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}", tok):
            return tok
        if "[REDACTED" in tok:
            return tok
        has_alpha = any(c.isalpha() for c in tok)
        has_digit = any(c.isdigit() for c in tok)
        if has_alpha and has_digit and shannon_entropy(tok) > 3.7:
            hits.append("HIGH_ENTROPY")
            return REDACTED % "HIGH_ENTROPY"
        return tok

    text = _re.sub(r"[A-Za-z0-9+/=_-]{20,}", entropy_repl, text)

    # --- マーカー無害化 (Phase 2 writer の行頭マーカー探索を本文が偽装できないように) ---
    # zero-width space (U+200B) を挿入。可視性は変わらない
    text = _re.sub(r"<!--(\s*(?:prompt-history|evt:))", "<!--​\\1", text)
    text = _re.sub(r"(?m)^(\s*event_id\s*:)", "​\\1", text)

    return text, sorted(set(hits))


def resolve_route(cwd, home, config_path):
    """cwd → route 名。プレフィクス最長一致 → 外れたら worktree 主 repo 解決 → unrouted。"""
    import json
    import os

    try:
        with open(config_path) as f:
            cfg = json.load(f)
        prefixes = cfg.get("cwd_prefixes", {})
        excludes = cfg.get("exclude_cwd_prefixes", [])
    except Exception:
        prefixes, excludes = {}, []

    real_home = os.path.realpath(home)

    def norm(p):
        p = os.path.realpath(p)
        for h in (home, real_home):
            if p == h or p.startswith(h + os.sep):
                return "~" + p[len(h):]
        return p

    def match(p):
        best = None
        for prefix, route in prefixes.items():
            if p == prefix or p.startswith(prefix.rstrip("/") + "/"):
                if best is None or len(prefix) > len(best[0]):
                    best = (prefix, route)
        return best[1] if best else None

    n = norm(cwd)
    # 機械プロンプト (claude-mem observer 等) は捕捉除外 (ユーザーの実行プロンプトではない)
    for ex in excludes:
        if n == ex or n.startswith(ex.rstrip("/") + "/"):
            return "__excluded__"
    r = match(n)
    if r:
        return r
    # worktree → 主リポジトリの root で再判定 (git が無い/非repo なら諦める)
    try:
        import subprocess

        out = subprocess.run(
            ["git", "-C", cwd, "rev-parse", "--git-common-dir"],
            capture_output=True, text=True, timeout=2,
        )
        if out.returncode == 0:
            common = out.stdout.strip()
            if common and common != ".git":
                main_root = os.path.dirname(os.path.abspath(
                    common if os.path.isabs(common) else os.path.join(cwd, common)))
                r = match(norm(main_root))
                if r:
                    return r
    except Exception:
        pass
    return "unrouted:" + n


def main():
    import json
    import os
    import fcntl
    import uuid
    from datetime import datetime

    os.umask(0o077)

    raw = sys.stdin.read()
    d = json.loads(raw)  # malformed → 例外 → 呼び出し元 except で exit 0
    if not isinstance(d, dict):
        return

    prompt = d.get("prompt", "")
    if not isinstance(prompt, str) or not prompt.strip():
        return
    session_id = str(d.get("session_id", "") or "")
    cwd = str(d.get("cwd", "") or os.getcwd())

    home = os.path.expanduser("~")
    base = os.path.join(home, ".claude", "state", "prompt-history")
    receipts_dir = os.path.join(base, "receipts")
    os.makedirs(receipts_dir, exist_ok=True)

    # host_uuid: 初回生成しローカル保存 (hostname 不使用)。
    # 読取り/生成の全体を専用 flock で覆い単一 UUID を決定的に保証 (Codex 再指摘対応)。
    # 空/不正ファイルが残っていてもロック下で再生成される
    host_uuid_path = os.path.join(base, "host-uuid")

    def _read_valid_uuid():
        try:
            with open(host_uuid_path) as f:
                v = f.read().strip()
            return str(uuid.UUID(v))
        except Exception:
            return None

    host_uuid = _read_valid_uuid()
    if not host_uuid:
        hl_fd = os.open(host_uuid_path + ".lock", os.O_CREAT | os.O_RDWR, 0o600)
        try:
            fcntl.flock(hl_fd, fcntl.LOCK_EX)
            host_uuid = _read_valid_uuid()
            if not host_uuid:
                host_uuid = str(uuid.uuid4())
                with open(host_uuid_path, "w") as f:
                    f.write(host_uuid + "\n")
                    f.flush()
                    os.fsync(f.fileno())
        finally:
            try:
                fcntl.flock(hl_fd, fcntl.LOCK_UN)
            except Exception:
                pass
            os.close(hl_fd)

    config_path = os.path.join(home, ".claude", "config", "prompt-history-routing.json")

    record = {
        "ts": datetime.now().astimezone().isoformat(timespec="seconds"),
        "event_id": str(uuid.uuid4()),
        "host_uuid": host_uuid,
        "session_id": session_id,
        "cwd": cwd,
        "route": None,
        "prompt": None,
        "mask_hits": [],
        "held": False,
    }

    # ルーティング (失敗しても捕捉は続行)。除外 route は記録自体をしない
    try:
        record["route"] = resolve_route(cwd, home, config_path)
    except Exception:
        record["route"] = "unrouted:resolve-error"
    if record["route"] == "__excluded__":
        return

    # マスキング。例外・サイズ超過時は held:true・本文なし (生文を絶対に出さない)
    # 上限 200KB: 巨大貼付での timeout/メモリ圧迫を防ぐ。原文は transcript に残る (Codex 指摘)
    try:
        if os.environ.get("PROMPT_HISTORY_FORCE_MASK_ERROR") == "1":
            raise RuntimeError("forced mask error (test)")
        if len(prompt.encode("utf-8", errors="replace")) > 200_000:
            raise ValueError("oversize prompt")
        masked, hits = mask_secrets(prompt)
        record["prompt"] = masked
        record["mask_hits"] = hits
    except Exception as e:
        record["held"] = True
        record["prompt"] = None
        try:
            # 例外の型名のみ記録 (メッセージは入力断片を含みうるため書かない・Codex 指摘)
            with open(os.path.join(base, "capture-warnings.log"), "a") as w:
                w.write("%s mask-error event_id=%s session=%s type=%s\n"
                        % (record["ts"], record["event_id"], session_id,
                           e.__class__.__name__))
        except Exception:
            pass

    receipt_file = os.path.join(receipts_dir, datetime.now().strftime("%Y-%m-%d") + ".jsonl")
    lock_file = receipt_file + ".lock"
    line = json.dumps(record, ensure_ascii=False) + "\n"

    lock_fd = os.open(lock_file, os.O_CREAT | os.O_RDWR, 0o600)
    try:
        fcntl.flock(lock_fd, fcntl.LOCK_EX)
        with open(receipt_file, "a") as f:
            f.write(line)
            f.flush()
            os.fsync(f.fileno())  # 電源断で直近の受領票を失わない (恒久性レビュー P2)
        os.chmod(receipt_file, 0o600)
    finally:
        try:
            fcntl.flock(lock_fd, fcntl.LOCK_UN)
        except Exception:
            pass
        os.close(lock_fd)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        # fail-open: 捕捉失敗を warning に残す試みだけして必ず exit 0
        try:
            import os
            from datetime import datetime

            base = os.path.join(os.path.expanduser("~"), ".claude", "state", "prompt-history")
            os.makedirs(base, exist_ok=True)
            with open(os.path.join(base, "capture-warnings.log"), "a") as w:
                w.write("%s capture-error: unhandled exception\n"
                        % datetime.now().astimezone().isoformat(timespec="seconds"))
        except Exception:
            pass
    sys.exit(0)
