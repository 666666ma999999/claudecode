# Web リサーチツール選択（2軸主義）

`30-routing.md` から分離（2026-04-26）。Web リサーチ系スキル選定の正典。

> **🔎 検索・調査の前に必ず**: vault `02_Ai/search-playbook.md`（**検索攻略ノート**）を先に引く — ドメイン別の勝ちパターン・見張り台帳・効く/効かない条件の正本。ノートに該当ドメインがあれば、その手法・資産（chacha 人リスト / 3ソース照合 / x-keywords 等）を第一選択にし、ゼロからの場当たり検索をしない。検索後は対象案件（繰り返す検索・重い判断・外れた時・新パターンの芽）なら §4-B の固定書式で1行ログを書き戻す（軽い事実確認は不要）。初回検索時は PreToolUse hook が想起注入する（2026-07-22 敵対レビュー2R 確定）。
> MCP の接続状態の正本は `claude mcp list` のみ。本文書に接続状態を書かない。

**情報収集の主軸は 2 つだけ**。残りは補助情報として必要時に使う。

## 主軸・副軸の定義

| 位置づけ | ツール | 指標の性格 | 用途 |
|---|---|---|---|
| **主軸** | **X バズ**（grok-search + `/fetch-engagement` 2段） | 鮮度・バイラル兆候 | いいね/views/RTの実測、今Xで何が流行ってるか |
| **副軸** | **GitHub star**（`gh` CLI + `/gh-star-harvest`） | 客観性・継続性 | 世界中のdevが投票した結果、数値が絶対 |
| 補助 | 公式・Anthropic直系 | 確度最高 | 出現頻度低、補助扱い |
| 補助 | MCPレジストリ（pulsemcp/smithery等） | 範囲狭い | 特定記事テーマの時のみ |
| 補助 | firecrawl MCP（cloud 版 `npx firecrawl-mcp`・User scope 全プロジェクト） | JS描画ページも綺麗にMarkdown化。`firecrawl_search` は一般 Web 検索の第一候補（builtin WebSearch より内容抽出が濃い） | 動的ページの scrape/crawl/extract。旧 self-host localhost:3002 は廃止（2026-07-21） |
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

## 量的計器（M8「数字で絞る」）の取得ルート

> 攻略ノート `02_Ai/search-playbook.md` §7 計器索引の実務詳細。候補の量的KPIを〈①確定=読むだけ / ②推定=集めて計算 / ③あやふや=M5+芽観察〉で取る。値タグ[絶対/相対/公式推定/順位]必須・**数字大≠良い**。取得可否は揺れる（API有料化・仕様変更）→ 索引に固定せず、分野着手時に1回実測してから使う。

### SNS の大原則（2026-07-22 実測）: 露出は自分だけ・他人は反応だけ
| SNS | 他人について読める | 自分だけ（Insights） | 取得の入口 |
|---|---|---|---|
| X | いいね数（views は返らない・実測） | imp/engagements/クリック | 他人=`cdn.syndication.twimg.com/tweet-result?id=<id>&lang=ja&token=a`／自社or対象=`/fetch-engagement`(Cookie・views含む)／grok は課金切れ時403→フォールバック |
| ニコニコ | 再生/コメント/マイリスト（全公開・実測） | クリエイター詳細 | `ext.nicovideo.jp/api/getthumbinfo/<smID>`（無認証・最も他人が開いている） |
| YouTube | 再生/いいね/コメント（WebFetchでは不可・API要） | 維持率/流入/収益 | Data API v3 `videos.list`（`YOUTUBE_API_KEY`）。search endpoint は quota 大 |
| Instagram | いいね/コメント（ログイン壁）・**リーチ/imp/保存は不可** | リーチ/imp/保存/属性 | 自社=Meta Graph（要 instagram_manage_insights・現トークンは ads_read のみ）／他人=実質不可 |
| TikTok | 再生/いいね/コメント（scrape脆弱） | 維持/流入 | 候補=Creative Center(radar既存)／自社=TikTok API(要申請) |
| Facebook | 公開Pageの反応（個人post不可） | Page Insights | 自社=Graph(Page token)／他人organic=不可 |
| LINE公式 | **不可**（他社は取れない） | 友だち/ブロック/開封/クリック | 自社=Messaging Insight(`LINE_CHANNEL_TOKEN`・稼働) |
| note | スキ数（公開） | PV/売上 | 他人=公式記事ページ WebFetch／自社=ダッシュボード |
| Threads/Pinterest/Twitch | 反応の一部のみ公開 | 各Insights | 自社API(要token)／他人詳細は不可 |

### 無認証で即読める確定計器（2026-07-22 実測済み・低頻度で）
- はてブ件数: `https://bookmark.hatenaapis.com/count/entry?url=<URL>` → 裸の整数
- Qiita: `https://qiita.com/api/v2/items?query=<kw>`（60req/h）→ likes_count/stocks_count
- Zenn: `https://zenn.dev/api/articles?order=liked_count` → liked_count
- iTunes/App Store: `https://itunes.apple.com/search?term=<kw>&country=jp&entity=software` → averageUserRating/userRatingCount
- PubMed件数: `https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=pubmed&term=<q>&retmode=json` → esearchresult.count（件数≠正しさ）
- Wikipedia閲覧: Wikimedia Pageviews API ／ npm: npm Downloads API ／ Trends日次: WebFetch `trends.google.com/trending/rss?geo=JP`（相対）
- 取れなかった実例: Reddit `top.json`=WebFetch遮断・PatentsView=要APIキー → Codex横断 or 別ルート

### 分野別の確定計器（鍵あり・分野の回に実測して索引へ）
- 株: EDINET API(`EDINET_API_KEY`)・J-Quants(`JQUANTS_API_KEY`)・JPX空売り/信用残・TDnet
- マネタイズ/生活: e-Stat(要appId)・法人番号・政府調達
- 健康: PubMed件数・ClinicalTrials.gov・PMDA・厚労省(e-Stat)
- 旅行: 観光庁宿泊統計・JNTO・気象庁
- ポケカ: PSA Population Report・公式大会参加者

### フォールバックの鉄則
- 検索ツールは1回試して認証/課金/接続エラーなら即フォールバック（grok403→syndication いいね/builtin、GSC auth error→復旧まで検索流入は空欄扱い）。接続状態は本文書に固定しない（下の Don'ts）。

## Don'ts

- **builtinで済むものをMCPで呼ばない** — GitHub starは`gh`、WebSearchはbuiltin。MCP経由は10倍遅い
- **grepで集計しない** — JSONL は `jq` か `env-factcheck`。grep は artifact に騙される
- **同一ソースを複数スキルから独立に叩かない** — Canonical Module原則のリサーチ版
- **X/バズ系クエリを WebSearch(builtin) で取らない** — バズ・いいね・話題・トレンド・バイラルを含む X検索は **`mcp__grok-search__web_search` sources=["x"]** を使う。WebSearch(builtin) は likes/views を返さないため `/fetch-engagement` での再計測が必要になり二度手間（実測: builtin 409回 / grok-search 62回 の棲み分けが崩れていた）
- **補助ルートを個別に直叩きしない** — HN/Reddit/Zenn/Qiita/はてブ/Hugging Face 等は Codex MCP の「横断」機能に任せる。個別curl叩きは情報源追加のたびにルーティング表が肥大する
- **どのツールが今使えるかを本文書に書かない** — 検索ツールは1回試して認証/課金/接続エラーなら即フォールバック列へ移る。接続・課金状態の正本は `claude mcp list`（本文書冒頭の掟）。「grok が今使える/使えない」等を本文に固定しない（drift 源になる）
