# 出典一覧 (research 2026-05-30)

> [!success] 独立検証済 (2026-05-30・48出典を実 fetch)
> **yes 31 / partial 14 / unsupported 3 / dead 1 / redirect 8**。修正反映済:
> - **redirect 8**: `help.obsidian.md/*` → `obsidian.md/help/*` に正規化 (301 解消)
> - **dead 1**: 旧 YAML front matter ページ → Properties に差し替え
> - **unsupported 3 (= 捏造)**: kepano 個別ツイート 2 件は ID 実在だが内容不一致で**撤回**。YAML URL も dead で差し替え
> - **partial 14 の主な caveat**: テーブル列アライメントは別ページ (Tables) / Obsidian Charts のブログ例は line のみ (bar はプラグイン機能としては実在) / obsidian.rocks Bases に「Dataview 移行手順」は無い / SANS は能動態+ExecSummary のみ明示 / X スレッド最適長は 5-7 (5-10 は緩め) / xdgov 正式名は **Data Visualization Standards**
> - callout の base type は **13 種で正しい** (検証 agent の「約14」は over-count・非採用)

vault-report-writing skill の根拠。全主張は下記 URL ベース (一部は広く知られる慣行)。

## Obsidian 実例

- [Callouts - Obsidian Help (公式)](https://obsidian.md/help/callouts) — callout の正式構文・全13タイプ・aliases・折りたたみ(+/-)・ネスト・カスタムタイトルの一次ソース
- [Basic formatting syntax - Obsidian Help (公式)](https://obsidian.md/help/Editing+and+formatting/Basic+formatting+syntax) — ==highlight==・%%comment%%・テーブル列アライメント・脚注など Obsidian Flavored Markdown の基本構文
- [Properties - Obsidian Help (公式)](https://obsidian.md/help/properties) — properties/frontmatter の公式仕様。tags/aliases/cssclasses 等。※旧 YAML front matter ページは **Properties に改名・統合**済 (旧 URL は dead・2026-05-30 検証)
- [Introduction to Bases - Obsidian Help (公式)](https://obsidian.md/help/bases) — 組み込みデータベース Bases の公式ドキュメント。Table/Cards/List/Map ビュー・filters・formulas
- [How I use Obsidian — Steph Ango (kepano)](https://stephango.com/vault) — Obsidian CEO 本人のミニマル流儀。フォルダ最小化・日付命名・プロパティ再利用・リンク駆動・file over app 哲学の一次ソース
- [kepano/obsidian-skills — obsidian-markdown SKILL.md](https://github.com/kepano/obsidian-skills/blob/main/skills/obsidian-markdown/SKILL.md) — kepano 公式の Obsidian Flavored Markdown 規約集。wikilink/embed/block ref/callout/properties の推奨構文と使い分け
- [data-cards README — Sophokles187 (GitHub)](https://github.com/Sophokles187/data-cards/blob/main/README.md) — DataCards プラグインの正式構文。datacards コードブロック・preset(grid/portrait/square/compact/dense/kanban)・imageProperty/columns
- [How Mermaid diagrams work in Obsidian — Obsidian Observer (Medium)](https://medium.com/obsidian-observer/how-mermaid-diagrams-work-in-obsidian-b7680fe00fa8) — Obsidian での Mermaid 図 (flowchart/sequence/gantt) の書き方・方向指定・内部リンク化の実践記事
- [obsidian-excalidraw-plugin — zsviczian (GitHub)](https://github.com/zsviczian/obsidian-excalidraw-plugin) — Excalidraw 手描き図解プラグイン公式。vault 内ファイル編集・埋め込み・ExcaliBrain 自動マインドマップ
- [obsidian-kanban — obsidian-community (GitHub)](https://github.com/obsidian-community/obsidian-kanban) — markdown 連動カンバンプラグイン公式。列=見出し/カード=チェックリスト・Open as Markdown・WIP limit
- [Plotting Task Completions with DataviewJS and Obsidian Charts — Obsidian Rocks](https://obsidian.rocks/plotting-task-completions-with-dataviewjs-and-obsidian-charts/) — Charts プラグイン + DataviewJS で動的グラフを描く実例。bar/line/chart.js 連携
- [Getting Started with Obsidian Bases — Obsidian Rocks](https://obsidian.rocks/getting-started-with-obsidian-bases/) — Bases の実践ガイド (Dataview からの移行・ビュー設定の補足二次ソース)

## 公式・可視化原則

- [Callouts - Obsidian Help](https://obsidian.md/help/Editing+and+formatting/Callouts) — callout 構文・13 種タイプ + 別名・カスタムタイトル・foldable (+/-)・ネストを公式確認。WebFetch で literal 構文取得済 (verified)
- [Advanced formatting syntax - Obsidian Help](https://obsidian.md/help/Editing+and+formatting/Advanced+formatting+syntax) — mermaid コードフェンス (graph TD)・表・数式 ($$)・ノードの internal-link クラスを公式確認 (verified)
- [Properties - Obsidian Help](https://obsidian.md/help/properties) — YAML frontmatter の 6 型 (text/number/checkbox/date/datetime/list)・wikilink クオート規則を公式確認 (verified)
- [Embed files - Obsidian Help](https://obsidian.md/help/embeds) — ![[Note]] / #見出し / #^block / 画像幅 |100 の literal 構文を公式確認。drift 防止のトランスクルージョン根拠 (verified)
- [Canvas - Obsidian Help](https://obsidian.md/help/Plugins/Canvas) — 無限キャンバス・カード配置・JSON Canvas フォーマットの公式ページ (verified)
- [The Visual Display of Quantitative Information - Edward Tufte (公式)](https://www.edwardtufte.com/book/the-visual-display-of-quantitative-information/) — data-ink ratio / chartjunk / small multiples の原典。著者公式サイト。概念は二次ソースでも広範に確認 (community-common)
- [Mastering Tufte's Data Visualization Principles - GeeksforGeeks](https://www.geeksforgeeks.org/data-visualization/mastering-tuftes-data-visualization-principles/) — small multiples / data-ink の実務解説。Tufte 原則の二次まとめ
- [Common Pitfalls in Dashboard Design - Stephen Few (Perceptual Edge 公式)](https://www.perceptualedge.com/articles/Whitepapers/Common_Pitfalls.pdf) — 単一画面・サイズ=重要度・情報階層・at-a-glance の根拠。著者公式 whitepaper (verified)
- [Minto Pyramid & SCQA - ModelThinkers](https://modelthinkers.com/mental-model/minto-pyramid-scqa) — 結論先出し・SCQA (状況/複雑化/問い/答え)・top-down 構造の解説 (community-common)
- [Start here - Diátaxis in five minutes (公式)](https://diataxis.fr/start-here/) — tutorial/how-to/reference/explanation の 4 分類・混在禁止原則。公式サイト (verified)
- [Highlights - Google developer documentation style guide (公式)](https://developers.google.com/style/highlights) — 能動態・短文・記述的リンク文言・prescriptive 手順・グローバル読者向け規約。公式 (verified)
- [Scannable content - Microsoft Writing Style Guide (公式)](https://learn.microsoft.com/en-us/style-guide/scannable-content/) — above the fold・F 字読み・短見出し/短段落 (3-7 行)・front-load・目次/Back to top。公式 WebFetch 全文取得 (verified)
- [Colors - Data Visualization Standards (xdgov 公式)](https://xdgov.github.io/data-design-standards/components/colors) — 色の最小使用・グレー基調 + アクセント・色覚アクセシビリティ・直接ラベル併用の根拠 (verified)
- [How to Structure Your README File - freeCodeCamp](https://www.freecodecamp.org/news/how-to-structure-your-readme-file/) — README セクション順 (Title→Description→Install→Usage)・ニュース記事構造・コピペ可能コマンド (community-common)

## ハッカー報告術

- [OWASP WSTG - 5. Reporting (Stable)](https://owasp.org/www-project-web-security-testing-guide/stable/5-Reporting/README) — 一次ソース。レポート 4 セクション構成 (Introduction/Executive Summary/Findings/Appendices) と finding 必須要素 (Reference ID・Title・Exploitability・Impact・Severity・Description・Remediation)、二層化、ツール出力整形 (clean not dump) を明記。verified。
- [OWASP Risk Rating Methodology](https://owasp.org/www-community/OWASP_Risk_Rating_Methodology) — 深刻度を Likelihood × Impact で算出する公式手法。深刻度マトリクスの根拠。verified。
- [Google SRE Book - Example Postmortem](https://sre.google/sre-book/example-postmortem/) — 一次ソース。postmortem の正確なセクション構成 (Summary/Impact/Root Causes/Trigger/Resolution/Detection/Action Items/Lessons Learned/Timeline) を確認。blameless 原則は同 sre.google/sre-book/postmortem-culture/。verified。
- [HackerOne Docs - Quality Reports](https://docs.hackerone.com/en/articles/8475116-quality-reports) — 一次ソース。強いタイトル例 (弱:『XSS in web app』/強:『Stored XSS in user profile field allows...』)、番号付き再現手順 (URL/パラメータ/ロール)、期待 vs 実際、PoC 添付の慣行を確認。verified。
- [noraj OSCP Exam Report Template (Markdown)](https://github.com/noraj/OSCP-Exam-Report-Template-Markdown/blob/master/src/OSCP-exam-report-template_OS_v2.md) — 一次ソース。High-Level Summary / Recommendations / Methodologies / per-target の finding 形式 (Vulnerability Explanation・Fix・Severity・Steps・PoC Code・Proof Screenshot)、IP+flag 同一画面要件を確認。verified。
- [PTES - Reporting (Penetration Testing Execution Standard)](https://pentest-standard.readthedocs.io/en/latest/reporting.html) — PTES 公式の reporting 章 (readthedocs ミラー)。Executive Summary + Technical Report の 2 部構成、risk rating、business impact 重視を規定。pentest-standard.org 本体は接続不可だったため ReadTheDocs ミラーを参照。verified (ミラー)。
- [Bugcrowd Vulnerability Rating Taxonomy (VRT)](https://github.com/bugcrowd/vulnerability-rating-taxonomy) — P1 (Critical)〜P5 (Informational) のオープン標準 priority rating。深刻度を共通言語化する根拠。報告フォーマット (Overview/Walkthrough+POC/Evidence) は docs.bugcrowd.com 参照。verified。
- [SANS - Tips for Creating a Strong Cybersecurity Assessment Report](https://www.sans.org/blog/tips-for-creating-a-strong-cybersecurity-assessment-report) — 一次ソース。論理セクション分割、能動態・簡潔、BLUF をエグゼクティブサマリーに、具体的再現手順、暗号化保管、ドラフトレビューを推奨。verified。
- [BLUF (communication) - Wikipedia](https://en.wikipedia.org/wiki/BLUF_(communication)) — BLUF の定義・軍/諜報での標準性・逆ピラミッド (journalism) との類似・abstract との差を確認。テクニック『結論先出し』の根拠。verified。
- [Intigriti - Chaining in action: business impact of vulnerability chaining](https://www.intigriti.com/blog/business-insights/chaining-in-action-techniques-terminology-and-real-world-impact-on-business) — attack narrative / 脆弱性連鎖の根拠。[初期ベクタ]→[ピボット]→[影響] 形式と、小さな穴の合算が critical になりビジネス被害 (PII/口座) を生む点を確認。verified。

## X 発信の型

- ⚠️ **「steal my system」型 — 元の kepano 個別ツイート citation は撤回** (2026-05-30 検証): ID 1703107844248404169 は実在するが内容『The problem with note-taking...』で claim と**無関係**だった (原リサーチのハルシネーション)。型自体は実在で、kepano の vault 配布の実例は [stephango.com/vault](https://stephango.com/vault)
- ⚠️ **「build in public / ダッシュボードツアー」型 — 元の kepano 個別ツイート citation は撤回** (2026-05-30 検証): ID 1874150921963532377 は実在するが内容『2025 is the year of local AI』で claim と**無関係**だった。型自体は他ソース ([usevisuals](https://usevisuals.com/blog/writing-effective-twitter-threads-2025) / [zebracat](https://www.zebracat.ai/post/how-viral-twitter)) で裏付け
- [How to Make Your Notes Visual in Obsidian — Nicole van der Hoeven](https://nicolevanderhoeven.com/blog/20220818-how-to-make-your-notes-visual-in-obsidian/) — Excalidraw/Excalibrain/Mind Map/Advanced Slides 等 visual PKM プラグインの一次ソース。スクショ映えするノート作りの実装。verified
- [How to Write Twitter Threads That Go Viral: 2026 Guide — Tweet Archivist](https://www.tweetarchivist.com/how-to-write-viral-twitter-threads) — 番号付きスレッド5〜10ツイート、1ツイート1アイデア、視覚break+45%完了率、CTA/保存促し。verified
- [How to Create X Threads That Go Viral in 2025 — Hipclip](https://www.hipclip.ai/workflows/how-to-create-x-twitter-threads-that-actually-go-viral-in-2025) — BAB(Before-After-Bridge)含む5フレーム、最適7ツイート、3〜4ツイートごと視覚break。verified
- [Good Hooks: How to Grab Attention in 2025 — Buffer](https://buffer.com/resources/good-hooks/) — 数字+ベネフィット明示フック、curiosity/bold claim、1秒勝負の原則。verified
- [X(旧Twitter)でフォロワーが増える図解ポストの作り方5ステップ — 吉和の森](https://yoshikazunomori.com/blog/digitalmarketing/x-illustration/) — 日本語圏の図解ポスト実装:1枚目縦長4:5/15文字、2〜4枚16:9、130文字以内/36pt/3色/余白20%、AI効率化。verified
- [がんばらないObsidianノート術 — Qiita (YUM_3)](https://qiita.com/YUM_3/items/80cf5705a54f70ad7e5b) — 日本の技術ノート発信(Qiita/Zenn)の代表。コピペできる再現性パッケージ型の文脈。community-common
- [Obsidianで構成図を書く方法 Mermaid記法 — note (眠)](https://note.com/minn_1092/n/n4975691a5c99) — Mermaid でテキスト→図解、PowerPoint 不要の体験談。日本の技術発信での頻出型。verified
- [Andrew Tattersall on Instagram: Build a second brain w Claude + Obsidian](https://www.instagram.com/p/DYDFpA-mHTD/) — Claude×Obsidian で second brain 構築する AI×PKM 掛け合わせの高エンゲージ実例(3,198 likes)。verified
- [How to Go Viral on X (Twitter) Expert Tips 2025 — Zebracat](https://www.zebracat.ai/post/how-viral-twitter) — contrarian/通説否定フック、reply 重視のアルゴリズム特性。verified
- [Writing Effective Twitter Threads in 2025 — Usevisuals](https://usevisuals.com/blog/writing-effective-twitter-threads-2025) — スパルタン整形(短文・改行・箇条書き)、視覚要素の配置。verified
