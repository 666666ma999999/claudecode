# Obsidian 表現 — レポートでの使い分けカタログ

Obsidian 公式機能 + コミュニティ実践を「レポートを見やすくする」観点で整理。

> 構文そのものの詳細は [[obsidian-markdown]] skill に委譲。本ファイルは「**いつ・何のために使うか**」のカタログ。

### Callout (admonition) のタイプ別使い分け
`> [!type]` ブロックで色とアイコン付きの注意喚起ボックスを作る。13 種の組み込みタイプ (note/abstract/info/todo/tip/success/question/warning/failure/danger/bug/example/quote) を意味で使い分けると、長文レポートでも視線が要点に誘導される。
- **いつ使うか**: レポートの結論・注意点・補足・TODO を本文から視覚的に分離したいとき。分析レポートなら success=確定知見 / warning=留保データ / question=未解決の論点 / info=前提条件、のように意味を割り当てる。
- **実装の要点**: `> [!success] 確定知見` のように type + カスタムタイトル。本文は2行目以降に `> ` を付けて記述。aliases も使える (summary→abstract, hint→tip, caution→warning, error→danger 等)。
- 出典: [obsidian.md](https://obsidian.md/help/callouts) `✅出典確認`

### 折りたたみ Callout でダッシュボードを圧縮
Callout タイプ識別子の直後に `-`(初期折りたたみ) / `+`(初期展開) を付けると開閉可能になる。詳細データを畳んでおき、見出しだけ一覧できる「アコーディオン型」ノートにできる。
- **いつ使うか**: 1 ノートに多数のセクション (Phase 別・施策別・FAQ) を載せる司令塔/MOC やダッシュボードで、初期表示を要約だけにして圧縮したいとき。
- **実装の要点**: `> [!faq]- よくある質問` (折りたたみ) / `> [!tip]+ 展開済み` 。ネストは `> > [!todo]` のように blockquote マーカーを重ねる。
- 出典: [obsidian.md](https://obsidian.md/help/callouts) `✅出典確認`

### ==ハイライト== と %% コメント %% の使い分け
`==text==` は黄色マーカーで本文中の語句を強調 (Obsidian 独自・標準 MD 外)。`%% ... %%` は編集モードでのみ見え、Reading view と Publish では非表示になるコメント。
- **いつ使うか**: ハイライトはレポート内の数値・キーワードの強調に。コメントは『レビュー後に消すメモ』『drift 注意書き』など読者に見せたくない作業メモを本文に残すときに使う。
- **実装の要点**: `重要な数値は ==52,978 件== でした。` / `%% TODO: 出典を後で確認 %%` (インラインまたは複数行ブロック)。
- 出典: [obsidian.md](https://obsidian.md/help/Editing+and+formatting/Basic+formatting+syntax) `✅出典確認`

### Mermaid 図 (フローチャート/シーケンス/ガント) を本文に埋め込む
````mermaid```` コードブックでテキストからフロー図・シーケンス図・ガントチャートを生成。プラグイン不要 (Obsidian 組み込み)。テキストを編集すれば図が即更新されるので diff・版管理しやすい。
- **いつ使うか**: パイプラインのデータフロー、施策の意思決定分岐、Phase スケジュール (ガント) を図解したいとき。スクショ画像と違い検索・差分・リンクが効く。
- **実装の要点**: ```` ```mermaid\nflowchart LR\n A[取得] --> B[集計] --> C[レポート]\n``` ```` 。方向は TB/LR/BT/RL。ガントは `gantt` キーワード、`%%` でコメント、タグは active/done/crit/milestone。ノード→ノートのリンクは `class NodeName internal-link;`。
- 出典: [medium.com](https://medium.com/obsidian-observer/how-mermaid-diagrams-work-in-obsidian-b7680fe00fa8) `✅出典確認`

### Properties (YAML frontmatter) でメタデータを構造化
ノート冒頭の `---` で囲った YAML に title/date/tags/aliases/cssclasses 等を持たせる。Properties はテーブル化・フィルタ・自動化の基盤になり、`cssclasses` でノート単位の見た目も切り替えられる。
- **いつ使うか**: 全ノートに一貫したメタ (project / type / last_updated / status) を持たせ、後述の Dataview/Bases で集計・索引したいとき。レポートの鮮度管理 (last_updated) にも有効。
- **実装の要点**: `---\ntitle: 月次レポート\ntags:\n  - report\naliases:\n  - 5月レポート\ncssclasses:\n  - wide-table\n---`。プロパティ名は短く再利用可能に (kepano は `start` を `start-date` より優先)。
- 出典: [obsidian.md](https://obsidian.md/help/properties) `✅出典確認`

### GFM パイプテーブル + 列アライメントで数値表を整える
`|` 区切りのテーブルで、区切り行に `:--`(左)/`:--:`(中央)/`--:`(右) を指定して列ごとに揃える。数値列を右揃え・ラベル列を左揃えにすると桁が揃い読みやすい。
- **いつ使うか**: KPI 表・施策一覧・現状/目標比較など、行数が中程度で『一目で比較』させたい表。大量行・動的集計は Dataview/Bases に寄せる。
- **実装の要点**: `| 指標 | 現状 | 目標 |\n| :-- | --: | --: |\n| CV | 120 | 150 |`。セル内改行は `<br>`、長い表は frontmatter `cssclasses` + CSS snippet で横幅調整。
- 出典: [obsidian.md](https://obsidian.md/help/Editing+and+formatting/Basic+formatting+syntax) `✅出典確認`

### Dataview の TABLE クエリで動的索引/集計表を生成
`dataview` コードブロックに `TABLE ... FROM ... WHERE ... SORT ...` を書くと、frontmatter プロパティを横断集計した表を自動生成。手で索引を更新せずに済む。
- **いつ使うか**: 複数ノート (施策・findings・タスク) を横断して一覧・進捗ダッシュボードを作るとき。各ノートのメタを直すだけで索引が自動追従するので drift しにくい。
- **実装の要点**: ```` ```dataview\nTABLE status, last_updated FROM #report\nWHERE status != "done"\nSORT last_updated DESC\n``` ````。より複雑な集計は `dataviewjs` で JS API。
- 出典: [obsidian.rocks](https://obsidian.rocks/creating-dynamic-graphs-in-obsidian/) `✅出典確認`

### DataCards で Dataview テーブルをカード/カンバン表示に変換
`datacards` コードブロックに Dataview クエリ + 設定を書くと、表をカードレイアウト (grid/portrait/square/compact/dense/kanban プリセット) に変換。画像プロパティ付きで見栄えするギャラリーやカンバンになる。
- **いつ使うか**: 書籍/施策/プロジェクトを表ではなくサムネイル付きカードやカンバンで俯瞰したいダッシュボード。視覚的に映えるショーケースを作りたいとき。
- **実装の要点**: ```` ```datacards\nTABLE author, rating, cover FROM #books\nSORT rating DESC\n// Settings\npreset: portrait\nimageProperty: cover\ncolumns: 4\n``` ````。表示したい全プロパティ (画像含む) をクエリに列挙する必要あり。
- 出典: [github.com](https://github.com/Sophokles187/data-cards/blob/main/README.md) `✅出典確認`

### Charts / ChartsView プラグインで棒・折れ線グラフを埋め込む
`chart` コードブロックに YAML (type/labels/series) を書く、または `dataviewjs` + chart.js でインタラクティブな bar/line/pie/radar グラフを描画。CSV・ノート内データ・Dataview クエリを入力源にできる。
- **いつ使うか**: KPI 推移・タスク完了数の時系列など、数値トレンドを図示したいレポート/ダッシュボード。表より傾向が一目で伝わる場面。
- **実装の要点**: ```` ```chart\ntype: bar\nlabels: [1月, 2月, 3月]\nseries:\n  - title: CV\n    data: [120, 135, 150]\n``` ````。動的化は ChartsView の『Insert Template → Dataviewjs Example』から雛形挿入。
- 出典: [obsidian.rocks](https://obsidian.rocks/plotting-task-completions-with-dataviewjs-and-obsidian-charts/) `✅出典確認`

### Excalidraw / ExcaliBrain で手描き図解・自動マインドマップ
Excalidraw プラグインは手描き風のホワイトボード/ワイヤフレーム/ビジュアルノートを vault 内ファイルとして編集・埋め込み可能。ExcaliBrain は links/tags/dataview/frontmatter を解釈して vault 全体のマインドマップを自動生成する。
- **いつ使うか**: アーキ図・概念整理・ブレストなど自由レイアウトの図解が要るとき (Excalidraw)。ノート間の関係性をグラフで俯瞰したいとき (ExcaliBrain)。
- **実装の要点**: コマンドパレットから新規 Excalidraw 描画を作成→`![[drawing.excalidraw]]` でノートに埋め込み。LaTeX・Markdown 埋め込み・スクリプトエンジン対応。ExcaliBrain は有効化すると自動でリンクからマップ生成。
- 出典: [github.com](https://github.com/zsviczian/obsidian-excalidraw-plugin) `✅出典確認`

### Kanban プラグインで markdown 連動のボード管理
列とカードのカンバンボードを作るが、実体は markdown (列=見出し / カード=チェックリスト)。『Open as Markdown』でプレーンテキストとして編集でき、git 版管理とも相性が良い。WIP 上限やカード checkbox 表示も設定可能。
- **いつ使うか**: ToDo/Doing/Done のワークフロー、執筆パイプライン、施策の進行管理を視覚的にドラッグ操作したいとき。データは MD のままにしたいプロジェクトで有効。
- **実装の要点**: プラグイン有効化→『New kanban board』。三点メニュー『Open as Markdown』で `## 列名` + `- [ ] カード` のテキストを確認・編集。設定で Display card checkbox / WIP limit を切替。
- 出典: [github.com](https://github.com/obsidian-community/obsidian-kanban) `✅出典確認`

### Bases (組み込みデータベース) でノートを DB ビュー化
Obsidian 1.9+ のコアプラグイン Bases は、ノートをレコード・プロパティをフィールドとして Table/Cards/List/Map ビューで表示。filters (All views / This view の2段) と formulas (経過日数算出・条件付き表示等) を持つ、Dataview の公式後継的存在。
- **いつ使うか**: Dataview に依存せず公式機能で永続的なダッシュボード/索引を作りたいとき。プロパティでフィルタ・ソートし複数ビューを切り替えたい運用台帳・レポート集約に。
- **実装の要点**: `.base` ファイルを作成、または `base` コードブロックに埋め込み。filter は Property/Operator(is, contains, greater than 等)/Value の3要素。formula で `file.mtime` からの経過日数等を算出。
- 出典: [obsidian.md](https://obsidian.md/help/bases) `✅出典確認`

### Embed (トランスクルージョン) と Block Reference で再利用
`![[Note]]` でノート全体、`![[Note#見出し]]` でセクション、`![[Note#^block-id]]` で特定ブロックを別ノートに埋め込む (transclusion)。同じ内容を二重管理せず参照で一元化できる。
- **いつ使うか**: 司令塔/MOC に各レポートの要約セクションだけ集約したいとき。共通の前提・定義を1か所に書いて複数ノートから引きたいとき (drift 防止)。
- **実装の要点**: `![[月次レポート#結論]]` でセクション埋め込み。`![[image.png|300]]` で画像幅指定。ブロック ID は段落末尾に `^block-id` を付与し `![[Note#^block-id]]` で参照。
- 出典: [github.com](https://github.com/kepano/obsidian-skills/blob/main/skills/obsidian-markdown/SKILL.md) `✅出典確認`

### kepano 流ミニマル設計 (フォルダ最小化・リンク駆動・日付命名)
Obsidian CEO Steph Ango (kepano) のミニマル流儀: フォルダをほぼ使わず root 直置き、quick switcher とバックリンクで移動、プロパティ名を再利用・短縮、日付は `YYYY-MM-DD` で統一、未解決リンクも『将来の接続の手がかり』として歓迎。見た目は Minimal テーマ + Flexoki 配色。
- **いつ使うか**: vault 全体の設計哲学として。1ノートが複数テーマに属し分類しづらいとき (フォルダ階層より wikilink で多重所属を表現)。長期に壊れない『file over app』なレポート資産を作りたいとき。
- **実装の要点**: フォルダは References/Clippings/Attachments/Daily/Templates の管理用のみ。カテゴリ/タグは複数形・ネスト回避。最初の言及は必ずリンク化 `[[...]]`。frontmatter に `categories` プロパティで俯瞰整理。テーマは Minimal を採用。
- 出典: [stephango.com](https://stephango.com/vault) `✅出典確認`

## 核心原則

- 索引・集計は動的化して drift を防ぐ: 手書きの一覧表は古くなる。frontmatter プロパティ + Dataview/Bases/DataCards で『メタを直せば表が自動追従』する構造にすると、レポートが常に最新を保つ。
- 意味で視覚を割り当てる: callout タイプ・==ハイライト==・色は装飾ではなく『確定/留保/未解決/前提』など意味のレイヤーに対応させる。一貫した割当が読み手の視線誘導を生む。
- 図はテキストで持つ (diagrams as code): スクショ画像でなく Mermaid / Excalidraw(vault 内ファイル) を使うと、検索・差分・版管理・リンクが効き、編集即更新で陳腐化しない。
- 二重管理を避け参照で一元化する: 同じ内容は embed (`![[Note#section]]`) と block reference で1か所に書いて引く。司令塔/MOC は実体コピーでなくリンク索引にする (kepano の file over app + 単一正本原則)。
- フォルダより wikilink: 1ノートは複数テーマに属しうる。深いフォルダ階層でなく内部リンク・タグ・プロパティで多重所属と関係性を表現し、quick switcher とバックリンクで辿る。
- 公式機能を優先し永続性を担保する: callout/highlight/embed/Bases/Mermaid は Obsidian 組み込み。プラグイン依存を最小化すると、将来プラグインが廃れてもプレーンテキストとして読め『長期に壊れない』。
