# Webデータ取得ツール選択ガイド

## 判定フロー

```
1. ログイン/フォーム操作が必要？
   → YES → Playwright系（web-data-downloader / web-form-detector / Playwright MCP）
   → NO ↓

2. X（Twitter）のデータ？
   → YES → x-scraping（専用スキル）
   → NO ↓

3. バッチ処理（リスト駆動）？
   → YES → web-list-scraper（JSが必要な行はFirecrawlにフォールバック）
   → NO ↓

4. JSレンダリングが必要？ or サイト全体をクロール？
   → YES → Firecrawl MCP
   → NO → WebFetch（最速・最軽量）
```

## ツール別の得意領域

| ツール | 得意領域 | JSレンダリング | 認証 | クロール |
|---|---|---|---|---|
| WebFetch | 静的ページ・単発・軽量 | × | × | × |
| Firecrawl MCP | JSページ・クリーンMarkdown | ○ | △ | ○ |
| web-list-scraper | CSV/Excelリスト駆動バッチ | △（Firecrawl連携時） | × | ○（リスト駆動） |
| web-data-downloader | ログイン必須サイト | ○ | ○ | × |
| web-form-detector | フォーム操作 | ○ | ○ | × |
| Playwright MCP | ブラウザ操作全般 | ○ | ○ | × |
| x-scraping | X（Twitter）専用 | ○ | ○（CDP） | ○（スクロール） |
| Chrome DevTools | パフォーマンス分析 | ○ | - | × |

## 優先順位（同じことができる場合）

1. **WebFetch** — 追加設定不要・キャッシュ付き・最速
2. **Firecrawl** — JSレンダリング対応・クリーンMarkdown
3. **web-list-scraper** — バッチ処理特化
4. **Playwright系** — フルブラウザが必要な場合のみ

## Firecrawl未導入時

- WebFetchをデフォルトで使用
- JSレンダリングが必要な場合はPlaywright MCPにフォールバック
- 全スキルは正常動作する（Firecrawlはオプショナル）
