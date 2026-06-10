# データ可視化・レポート設計の原則 (Tufte / Few / Minto / Diátaxis / 公式)

Obsidian に依存しない普遍原則。Obsidian 表現に落とす前の「設計の判断軸」。

> 構文そのものの詳細は [[obsidian-markdown]] skill に委譲。本ファイルは「**いつ・何のために使うか**」のカタログ。

### 結論先出し (Minto/SCQA・BLUF)
レポート/ノート冒頭に「答え（結論・推奨）」を 1 ブロックで置き、以降を根拠で支える逆ピラミッド構造。読み手は結論だけで意思決定でき、必要なら下へ深掘りできる。SCQA (状況→複雑化→問い→答え) で導入を組み立てると、なぜこの結論かが自然につながる。
- **いつ使うか**: 全レポート・分析サマリー・findings ノート・経営層向け 1-pager。特に忙しい読み手（執行層）に渡す資料。prime_crm の key_findings や executive_summary に最適。
- **実装の要点**: ノート冒頭に `> [!success] 結論` callout で推奨を 1-2 行。直後に `## なぜ (根拠)` 見出しで 3 本柱を箇条書き。Obsidian なら `> [!abstract]- 詳細根拠` の foldable callout で深掘りを折りたたみ、スキャン性と網羅性を両立。
- 出典: [modelthinkers.com](https://modelthinkers.com/mental-model/minto-pyramid-scqa) `◎広く知られる慣行`

### Obsidian callout で情報を意味づけ分類
blockquote 拡張記法で「注意・結論・例・質問」など意味別の色付きボックスを作り、本文の流し読み中でも種別が一目で分かる。13 種のタイプ (note/tip/warning/success/danger/question/example/quote 等) と別名 (summary, tldr, caution 等) が公式サポート。
- **いつ使うか**: 重要結論の強調、注意喚起、補足の隔離、FAQ。レポートで「これは結論」「これは前提リスク」を視覚的に分離したい場面すべて。
- **実装の要点**: `> [!tip] カスタムタイトル` で種別+任意タイトル。本文は次行に `> 内容`。種別の正確な構文は公式リファレンス参照。タイプ別に自動で色とアイコンが付く。
- 出典: [obsidian.md](https://obsidian.md/help/Editing+and+formatting/Callouts) `✅出典確認`

### foldable callout で詳細を折りたたみスキャン性確保
callout を初期折りたたみ状態にして、サマリーだけ見せ詳細は必要な人だけ開く。長文レポートでも「上から読めばスキャンでき、深掘りは展開」という二層構造を 1 ファイルで実現。rules/41 の「vault=サマリー / repo=実体」思想とも整合。
- **いつ使うか**: 統計根拠・SQL・補足ログ・長い前提条件など「載せたいが普段は邪魔」な情報。Diátaxis の reference 的な細目を explanation の流れから隔離する用途。
- **実装の要点**: 種別の直後に `-` で初期折りたたみ、`+` で初期展開。例: `> [!faq]- 詳細な算出根拠`（`-` 付き）。クリックで開閉する。
- 出典: [obsidian.md](https://obsidian.md/help/Editing+and+formatting/Callouts) `✅出典確認`

### properties (YAML frontmatter) で構造化メタデータ
ノート冒頭に YAML で project/type/last_updated/KPI 等を構造化保存。Dataview/Bases から横断クエリでき、本文を汚さずに機械可読なメタ情報を持てる。型は text/number/checkbox/date/datetime/list の 6 種。
- **いつ使うか**: MOC・plan・findings など台帳系ノート。last_updated での drift 検出、target_cv/target_cpa の構造化、tags での分類。rules/41 の 6 必須フィールド運用そのもの。
- **実装の要点**: ファイル先頭を `---` で囲み `key: value`。数値は素のまま (`target_cv: 200`)、日付は `YYYY-MM-DD`、リストは `-` で複数行、wikilink は `"[[Note]]"` とクオート。
- 出典: [obsidian.md](https://obsidian.md/help/properties) `✅出典確認`

### Mermaid でフロー/関係を図解
コードフェンスでフローチャート・シーケンス・ガント等をテキストから描画。データのパイプライン・意思決定フロー・KPI ツリーを文章でなく図で示せる。ノードから内部ノートへリンクも可能。
- **いつ使うか**: ETL パイプライン構成、施策の依存関係、KPI 分解ツリー、Phase 遷移図。文章 3 段落より図 1 枚が速い構造説明。
- **実装の要点**: ```mermaid フェンス内に `graph TD` + `A --> B`。ノートへリンクは `class Biology,Chemistry internal-link;` を付与。表示は折りたたみ callout 内にも置ける。
- 出典: [obsidian.md](https://obsidian.md/help/Editing+and+formatting/Advanced+formatting+syntax) `✅出典確認`

### embed (トランスクルージョン) で正本を一箇所に
別ノートの全体/見出しセクション/ブロック/画像を `![[...]]` で埋め込み表示。同じ内容をコピーせず参照だけで再利用でき、drift（二重管理）を防ぐ。rules/40 の Anti-drift 原則と完全一致。
- **いつ使うか**: MOC から各施策サマリーを集約、複数レポートで共通の KPI 定義を参照、画像をサイズ指定で挿入。「同じ情報を 2 箇所に書かない」を徹底する場面。
- **実装の要点**: 全体 `![[Note]]` / 見出し `![[Note#見出し]]` / ブロック `![[Note#^blockid]]` / 画像幅指定 `![[img.png|100]]`（幅のみで比率維持、`|100x145` で縦横）。
- 出典: [obsidian.md](https://obsidian.md/help/embeds) `✅出典確認`

### Canvas で空間的に俯瞰
無限キャンバス上にノート・カード・画像・矩形を自由配置し、矢印で関係を結ぶ。線形の md では表せない「全体像・分岐・クラスタ」を空間レイアウトで把握できる。JSON Canvas は公開フォーマット。
- **いつ使うか**: プロジェクト全体マップ、ブレスト、施策の優先度マトリクス（2軸配置）、調査結果のクラスタリング。経営層 1-pager の俯瞰図。
- **実装の要点**: 新規 Canvas ファイルを作成し、既存ノートをドラッグでカード化、矩形でグルーピング、矢印で因果/順序を表現。`.canvas` (JSON Canvas) として保存され他ツールとも相互運用。
- 出典: [obsidian.md](https://obsidian.md/help/Plugins/Canvas) `✅出典確認`

### data-ink ratio 最大化 / chartjunk 除去
Tufte の中核原則。グラフのインクは「データを表す非冗長な部分」に最大限割り当て、グリッド線・枠・3D・背景・装飾 (=chartjunk) を削る。要素を引くほど数値が際立ち、誤読も減る。
- **いつ使うか**: あらゆるチャート作成・レビュー時。ダッシュボードや mermaid/表で「飾りすぎ」を疑うとき。スクショ前の最終チェック。
- **実装の要点**: グリッド線を薄いグレーか削除、枠線・目盛りを最小化、凡例より直接ラベル、背景は白。Obsidian の表は罫線が元々ミニマルなので、不要な列を削るだけで data-ink が上がる。
- 出典: [www.edwardtufte.com](https://www.edwardtufte.com/book/the-visual-display-of-quantitative-information/) `◎広く知られる慣行`

### small multiples (小さな同型図の反復)
同じ軸・スケールの小さなグラフを格子状に並べ、カテゴリ/期間ごとの差分を一目で比較させる Tufte の手法。1 枚の複雑な多系列図より、認知負荷が低く比較が速い。
- **いつ使うか**: セグメント別・チャネル別・月別など「同じ指標を多数の切り口で比較」する分析。広告チャネル別 LTV、worry_group 別継続率など prime_crm の比較分析に最適。
- **実装の要点**: 全パネルで軸スケールを統一して横並び配置。Obsidian では同型の小表を 2-3 列のグリッド状に並べる、または mermaid/画像を表セルに入れて整列。スケール統一が命。
- 出典: [www.geeksforgeeks.org](https://www.geeksforgeeks.org/data-visualization/mastering-tuftes-data-visualization-principles/) `◎広く知られる慣行`

### 色は最小限・グレー基調 + 1 色強調
全体をグレー/中間色で描き、注目させたい 1 系列だけアクセント色で塗る。「全部強調=何も強調しない」を避け、視線を意図した 1 点に誘導する。色覚多様性 (人口の 4%超) にも配慮。
- **いつ使うか**: トレンドの中で当年だけ目立たせる、異常値・閾値超えだけ赤、KPI のうち最重要 1 つだけ色付け。ダッシュボードと findings の図全般。
- **実装の要点**: ベースは `#999` 系グレー、強調は 1 色のみ。色だけに頼らず直接ラベル/太字も併用。Obsidian なら表で重要行を `**太字**`、callout 種別 (danger=赤) を閾値超えに使い分け。
- 出典: [xdgov.github.io](https://xdgov.github.io/data-design-standards/components/colors) `✅出典確認`

### ダッシュボードは 1 画面・サイズで重要度を表現 (Stephen Few)
ダッシュボードはスクロールさせず単一画面に収め、全体の関連が一目で見える状態を作る。各情報の重要度を相対評価し、重要なものほど大きく・左上に置く。サイズ=重要度の視覚的手がかり。
- **いつ使うか**: 監視用ダッシュボード、KPI サマリー、経営層 1-pager。「at-a-glance（一目で）」の把握が目的の画面。
- **実装の要点**: 最重要 KPI を左上・大きく、補助指標は右下・小さく。Obsidian なら H2 セクション順と表の列順で重要度を表現し、最重要ブロックを冒頭の callout に格上げ。
- 出典: [www.perceptualedge.com](https://www.perceptualedge.com/articles/Whitepapers/Common_Pitfalls.pdf) `✅出典確認`

### スキャンできるレイアウト (見出し・短段落・F 字)
MS スタイルガイド準拠。長い密なテキストは敬遠されるため、短い見出し・短文・短段落 (3-7 行) に分解。読者は F 字に読むので最重要情報を上部・左上・段落冒頭に front-load する。
- **いつ使うか**: 全ドキュメント・レポート・README・MOC。オンラインで読まれる長文すべて。「読まずに離脱」を防ぎたい場面。
- **実装の要点**: 見出しキーワードを前置 (`## LTV: チャネル別の差` 等)、段落は 3-7 行で改行、重要語を `**太字**`、長文には目次と `Back to top` リンク。1 行段落も可。
- 出典: [learn.microsoft.com](https://learn.microsoft.com/en-us/style-guide/scannable-content/) `✅出典確認`

### Diátaxis で文書の種類を混ぜない
ドキュメントを tutorial / how-to / reference / explanation の 4 種に分け、1 ファイルで混在させない。「手順を知りたい人」と「なぜを理解したい人」は別ニーズなので、分離すると各々が速く目的に到達できる。
- **いつ使うか**: docs/ 配下の設計・運用ドキュメント整備、README とランブックの切り分け、findings (説明) と setup-runbook (how-to) の役割分担。
- **実装の要点**: how-to は番号付き手順 + コピペ可能コマンド、reference は事実の表 (解釈なし)、explanation は why の散文、tutorial は手取り足取り。ファイル/見出し単位で種別を 1 つに固定。
- 出典: [diataxis.fr](https://diataxis.fr/start-here/) `✅出典確認`

### Google スタイル: 能動態・短文・記述的リンク文言
明快さ最優先。能動態・直接話法・短文を使い、否定形/方向依存語 (右の/上の)/句動詞/略語を避ける。リンクは『ここをクリック』でなく行き先を表す記述的文言にする。手順は選択肢列挙でなく『何をすべきか』を断定 (prescriptive)。
- **いつ使うか**: 技術ドキュメント・手順書・API リファレンス・README の文章すべて。グローバル/翻訳前提の文書では特に効果大。
- **実装の要点**: 『〜される』→『〜する』、1 文 1 アクション、リンクは `[チャネル別 LTV 分析](...)` のように内容を明示。手順は『A を実行する』と命令形で断定。日付は曖昧形式を避け ISO。
- 出典: [developers.google.com](https://developers.google.com/style/highlights) `✅出典確認`

### README/ドキュメントの構造順 (重要度降順)
ニュース記事構造に倣い、一般情報を先頭、詳細を後方、任意項目を末尾に。Title→Description (何を/誰に)→Installation→Usage→詳細の順。読者は前提知識ゼロと仮定し、コピペ可能なコマンドと視覚的な見出し構造で組む。
- **いつ使うか**: 全 repo の README、setup-runbook、data-sources.md など入口ドキュメント。新規参加者/別 PC 引き継ぎ時に読まれる文書。
- **実装の要点**: `# タイトル` → 1-2 行の概要 → `## Installation` (コピペ可コマンド) → `## Usage` (例 + スクショ) → 詳細セクション。各セクションは短く、Markdown 見出しで視覚構造化。
- 出典: [www.freecodecamp.org](https://www.freecodecamp.org/news/how-to-structure-your-readme-file/) `◎広く知られる慣行`

## 核心原則

- 結論先出し (BLUF / Minto): 答えを冒頭に置き、以降を根拠で支える。読み手は結論だけで判断でき、深掘りは任意にする
- vault=サマリー+索引 / repo=実体: 同じ情報を 2 箇所に書かず embed (トランスクルージョン) で参照。drift を構造的に防ぐ
- 引く美学 (Tufte): data-ink を最大化し chartjunk を削る。装飾・グリッド・色を減らすほどデータが際立つ
- 色と強調は希少資源: グレー基調 + 1 色強調。全部強調は何も強調しないのと同じ。色だけに頼らず直接ラベル併用
- スキャンできる構造 (MS/Google): 短い見出し・短段落・重要語の front-load・F 字レイアウト。読まずに離脱させない
- 文書の種類を混ぜない (Diátaxis): how-to / reference / explanation を分離し、各読者ニーズへ最短到達させる
