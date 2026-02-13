# ツール選択ガイド

## 1. Webスクレイピング 3段階エスカレーション

```
Level 0: WebFetch（静的HTML）→ 追加設定不要・キャッシュ付き・最速
Level 1: Firecrawl（JSレンダリング + actions + LLM抽出）→ bot検知回避(stealth)対応
Level 2: Playwright（フルブラウザ制御）→ ログイン・セッション管理・CDP・iframe/Shadow DOM
```

### 判定フロー

```
1. ログイン/セッション管理が必要？ → YES → Playwright系
2. X（Twitter）のデータ？ → YES → x-scraping
3. バッチ処理（リスト駆動）？ → YES → web-list-scraper
4. 単純なページ操作（クリック/スクロール/入力）？ → YES → Firecrawl actions
5. JSレンダリング/サイト全体クロール？ → YES → Firecrawl MCP
6. LLMベース構造化データ抽出？ → YES → Firecrawl extract
7. それ以外 → WebFetch
```

### 優先順位（同機能の場合）

1. **WebFetch** — 最速・最軽量
2. **Firecrawl** — JSレンダリング + LLM抽出
3. **web-list-scraper** — バッチ処理特化
4. **Playwright系** — フルブラウザが必要な場合のみ

**Firecrawl実装パターン詳細**: 下記セクション3参照（詳細例は `~/.claude/skills/web-scraping-guide/SKILL.md`）

## 2. SubAgent vs Agent Teams

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

## 3. Firecrawl実装パターン

### Actionsパターン（ページ操作）

`firecrawl_scrape`の`actions`パラメータでスクレイピング前にページ操作を実行:

| アクション | 用途 |
|-----------|------|
| `click` (selector) | ボタンクリック・タブ切り替え・「もっと見る」展開 |
| `scroll` (direction, amount) | 無限スクロールページの全件取得 |
| `write` (text, selector) + `press` (key) | 検索フォーム入力→実行 |
| `wait` (milliseconds) | 動的コンテンツの読み込み待機 |
| `executeJavascript` (script) | カスタムDOM操作 |

### LLM Extractパターン（構造化データ抽出）

`firecrawl_extract`でJSON schemaベースの構造化データをLLMで抽出。CSSセレクタ特定が困難な場合に有効:

```
firecrawl_extract(
  urls=["https://example.com/page"],
  prompt="抽出指示",
  schema={"type": "object", "properties": {...}, "required": [...]}
)
```

- 複数URLを`urls`配列に渡して一括抽出可能
- テーブル・リストは`array`型のschemaで抽出

### バッチ最適化（map -> targeted scrape）

1. `firecrawl_map`でサイト内URL一覧を取得
2. 対象URLをフィルタリング
3. `firecrawl_extract`で複数URLを一括抽出（最も効率的）
4. 逐次`firecrawl_scrape`の場合はURL間に1秒以上の間隔を設ける
