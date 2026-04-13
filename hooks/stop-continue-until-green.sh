#!/bin/bash
# Stop hook: implementation-checklist 未完了 or テスト未検証なら停止をブロック
# JSON decision=block で Claude を停止させず作業を継続させる

STATE_DIR="$HOME/.claude/state"

export STATE_DIR
# 単一 python3 起動で全チェックを処理（hot path 短縮 + JSON injection 防止）
python3 <<'PYEOF'
import json
import os
import sys
from pathlib import Path

try:
    data = json.load(sys.stdin)
except json.JSONDecodeError:
    data = {}

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


def log(msg: str) -> None:
    print(msg, file=sys.stderr)


def read_int(path: Path, default: int = 0) -> int:
    try:
        return int(path.read_text(encoding="utf-8").strip())
    except (OSError, ValueError):
        return default


# チェック0: 中間バッチ検証
if verify_pending.exists():
    try:
        edit_count = int(json.loads(verify_pending.read_text(encoding="utf-8")).get("edit_count", 0))
    except (OSError, json.JSONDecodeError, ValueError):
        edit_count = 0
    if edit_count > 0:
        blockers.append(f"⚠️ 中間バッチ検証が未完了です（{edit_count}回の編集が未検証）。検証を実行してください。")
        log(f"blocker: verify-step pending ({edit_count} edits)")

# チェック0.5: /simplify 未実行
if simplify_pending.exists():
    current = read_int(simplify_pending, 0)
    saved = read_int(simplify_snapshot, -1)
    itr = read_int(simplify_iteration, 0)

    if current != saved:
        itr += 1
        if itr <= 3:
            simplify_snapshot.write_text(f"{current}\n", encoding="utf-8")
            simplify_iteration.write_text(f"{itr}\n", encoding="utf-8")
            blockers.append(f"/simplify を実行してコード品質を確認してください（{itr}/3回目）。")
            log(f"blocker: simplify pending (count={current}, iter={itr})")
        else:
            for f in (simplify_pending, simplify_snapshot, simplify_iteration):
                f.unlink(missing_ok=True)
            log("simplify: forced clear after 3 iterations")
    else:
        for f in (simplify_pending, simplify_snapshot, simplify_iteration):
            f.unlink(missing_ok=True)
        log("simplify: converged (no new edits)")

# チェック0.75: FEブラウザ検証
if (
    pending_file.exists()
    and pending_file.stat().st_size > 0
    and not simplify_pending.exists()
):
    fe_exts = {".html", ".css", ".scss", ".less", ".tsx", ".jsx"}
    fe_dirs = ("/frontend/", "/static/", "/public/", "/components/", "/pages/")
    has_fe = False
    try:
        for line in pending_file.read_text(encoding="utf-8").splitlines()[1:]:
            f = line.strip()
            if not f:
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

# チェック1: checklist.pending
if pending_file.exists() and pending_file.stat().st_size > 0:
    blockers.append("⚠️ implementation-checklist が未完了です。完了してから停止してください。")
    log("blocker: implementation-checklist pending")

# チェック2: docker-compose + tests-passed
compose_file = None
for name in ("docker-compose.yml", "docker-compose.yaml"):
    if Path(name).exists():
        compose_file = name
        break

if compose_file and pending_file.exists() and pending_file.stat().st_size > 0:
    if not tests_passed.exists():
        blockers.append("⚠️ テストが未検証です。テストを実行してください。")
        log("blocker: tests not verified (no tests-passed file)")
    elif pending_file.stat().st_mtime > tests_passed.stat().st_mtime:
        blockers.append("⚠️ テストが未検証です。テストを実行してください。")
        log("blocker: tests-passed older than pending")

# チェック3: 3-Fix Limit
if fix_count_file.exists():
    fix_count = read_int(fix_count_file, 0)
    if fix_count >= 3:
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
