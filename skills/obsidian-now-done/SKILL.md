---
name: obsidian-now-done
description: |
  Obsidian MDのNOW→DONE移動を refs/分離方式で実行するスキル。
  元プロンプト全文は同ディレクトリの refs/ に退避し、メインMDは軽量化する。
  全文保存ルールは維持（場所だけ変更）。hookによる違反検出と連携。
  キーワード: NOW→DONE, Obsidian, タスク完了, 元プロンプト保存, 結果記録, refs分離
  NOT for: task.md更新（→ task-progress）、通常のファイル編集
allowed-tools: "Read Edit Write Grep Glob"
license: proprietary
metadata:
  author: masaaki-nagasawa
  version: 2.0.0
  category: workflow-automation
  tags: [obsidian, now-done, task-completion, prompt-preservation, refs-separation]
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

### Step 5: NOWセクションから該当項目を削除

DONEに追加した内容を、NOWセクションから取り除く。

### Step 6: hook検証

`Edit` 実行後、`obsidian-now-done-guard.sh` hookが自動的に形式を検証:
- `**プロンプト要約:**` マーカー
- `**元プロンプト:** [[refs/...]]` リンク
- refs ファイル実在 + 非空（50バイト以上）
- `**結果:**` マーカー

違反があれば hook がexit 2でブロックし、修正指示が届く。

### Step 7: 長期保存する知見のVault再配置（オプション）

DONEエントリに**再利用可能な確定知見**（設定値・制約・教訓・手順）が含まれる場合、Vault内の適切なMDへ分散配置:

- **メインMDのDONEエントリも refs ファイルも削除しない**（履歴ログとして保持）
- `obsidian-short-note-merge` スキルのパターン4を呼び出す
- 移動先例:
  - 運用手順・設定値 → ドメイン別運用MD（例: `02_ai/rohan/auto_regist_Uranaiitem.md` のSPEC）
  - 再発回避の教訓 → `00_General/やらないこと.md`
  - 長期仕様 → `01_Biz/Bot仕様書/*.md`

## エッジケース

### ケース1: 元プロンプトが長大（100行超）

refs/ ファイルに全文そのまま保存。メインMDは軽量のまま。refs/分離のメリットが最大化される。

### ケース2: 元プロンプトが画像添付のみ

refs/ ファイル本文:
```markdown
# スクショレビュー (2026-04-10)
参照元: [[../rohan]]

---

（画像添付のみ・テキストなし）
```

空ファイルにしない（hookが 50バイト未満をブロック）。

### ケース3: 元プロンプトが既に失われている

前セッションで省略されてしまった場合:
1. ユーザーに元プロンプトを尋ねる（`AskUserQuestion`）
2. 思い出せない場合は refs/ ファイルに `（元プロンプト未保存 — セッション間で失われた）` と明記
3. メインMD側には通常通り `**プロンプト要約:**` と `**元プロンプト:** [[refs/...]]` を記録

### ケース4: 複数タスクをまとめてDONE化

1タスクにつき1エントリ、1つの refs/ ファイル。複数タスクを1エントリに詰め込まない。

### ケース5: 既存の LEGACY 形式エントリ（本体に全文）

既存エントリは grandfather される（hookが自動判別）。触らずそのまま保持。必要に応じてPhase 3の移行スクリプトで NEW形式へ変換する。

### ケース6: refs/ ディレクトリが既に別用途で使われている

想定外。ユーザーに確認 → 別名（例: `_prompts/`）を提案。CLAUDE.md・hook・SKILLの命名変更が必要になるため原則 refs/ で統一。

## 失敗パターン（絶対に避ける）

| パターン | なぜダメか |
|---------|-----------|
| メインMDを先に Edit し refs/ を後回し | hookが refs 不在でブロック。順序は refs Write → メインMD Edit |
| 結果だけ書いてプロンプト要約を省略 | hookがブロック。タスク意図が後で辿れない |
| refs リンクなしで全文をメインMDに貼る | 新形式違反（LEGACY扱いで一応通るが肥大化目的に反する） |
| refs/ ファイルを後から編集 | append-only ルール違反。監査性喪失 |
| 同じ refs ファイル名を別タスクで再利用 | 上書きによる元プロンプト喪失 |

## 関連

- `~/.claude/CLAUDE.md` 「行動原則」「Obsidian連携」セクション
- `~/.claude/hooks/obsidian-now-done-guard.sh` — PostToolUse検証hook (v2: refs検証対応)
- `~/.claude/hooks/obsidian-session-reminder.sh` — SessionStart警告hook
- `~/.claude/projects/-Users-masaaki-Documents/memory/feedback_obsidian_now_done.md` — feedback memory
- `obsidian-short-note-merge` スキル パターン4 — DONEエントリから知見抽出 → Vault内別MDへの再配置（Step 7で呼び出し）
