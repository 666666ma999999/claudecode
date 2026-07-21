#!/bin/bash
# stop-influx-loop-closing.sh — influx専用 Stop 締めゲート（教訓クロージング＋実装commit催促）
#
# 由来: ユーザー恒久指示 2026-07-21「hook化して、またcommitも実装が終わったごとに走らすように」
#       （方式裁定: 催促hook＋AI恒久コミット。hook自体は git を書き換えない＝読み取りのみ）
# 検知1（教訓クロージング）: このセッションでKPIループ正本（catalog / data/kpi_trials/）を
#   編集していたら、締め前に「指紋台帳→catalog→memory の3点記録漏れ自問」を1回だけ促す。
# 検知2（実装commit）: このセッションで編集した influx 配下の tracked ファイルが
#   未コミットのまま停止しようとしたら、意味単位の個別addでのcommitを1回だけ促す。
#
# 設計: hook-development-guide 準拠
#   ① state はセッション複合キー（stop-nudges/influx-closing__<session_id>）
#   ③ 自己制限=セッション1回（2回目以降の停止はブロックしない）・state不能時は fail-open
#   ④ state flag は起動時に7日超を自己削除（retention cap 内蔵）
#   headlessガード: VAULT_PROMPT_RUNNER では Stop block が本文を分断するため即 exit
[ -n "$VAULT_PROMPT_RUNNER" ] && exit 0

# influx メインリポジトリ限定（worktree ../influx-<topic> は対象外＝research-isolation）
case "$PWD" in
  */biz/influx) ;;
  *) exit 0 ;;
esac

# 注意: heredoc はスクリプト自体を python の stdin に流すため、hook 入力JSONは
# bash 側で先に受けて argv で渡す（stdinから読むと空EOFになり全て fail-open する実測バグ）
INPUT=$(cat)
exec /usr/bin/env python3 -I - "$PWD" "$INPUT" <<'PY'
import glob
import json
import os
import subprocess
import sys
import time

try:
    d = json.loads(sys.argv[2] if len(sys.argv) > 2 else "{}")
except Exception:
    sys.exit(0)  # 入力不正は fail-open
sid = str(d.get("session_id") or "")
if not sid:
    sys.exit(0)  # session_id 無し（headless等）は fail-open

pwd = sys.argv[1]
state_dir = os.path.expanduser("~/.claude/state/stop-nudges")
try:
    os.makedirs(state_dir, exist_ok=True)
except OSError:
    sys.exit(0)

# retention cap: 7日超の flag を自己削除（④）
now = time.time()
for f in glob.glob(os.path.join(state_dir, "influx-closing__*")):
    try:
        if now - os.path.getmtime(f) > 7 * 86400:
            os.remove(f)
    except OSError:
        pass

flag = os.path.join(state_dir, f"influx-closing__{sid}")
if os.path.exists(flag):
    sys.exit(0)  # 自己制限: セッション1回のみ（③）

# このセッションの編集ファイル集合（Read は記録されるが編集ではないので除外）
hist = os.path.expanduser("~/.claude/state/edit-history.jsonl")
edited = set()
try:
    with open(hist, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            try:
                r = json.loads(line)
            except Exception:
                continue
            if r.get("session") != sid:
                continue
            if r.get("tool") not in ("Edit", "Write", "MultiEdit"):
                continue
            fp = r.get("file") or ""
            if fp:
                edited.add(fp)
except OSError:
    sys.exit(0)  # 履歴が読めない時は fail-open
if not edited:
    sys.exit(0)

msgs = []

# 検知1: 教訓クロージング（ループ正本を編集した周のみ発火）
LESSON_TRIGGERS = ("/docs/stock-algo-kpi-catalog.md", "/data/kpi_trials/")
if any(t in f for f in edited for t in LESSON_TRIGGERS):
    msgs.append(
        "①教訓クロージング自問（恒久指示2026-07-21・正本=task.md Start Here）: "
        "この周に見送り/棄却/重要な機序知見が出たなら、指紋台帳(build_trial_fingerprints.py CURATED_ENTRIES→再生成)・"
        "catalog(§7-X/§8-6)・memory(project_stock_algo_loop.md) の3点に記録したか確認。"
        "知見が出ていない周なら『教訓なし』と本文に一言添えて再停止してよい。"
    )

# 検知2: 実装commit（influx配下の tracked 編集が未コミットのまま）
in_repo = sorted(f for f in edited if f.startswith(pwd + "/"))
uncommitted = []
if in_repo:
    try:
        out = subprocess.run(
            ["git", "-C", pwd, "status", "--porcelain"],
            capture_output=True, text=True, timeout=5,
        ).stdout
        dirty = set()
        for ln in out.splitlines():
            if len(ln) < 4 or ln[:2] == "??":
                continue  # untracked（_tmp_等 gitignore漏れ含む）は対象外
            dirty.add(os.path.join(pwd, ln[3:].strip().strip('"')))
        uncommitted = [f for f in in_repo if f in dirty]
    except Exception:
        uncommitted = []  # git 不調時は fail-open（ブロックしない）
if uncommitted:
    names = ", ".join(os.path.relpath(f, pwd) for f in uncommitted[:6])
    more = f" 他{len(uncommitted) - 6}件" if len(uncommitted) > 6 else ""
    msgs.append(
        f"②実装commit（恒久指示2026-07-21・都度確認不要の恒久承認）: このセッションで編集した "
        f"tracked ファイルが未コミット: {names}{more}。意味単位の個別addでcommitしてから締める"
        "（意図的な中間状態のまま残す場合は、その理由を本文に明記して再停止してよい）。"
    )

if not msgs:
    sys.exit(0)

# ブロック前に flag を書く。書けなければブロックしない（fail-open・無限ループ防止）
try:
    with open(flag, "w"):
        pass
except OSError:
    sys.exit(0)

print(json.dumps(
    {"decision": "block", "reason": "🧾 influxループ締めゲート:\n" + "\n".join(msgs)},
    ensure_ascii=False,
))
PY
