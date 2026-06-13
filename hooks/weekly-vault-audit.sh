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
# audit 出力先は vault-level wiki/meta/_audit/ に集約 (rules/42 K-3: project 内 wiki/ 廃止・2026-06-13)
AUDIT_FILE="$VAULT/wiki/meta/_audit/AI_adscrm.md"
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
         "$VAULT/02_Ai/AI_adscrm/AIcrm/research/"*.md \
         "$VAULT/02_Ai/AI_adscrm/AIcrm/research/_raw/"*.md \
         "$VAULT/02_Ai/AI_adscrm/AIcrm/research/_archive/"*.md; do
  [ -f "$f" ] || continue
  # claude-mem 自動生成ファイル (AGENTS.md/CLAUDE.md) はスキップ。
  # frontmatter を足しても再生成で消えるため audit 対象外 (2026-06-10)。
  if head -1 "$f" 2>/dev/null | grep -q '<claude-mem-context>'; then
    continue
  fi
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
HOOK_REG=$(grep 'wiki/meta/project-registry' "$HOME/.claude/hooks/sessionstart-project-registry.sh" 2>/dev/null | head -1)
RULES41_REG=$(grep 'wiki/meta/project-registry' "$HOME/.claude/rules/41-vault-project-structure.md" 2>/dev/null | head -1)
RULES42_REG=$(grep 'wiki/meta/project-registry' "$HOME/.claude/rules/42-file-type-placement.md" 2>/dev/null | head -1)
[ -n "$HOOK_REG" ] || { result="${result}- ❌ registry: hook script に wiki/meta/project-registry 言及なし\n"; violations=$((violations + 1)); }
[ -n "$RULES41_REG" ] || { result="${result}- ❌ registry: rules/41 に wiki/meta/project-registry 言及なし\n"; violations=$((violations + 1)); }
[ -n "$RULES42_REG" ] || { result="${result}- ❌ registry: rules/42 に wiki/meta/project-registry 言及なし\n"; violations=$((violations + 1)); }

# ============================================================
# (検証 4 削除: 2026-05-17 X2 統合構成移行で AIads/AIcrm 両方の
#  measures.md が削除済のため。施策本体は repo `docs/measures-detail.md` 側に移譲)
# ============================================================

# ============================================================
# 検証 5: rules/42 K-3 違反 (project 内 wiki/ 廃止)
# 02_Ai/<group>/wiki/ ディレクトリ存在を検出。
# (2026-06-13: AI_adscrm/wiki/ 解体・audit 出力を wiki/meta/_audit/ へ移したため allowlist 撤去。
#  以後 project 内 wiki/ が再生成されたら違反として検出する)
# ============================================================
while IFS= read -r dir; do
  [ -z "$dir" ] && continue
  result="${result}- ❌ K-3 placement: ${dir#$VAULT/} - project 内 wiki/ は廃止 (rules/42 K-3、vault root wiki/meta/ に集約)\n"
  violations=$((violations + 1))
done < <(find "$VAULT/02_Ai" -maxdepth 3 -type d -name wiki 2>/dev/null)

# ============================================================
# 検証 6: rules/42 placement 違反 (repo 専用ファイルの vault 流入)
# repo 側 SSoT のファイル名が vault 内に存在 = drift サイン
# (A-2 phase-tracker / 0-4+0-5 施策実体 / C-1+C-2 データ系譜)
# ============================================================
for repo_only_file in phase-tracker.md measures-detail.md measure-impact-table.md data_lineage.yaml data-sources.md; do
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    result="${result}- ❌ placement: ${f#$VAULT/} - repo 専用ファイル名が vault に流入 (rules/42、正本は repo <project>/{tasks,docs}/)\n"
    violations=$((violations + 1))
  done < <(find "$VAULT" -type f -name "$repo_only_file" 2>/dev/null)
done

# ============================================================
# audit ファイル append-only 更新
# ============================================================
mkdir -p "$(dirname "$AUDIT_FILE")"

# 初回作成時はヘッダ (type: guide で rules/41 例外 type 扱い)
if [ ! -f "$AUDIT_FILE" ]; then
  cat > "$AUDIT_FILE" <<'EOF'
---
type: guide
folder: "wiki/meta/_audit/"
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
    echo "- ✅ all checks passed (frontmatter / ambiguity / registry / K-3 placement / repo-only files)"
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
