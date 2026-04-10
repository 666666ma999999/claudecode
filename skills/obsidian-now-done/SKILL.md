---
name: obsidian-now-done
description: |
  Obsidian MDのNOW→DONE移動を正しい形式で実行するスキル。
  元プロンプト全文の保存を強制し、結果サマリーの追記を定型化する。
  hookによる違反検出と連携し、形式違反を未然に防ぐ。
  キーワード: NOW→DONE, Obsidian, タスク完了, 元プロンプト保存, 結果記録, NOW完了
  NOT for: task.md更新（→ task-progress）、通常のファイル編集
allowed-tools: "Read Edit Write Grep Glob"
license: proprietary
metadata:
  author: masaaki-nagasawa
  version: 1.0.0
  category: workflow-automation
  tags: [obsidian, now-done, task-completion, prompt-preservation]
---

# Obsidian NOW→DONE 移動スキル

Obsidian VaultのMDファイルでNOWセクションのタスクをDONEに移す際、**元プロンプトを省略せず保存する**ことを強制するスキル。

## 発動条件

以下のいずれかに該当する場合:
- 「NOWを完了した」「NOWをDONEに移して」
- 「このタスク終わったから記録して」
- Obsidian Vault配下のMDファイルでDONEセクションへの追記が必要な場面
- タスク完了時に `obsidian-session-reminder` hookから違反通知があった場合

## 絶対ルール

**見出しレベルは h5（`#####`）固定**。他MDファイルへの貼り付け時にh1-h3構造を壊さないため。

### ❌ 禁止（違反）

```markdown
##### test3: hayatomo 職場不倫 (2026-04-10)
- ppv_id=42300064, STEP 1-8 全成功
- W不倫商品はGemini PROHIBITED_CONTENTでブロック
```

結果サマリーだけで元プロンプトが無い → **hookがブロックする**

また `### ` (h3) や `#### ` (h4) の見出しも hook が検出対象外となるため禁止。必ず `##### ` (h5) を使う。

### ✅ 正しい形式

```markdown
##### test3: hayatomo 職場不倫 (2026-04-10)
hayatomoでsite_id=423, ppv_id=42300064のW不倫商品を自動登録して。
STEP1-8全部走らせて、教師データは「はやとも不倫」を使う。
Sheetsにも書き戻すこと。

**結果:** STEP 1-8 全成功 (STEP6リトライ1回)。W不倫商品はGemini PROHIBITED_CONTENTでブロックされたため、職場不倫で代替実行。Sheets書き戻し済み。
```

元プロンプトを**一字一句そのまま**維持 → `**結果:**` で結果サマリーを追記

## 実行フロー

### Step 1: 対象MDファイルの特定

```bash
# プロジェクトCLAUDE.mdに記載されたObsidian MDパスを確認
# 例: /Users/masaaki/Documents/Obsidian Vault/02_ai/rohan/auto_regist_Uranaiitem.md
```

対象ファイル確認後、`Read` で現在のNOWセクションを取得する。

### Step 2: NOWセクションの元プロンプトを抽出

```markdown
## NOW
（ここに書かれている全文を一字一句コピーする）
```

**重要**:
- 改行・空行・インデント・typoを含めて完全コピー
- 「ここは省略していいだろう」の判断は禁止
- スクリーンショットやファイル添付への参照もそのまま残す

### Step 3: DONEセクションへの追記

以下の形式で追記する:

```markdown
### {タスク名} ({完了日 YYYY-MM-DD})
{NOWの元プロンプト全文}

**結果:** {実行結果のサマリー}
```

**タスク名**の付け方:
- 元プロンプトの冒頭を要約した簡潔な見出し
- 既存DONEエントリの命名スタイルに合わせる

**結果サマリー**の書き方:
- 成功/失敗、エラー内容、リトライ回数、書き戻し状況など
- 箇条書き可だが、`**結果:**` マーカーの後に書く

### Step 4: NOWセクションから該当項目を削除

DONEに追加した内容を、NOWセクションから取り除く。NOWには未完了タスクのみが残るようにする。

### Step 5: hook検証

`Edit` 実行後、`obsidian-now-done-guard.sh` hookが自動的に形式を検証する:
- `**結果:**` マーカーがあるか
- 本文に2行以上あるか（元プロンプトが空でないか）

違反があれば hook がexit 2でブロックし、Claudeに修正指示が届く。

### Step 6: 長期保存する知見のVault再配置（オプション）

DONEエントリに**再利用可能な確定知見**（設定値・制約・教訓・手順）が含まれる場合、Vault内の適切なMDへ分散配置する:

- **元のDONEエントリは削除しない**（履歴ログとして保持）
- `obsidian-short-note-merge` スキルのパターン4を呼び出す:
  ```
  パターン4: DONEエントリ入力
  入力: source_file = "<元のMDファイル>"
        entry_heading = "##### <タスク名> (<完了日>)"
  出力: 抽出した知見の移動先候補 + 最終Markdownブロック
  ```
- スキルが提案する移動先候補から選択し、ユーザーにEdit実行を委ねる
- 移動先例:
  - 運用手順・設定値 → ドメイン別運用MD（例: `02_ai/rohan/auto_regist_Uranaiitem.md` のSPEC）
  - 再発回避の教訓 → `00_General/やらないこと.md`
  - 長期仕様 → `01_Biz/Bot仕様書/*.md`

**Step 6 をスキップしてよい場合**:
- DONEエントリが一時的な作業ログで再利用価値が低い
- ユーザーが明示的に「DONEに残したままでよい」と指示

## エッジケース

### ケース1: 元プロンプトが長大

元プロンプトが100行超でも省略禁止。全文残す。コードブロックやスクリーンショット参照もそのまま。

### ケース2: 元プロンプトが画像添付のみ

```markdown
### スクショレビュー (2026-04-10)
（画像添付のみ・テキストなし）

**結果:** ...
```

`（画像添付のみ・テキストなし）` のような明示的な記述を残す。空のままDONEに入れてはならない。

### ケース3: 元プロンプトが既に失われている

前セッションで省略されてしまった場合:
1. ユーザーに元プロンプトを尋ねる（`AskUserQuestion`）
2. 思い出せない場合は、DONEエントリの冒頭に `（元プロンプト未保存 — セッション間で失われた）` と明記
3. **結果:** マーカーは必ず付ける（hook要件）

### ケース4: 複数タスクをまとめてDONE化

1タスクにつき1エントリ（`### `見出し）を作成する。複数タスクを1エントリに詰め込まない。

## 失敗パターン（絶対に避ける）

| パターン | なぜダメか |
|---------|-----------|
| 結果だけ箇条書きで書く | 元プロンプトが失われ、後から再現不可 |
| 「STEP 1-8 全成功」のような一行サマリー化 | プロンプトの意図・制約・ユーザー希望が消える |
| 「前回と同じ」で参照のみ | 過去エントリが変更・削除されたら辿れない |
| `**結果:**` マーカーを省略 | hookがブロックする |

## 関連

- `~/.claude/CLAUDE.md` 「行動原則」セクション
- `~/.claude/hooks/obsidian-now-done-guard.sh` — PostToolUse検証hook
- `~/.claude/hooks/obsidian-session-reminder.sh` — SessionStart警告hook
- `~/.claude/projects/-Users-masaaki-Documents/memory/feedback_obsidian_now_done.md` — feedback memory
