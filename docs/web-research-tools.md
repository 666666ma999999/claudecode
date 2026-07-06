# Web リサーチツール選択（2軸主義）

`30-routing.md` から分離（2026-04-26）。Web リサーチ系スキル選定の正典。

**情報収集の主軸は 2 つだけ**。残りは補助情報として必要時に使う。

## 主軸・副軸の定義

| 位置づけ | ツール | 指標の性格 | 用途 |
|---|---|---|---|
| **主軸** | **X バズ**（grok-search + `/fetch-engagement` 2段） | 鮮度・バイラル兆候 | いいね/views/RTの実測、今Xで何が流行ってるか |
| **副軸** | **GitHub star**（`gh` CLI + `/gh-star-harvest`） | 客観性・継続性 | 世界中のdevが投票した結果、数値が絶対 |
| 補助 | 公式・Anthropic直系 | 確度最高 | 出現頻度低、補助扱い |
| 補助 | MCPレジストリ（pulsemcp/smithery等） | 範囲狭い | 特定記事テーマの時のみ |
| 補助 | firecrawl MCP（導入済・self-host localhost:3002） | JS描画ページも綺麗にMarkdown化 | WebFetchで読めない動的ページのscrape/crawl/extract |
| 補助 | HN/Reddit/Zenn/Qiita/はてブ等 | X/GitHubと重複 | Codex経由でまとめて横断 |

## 情報源ごとの推奨ツール

| 情報源 | 第一選択 | フォールバック |
|---|---|---|
| X(Twitter) バズ | `mcp__grok-search__web_search` sources=["x"] + `/fetch-engagement` | Codex自律 |
| X 個別ポスト本文（grok クレジット切れ/ログイン壁時） | WebFetch `https://cdn.syndication.twimg.com/tweet-result?id=<STATUS_ID>&lang=ja&token=a`（認証不要・X Articles はタイトル+リードまで） | `publish.x.com/oembed?url=...` |
| **X Articles（長文記事）全文** — ログイン必須 | **influx Cookie 経路**: `docker exec -i xstock-vnc python3 -` heredoc で `collector.cookie_crypto.load_cookies_or_raise("/app/x_profiles/maaaki/cookies.json")` → Playwright headless で記事 URL へ goto → innerText をスクロール収集（2026-07-06 実測成功: 36日前 Cookie で 2 記事全文取得。API 系 6 経路全滅時も生存） | Chrome 拡張（要接続）。Cookie 失効時は influx `refresh-x-cookies` |
| GitHub star/trending | `/gh-star-harvest` (gh CLI + pushed:> + paginate) | WebFetch(github.com/trending) |
| GitHub リポの中身を読む（star調査→コード深掘り連携） | `mcp__repomix__pack_remote_repository` / `codebase-investigation` | `gh api /repos/.../contents` |
| Anthropic 公式 | WebFetch `anthropic.com/news` | WebSearch `site:anthropic.com` |
| MCP レジストリ | `curl api.pulsemcp.com/v0beta/servers` + jq | smithery API |
| 動的ページ/SPA | Playwright MCP | — |
| HN / Reddit / Zenn / Qiita / はてブ / Hugging Face / dev.to 等の横断 | **Codex MCP（自律多段階）に一本化** | 個別API直叩きは基本しない |
| 単発の事実確認 | WebSearch + WebFetch (builtin) | — |
| 自分の環境集計 | `env-factcheck` | — |

> **削減判断（2026-04-22）**: HN/Reddit/Zenn/Qiita/はてブ の個別curl叩きは、Codex横断に任せた方が（a）問いを1回で済む（b）ソース横断の要約が一貫する（c）ドキュメント肥大化を避けられる。どうしても個別APIが必要な時だけ、Codex内から該当APIを呼ばせる。

## 日常運用フロー

```
毎日:    X バズ候補取得（grok-search + /fetch-engagement）
毎週:    GitHub star 収集（/gh-star-harvest 7 claude-code 50）
必要時:  公式blog 直読み / MCPレジストリ API叩き
横断:    Codex に任せる（1軸で見えない時のみ）
```

## Don'ts

- **builtinで済むものをMCPで呼ばない** — GitHub starは`gh`、WebSearchはbuiltin。MCP経由は10倍遅い
- **grepで集計しない** — JSONL は `jq` か `env-factcheck`。grep は artifact に騙される
- **同一ソースを複数スキルから独立に叩かない** — Canonical Module原則のリサーチ版
- **X/バズ系クエリを WebSearch(builtin) で取らない** — バズ・いいね・話題・トレンド・バイラルを含む X検索は **`mcp__grok-search__web_search` sources=["x"]** を使う。WebSearch(builtin) は likes/views を返さないため `/fetch-engagement` での再計測が必要になり二度手間（実測: builtin 409回 / grok-search 62回 の棲み分けが崩れていた）
- **補助ルートを個別に直叩きしない** — HN/Reddit/Zenn/Qiita/はてブ/Hugging Face 等は Codex MCP の「横断」機能に任せる。個別curl叩きは情報源追加のたびにルーティング表が肥大する
