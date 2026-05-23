#!/usr/bin/env bash
# wiki-auto-capture-on-stop.sh — Stop hook
#
# vault 内 cwd の時、transcript に決定/教訓ワードが現れ、かつ
# wiki/meta/decisions.md が直近 30 分以内に更新されていない場合、警告を出す。
#
# 設計理由 (plan.md#phase-e):
# - 過去 2 回の Stop hook は echo のみで Claude が無視できた (inform-only failure)。
# - 初版は exit 0 で警告のみ、Phase 2 audit で効果不足なら exit 2 強化。
# - exit 2 即時化は Claude が無限に再 invoke される懸念があるため段階的アプローチ。

set -u

VAULT="$HOME/Documents/Obsidian Vault"

case "$PWD" in
  "$VAULT"|"$VAULT"/*) ;;
  *) exit 0 ;;
esac

INPUT=$(cat 2>/dev/null || true)
TRANSCRIPT=$(echo "$INPUT" | python3 -c "
import json, sys
try:
    d = json.loads(sys.stdin.read())
    print(d.get('transcript_path', ''))
except: print('')
" 2>/dev/null)

[ -z "$TRANSCRIPT" ] && exit 0
[ -f "$TRANSCRIPT" ] || exit 0

# assistant turn 本文から決定キーワード grep
HITS=$(python3 -c "
import json, sys
keywords = ['決定した', '採用し', '却下', '教訓', 'adopted', 'rejected as', 'lesson learned']
count = 0
try:
    with open('$TRANSCRIPT', encoding='utf-8') as f:
        for line in f:
            try:
                d = json.loads(line)
                if d.get('type') == 'assistant':
                    msg = d.get('message', {})
                    contents = msg.get('content', [])
                    if isinstance(contents, list):
                        for c in contents:
                            if isinstance(c, dict) and c.get('type') == 'text':
                                text = c.get('text', '')
                                if any(kw in text for kw in keywords):
                                    count += 1
                                    break
            except: pass
except: pass
print(count)
" 2>/dev/null)

[ -z "$HITS" ] && HITS=0
[ "$HITS" -lt 1 ] && exit 0

DECISIONS="$VAULT/wiki/meta/decisions.md"
if [ -f "$DECISIONS" ]; then
  NOW=$(date +%s)
  MTIME=$(stat -f '%m' "$DECISIONS" 2>/dev/null || echo 0)
  AGE=$((NOW - MTIME))
  # 直近 30 分以内に更新済み = capture 済み、警告不要
  if [ "$AGE" -lt 1800 ]; then
    exit 0
  fi
fi

echo ""
echo "💾 WIKI_AUTO_CAPTURE: このセッションで決定/教訓に関する議論が $HITS turn 検出されました。"
echo "   wiki/meta/decisions.md が直近 30 分以上更新されていません。"
echo "   重要な判断・教訓があった場合は \`wiki/meta/decisions.md\` に append してください："
echo "   $DECISIONS"
echo ""

exit 0
