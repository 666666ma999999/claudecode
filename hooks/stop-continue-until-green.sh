#!/bin/bash
# Stop hook: implementation-checklist未完了 or テスト未検証なら停止をブロック
# stdout出力あり → Claudeは作業を継続
# stdout出力なし → Claudeは通常停止

STATE_DIR="$HOME/.claude/state"
PENDING_FILE="$STATE_DIR/implementation-checklist.pending"
TESTS_PASSED="$STATE_DIR/tests-passed"

# stdin JSON を読み取り
INPUT=$(cat)

# stop_hook_active チェック（無限ループ防止）
STOP_HOOK_ACTIVE=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('stop_hook_active', False))" 2>/dev/null)
if [ "$STOP_HOOK_ACTIVE" = "True" ] || [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  echo "stop_hook_active=true, skipping" >&2
  exit 0
fi

# transcript_path を取得（デバッグ用）
TRANSCRIPT_PATH=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('transcript_path', ''))" 2>/dev/null)
echo "transcript_path=$TRANSCRIPT_PATH" >&2

BLOCKERS=""

# チェック0: verify-step.pending（中間バッチ検証）が残っているか
VERIFY_PENDING="$STATE_DIR/verify-step.pending"
if [ -f "$VERIFY_PENDING" ]; then
  EDIT_COUNT=$(python3 -c "import json; print(json.load(open('$VERIFY_PENDING')).get('edit_count',0))" 2>/dev/null)
  if [ "$EDIT_COUNT" -gt 0 ] 2>/dev/null; then
    BLOCKERS="${BLOCKERS}⚠️ 中間バッチ検証が未完了です（${EDIT_COUNT}回の編集が未検証）。検証を実行してください。\n"
    echo "blocker: verify-step pending (${EDIT_COUNT} edits)" >&2
  fi
fi

# チェック0.5: /simplify 未実行（コード品質レビュー）
SIMPLIFY_PENDING="$STATE_DIR/needs-simplify.pending"
SIMPLIFY_SNAPSHOT="$STATE_DIR/simplify-snapshot"
SIMPLIFY_ITERATION="$STATE_DIR/simplify-iteration"

if [ -f "$SIMPLIFY_PENDING" ]; then
  CURRENT_COUNT=$(cat "$SIMPLIFY_PENDING" 2>/dev/null | tr -d '[:space:]')
  SAVED_COUNT=$(cat "$SIMPLIFY_SNAPSHOT" 2>/dev/null | tr -d '[:space:]')
  ITER=$(cat "$SIMPLIFY_ITERATION" 2>/dev/null | tr -d '[:space:]')
  [ -z "$CURRENT_COUNT" ] && CURRENT_COUNT=0
  [ -z "$SAVED_COUNT" ] && SAVED_COUNT=-1
  [ -z "$ITER" ] && ITER=0

  if [ "$CURRENT_COUNT" -ne "$SAVED_COUNT" ] 2>/dev/null; then
    # 新しい編集あり → /simplify 必要
    ITER=$((ITER + 1))
    if [ "$ITER" -le 3 ]; then
      echo "$CURRENT_COUNT" > "$SIMPLIFY_SNAPSHOT"
      echo "$ITER" > "$SIMPLIFY_ITERATION"
      BLOCKERS="${BLOCKERS}/simplify を実行してコード品質を確認してください（${ITER}/3回目）。\n"
      echo "blocker: simplify pending (count=$CURRENT_COUNT, iter=$ITER)" >&2
    else
      # 安全弁: 3回超 → 強制解除
      rm -f "$SIMPLIFY_PENDING" "$SIMPLIFY_SNAPSHOT" "$SIMPLIFY_ITERATION"
      echo "simplify: forced clear after 3 iterations" >&2
    fi
  else
    # カウンタ一致 → 収束（/simplify で変更なし）→ フラグ解除
    rm -f "$SIMPLIFY_PENDING" "$SIMPLIFY_SNAPSHOT" "$SIMPLIFY_ITERATION"
    echo "simplify: converged (no new edits)" >&2
  fi
fi

# チェック1: implementation-checklist.pending が存在し中身があるか
if [ -f "$PENDING_FILE" ] && [ -s "$PENDING_FILE" ]; then
  BLOCKERS="${BLOCKERS}⚠️ implementation-checklist が未完了です。完了してから停止してください。\n"
  echo "blocker: implementation-checklist pending" >&2
fi

# チェック2: docker-compose があればテスト検証状態を確認
COMPOSE_FILE=""
if [ -f "docker-compose.yml" ]; then
  COMPOSE_FILE="docker-compose.yml"
elif [ -f "docker-compose.yaml" ]; then
  COMPOSE_FILE="docker-compose.yaml"
fi

if [ -n "$COMPOSE_FILE" ] && [ -f "$PENDING_FILE" ] && [ -s "$PENDING_FILE" ]; then
  if [ ! -f "$TESTS_PASSED" ]; then
    BLOCKERS="${BLOCKERS}⚠️ テストが未検証です。テストを実行してください。\n"
    echo "blocker: tests not verified (no tests-passed file)" >&2
  else
    # tests-passed が pending より古ければ未検証扱い
    if [ "$PENDING_FILE" -nt "$TESTS_PASSED" ]; then
      BLOCKERS="${BLOCKERS}⚠️ テストが未検証です。テストを実行してください。\n"
      echo "blocker: tests-passed older than pending" >&2
    fi
  fi
fi

# チェック3: 3-Fix Limit（同一ファイルへの連続修正回数）
FIX_COUNT_FILE="$STATE_DIR/fix-retry-count"
if [ -f "$FIX_COUNT_FILE" ]; then
  FIX_COUNT=$(cat "$FIX_COUNT_FILE" 2>/dev/null | tr -d '[:space:]')
  if [ "$FIX_COUNT" -ge 3 ] 2>/dev/null; then
    BLOCKERS="${BLOCKERS}🛑 3-Fix Limit到達（${FIX_COUNT}回連続修正）。ブロッカープロトコルに従い、ユーザーに確認してください。\n"
    echo "blocker: 3-fix-limit reached ($FIX_COUNT)" >&2
  fi
fi

# ブロッカーがあれば出力（Claudeが作業を継続する）
if [ -n "$BLOCKERS" ]; then
  echo -e "$BLOCKERS"
fi

exit 0
