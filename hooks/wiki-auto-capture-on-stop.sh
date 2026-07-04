#!/usr/bin/env bash
# wiki-auto-capture-on-stop.sh — Stop hook (Phase 2 拡張 2026-05-24)
#
# transcript に
#   (1) 決定/採用/却下 系キーワード → decisions.md (append-only)
#   (2) 教訓/失敗/再発 系キーワード → mistakes.md (de-dup 上書き型)
#   (3) 定石/運用知 系キーワード → /save playbook 促し (2026-07-04 第3系統・Playbook Memory)
# が出現し、かつ該当 md が直近 30 分以内に未更新の場合、警告を出す ((3) は stale 判定なし)。
#
# 設計理由 (plan.md#phase-e + Phase 2):
# - 過去 2 回の Stop hook は echo のみで Claude が無視できた (inform-only failure)
# - 初版 (2026-05-23 朝) は decisions.md 単系統。mistakes.md の capture が欠落
# - 二系統化版 (同日午後) で両 md が dormant 化しないよう独立に促す
# - Phase 2 (2026-05-24): vault path guard を撤去。repo cwd (~/Desktop/prm/*) で
#   開発中も発火させる (decisions.md 0 entry の根本原因対策)。vault file 操作はせず
#   stdout 警告のみのため、rules/40 「vault 外プロジェクトで vault 操作禁止」とは
#   両立する (この変更は decision として wiki/meta/decisions.md に記録予定)

set -u

VAULT="$HOME/Documents/Obsidian Vault"

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

# 二系統のキーワード群を独立に検出
COUNTS=$(python3 -c "
import json, sys
decision_kw = ['決定した', '採用し', '却下', 'adopted', 'rejected as', '方針確定', '確定し']
mistake_kw  = ['教訓', 'lesson learned', '失敗した', '再発した', '同じミス', '再発防止', 'recurring mistake', 'made the same']
playbook_kw = ['定石', '運用ルール化', '今後はこうする', '毎回こうする', '運用知', '確立ルール']
d_count, m_count, p_count = 0, 0, 0
try:
    with open('$TRANSCRIPT', encoding='utf-8') as f:
        for line in f:
            try:
                d = json.loads(line)
                if d.get('type') != 'assistant': continue
                msg = d.get('message', {})
                contents = msg.get('content', [])
                if not isinstance(contents, list): continue
                text = ''
                for c in contents:
                    if isinstance(c, dict) and c.get('type') == 'text':
                        text += c.get('text', '')
                hit_d = any(kw in text for kw in decision_kw)
                hit_m = any(kw in text for kw in mistake_kw)
                hit_p = any(kw in text for kw in playbook_kw)
                if hit_d: d_count += 1
                if hit_m: m_count += 1
                if hit_p: p_count += 1
            except: pass
except: pass
print(f'{d_count} {m_count} {p_count}')
" 2>/dev/null)

D_HITS=$(echo "$COUNTS" | awk '{print $1}')
M_HITS=$(echo "$COUNTS" | awk '{print $2}')
P_HITS=$(echo "$COUNTS" | awk '{print $3}')
[ -z "$D_HITS" ] && D_HITS=0
[ -z "$M_HITS" ] && M_HITS=0
[ -z "$P_HITS" ] && P_HITS=0

# 該当 md が直近 30 分以内に更新されているか判定
check_stale () {
  local file="$1"
  [ -f "$file" ] || { echo "stale"; return; }
  local now=$(date +%s)
  local mtime=$(stat -f '%m' "$file" 2>/dev/null || echo 0)
  local age=$((now - mtime))
  if [ "$age" -lt 1800 ]; then echo "fresh"; else echo "stale"; fi
}

DECISIONS="$VAULT/wiki/meta/decisions.md"
MISTAKES="$VAULT/wiki/meta/mistakes.md"
D_STALE=$(check_stale "$DECISIONS")
M_STALE=$(check_stale "$MISTAKES")

ANY_WARN=0

if [ "$D_HITS" -ge 1 ] && [ "$D_STALE" = "stale" ]; then
  echo ""
  echo "💾 WIKI_AUTO_CAPTURE [decisions]: 決定/採用/却下に関する議論が $D_HITS turn 検出されました。"
  echo "   wiki/meta/decisions.md が直近 30 分以上未更新。重要な判断があれば append してください："
  echo "   $DECISIONS"
  ANY_WARN=1
fi

if [ "$M_HITS" -ge 1 ] && [ "$M_STALE" = "stale" ]; then
  echo ""
  echo "💾 WIKI_AUTO_CAPTURE [mistakes]: 教訓/失敗/再発に関する議論が $M_HITS turn 検出されました。"
  echo "   wiki/meta/mistakes.md が直近 30 分以上未更新。同一パターン 2 回以上で 1 entry に統合 (de-dup)："
  echo "   $MISTAKES"
  echo "   ↳ 初回発生は新規追加、2 回目以降は既存 entry の「最終発生」「頻度」を更新"
  ANY_WARN=1
fi

if [ "$P_HITS" -ge 1 ]; then
  echo ""
  echo "💾 WIKI_AUTO_CAPTURE [playbook]: 定石/運用知に関する議論が $P_HITS turn 検出されました。"
  echo "   今後も守る定石・閾値なら \`/save playbook\` で当該 project の playbook (02_Ai/<group>/<sub>-playbook.md) へ保存を検討してください。"
  echo "   ↳ 保存された playbook の Must Remember は SessionStart で自動注入される (蓄積→翌セッション反映の両輪)"
  ANY_WARN=1
fi

[ "$ANY_WARN" -eq 1 ] && echo ""
exit 0
