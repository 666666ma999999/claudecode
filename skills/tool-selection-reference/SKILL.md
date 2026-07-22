---
name: tool-selection-reference
description: |
  ツール選択の詳細ガイド。Webスクレイピング段階エスカレーション
  （WebFetch→Playwright）判定フロー、SubAgent vs Agent Teams判定表。
  Web情報取得時、エージェント構成検討時に使用。
  キーワード: Webスクレイピング, Playwright, SubAgent, Agent Teams, ツール選択
  NOT for: 通常のファイル操作、コード編集
allowed-tools: [Read, Glob, Grep]
---

# ツール選択ガイド

## 0. ツール提案の前提規律

①収集・検索・自動化を提案する前に、当プロジェクトの既存実装（Cookie 機構・collector・skill）を grep/ls で棚卸しし、あれば第一選択にする ②恒久ブロッカー（API 恒久 403 等）は初回に記録し**既定代替経路を固定**。死んだ経路を提案 ladder の起点にしない（同じ指摘を 10 回受けた実例） ③「不可能」宣言はユーザーが指す既存機構を実調査した後のみ ④欠損データは AI 側解決が第一候補。ユーザー手作業依頼は最終手段で 1 アクションに圧縮。

## 1. Webスクレイピング 3段階エスカレーション

```
Level 0: WebFetch（静的HTML）→ 追加設定不要・キャッシュ付き・最速
Level 1: Playwright / claude-in-chrome（JSレンダリング・ページ操作・フルブラウザ制御）
```

> ✅ Firecrawl（cloud 版 `npx firecrawl-mcp`）と X 用 Grok Search は **User scope で全プロジェクト配線済み**（2026-07-21 `claude mcp list` 実測・両方 Connected）。旧 self-host localhost:3002 は廃止。**接続状態の正本は `claude mcp list` のみ**（本文書に接続状態を書き込まない — 過去に「未配線」誤記が残存し、稼働中の2ツールを推奨から外し続けた実害あり）。

### 判定フロー

```
1. ログイン/セッション管理が必要？ → YES → Playwright系 / claude-in-chrome
2. X（Twitter）のデータ？ → YES → influx Cookie 経路（既定・docs/web-research-tools.md）
3. サイト全体クロール/リスト駆動バッチ？ → YES → Playwright + スクリプト（または Codex 委譲）
4. 単純なページ操作（クリック/スクロール/入力）？ → YES → claude-in-chrome / Playwright
5. LLMベース構造化データ抽出？ → YES → WebFetch(+prompt) / Codex
6. それ以外 → WebFetch
```

### 優先順位（同機能の場合）

1. **WebFetch** — 最速・最軽量
2. **Playwright系 / claude-in-chrome** — JS レンダリング・フルブラウザが必要な場合のみ

## 2. Web リサーチツール選択（調査・検索）

スクレイピング（データ収集）とは別に、調査・検索の用途でのツール選択:

```
1. 単純な事実確認・1〜2ページ参照？ → WebSearch + WebFetch
2. 複数ソース横断・比較分析・深掘り調査？ → Codex / deep-research
3. 特定サイトの全ページクロール・構造化データ抽出？ → Playwright + スクリプト
4. X(Twitter)データ？ → influx Cookie 経路（既定）、代替: Codex（Yahoo!リアルタイム経由）
```

### 判定根拠（2026-03-27 検証済み）

| ツール | 情報源の質 | 即座に使える度 | コスト |
|--------|-----------|---------------|--------|
| WebSearch + WebFetch | 検索結果次第 | ページ単位で手動読み込み | 無料 |
| Codex | 一次情報源に自律到達 | 要約済みで即使える | OpenAI API |
| Playwright / claude-in-chrome | フルブラウザ（ログイン可） | セットアップ済み | 無料 |
| influx Cookie 経路（X 専用） | X 実データ | コンテナ起動で即 | 無料 |

| firecrawl MCP（cloud） | JS描画ページもMarkdown化・`firecrawl_search` | User scope 配線済み | Firecrawl クレジット |

> ❌ grok-search は **2026-07-22 廃止裁定（課金しない・再提起禁止）**。X の数字は influx Cookie 経路（`/fetch-engagement`）＋他人いいね=syndication が正（recurring-mistakes `x-numbers-cookie-route`）。

> 接続状態の正本は `claude mcp list`。本表に接続状態を書かない（2026-07-21 ルール化）。

## 3. SubAgent vs Agent Teams

| 条件 | SubAgent | Agent Teams |
|------|----------|-------------|
| 結果だけ欲しい（調査→サマリー返却） | **使う** | 不要 |
| ワーカー同士が議論・反証する必要 | 不可 | **使う** |
| 同じファイルを編集する可能性 | **使う**（直列で安全） | 危険（競合） |
| 3つ以上の独立した視点が必要 | 可能だが通信不可 | **使う** |
| トークンコストを抑えたい | **使う** | 高コスト |

### Agent Teamsを使うべき場面

- **多視点レビュー**: セキュリティ/パフォーマンス/FE-BE整合性の並列レビュー
- **競合仮説デバッグ**: 複数エージェントで異なる仮説を調査・反証
- **クロスレイヤー実装**: FE/BE/テストの並列実装（明確なファイル所有権割り当て）
- **並列調査**: コードベース調査+業界標準調査+依存関係分析

### 使ってはいけない場面

- **順序依存タスク**: STEP 1→8のような直列パイプライン
- **同一ファイル編集**: 上書き競合が発生
- **単純な1ファイル修正**: オーバーヘッドが利益を超過
- **ルーチン作業**: SubAgentで十分

### Agent Teams運用ルール

- リーダーはデリゲートモード、実装はTeammateに委任
- 各Teammateに明確なファイル所有権を割り当て（競合回避）
- Teammateあたり5-6タスク用意（遊休防止）
- 完了時: 全Teammate完了確認 → 結果統合 → シャットダウン → Codexレビュー
- レビュー指摘が未解決の状態で次タスクに進行しない
- 注意: `/resume`でTeammateは復元不可、セッションあたり1チームのみ
