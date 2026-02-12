# Webスクレイピング統合ガイド

## 1. 3段階エスカレーション戦略

```
Level 0: WebFetch（静的HTML）
  → 追加設定不要・キャッシュ付き・最速
  → 静的HTMLで十分な場合はこれで完結

Level 1: Firecrawl（JSレンダリング + actions + LLM抽出）
  → JSレンダリング、単純なページ操作（クリック/スクロール/入力）
  → LLMベースの構造化データ抽出（セレクタ不要）
  → スクリーンショット取得
  → proxy: "stealth" でbot検知回避（Level 1）

Level 2: Playwright（フルブラウザ制御）
  → ログイン・セッション管理が必要
  → CDP接続によるbot検知回避（Level 2）
  → 複雑なSPA操作・マルチステップフォーム
  → iframe/Shadow DOM操作
  → ファイルダウンロード・アップロード
```

## 2. ツール選択判定フロー

```
1. ログイン/セッション管理が必要？
   → YES → Playwright系（web-data-downloader / web-form-detector / Playwright MCP）
   → NO ↓

2. X（Twitter）のデータ？
   → YES → x-scraping（専用スキル）
   → NO ↓

3. バッチ処理（リスト駆動）？
   → YES → web-list-scraper（JSが必要な行はFirecrawlにフォールバック）
   → NO ↓

3.5. 単純なページ操作（クリック/スクロール/入力）が必要？
   → YES → Firecrawl actions（firecrawl_scrapeのactionsパラメータ）
   → NO ↓

4. JSレンダリングが必要？ or サイト全体をクロール？
   → YES → Firecrawl MCP（firecrawl_scrape / firecrawl_crawl）
   → NO ↓

5. LLMベースの構造化データ抽出が必要？（セレクタ不要で抽出したい）
   → YES → Firecrawl extract（firecrawl_extract + JSON schema）
   → NO → WebFetch（最速・最軽量）
```

## 3. ツール別の得意領域

| ツール | 得意領域 | JSレンダリング | 認証 | クロール | Actions | LLM抽出 |
|---|---|---|---|---|---|---|
| WebFetch | 静的ページ・単発・軽量 | × | × | × | × | × |
| Firecrawl MCP | JSページ・クリーンMarkdown | ○ | △ | ○ | ○ | ○ |
| web-list-scraper | CSV/Excelリスト駆動バッチ | △（Firecrawl連携時） | × | ○（リスト駆動） | × | △ |
| web-data-downloader | ログイン必須サイト | ○ | ○ | × | × | × |
| web-form-detector | フォーム操作 | ○ | ○ | × | × | × |
| Playwright MCP | ブラウザ操作全般 | ○ | ○ | × | ○（フル） | × |
| x-scraping | X（Twitter）専用 | ○ | ○（CDP） | ○（スクロール） | × | × |

## 4. 優先順位（同じことができる場合）

1. **WebFetch** — 追加設定不要・キャッシュ付き・最速
2. **Firecrawl** — JSレンダリング + actions + LLM抽出対応
3. **web-list-scraper** — バッチ処理特化
4. **Playwright系** — フルブラウザが必要な場合のみ

## 5. Firecrawl → Playwright エスカレーション条件

以下のいずれかに該当する場合、FirecrawlからPlaywrightにエスカレーション:

| 条件 | 理由 |
|------|------|
| ログイン/セッション管理が必要 | Firecrawlは認証セッション非対応 |
| bot検知がFirecrawl stealthで突破不可 | CDP接続が必要 |
| iframe/Shadow DOM内の操作 | Firecrawl actionsでは操作不可 |
| ファイルダウンロード/アップロード | Firecrawlにはファイル操作なし |
| 複雑なマルチステップフォーム | 状態管理が必要 |
| Firecrawl actionsでタイムアウト/エラー | フルブラウザにフォールバック |

## 6. グレースフルデグレード（Firecrawl未導入時）

- WebFetchをデフォルトで使用
- JSレンダリングが必要な場合はPlaywright MCPにフォールバック
- Firecrawl actionsが必要な場面 → Playwright MCPで代替
- LLM抽出が必要な場面 → Playwright snapshot + 手動パース
- 全スキルは正常動作する（Firecrawlはオプショナル）

## Firecrawl実装パターン

Firecrawl Actions・LLM抽出・パフォーマンス最適化の詳細は `firecrawl-patterns.md` を参照。
