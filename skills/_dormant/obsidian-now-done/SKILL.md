---
name: obsidian-now-done
description: |
  Obsidian MDのNOW→DONE移動を refs/分離方式で実行するスキル。
  元プロンプト全文は同ディレクトリの refs/ に退避し、メインMDは軽量化する。
  全文保存ルールは維持（場所だけ変更）。hookによる違反検出と連携。
  キーワード: NOW→DONE, Obsidian, タスク完了, 元プロンプト保存, 結果記録, refs分離
  NOT for: task.md更新（→ task-progress）、通常のファイル編集
allowed-tools: [Read, Edit, Write, Grep, Glob]
license: proprietary
metadata:
  author: masaaki-nagasawa
  version: 2.1.0
  category: workflow-automation
  tags: [obsidian, now-done, task-completion, prompt-preservation, refs-separation, suggest-integration]
---

# Obsidian NOW→DONE 移動スキル (refs/分離方式)

Obsidian VaultのMDファイルでNOWセクションのタスクをDONEに移す際、**元プロンプト全文を refs/ 別ファイルに退避** してメインMDを軽量化するスキル。全文保存は維持、保存先のみ変更。

## 発動条件

以下のいずれかに該当する場合:
- 「NOWを完了した」「NOWをDONEに移して」
- 「このタスク終わったから記録して」
- Obsidian Vault配下のMDファイルでDONEセクションへの追記が必要な場面
- タスク完了時に `obsidian-session-reminder` hookから違反通知があった場合

## 絶対ルール

1. **見出しレベルは h5（`#####`）固定**（h1-h3構造を壊さないため）
2. **元プロンプトは一字一句 refs/ に保存**（省略・要約・箇条書き化は禁止）
3. **メインMDのDONE本体は軽量**（要約 + 結果 + refsリンクのみ）
4. **refs/ ファイルは append-only**（編集・削除禁止）

### ❌ 禁止パターン

```markdown
##### test3: hayatomo 職場不倫 (2026-04-10)
- STEP 1-8 全成功
- W不倫商品はブロックされたため代替実行
**結果:** 完了
```
→ プロンプト要約なし、refsリンクなし。hookがブロック。

```markdown
##### test3 (2026-04-10)
**プロンプト要約:** W不倫商品を自動登録
**元プロンプト:** [[refs/2026-04-10_hayatomo-affair]]
**結果:** 完了
```
→ refs ファイルが実在しないならhookがブロック。先に refs を Write する。

### ✅ 正しい形式

**メインMD側（DONEセクション）:**

```markdown
##### test3: hayatomo 職場不倫 (2026-04-10)
**プロンプト要約:** hayatomoでW不倫商品(ppv_id=42300064)をSTEP1-8で自動登録、教師データは「はやとも不倫」、Sheets書き戻しまで実行。
**元プロンプト:** [[refs/2026-04-10_hayatomo-workplace-affair]]

**結果:** STEP 1-8 全成功 (STEP6リトライ1回)。W不倫商品はGemini PROHIBITED_CONTENTでブロックされたため、職場不倫で代替実行。Sheets書き戻し済み。
```

**refs/2026-04-10_hayatomo-workplace-affair.md:**

```markdown
# test3: hayatomo 職場不倫 (2026-04-10)
参照元: [[../auto_regist_Uranaiitem]]

---

hayatomoでsite_id=423, ppv_id=42300064のW不倫商品を自動登録して。
STEP1-8全部走らせて、教師データは「はやとも不倫」を使う。
Sheetsにも書き戻すこと。
```

## 実行フロー

### Step 1: 対象MDファイルの特定

プロジェクトCLAUDE.mdに記載されたObsidian MDパスを確認。対象ファイル確認後、`Read` で現在のNOWセクションを取得する。

### Step 2: NOWセクションの元プロンプトを抽出

```markdown
## NOW
（ここに書かれている全文を一字一句コピーする）
```

**重要**:
- 改行・空行・インデント・typoを含めて完全コピー
- 「ここは省略していいだろう」の判断は禁止
- スクリーンショットやファイル添付への参照もそのまま残す

### Step 3: refs/ ディレクトリとファイルを作成（メインMD編集より先）

対象MDファイルの同ディレクトリに `refs/` があるか確認。なければ作成。

**ファイル名規則**: `YYYY-MM-DD_slug.md`
- `YYYY-MM-DD`: 完了日
- `slug`: タスクの短い識別子（kebab-case推奨、日本語可、40文字以内目安）
- 例: `2026-04-10_hayatomo-workplace-affair.md`, `2026-04-20_rohan-api-refactor.md`

`Write` ツールで refs ファイルを作成:

```markdown
# <タスク名> (<YYYY-MM-DD>)
参照元: [[../<元MDファイル名(拡張子なし)>]]

---

<NOWの元プロンプト全文>
```

**この段階ではメインMDには触らない**（hook が refs 不在でブロックするため順序重要）。

### Step 4: メインMDのDONEセクションへ軽量エントリを追記

`Edit` ツールで以下を追加:

```markdown
##### <タスク名> (<YYYY-MM-DD>)
**プロンプト要約:** <NOWプロンプトの意図を1-3行で要約>
**元プロンプト:** [[refs/<YYYY-MM-DD_slug>]]

**結果:** <実行結果のサマリー>
```

**プロンプト要約の書き方**:
- 元プロンプトの「何を・なぜ・制約」を1-3行で凝縮
- refs を開かなくてもタスク意図が分かる粒度
- 例: "hayatomoでW不倫商品をSTEP1-8で自動登録、Sheets書き戻しまで実行"

**結果サマリーの書き方**:
- 成功/失敗、エラー内容、リトライ回数、書き戻し状況など
- `**結果:**` マーカーの後に記述（箇条書き可）

## Step 4.3: 統合先サジェスト (フラグなし時の自動提案)

候補抽出・ユーザー提示・選択後処理・トークンコスト管理の詳細は `references/integration-suggest.md` を参照。
