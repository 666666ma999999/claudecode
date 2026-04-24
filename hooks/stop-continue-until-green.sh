#!/bin/bash
# Stop hook: implementation-checklist 未完了 or テスト未検証なら停止をブロック
# JSON decision=block で Claude を停止させず作業を継続させる

STATE_DIR="$HOME/.claude/state"

# stdin は heredoc に占有されるため、INPUT を環境変数経由で Python に渡す
INPUT=$(cat)
export STATE_DIR HOOK_INPUT="$INPUT"
# 単一 python3 起動で全チェックを処理（hot path 短縮 + JSON injection 防止）
python3 <<'PYEOF'
import json
import os
import sys
import time
from datetime import datetime
from pathlib import Path

try:
    data = json.loads(os.environ.get("HOOK_INPUT", "{}"))
except json.JSONDecodeError:
    data = {}

# TTL（時間単位、環境変数で上書き可）
CHECKLIST_TTL_HOURS = float(os.environ.get("CHECKLIST_TTL_HOURS", "24"))
SIMPLIFY_TTL_HOURS = float(os.environ.get("SIMPLIFY_TTL_HOURS", "24"))

# 無限ループ防止
if str(data.get("stop_hook_active", False)).lower() == "true":
    print("stop_hook_active=true, skipping", file=sys.stderr)
    sys.exit(0)

print(f"transcript_path={data.get('transcript_path', '')}", file=sys.stderr)

state_dir = Path(os.environ["STATE_DIR"])
pending_file = state_dir / "implementation-checklist.pending"
tests_passed = state_dir / "tests-passed"
verify_pending = state_dir / "verify-step.pending"
simplify_pending = state_dir / "needs-simplify.pending"
simplify_snapshot = state_dir / "simplify-snapshot"
simplify_iteration = state_dir / "simplify-iteration"
fe_verified = state_dir / "fe-browser-verified.done"
fix_count_file = state_dir / "fix-retry-count"

blockers = []

# cwd を早期に取得（全チェックで使用）
hook_cwd = Path(data.get("cwd") or os.getcwd()).resolve()


def log(msg: str) -> None:
    print(msg, file=sys.stderr)


def read_int(path: Path, default: int = 0) -> int:
    try:
        return int(path.read_text(encoding="utf-8").strip())
    except (OSError, ValueError):
        return default


def cwd_matches(stored_cwd: str) -> bool:
    """stored_cwd が空なら True（旧形式は常にマッチ）、違うプロジェクトなら False"""
    if not stored_cwd:
        return True
    return Path(stored_cwd).resolve() == hook_cwd


# チェック0: 中間バッチ検証（cwd + TTL 対応）
if verify_pending.exists():
    try:
        vp_data = json.loads(verify_pending.read_text(encoding="utf-8"))
        edit_count = int(vp_data.get("edit_count", 0))
    except (OSError, json.JSONDecodeError, ValueError):
        vp_data = {}
        edit_count = 0
    if edit_count > 0:
        vp_cwd = vp_data.get("cwd", "")
        if not cwd_matches(vp_cwd):
            log(f"verify-step: cwd mismatch (hook={hook_cwd} vs stored={vp_cwd}), skipping")
        else:
            # TTL check: 期限切れなら自動削除してスキップ
            from datetime import datetime
            ttl = vp_data.get("ttl_expires_at", "")
            expired = False
            if ttl:
                try:
                    expired = datetime.fromisoformat(ttl) < datetime.now()
                except ValueError:
                    pass
            if expired:
                verify_pending.unlink(missing_ok=True)
                log("verify-step: TTL expired, auto-deleted")
            else:
                blockers.append(f"⚠️ 中間バッチ検証が未完了です（{edit_count}回の編集が未検証）。検証を実行してください。")
                log(f"blocker: verify-step pending ({edit_count} edits)")

# チェック0.5: /simplify 未実行（cwd 対応 + TTL）
simplify_done = state_dir / "simplify-done.timestamp"
if simplify_pending.exists():
    if simplify_done.exists() and simplify_done.stat().st_mtime > simplify_pending.stat().st_mtime:
        # /simplify実行済み → pending解除
        for f in (simplify_pending, simplify_snapshot, simplify_iteration, simplify_done):
            f.unlink(missing_ok=True)
        log("simplify: done (marker newer than pending)")
    else:
        # TTL チェック: JSON の ttl_expires_at 優先、無ければ mtime で判定
        simplify_expired = False
        sp_data = None
        try:
            sp_raw = simplify_pending.read_text(encoding="utf-8")
            sp_data = json.loads(sp_raw)
        except (OSError, json.JSONDecodeError, ValueError):
            sp_data = None
        if isinstance(sp_data, dict):
            ttl = sp_data.get("ttl_expires_at", "")
            if ttl:
                try:
                    if datetime.fromisoformat(ttl) < datetime.now():
                        simplify_expired = True
                except ValueError:
                    pass
        if not simplify_expired:
            # フォールバック: mtime で判定
            age_hours = (time.time() - simplify_pending.stat().st_mtime) / 3600
            if age_hours > SIMPLIFY_TTL_HOURS:
                simplify_expired = True
        if simplify_expired:
            for f in (simplify_pending, simplify_snapshot, simplify_iteration):
                f.unlink(missing_ok=True)
            log(f"simplify: TTL expired, auto-deleted")
        else:
            # cwd チェック: JSON形式なら cwd を確認、旧形式(数値のみ)は常にマッチ
            simplify_skip = False
            if isinstance(sp_data, dict) and not cwd_matches(sp_data.get("cwd", "")):
                simplify_skip = True
                log(f"simplify: cwd mismatch, skipping")
            if not simplify_skip:
                blockers.append("/simplify を実行してコード品質を確認してください。実行するまでブロックされます。")
                log(f"blocker: simplify pending, done_marker={'exists' if simplify_done.exists() else 'missing'}")

# TTL チェック: checklist.pending が古すぎる場合は自動削除
# （消し忘れで次セッションが永久ブロックされるのを防ぐ）
if pending_file.exists() and pending_file.stat().st_size > 0:
    age_hours = (time.time() - pending_file.stat().st_mtime) / 3600
    if age_hours > CHECKLIST_TTL_HOURS:
        pending_file.unlink(missing_ok=True)
        log(f"checklist: TTL expired (age={age_hours:.1f}h > {CHECKLIST_TTL_HOURS}h), auto-deleted")

# チェック0.75: FEブラウザ検証（cwd対応: 他プロジェクトのFEファイルを誤検出しない）
if (
    pending_file.exists()
    and pending_file.stat().st_size > 0
    and not simplify_pending.exists()
):
    fe_exts = {".html", ".css", ".scss", ".less", ".tsx", ".jsx"}
    fe_dirs = ("/frontend/", "/static/", "/public/", "/components/", "/pages/")
    has_fe = False
    hook_cwd_str = str(hook_cwd)
    try:
        for line in pending_file.read_text(encoding="utf-8").splitlines()[1:]:
            f = line.strip()
            if not f:
                continue
            # cwd外のファイルは他セッション由来とみなしてスキップ
            if not f.startswith(hook_cwd_str):
                continue
            ext = os.path.splitext(f)[1].lower()
            if ext in fe_exts or any(d in f for d in fe_dirs):
                has_fe = True
                break
            if ext in {".js", ".ts"} and any(d in f for d in fe_dirs):
                has_fe = True
                break
    except OSError:
        pass

    if has_fe and not fe_verified.exists():
        blockers.append(
            "⚠️ FE変更が検出されましたが、ブラウザ検証が未実行です。"
            "Playwright MCPで確認してください: (1) browser_navigate "
            "(2) console_messages でエラーゼロ確認 (3) 変更した操作を1回実行。"
        )
        log("blocker: FE browser verification pending")

# チェック1: checklist.pending（cwd 対応: 自プロジェクト由来の行が1つでもあればblocker）
if pending_file.exists() and pending_file.stat().st_size > 0:
    cl_has_cwd_file = False
    try:
        cl_lines = pending_file.read_text(encoding="utf-8").splitlines()
        hook_cwd_str = str(hook_cwd)
        for line in cl_lines[1:]:
            f = line.strip()
            if f and f.startswith(hook_cwd_str):
                cl_has_cwd_file = True
                break
        if not cl_has_cwd_file and len(cl_lines) >= 2:
            log(f"checklist: no files under current project {hook_cwd}, skipping")
    except OSError:
        pass
    if cl_has_cwd_file:
        blockers.append("⚠️ implementation-checklist が未完了です。完了してから停止してください。")
        log("blocker: implementation-checklist pending")

# チェック2: docker-compose + tests-passed
cwd = hook_cwd  # 早期定義済み
compose_file = None
for name in ("docker-compose.yml", "docker-compose.yaml"):
    if (cwd / name).exists():
        compose_file = name
        break

if compose_file and pending_file.exists() and pending_file.stat().st_size > 0:
    # cwd チェック: 自プロジェクト由来の行が1つでもあればblocker判定に入る
    tp_has_cwd_file = False
    try:
        tp_lines = pending_file.read_text(encoding="utf-8").splitlines()
        hook_cwd_str = str(hook_cwd)
        for line in tp_lines[1:]:
            f = line.strip()
            if f and f.startswith(hook_cwd_str):
                tp_has_cwd_file = True
                break
        if not tp_has_cwd_file and len(tp_lines) >= 2:
            log(f"tests-passed: no files under current project {hook_cwd}, skipping")
    except OSError:
        pass
    if tp_has_cwd_file:
        if not tests_passed.exists():
            blockers.append("⚠️ テストが未検証です。テストを実行してください。")
            log("blocker: tests not verified (no tests-passed file)")
        elif pending_file.stat().st_mtime > tests_passed.stat().st_mtime:
            blockers.append("⚠️ テストが未検証です。テストを実行してください。")
            log("blocker: tests-passed older than pending")

# チェック3: 3-Fix Limit（fix-last-file のパスで cwd チェック）
if fix_count_file.exists():
    fix_count = read_int(fix_count_file, 0)
    if fix_count >= 3:
        fix_skip = False
        fix_last = state_dir / "fix-last-file"
        if fix_last.exists():
            try:
                last_path = fix_last.read_text(encoding="utf-8").strip()
                if last_path and not last_path.startswith(str(hook_cwd)):
                    fix_skip = True
                    log(f"3-fix-limit: file outside current project ({last_path}), skipping")
            except OSError:
                pass
        if not fix_skip:
            blockers.append(
                f"🛑 3-Fix Limit到達（{fix_count}回連続修正）。"
                "ブロッカープロトコルに従い、ユーザーに確認してください。"
            )
            log(f"blocker: 3-fix-limit reached ({fix_count})")

# ブロッカーがあれば JSON decision=block で作業継続を強制
if blockers:
    blockers_text = "\n".join(blockers)
    reason = (
        '<system-reminder severity="blocking" action-required="resolve-before-stop">\n'
        "STOP BLOCKED: 報告前の必須チェックが未完了です。\n\n"
        f"{blockers_text}\n\n"
        "実行順:\n"
        "  [1] 中間バッチ検証（verify-step.pending 残存時）\n"
        "  [2] /simplify でコード品質レビュー（needs-simplify.pending 残存時）\n"
        "  [3] FEブラウザ検証（該当時 / Playwright MCP）\n"
        "  [4] Codex仕様準拠+品質レビュー（mcp__codex__codex 2回）or feature-dev:code-reviewer agent\n"
        "  [5] Codex完了後 touch ~/.claude/state/codex-review.done\n"
        "  [6] rm ~/.claude/state/implementation-checklist.pending\n\n"
        "全完了まで作業を続けてください。\n"
        "</system-reminder>"
    )
    print(json.dumps({"decision": "block", "reason": reason}))

sys.exit(0)
PYEOF
