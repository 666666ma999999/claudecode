#!/bin/bash
# ~/.claude/hooks/weekly-vault-audit.sh
#
# 週次で vault プロジェクト構造の整合性を検証する。
# rules/41 ④章 grep 検証コマンドを統合実行し、結果を append-only audit ファイルに追記。
# launchd で週次起動 (~/Library/LaunchAgents/com.masa.vault-audit.plist 経由)。
# 違反検出時は SessionStart hook が次回起動時に warning 注入。
#
# 設計根拠: ~/.claude/plan.md L9「動く hook 1 個＋使われる住所録」+ rules/41 ④章 grep 検証
# Agent adversarial review (2026-05-16) で 5/14 同型 (人手依存→忘却) 回避策として追加

set -u

VAULT="$HOME/Documents/Obsidian Vault"
AUDIT_FILE="$VAULT/02_Ai/AI_adscrm/wiki/_audit.md"
STATE_FILE="$HOME/.claude/state/vault-audit-violations"
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# 違反カウンタ + 結果バッファ
violations=0
result=""

# ============================================================
# 検証 1: AI_adscrm/ frontmatter 6 必須フィールド (例外 type 除く)
# rules/41 ②章準拠
# ============================================================
for f in "$VAULT/02_Ai/AI_adscrm/"*.md \
         "$VAULT/02_Ai/AI_adscrm/wiki/"*.md; do
  [ -f "$f" ] || continue
  # 例外 type (concept/registry/guide) スキップ
  if awk '/^---$/{c++; if(c==2)exit} c==1' "$f" 2>/dev/null | grep -qE '^type: (concept|registry|guide)$'; then
    continue
  fi
  for key in 'project:' 'type:' 'folder:' 'categories:' 'last_updated:' 'tags:'; do
    if ! grep -q "^$key" "$f" 2>/dev/null; then
      result="${result}- ❌ frontmatter: $(basename "$f") - $key 欠落\n"
      violations=$((violations + 1))
    fi
  done
done

# ============================================================
# 検証 2: wikilink ambiguity (vault 全体・rules/41 ②章命名禁止)
# ============================================================
for name in plan.md measures.md progress.md index.md strategy.md hub.md; do
  count=$(find "$VAULT" -name "$name" 2>/dev/null | wc -l | tr -d ' ')
  # ai_dashboard/plan.md (既存・不変更) + wiki/index.md (既存・不変更) は許容
  if [ "$name" = "plan.md" ] && [ "$count" -le 1 ]; then continue; fi
  if [ "$name" = "index.md" ] && [ "$count" -le 1 ]; then continue; fi
  if [ "$count" -gt 0 ] && [ "$name" != "plan.md" ] && [ "$name" != "index.md" ]; then
    result="${result}- ❌ ambiguity: $name - $count 件 (rules/41 ②章 命名禁止違反)\n"
    violations=$((violations + 1))
  fi
done

# ============================================================
# 検証 3: registry hardcode 整合 (3 箇所)
# ============================================================
HOOK_REG=$(grep 'AI_adscrm/project-registry' "$HOME/.claude/hooks/sessionstart-project-registry.sh" 2>/dev/null | head -1)
RULES41_REG=$(grep 'AI_adscrm/project-registry' "$HOME/.claude/rules/41-vault-project-structure.md" 2>/dev/null | head -1)
RULES05_REG=$(grep 'AI_adscrm/project-registry' "$HOME/.claude/rules/05-plan-task-md.md" 2>/dev/null | head -1)
[ -n "$HOOK_REG" ] || { result="${result}- ❌ registry: hook script に AI_adscrm/project-registry 言及なし\n"; violations=$((violations + 1)); }
[ -n "$RULES41_REG" ] || { result="${result}- ❌ registry: rules/41 に AI_adscrm/project-registry 言及なし\n"; violations=$((violations + 1)); }
[ -n "$RULES05_REG" ] || { result="${result}- ❌ registry: rules/05 に AI_adscrm/project-registry 言及なし\n"; violations=$((violations + 1)); }

# ============================================================
# (検証 4 削除: 2026-05-17 X2 統合構成移行で AIads/AIcrm 両方の
#  measures.md が削除済のため。施策本体は repo `docs/measures-detail.md` 側に移譲)
# ============================================================

# ============================================================
# audit ファイル append-only 更新
# ============================================================
mkdir -p "$(dirname "$AUDIT_FILE")"

# 初回作成時はヘッダ (type: guide で rules/41 例外 type 扱い)
if [ ! -f "$AUDIT_FILE" ]; then
  cat > "$AUDIT_FILE" <<'EOF'
---
type: guide
folder: "02_Ai/AI_adscrm/wiki/"
last_updated: 2026-05-16
tags:
  - type/guide
---

# vault audit log

> append-only。weekly-vault-audit.sh が週次で追記。
> 違反検出時は SessionStart hook が次回起動時に warning 注入。
EOF
fi

{
  echo ""
  echo "## $TIMESTAMP (violations: $violations)"
  if [ "$violations" -eq 0 ]; then
    echo "- ✅ all checks passed (frontmatter / ambiguity / registry)"
  else
    echo -e "$result"
  fi
} >> "$AUDIT_FILE"

# ============================================================
# violations state 保存 (SessionStart hook で読む)
# ============================================================
mkdir -p "$(dirname "$STATE_FILE")"
echo "$violations" > "$STATE_FILE"
echo "$TIMESTAMP" > "${STATE_FILE}.timestamp"

exit 0
