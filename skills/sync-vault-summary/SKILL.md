---
name: sync-vault-summary
description: >
  ⚠️2026-06-14 RETIRED: MOC「🔁最新更新ログ」append(=last_updated更新)は廃止・no-op。
  現状有効なのは list(候補抽出)/resolve(repo→MOC解決)/issues(Open Issuesミラー)のみ。
  rules/42対象ファイル(plan/measures/spec/analysis/CLAUDE/README/data-sources等)の
  vault MOC(02_Ai/<group>/<sub>_ope.md)同期スキル。全面改訂は vault-restructure-proposal 待ち。
  Triggers: /sync-vault-summary, vault MOC同期, MOC更新, vaultサマリー追記,
  VAULT_SUMMARY_SUGGEST(Stop hook警告).
  NOT for: MOC本文の実データ設計→vault-report-writing / 施策状態同期義務→rules/41 §④。
allowed-tools: Read Write Edit Bash Glob Grep
---

# sync-vault-summary

## 発火・詳細（description から移設 2026-07-03）

rules/42 対象ファイル (plan/measures/spec/analysis/CLAUDE/README/data-sources 等) を Claude 自身が 1-3 行に要約し、vault MOC (02_Ai/`<group>`/`<sub>`_ope.md) の 「🔁 最新更新ログ」セクションに prepend、frontmatter last_updated を当日へ更新する。 edit-history.jsonl (同 session の Edit/Write) と git diff を source of truth とする。 Triggers on: "/sync-vault-summary", "vault MOC 同期", "MOC 更新", "vault サマリー追記", "VAULT_SUMMARY_SUGGEST" (Stop hook 警告を見たとき).

> **⚠️ 現状（2026-07-11 実測）**: 起動フラグ `~/.claude/state/vault-cc-enabled` が**不在のため、本 skill は STEP 0 で常に即 abort する**（現役の list/resolve/issues も動かない）。使う場合はフラグを作成してから。
>
> **⚠️ 2026-06-14 RETIRED（誤用注意）**: 「🔁 最新更新ログ」への append は**廃止**（rules/41 §④・MOC 自動ログ全廃）。helper の `append` subcommand は **no-op**（`scripts/sync-vault-summary.py` cmd_append）。よって本 skill の **STEP 2-4（append 系手順）は実行しても何も起きない**。現状で有効に残るのは `list`（候補抽出）/ `resolve`（repo→MOC マッピング）/ `cmd_issues`（Open Issues ライブミラー）のみ。**本 skill の全面改訂は vault 構造リフォーム施策で実施予定** → [[vault-restructure-proposal]]。それまで append を再実装しないこと。

repo のファイル編集を **Claude が 1-3 行に要約** → vault MOC の「🔁 最新更新ログ」に prepend するスキル。**（↑ 上記のとおり append は廃止済。以下の記述は歴史的経緯・改訂待ち）**

## 起動条件
- ユーザーが `/sync-vault-summary` を入力
- Stop hook の `📝 VAULT_SUMMARY_SUGGEST` を見て同期したいとき
- `~/.claude/state/vault-cc-enabled` が存在すること

## STEP 0: 前提チェック
```bash
[ -f "$HOME/.claude/state/vault-cc-enabled" ] || { echo "vault-cc-enabled flag なし。abort"; exit 0; }
SESSION_ID="${CLAUDE_SESSION_ID:-$(date +%s)}"  # session_id が取れない環境用 fallback
```

session_id は本セッションのものを使う (Claude Code が `CLAUDE_SESSION_ID` 環境変数で渡す or ユーザーに聞く)。

## STEP 1: 対象ファイル候補抽出

```bash
python3 ~/.claude/scripts/sync-vault-summary.py list <session_id>
```

出力例:
```
2026-05-25T13:04:23.123456+09:00	/Users/.../prime_ad/plan.md
2026-05-25T13:10:05.456789+09:00	/Users/.../prime_crm/docs/measures-detail.md
```

候補 0 件なら「同期対象なし」と報告して終了。

## STEP 2: 各候補に対し以下を実施

### 2-1. vault MOC マッピング解決
```bash
MOC=$(python3 ~/.claude/scripts/sync-vault-summary.py resolve <repo_file>)
[ "$MOC" = "UNRESOLVED" ] && echo "⚠️ skip (registry 未登録): <repo_file>" && continue
```

heuristic マッピング:
- `/prime_suite/prime_ad/` → `02_Ai/AI_adscrm/AIads/AIads_ope.md`
- `/prime_suite/prime_crm/` → `02_Ai/AI_adscrm/AIcrm/AIcrm_ope.md`
- `/prime_suite/` → `02_Ai/AI_adscrm/adscrm_cross.md`
- `/biz/make_article/` → `02_Ai/x-buzz/make_article/make_article_ope.md`

### 2-2. 対象ファイル Read + git diff 取得
**必須**: 「自編集ファイルの記憶過信」mistakes.md 由来で、要約前に必ず Read で全体把握。

```bash
# 対象ファイル全体を Read (Read ツール使用・履歴に残す)
# git diff で変更内容取得
cd "$(dirname <repo_file>)"
git diff HEAD -- "$(basename <repo_file>)"
git log -1 --pretty=format:"%h %s" -- "$(basename <repo_file>)"
```

diff が空 (commit 済 / 実質変更なし) ならその候補は skip。

### 2-3. LLM 要約生成 (Claude セッション内)
1-3 行のサマリーを生成。フォーマット:

```
- YYYY-MM-DD HH:MM [<basename> L<行範囲>] <変更の核心 30 字以内>
  - 背景 (任意・1 行)
  - 関連 Phase/施策 ID / 影響範囲 (任意・1 行)
```

**ルール**:
- declarative present tense (例: "M19 tROAS 制約緩和を Phase 1 中盤の本命に再修正")
- 数値・将来推測は書かない (rules/40 事実確認ルール)
- ファイル全体ではなく **diff の意味要約**

### 2-4. MOC に append — **RETIRED（no-op・実行しても何も起きない）**

旧仕様の全文 → `references/append-retired.md`（再実装禁止・rules/41 §④）。

## STEP 3: 確認報告
処理した件数とサマリーをユーザーに 5 行以内で報告:

```
ℹ️ vault MOC append は廃止済(no-op)。実際の書き込みは行われません:
  - list/resolve は動作。候補: AIads_ope.md, AIcrm_ope.md
  - append 呼び出しは RETIRED メッセージを返すのみ(MOC 不変)
  - AI の最近の活動把握は decisions.md + git log + claude-mem を参照
```

## エラー処理
| 状況 | 対応 |
|---|---|
| vault-cc-enabled flag なし | abort + 報告 |
| edit-history.jsonl 空 | 「同期対象なし」報告で終了 |
| registry 未登録 repo | warning + skip (entry 生成しない) |
| MOC ファイル不在 | warning + skip |
| git diff 空 (commit 済等) | entry 生成 skip |
| 同 session で同ファイル複数 entry | 最新の merge 後 entry 1 つに統合 |

## 関連
- `~/.claude/rules/42-file-type-placement.md` — 対象ファイル種別 SSoT (Draft)
- `~/.claude/rules/41-vault-project-structure.md` §④ — drift 防止
- `~/.claude/hooks/stop-vault-summary-suggest.sh` — Stop hook (起動推奨 stdout)
- `~/.claude/hooks/posttooluse-edit-history.sh` — edit-history.jsonl の生成元
- `~/.claude/scripts/sync-vault-summary.py` — atomic append helper
- `wiki/meta/mistakes.md#自編集ファイルの記憶過信` — STEP 2-2 の Read 必須由来

## 過去 drift 回避策 (本 skill に織り込み済)
1. **scaffold-bias 回避** (既存資産確認なしの設計提案): registry 必須参照・未登録 repo skip
2. **自編集ファイル記憶過信 回避**: 要約前に必ず Read + git diff
3. **vault MOC drift 拡大 回避**: 専用 H2 セクションで隔離・30 entry 上限 (上限超は別途 _audit へ移動 = 別タスク)
