#!/bin/bash
# ~/.claude/hooks/weekly-vault-audit.sh
#
# 週次で vault プロジェクト構造の整合性を検証する。
# rules/41 ④章 grep 検証コマンドを統合実行し、結果を append-only audit ファイルに追記。
# 実行: launchd `com.masa.vault-audit`（定期）+ 手動実行可（2026-07-15 訂正: 旧「launchd 未設定」記述は stale だった）。
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

# retention sweep 設定: dated な「自動生成 read-once」レポートを N 日経過で reports/_archive/ へ。
# 参照ドキュメント (type: progress 等) は type ゲートで永久保護。環境変数で日数上書き可。
SWEEP_DAYS="${VAULT_REPORT_RETENTION_DAYS:-14}"
swept=0
swept_log=""

# ============================================================
# 検証 1: AI_adscrm/ frontmatter 6 必須フィールド (例外 type 除く)
# rules/41 ②章準拠
# ============================================================
for f in "$VAULT/02_Ai/AI_adscrm/"*.md \
         "$VAULT/02_Ai/AI_adscrm/AIads/"*.md \
         "$VAULT/02_Ai/AI_adscrm/AIcrm/"*.md \
         "$VAULT/02_Ai/AI_adscrm/AIcrm/research/"*.md \
         "$VAULT/02_Ai/AI_adscrm/AIcrm/research/_raw/"*.md \
         "$VAULT/02_Ai/AI_adscrm/AIcrm/research/_archive/"*.md; do
  [ -f "$f" ] || continue
  # symlink (repo の NOW.md 等を Obsidian に出す「窓」) はスキップ。
  # 実体は repo 側にあり vault frontmatter を持たないため audit 対象外 (2026-06-14)。
  [ -L "$f" ] && continue
  # claude-mem 自動生成ファイル (AGENTS.md/CLAUDE.md) はスキップ。
  # frontmatter を足しても再生成で消えるため audit 対象外 (2026-06-10)。
  if head -1 "$f" 2>/dev/null | grep -q '<claude-mem-context>'; then
    continue
  fi
  # 本人手書き原文 (原文不改変・frontmatter 付与禁止・rules/41 R36) はスキップ (2026-07-18)。
  case "$(basename "$f")" in adscrm-role.md) continue;; esac
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
# 検証 7: MOC 内の自動フィード残存 (rules/41 §④・2026-06-14)
# 「## 🔁 最新更新ログ」は廃止 (人間が読まず・git log/decisions の劣化コピー)。
# MOC に残っていたら回帰違反として検出。
# ============================================================
while IFS= read -r f; do
  [ -z "$f" ] && continue
  result="${result}- ❌ auto-feed: ${f#$VAULT/} - 「## 🔁 最新更新ログ」は廃止 (rules/41 §④・MOC から撤去せよ)\n"
  violations=$((violations + 1))
done < <(grep -rlE "^## 🔁 最新更新ログ" "$VAULT/02_Ai" --include="*.md" 2>/dev/null)

# ============================================================
# 検証 7.5: 旧プロンプトモデル残存 (2026-06-26 cutover)
# _INBOX.md は新モデル「## 🔵 やってほしいこと / ## 📒 記録」に統一済み。
# 旧「## ✅ 完了（…1 行で残す）」が _INBOX に残っていたら未移行=回帰違反。
# ============================================================
while IFS= read -r f; do
  [ -z "$f" ] && continue
  result="${result}- ❌ prompt-model: ${f#$VAULT/} - 旧 _INBOX 構造「## ✅ 完了」が残存 (rules/41・📒 記録へ移行せよ)\n"
  violations=$((violations + 1))
done < <(grep -rlE "^## ✅ 完了" "$VAULT" --include="*_INBOX.md" 2>/dev/null)

# ============================================================
# 検証 8: retention sweep (read-once レポートの自動アーカイブ・2026-06-17)
# 「閲覧頻度=一回見たら終わる」自動生成 dated レポートを N 日経過で reports/_archive/ へ移動。
# 安全ゲート (誤掃き防止):
#   - 対象 type: (analysis かつ tag auto-generated) または weekly-spec-pulse のみ
#   - type: progress / moc / playbook 等の「参照ドキュメント」は日付付きでも永久保護
#   - 固定名 (overwrite モード・日付なし) は対象外 = 常に最新1枚を残す
#   - _archive/ 配下・symlink は対象外
# violations ではなく housekeeping (掃いた件数を info 行で記録)。reversible (mv のみ・削除しない)。
# ============================================================
now_epoch="$(date +%s)"
# reports/ は group 直下 (02_Ai/<g>/reports) と subproject 配下 (02_Ai/<g>/<sub>/reports) の両方を走査。
# _archive/ 配下は除外 (既に退避済み)。
for f in "$VAULT/02_Ai/"*/reports/*.md "$VAULT/02_Ai/"*/*/reports/*.md; do
  [ -f "$f" ] || continue
  [ -L "$f" ] && continue
  case "$f" in */_archive/*) continue ;; esac
  base="$(basename "$f" .md)"
  # 末尾が -YYYY-MM-DD のものだけ (dated)。固定名は末尾日付なし → 対象外
  fdate="$(printf '%s' "$base" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}$')"
  [ -n "$fdate" ] || continue
  # frontmatter type ゲート (--- ... --- の最初のブロック)
  fm="$(awk '/^---$/{c++; if(c==2)exit} c==1' "$f" 2>/dev/null)"
  ftype="$(printf '%s\n' "$fm" | awk -F':' '/^type:/{sub(/^[ \t]*/,"",$2); gsub(/[" \r]/,"",$2); print $2; exit}')"
  sweepable=0
  case "$ftype" in
    weekly-spec-pulse) sweepable=1 ;;
    analysis) printf '%s\n' "$fm" | grep -qE '^[[:space:]]*-[[:space:]]*auto-generated[[:space:]]*$' && sweepable=1 ;;
  esac
  [ "$sweepable" -eq 1 ] || continue
  # 経過日数判定 (macOS date)
  fepoch="$(date -j -f "%Y-%m-%d" "$fdate" "+%s" 2>/dev/null)" || continue
  age_days=$(( (now_epoch - fepoch) / 86400 ))
  [ "$age_days" -gt "$SWEEP_DAYS" ] || continue
  arch_dir="$(dirname "$f")/_archive"
  mkdir -p "$arch_dir"
  if mv "$f" "$arch_dir/" 2>/dev/null; then
    swept=$((swept + 1))
    swept_log="${swept_log}- 🧹 swept (${age_days}d > ${SWEEP_DAYS}d): ${f#$VAULT/} → _archive/\n"
  fi
done

# ============================================================
# 検証 9: 常時ロード再肥大ガード (2026-07-04・記事40選採用 T5)
# CLAUDE.md + rules/{05,10,30,41,42} の合計バイト数が baseline+20% を超えたら違反。
# baseline = 2026-07-04 スリム化直後の wc -c 実測合計 (31,810B)。
# MEMORY.md だけ hook 保護され CLAUDE.md/rules が無防備だった非対称の解消。
# ============================================================
ALWAYS_LOADED_BASELINE=31810
al_total=0
for f in "$HOME/.claude/CLAUDE.md" \
         "$HOME/.claude/rules/05-plan-task-md.md" \
         "$HOME/.claude/rules/10-git-and-execution-guard.md" \
         "$HOME/.claude/rules/30-routing.md" \
         "$HOME/.claude/rules/41-vault-project-structure.md" \
         "$HOME/.claude/rules/42-file-type-placement.md"; do
  [ -f "$f" ] || continue
  sz=$(wc -c < "$f" | tr -d ' ')
  al_total=$((al_total + sz))
done
al_limit=$((ALWAYS_LOADED_BASELINE * 120 / 100))
if [ "$al_total" -gt "$al_limit" ]; then
  result="${result}- ❌ context-bloat: 常時ロード合計 ${al_total}B > 上限 ${al_limit}B (baseline ${ALWAYS_LOADED_BASELINE}B+20%・スリム化の巻き戻り。詳細は docs/ へ委譲せよ)\n"
  violations=$((violations + 1))
fi

# ============================================================
# 検証 10: playbook Must Remember bullet 数 >15 検出 (2026-07-04)
# sessionstart-project-registry.sh:105 が head -15 で注入するため 16 本目以降は
# 静かに注入落ちする (make_article で実際に発生)。超過を回帰違反として検出。
# ============================================================
while IFS= read -r f; do
  [ -z "$f" ] && continue
  mr_count=$(awk '/^## Must Remember/{f=1;next} /^## /{f=0} f' "$f" 2>/dev/null | grep -cE '^[[:space:]]*[-*] ')
  if [ "$mr_count" -gt 15 ]; then
    result="${result}- ❌ must-remember-overflow: ${f#$VAULT/} - bullet ${mr_count} 本 > 15 (head -15 で注入落ち・統合して 15 以内へ)\n"
    violations=$((violations + 1))
  fi
done < <(grep -rlE "^## Must Remember" "$VAULT/02_Ai" --include="*-playbook.md" 2>/dev/null)

# ============================================================
# 検証 11: reports/ 直下の dated 手作成ファイル 30日超 warn (2026-07-08 ✅3)
# 検証8 sweep の対象外 (auto-generated でない提案書・handover 等) は自動移動しない
# (D2「無人書込はハブ追記型・移動は人間ゲート」)。30日超を warn として列挙し
# 退避コマンドを添える。violations には数えない (housekeeping)。
# ============================================================
stale_reports=""
for f in "$VAULT/02_Ai/"*/reports/*.md "$VAULT/02_Ai/"*/*/reports/*.md; do
  [ -f "$f" ] || continue
  [ -L "$f" ] && continue
  case "$f" in */_archive/*) continue ;; esac
  base="$(basename "$f" .md)"
  fdate="$(printf '%s' "$base" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}$')"
  [ -n "$fdate" ] || continue
  fepoch="$(date -j -f "%Y-%m-%d" "$fdate" "+%s" 2>/dev/null)" || continue
  age_days=$(( (now_epoch - fepoch) / 86400 ))
  [ "$age_days" -gt 30 ] || continue
  stale_reports="${stale_reports}- 🟡 stale-report (${age_days}d): ${f#$VAULT/} → 退避は人間✅で: mv \"$f\" \"$(dirname "$f")/_archive/\"\n"
done

# ============================================================
# 検証 12: 承認カード block id (^why-*) の def/ref 突合 (2026-07-08 ✅3)
# 参照 [[note#^why-...]] の id が定義 (^why-... 行) に実在するか。固定名ボードの
# 書き換えで id が落ちると契約2本+result の理由資料リンクが静かに死ぬため機械検知。
# ============================================================
why_defs="$(grep -rhoE '(^|[[:space:]])\^why-[A-Za-z0-9-]+[[:space:]]*$' "$VAULT/02_Ai" --include="*.md" 2>/dev/null | grep -oE 'why-[A-Za-z0-9-]+' | sort -u)"
why_refs="$(grep -rhoE '#\^why-[A-Za-z0-9-]+' "$VAULT" --include="*.md" 2>/dev/null | grep -oE 'why-[A-Za-z0-9-]+' | sort -u)"
for rid in $why_refs; do
  if ! printf '%s\n' "$why_defs" | grep -qx "$rid"; then
    result="${result}- ❌ why-link-broken: 参照 #^${rid} の定義行 (^${rid}) が 02_Ai 配下に見つからない (承認カードの理由資料が断線)\n"
    violations=$((violations + 1))
  fi
done

# ============================================================
# 検証 13: 大文字小文字だけ違う重複ディレクトリ + broken symlink (2026-07-08 ✅3)
# git は 02_Ai/02_ai を別物として追跡できるため (macOS 非区別で偶然動くだけ)、
# vault git index のトップレベル重複を warn。加えて 02_Ai 配下の切れた symlink を検出。
# ============================================================
case_dups="$(git -C "$VAULT" ls-tree HEAD --name-only 2>/dev/null | awk '{print tolower($0)}' | sort | uniq -d)"
if [ -n "$case_dups" ]; then
  result="${result}- ❌ case-split: vault git のトップレベルに大文字小文字だけ違う重複名: $(echo "$case_dups" | tr '\n' ' ') (git mv 2段で統一せよ)\n"
  violations=$((violations + 1))
fi
while IFS= read -r sl; do
  [ -z "$sl" ] && continue
  result="${result}- ❌ broken-symlink: ${sl#$VAULT/} - リンク先不在 (窓が死んでいる。実体の git 管理化 or ミラー方式へ)\n"
  violations=$((violations + 1))
done < <(find "$VAULT/02_Ai" -type l ! -exec test -e {} \; -print 2>/dev/null)

# ============================================================
# 検証 14: 司令塔CP章の骨格検査 (2026-07-08 金標準恒久化・warn相当)
# gate --cp-sections で ⏱/窓/原因/判定/①〜④/状態タグ等の存在を週次でも機械検査
# (runner 経路の検査と二重化・手動編集での骨格崩れも拾う)。violations に計上。
# ============================================================
CPG_PY="$HOME/.claude/scripts/report_action_presence_gate.py"
CPG_BOARD="$VAULT/02_Ai/AI_adscrm/AIads/boards/AIads-cp-review.md"
if [ -f "$CPG_PY" ] && [ -f "$CPG_BOARD" ]; then
  if ! cpg_out="$(/usr/bin/python3 "$CPG_PY" --cp-sections "$CPG_BOARD" 2>/dev/null)"; then
    result="${result}- ❌ cp-sections: $(printf '%s' "$cpg_out" | head -1 | cut -c1-200) (CP章の金標準要素が欠落)\n"
    violations=$((violations + 1))
  fi
fi

# ============================================================
# 検証 15: グローバルルール層 vs wiki/meta サマリの同期ドリフト (2026-07-09)
# 「グローバルルールを変えたら wiki/meta のまとめも同セッション同期」が文章の約束のまま
# 破られた実例 (2026-07-09 Bases窓グローバル化) の再発防止。3日猶予つき mtime 突合。
# ============================================================
WIKI_SUM="$VAULT/wiki/meta/file-placement-rules.md"
if [ -f "$WIKI_SUM" ]; then
  sum_m=$(stat -f %m "$WIKI_SUM" 2>/dev/null || echo 0)
  for gsrc in "$HOME/.claude/rules/42-file-type-placement.md" "$VAULT/templates/cockpit-report.md" "$HOME/.claude/skills/vault-report-writing/SKILL.md"; do
    [ -f "$gsrc" ] || continue
    g_m=$(stat -f %m "$gsrc" 2>/dev/null || echo 0)
    if [ $((g_m - sum_m)) -gt 259200 ]; then
      result="${result}- ❌ wiki-sync-drift: $(basename "$gsrc") が wiki/meta/file-placement-rules.md より3日以上新しい (グローバルルール変更のwiki側同期漏れの疑い。同期不要なら file-placement-rules の last_updated を当日化して解消)\n"
      violations=$((violations + 1))
      break
    fi
  done
fi

# ============================================================
# 検証 17: research 台帳 (2026-07-09 グローバル新設・skill vault-research-ledger)
# (a) research/ を持つ project に台帳 _summary.md が必須
# (b) bare [[_summary]] リンク禁止 (basename 衝突があるため path-qualified 必須)
# ※ 2026-07-15 修理: マージ残骸でヘッダが欠損し裸行 ==== が実行時エラーを出していた
# ============================================================
for rdir in "$VAULT/02_Ai"/*/research "$VAULT/02_Ai"/*/*/research; do
  [ -d "$rdir" ] || continue
  if [ ! -f "$rdir/_summary.md" ]; then
    result="${result}- ❌ research-ledger: ${rdir#$VAULT/} に台帳 _summary.md が無い (雛形 = templates/research-summary.md・skill vault-research-ledger)\n"
    violations=$((violations + 1))
  fi
done
bare_files=$(grep -rlF --include='*.md' '[[_summary]]' "$VAULT" 2>/dev/null \
  | grep -v "^$VAULT/templates/" \
  | grep -v "wiki/meta/decisions.md" \
  | grep -v "wiki/meta/_audit/" \
  | grep -v "03_ClaudeEnv/" \
  | grep -v "/research/" \
  | grep -v "/_archive/" \
  | head -5)
# _audit/=違反メッセージ自身が [[_summary]] を含む自己参照 / 03_ClaudeEnv/=計器盤の diff 引用（code 内・linkify されない）— 2026-07-15 誤検知除外
if [ -n "$bare_files" ]; then
  bare_cnt=$(printf '%s\n' "$bare_files" | wc -l | tr -d ' ')
  result="${result}- ❌ research-ledger: bare [[_summary]] リンク ${bare_cnt} ファイル (path-qualified [[<path>/research/_summary|…]] へ修正・skill vault-research-ledger): $(printf '%s' "$bare_files" | tr '\n' ' ' | sed "s|$VAULT/||g")\n"
  violations=$((violations + 1))
fi

# ============================================================
# 検証 16: vault git 健全性 + プロジェクトフォルダ構造ガード (2026-07-07)
# 実事故: 2026-07-06 22:54 MASA.local 側で AIads/ が「売りあて/」に意図せずリネーム
# → git merge が衝突で 12h+ 停止・自動バックアップ停止・別セッションがリネームに追従改修。
# (a) 止まったマージ (MERGE_HEAD 残存 / unmerged paths / obsidian-git 衝突メモ) を検出
# (b) 必須プロジェクトフォルダの実在を確認 (消えた=リネーム/削除の疑い)
# ネットワーク非依存 (fetch しない・既存 ref のみ)。
# ============================================================
if [ -d "$VAULT/.git" ]; then
  if [ -f "$VAULT/.git/MERGE_HEAD" ]; then
    result="${result}- ❌ git-health: マージが未完了のまま停止中 (MERGE_HEAD 残存)。自動バックアップが止まっている。衝突を解消して commit せよ\n"
    violations=$((violations + 1))
  fi
  if [ -n "$(git -C "$VAULT" ls-files -u 2>/dev/null | head -1)" ]; then
    result="${result}- ❌ git-health: unmerged paths (衝突未解消ファイル) が残存\n"
    violations=$((violations + 1))
  fi
  if [ -f "$VAULT/conflict-files-obsidian-git.md" ] && [ ! -f "$VAULT/.git/MERGE_HEAD" ]; then
    # 衝突は解消済みなのにメモが残存 = obsidian-git が未削除 (info 扱いにせず軽微違反で可視化)
    result="${result}- ❌ git-health: conflict-files-obsidian-git.md が残存 (衝突解消済みなら削除してよい)\n"
    violations=$((violations + 1))
  fi
fi
for required_dir in "02_Ai/AI_adscrm/AIads" "02_Ai/AI_adscrm/AIcrm"; do
  if [ ! -d "$VAULT/$required_dir" ]; then
    result="${result}- ❌ structure: $required_dir が存在しない (意図しないリネーム/削除の疑い。git log で直近の rename を確認し復旧せよ。実例: 2026-07-06 売りあて事故)\n"
    violations=$((violations + 1))
  fi
done

# ============================================================
# 検証 17: research 台帳整合 (2026-07-10・skill vault-research-ledger)
# 採用済み research/ には台帳 _summary.md 必須 + bare [[_summary]] リンク禁止
# (固定名のため複数 project 展開で曖昧リンク化する。path-qualified 必須)
# 除外: templates/ (雛形は説明文に literal を含む) / wiki/meta/decisions.md (append-only・
#       過去エントリ編集禁止) / research/ 配下 (2026-07-10 以前の自己参照 legacy を grandfather。
#       skill が新規は path-qualified を義務化済み・検知面は MOC と一般ファイル)
# ============================================================
# 検証 18: repo task 退場滞留 (2026-07-15・rules/05 出口ルール / 同日 全 project 化)
# project-registry の **root**: 行から対象 repo を発見し (新 config 不要・registry が住所録の
# 正本)、NOW.md の Done/Superseded に記載済みの task md の tasks/ 直下残存を警告する。
# 誤検知ガード (2026-07-15 敵対レビュー指摘):
#   (a) config/*.yaml の task_md: が指す basename = 機械入力につき除外 (rules/05 と同じ事前検索)
#   (b) Done 掲載 = 14 日以上未更新のファイルのみ nag (「レビュー期日待ち」の意図的残置を許容)
#   (c) Superseded 掲載 = 即 nag
#   (d) 見出しは tolower 比較 (templates/now-done.md の ## DONE 表記とも整合)
# ============================================================
REGISTRY_MD="$VAULT/wiki/meta/project-registry.md"
if [ -f "$REGISTRY_MD" ]; then
  registry_roots=$(grep -oE '\*\*root\*\*: `[^`]+`' "$REGISTRY_MD" | sed -E 's/.*`([^`]+)`.*/\1/')
  for proot in $registry_roots; do
    case "$proot" in "~"*) proot="$HOME${proot#\~}";; esac
    [ -d "$proot" ] || continue
    machine_refs=$(grep -hoE 'task_md:[^#]*' "$proot"/config/*.yaml "$proot"/*/config/*.yaml 2>/dev/null | grep -oE '[A-Za-z0-9._-]+\.md' | sort -u)
    for now_md in "$proot/tasks/NOW.md" "$proot"/*/tasks/NOW.md; do
      [ -f "$now_md" ] || continue
      tasks_dir=$(dirname "$now_md")
      loc="${tasks_dir#"$HOME"/}"
      done_section=$(awk '{l=tolower($0)} l ~ /^## /{flag=0} l ~ /^## done/{flag=1} l ~ /^## superseded/{flag=2} flag{print flag":"$0}' "$now_md")
      [ -n "$done_section" ] || continue
      for f in "$tasks_dir"/*.md; do
        [ -f "$f" ] || continue
        base=$(basename "$f")
        case "$base" in NOW.md|CLAUDE.md|phase-tracker.md|lessons.md) continue;; esac
        if printf '%s\n' "$machine_refs" | grep -qxF "$base"; then continue; fi
        if printf '%s\n' "$done_section" | grep -F "$base" | grep -q '^2:'; then
          result="${result}- ❌ task-exit: ${loc}/${base} は NOW.md の Superseded 記載済みなのに直下に残存 (同セッションで tasks/archive/ へ退避・rules/05)\n"
          violations=$((violations + 1))
        elif printf '%s\n' "$done_section" | grep -F "$base" | grep -q '^1:'; then
          if [ -n "$(find "$f" -mtime +14 2>/dev/null)" ]; then
            result="${result}- ❌ task-exit: ${loc}/${base} は NOW.md の Done 記載済み・14日以上未更新のまま直下に残存 (tasks/archive/ へ退避・rules/05)\n"
            violations=$((violations + 1))
          fi
        fi
      done
    done
  done
fi

# 検証 19: superseded レポート/調査の vault 直下残存 (2026-07-16・rules/41 出口ルール R33-36)
# frontmatter `supersedes: [[旧版]]` を持つ後継があり、その旧版が同 reports/ 直下に living 残存
# = repo 退避対象 (R35「更新済み調査の旧版は repo へ」)。
# R34(定期レポ3世代超)/R33(ジャッジ済み) は誤検知回避のため機械検知せず、rules/41 出口ルール +
# 人手/AI 退避に委ねる (機械は確実な supersedes 被参照のみ warn)。
# R36 例外: 本人手書き *_MEMO.md は退避対象外につき除外。
for rdir in "$VAULT"/02_Ai/*/reports "$VAULT"/02_Ai/*/*/reports; do
  [ -d "$rdir" ] || continue
  loc="${rdir#"$VAULT"/}"
  for f in "$rdir"/*.md; do
    [ -f "$f" ] || continue
    case "$(basename "$f")" in *_MEMO*) continue;; esac
    sups=$(grep -oE 'supersedes:.*' "$f" 2>/dev/null | grep -oE '\[\[[^]]+\]\]' | tr -d '[]')
    for s in $sups; do
      sbase=$(basename "$s" .md)
      if [ -f "$rdir/$sbase.md" ]; then
        result="${result}- ⚠️ report-exit(R35): ${loc}/${sbase}.md は後継 $(basename "$f" .md) に superseded 済みなのに vault 直下に残存 (repo へ退避・rules/41 出口ルール)\n"
        violations=$((violations + 1))
      fi
    done
  done
done

# ============================================================
# 検証 20: dead link 双方向検知 (2026-07-17・rules/41 §④ 逆参照ガード機械化)
# 実事故: 2026-07-17 レポート統合で repo NOW.md の設計 SSoT file:// リンクが断線
# (旧 audit は wikilink ambiguity のみで検知不能だった)。
# 実体は scripts/vault_dead_link_check.py (macOS bash 3.2 は <() 内 heredoc を
# パースできないため外部ファイル化・2026-07-17)。
# (a) AI_adscrm 現役文書の dead wikilink (b) vault→repo file:// (c) repo→vault 逆参照
# 除外: _archive/・_INBOX・AGENTS/CLAUDE・*-result.md・symlink・code fence/inline code 内
# ============================================================
DLC_PY="$HOME/.claude/scripts/vault_dead_link_check.py"
if [ -f "$DLC_PY" ]; then
  while IFS= read -r dl_line; do
    [ -z "$dl_line" ] && continue
    result="${result}- ❌ ${dl_line}\n"
    violations=$((violations + 1))
  done < <(/usr/bin/python3 "$DLC_PY" 2>/dev/null)
fi

# ============================================================
# 検証 21: ドラフト滞留 + 名前と状態の乖離 (2026-07-18・rules/41 §④ ドラフト運用)
# 実事故: x-operation-rework DRAFT 580行が2ヶ月化石化 / delegation-charter-draft が
# 採択済みのまま -draft 名で残存。判定キーは basename *-draft.md（大文字/下線ゆらぎ含む）。
# (a) 30日超の未決着ドラフト → 🟡 warn (housekeeping・移動は人間ゲート)
# (b) 承認済み(✅/approved)なのに -draft 名のまま → ❌ 違反 (名前か置き場を動かせ)
# ============================================================
draft_stale=""
while IFS= read -r f; do
  [ -z "$f" ] && continue
  case "$f" in */_archive/*|*/works/*|*/ai_dashboard/*|*/rohan/*) continue ;; esac  # 既存プロジェクトは rules/41 適用外
  fst="$(awk '/^---$/{c++; if(c==2)exit} c==1' "$f" 2>/dev/null | grep -E '^status:' | head -1)"
  if printf '%s' "$fst" | grep -qE '✅|採択|approved|承認'; then
    result="${result}- ❌ draft-drift: ${f#$VAULT/} - 承認済みなのに -draft 名のまま (rules/41 §④: -draft を外すか _archive/ へ)\n"
    violations=$((violations + 1))
    continue
  fi
  fm_epoch=""
  fdate="$(awk '/^---$/{c++; if(c==2)exit} c==1' "$f" 2>/dev/null | grep -E '^last_updated:' | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)"
  [ -n "$fdate" ] && fm_epoch="$(date -j -f "%Y-%m-%d" "$fdate" "+%s" 2>/dev/null)"
  [ -z "$fm_epoch" ] && fm_epoch="$(stat -f %m "$f" 2>/dev/null || echo "$now_epoch")"
  d_age=$(( (now_epoch - fm_epoch) / 86400 ))
  if [ "$d_age" -gt 30 ]; then
    draft_stale="${draft_stale}- 🟡 draft-stale (${d_age}d): ${f#$VAULT/} - 30日超の未決着ドラフト (決裁するか closure: abandoned で箱内 _archive/ へ)\n"
  fi
done < <(find "$VAULT/02_Ai" "$VAULT/03_ClaudeEnv" -type f \( -iname "*-draft.md" -o -iname "*_draft.md" \) 2>/dev/null)

# ============================================================
# 検証 22: 平文シークレットの vault 流入 (2026-07-19)
# 実事故: totty(previous).md / vivecoring_memo.md 他 5 ファイルに実 API キー 6 本
# (Anthropic2/OpenAI3/Google1) が平文で残存し、private repo とはいえ GitHub 履歴へ同期
# されていた。伏せ字化しても履歴には残るため、流入そのものを毎週止める。
# 判定: 実キーのプレフィクス形状のみ (伏せ字 REDACTED_* とダミー XXXX 末尾は除外)。
# 検出値は絶対に出力しない (ファイル名・行番号・種別のみ)。
# ============================================================
while IFS= read -r hit; do
  [ -z "$hit" ] && continue
  result="${result}- ❌ secret-in-vault: ${hit} (鍵を無効化 → 伏せ字化 → 値は ~/.zshrc の export へ・secret-management skill)\n"
  violations=$((violations + 1))
done < <(
  grep -rnE '(sk-ant-api03-|sk-proj-|AIzaSy|AKIA[0-9A-Z]{16})[A-Za-z0-9_-]{15,}' "$VAULT" \
    --include="*.md" --include="*.json" --include="*.txt" --include="*.py" --include="*.sh" \
    --include="*.yaml" --include="*.yml" 2>/dev/null \
    | grep -v '/\.git/' | grep -v 'REDACTED_' | grep -vE 'XXXX' \
    | awk -F: -v v="$VAULT/" '{
        kind = "unknown";
        if ($0 ~ /sk-ant-api03-/) kind = "Anthropic";
        else if ($0 ~ /sk-proj-/) kind = "OpenAI";
        else if ($0 ~ /AIzaSy/) kind = "Google";
        else if ($0 ~ /AKIA/) kind = "AWS";
        f = $1; sub(v, "", f);
        print f " 行" $2 " (" kind ")";
      }'
)

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
  echo "## $TIMESTAMP (violations: $violations, swept: $swept)"
  if [ "$violations" -eq 0 ]; then
    echo "- ✅ all checks passed (frontmatter / ambiguity / registry / K-3 placement / repo-only files / context-bloat / must-remember / git-health / structure)"
  else
    echo -e "$result"
  fi
  if [ "$swept" -gt 0 ]; then
    echo -e "$swept_log"
  fi
  if [ -n "$stale_reports" ]; then
    echo -e "$stale_reports"
  fi
  if [ -n "$draft_stale" ]; then
    echo -e "$draft_stale"
  fi
} >> "$AUDIT_FILE"

# ============================================================
# violations state 保存 (SessionStart hook で読む)
# ============================================================
mkdir -p "$(dirname "$STATE_FILE")"
echo "$violations" > "$STATE_FILE"
echo "$TIMESTAMP" > "${STATE_FILE}.timestamp"

exit 0
