---
name: codex-delegate
description: |
  汎用Codex委譲スキル（thin forwarder）。任意のタスクをCodexに委譲して結果を取得する。
  非エンジニアタスク（資料レビュー、契約書チェック、文章校正、翻訳、要約等）にも対応。
  キーワード: Codex委譲, codex delegate, Codexに任せて, Codexで, 資料レビュー, 契約書チェック
  NOT for: コードレビュー（→ /review）、敵対的レビュー（→ /adversarial-review）、stuck時rescue（→ /rescue）
allowed-tools: "Read Glob Grep Bash"
license: proprietary
metadata:
  author: masaaki-nagasawa
  version: 1.0.0
  category: workflow-automation
  tags: [codex, delegation, thin-forwarder, non-engineer]
---

# Codex Delegate（汎用Codex委譲）

任意のタスクをCodexに委譲し、Codexの深い思考力で処理させる thin forwarder スキル。

## 発動条件

以下のいずれかに該当する場合に使用:
- 「{やりたいこと}をCodexに任せて」
- 「Codexで{タスク}して」
- 非コードタスクで深い分析・検証が必要な場面

## 実行フロー

### Step 1: 入力の特定

ユーザーの指示から以下を判定:
- **タスク種別**: レビュー / 分析 / 生成 / 校正 / 翻訳 / その他
- **入力ソース**: テキスト直接入力 / ファイルパス / クリップボード内容
- **出力形式**: 自由文 / 構造化レポート / 修正済みテキスト

### Step 2: 入力内容の収集

- ファイルパスが指定された場合: `Read` ツールで内容を取得
- テキストが直接入力された場合: そのまま使用
- 不明な場合: `AskUserQuestion` で確認

### Step 3: Codexへの委譲

`mcp__codex__codex` に以下の形式で送信:

```
## タスク
{ユーザーの指示を明確化したもの}

## 入力内容
{ファイル内容 or テキスト}

## 要件
- 日本語で回答すること
- 具体的な指摘・提案を含めること
- 根拠を明示すること
```

### Step 4: 結果の返却

- Codexの回答をそのままユーザーに表示
- 追加の質問や深掘りが必要な場合は `mcp__codex__codex-reply` で継続
- ファイル修正が必要な場合はユーザー確認後に適用

## 使用例

```
# 契約書をCodexでレビュー
「この契約書をCodexでレビューして」→ ファイルを読み取り、Codexに法的観点のレビューを依頼

# 企画書の論理チェック
「企画書.mdをCodexに論理チェックさせて」→ 論理的矛盾・抜け漏れをCodexが検出

# 文章校正
「このメールをCodexで校正して」→ テキストをCodexに送信、校正結果を返却

# 翻訳レビュー
「翻訳結果をCodexで品質チェックして」→ 翻訳の正確性・自然さをCodexが評価
```

## 注意事項

- **機密情報の送信禁止**: APIキー、パスワード、個人情報はCodexに送信しない
- **コードレビューには `/review` を使用**: このスキルは非コードタスク向け
- **大量テキスト（10000文字超）は要約してから送信**
