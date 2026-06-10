---
name: finding-sync
description: 分析で確定知見が出たときに、findings ノート + key_findings.md + (任意) decision_log + executive_summary + vault MOC を一貫して更新する半自動化スキル。詳細手順は prime_crm/docs/findings-workflow.md。
triggers:
  - 新しい発見
  - 確定知見
  - finding 追記
  - key_findings 更新
  - 知見台帳
  - findings ledger
  - /finding
not_for:
  - 仮説の追加（→ hypotheses_backlog.md に直接追記）
  - 議論経緯のみの記録（→ decision_log.md に直接 DL-NNN 起票）
  - データ集計スクリプト自体の実装（→ scripts/analysis/ に Python で書く）
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
---

# finding-sync スキル

分析で **確定数値** が出たときに、prime_crm の 6+1 ファイルを一貫した状態に保つための半自動化フロー。

完全な運用ルールは `prime_crm/docs/findings-workflow.md` を参照。本スキルはその STEP 1-5 のうち、機械的な雛形生成 + 整合性チェック部分を担当する。

## 起動条件

以下のいずれかが満たされたとき:

- ユーザーが `/finding <slug> <分類>` を入力した
- ユーザーが「新しい確定知見を台帳に登録したい」と述べた
- 分析スクリプトの実行結果が出て、その結果を恒久記録したい

## 処理フロー (人手 + 機械の協調)

### STEP 0: 起動前確認 (機械)

```bash
# prime_crm ルートを確認
[ -d "prime_crm/reports" ] && [ -f "prime_crm/reports/key_findings.md" ] || abort
# Phase 0 緊急修正済みかチェック (pre-commit hook が finding-sync 後に block しないように)
[ -f ".git/hooks/pre-commit" ] && grep -q "G1: finding_id 重複検知" ".git/hooks/pre-commit" || warn
```

### STEP 1: 入力収集 (人手)

ユーザーから以下を収集:

1. **finding_id 分類** (C/A/P/X/D — `I` は intent ID と衝突するため使わない・必要なら IN-N)
2. **slug** (英小文字ハイフン区切り・最大 4 トークン)
3. **生成元スクリプト** (パスを明示)
4. **依存 pkl** (リスト)
5. **spec 参照** (例: §1.12)
6. **数値の概要** (1 行)

不足があれば AskUserQuestion で収集。

### STEP 2: finding_id 連番の決定 (機械)

```bash
# 既存の同分類最大番号 + 1
MAX=$(grep -oE "^\| ${PREFIX}[0-9]+ " prime_crm/reports/key_findings.md | grep -oE '[0-9]+' | sort -n | tail -1)
NEW_ID="${PREFIX}$((MAX + 1))"
```

ユーザーに「次の ID は `C7` で良いか?」と確認 (AskUserQuestion)。

### STEP 3: findings ノート生成 (機械)

`prime_crm/tasks/findings/YYYY-MM-DD-<slug>.md` を以下のテンプレートで作成:

```markdown
---
finding_id: <NEW_ID>
stage: Conf
generated_at: YYYY-MM-DD
script: <生成元スクリプト>
pkl_deps:
  - <pkl1>
  - <pkl2>
spec_ref: <spec §X.X>
pii_checked: true
kanon_blocked: false
---

# Finding: <タイトル>

**発見日**: YYYY-MM-DD
**分類**: <顧客行動 / 占い師構造 / 商品 / cross-sell / intent / 設計方針>
**実装スコープ**: なし (発見ノート)
**昇格先 task 候補**: __TBD__

## 発見した事実

__数値表をここに記入__

## 出典

- 生成元: `<script>`
- 依存 pkl: `<pkl_deps>`
- spec 参照: <spec §X.X>

## 含意 (経営判断への影響)

__1-3 項目に分けて記入__

## 次アクション候補

__1-4 項目__

## 関連

- key_findings.md <NEW_ID>
- <他の関連 finding>
```

### STEP 4: key_findings に 1 行追加 (機械 + 人手)

該当セクション (C/A/P/X/I/D) の末尾に挿入:

```markdown
| <NEW_ID> | **__タイトル__** | __NUM__ | __含意 / 採用方針__ | [<slug>](../tasks/findings/YYYY-MM-DD-<slug>.md) |
```

`__NUM__` プレースホルダーは人手で実数値に置換。

### STEP 5: 意思決定の有無を確認 (人手)

AskUserQuestion で「この知見は不変ルール変更や採用/却下の分岐を含むか?」

- Yes → `decision_log.md` に DL-NNN 起票を促す (DL 番号は連番で最大+1)
- No → skip

### STEP 6: 上位サマリ更新 (機械 + 人手)

経営判断インパクト判定:

- LTV / リピート率 / cross-sell 等の中核数値を ±5pt 以上動かすか?
- Yes → `executive_summary.md` の更新を促す
- No → skip

### STEP 7: vault MOC 更新 (機械)

vault が同マシン上に存在する場合のみ実行:

```bash
VAULT_MOC="$HOME/Documents/Obsidian Vault/02_Ai/AI_adscrm/AIcrm/AIcrm_ope.md"
if [ -f "$VAULT_MOC" ]; then
  # last_updated を当日に更新
  # SECURITY.md V1-V5 の vault 固有ルールに従って数値丸め判定をユーザーに確認
fi
```

`SECURITY.md` の **V1-V5 (vault 固有ルール)** に該当する数値の丸め判断はユーザーに確認 (機械化禁止)。

### STEP 8: 検証 (機械)

```bash
# pre-commit hook を dry-run
bash .git/hooks/pre-commit  # ステージング前なので空 exit
# G1-G6 が pass することを確認
```

VIOLATIONS=0 を確認してから完了報告。

## 機械化しない部分 (人手レビュー必須)

- 数値妥当性の最終承認
- 分類 (C/A/P/X/D/IN) の確定
- decision_log の採用/却下判断
- executive_summary の表現調整
- vault 側の数値丸めルール (V1) 適用判断

## エラー処理

- `__NUM__` が key_findings に残ったまま commit しようとした → G1 ガードでは block されないが、レビューで指摘
- finding_id 重複 → G1 ガードで block
- D 行に DL リンク欠落 → G6 ガードで block
- H 系が key_findings に紛れた → G5 ガードで block

## 関連スキル

- `data-provenance-first`: 出典管理 (pkl + script + spec の 3 点セット)
- `task-progress`: task.md 進捗管理
- `obsidian-now-done`: vault NOW→DONE 移動 (本スキルからは呼ばない・MOC last_updated 更新のみ担当)
- `find-skills`: 他のスキル検索

## 関連ドキュメント

- `prime_crm/docs/findings-workflow.md` — 5 ステップ + 4 トリガー × 手順 + ガード詳細
- `prime_crm/reports/key_findings.md` — 確定知見の台帳 (正本)
- `prime_crm/reports/hypotheses_backlog.md` — 検証待ち仮説
- `prime_crm/reports/decision_log.md` — 議論経緯
- `prime_crm/SECURITY.md` V1-V5 — vault 固有ルール
- `prime_crm/hooks/pre-commit` — G1-G6 ガード実装

## 変更履歴

- 2026-05-22: 初版 (Phase 2・4 並列 Agent + Codex 設計の統合実装)
