# X(Twitter) 投稿アングル — 「レポート/ノートの見せ方」で発信する

Obsidian/PKM/データ可視化/AI レポートが X でウケる型。`x-stock` skill で `wiki/x-article-stock.md` に追記して運用。

## 投稿の型カタログ

### Before/After ビジュアル対比 (BAB フレーム)
「散らかったノート/プレーンな表」と「整理された美しいノート/図解レポート」を左右 or 上下に並べた 1 枚画像。変化(transformation)を一瞬で見せ、スクロールを止める。バズるスレッドの主要 5 フレームの 1 つ Before-After-Bridge に対応。
- **いつ使うか**: Obsidian vault のリファクタ成果、ダッシュボード改善、AI でレポートを清書した成果など「変化」が見せられる時。フォロワー獲得目的の単発ポスト or スレッド1枚目に最適。
- **実装の要点**: Obsidian なら Minimal/Flexoki テーマ適用前後をスクショ → 2枚を横並び画像に。Mermaid やテーブル化前後の比較も有効。1枚目を縦長(4:5)にして占有面積を稼ぐ。
- 出典: [www.hipclip.ai](https://www.hipclip.ai/workflows/how-to-create-x-twitter-threads-that-actually-go-viral-in-2025) `✅出典確認`

### "Steal my system" テンプレ配布フック
「自分のシステムをそのままコピーしていい」と公開・配布する型。kepano(Obsidian CEO)の vault テンプレ公開ツイートが代表例で、GitHub リポジトリ + ブログ + スクショの3点セットで拡散。所有欲と即効性を刺激し、保存・RT・フォローを同時に取る。
- **いつ使うか**: 自分の Obsidian vault / Notion テンプレ / レポート雛形を惜しみなく配る時。権威性より「持って帰れる価値」で伸ばしたい時。
- **実装の要点**: GitHub に vault テンプレ公開 → ツイートに「Here's my Obsidian vault template」+ スクショ + リンク。配布物(.md テンプレ, Canvas, dataview クエリ)を Gumroad/GitHub に置きリプ欄で配る導線も定番。
- 出典: ❌ **撤回** (2026-05-30 検証で内容不一致のハルシネーションと判明)。型は実在・要再ソース

### Numbered thread (番号付きスレッド・5〜10ツイート)
「N個の〜」形式で要素を番号化し、1ツイート1アイデアで構成するスレッド。最適長は5〜10ツイート(7が理想)。各ツイートを独立した知見にすることで途中保存・引用がしやすくなる。
- **いつ使うか**: ノート術のコツ、PKM ワークフロー、プラグイン紹介など「列挙できるノウハウ」をまとめる時。リスト系コンテンツ全般。
- **実装の要点**: 1ツイート目に数字入りフック「5 Obsidian habits that...」→ 2ツイート目以降を 1/ 2/ 3/ と番号付け。3〜4ツイートごとに画像を挟む(完了率+45%)。最後に要約+CTA。
- 出典: [www.tweetarchivist.com](https://www.tweetarchivist.com/how-to-write-viral-twitter-threads) `✅出典確認`

### 数字入り見出しフック (ベネフィット明示)
1ツイート目で「具体的な数字 + 得られる価値」を約束する。「5 AI tools that saved me 20+ hours」が「いくつかの AI ツール紹介」に勝つ。スクロール中の1秒で価値を伝える。
- **いつ使うか**: 全てのスレッド/単発ポストの冒頭。特にノウハウ・レポート系で必須。
- **実装の要点**: テンプレ:[数字]+[対象]+[ベネフィット/期間]。例「3 Mermaid diagrams that replaced my PowerPoint」。曖昧語(色々/いくつか)を排除し具体名詞・数値を入れる。
- 出典: [buffer.com](https://buffer.com/resources/good-hooks/) `✅出典確認`

### 図解ポスト (1〜4枚画像・カルーセル)
複雑な情報を図表・アイコンで1〜4枚に凝縮した画像投稿。TL占有面積が大きくクリックを誘発、ノウハウ系ではテキスト単体の2〜3倍リーチ。日本の X で「保存される投稿」の王道。
- **いつ使うか**: 手順・比較・体系図など「一目で要点を掴ませたい」レポート/ノート系。日本語圏のビジネス発信で特に強い。
- **実装の要点**: 1枚目=縦長(4:5)で占有面積最大化+タイトル15文字以内、2〜4枚目=16:9で統一。1枚1メッセージ・130文字以内・見出し36pt以上・配色3色まで・余白20%。Canva or Obsidian スクショで作成。
- 出典: [yoshikazunomori.com](https://yoshikazunomori.com/blog/digitalmarketing/x-illustration/) `✅出典確認`

### スクショ映えする Obsidian ビジュアル化
Excalidraw 手描き図、Mind Map、callout、Mermaid 図、バナー、Flexoki 配色などでノート自体を「作品」に仕上げてからスクショする。テキストの塊でなく視覚要素があることで保存・理解・拡散される。
- **いつ使うか**: ノートそのものを見せ物にする投稿。「俺の知識管理」系・vault ツアー・visual PKM。
- **実装の要点**: callout 構文 `> [!note] タイトル` `> [!tip]` `> [!warning]` で色付きボックス → 視覚的メリハリ。Excalidraw プラグインで手描き図、Mind Map プラグインで放射状図、コードブロックに ```mermaid。Minimal テーマ+Flexoki でスクショ。
- 出典: [nicolevanderhoeven.com](https://nicolevanderhoeven.com/blog/20220818-how-to-make-your-notes-visual-in-obsidian/) `✅出典確認`

### Mermaid 図でテキスト→図解 (PowerPoint 不要)
テキスト記述から自動でフローチャート/シーケンス図/ガントを生成し、コード片と完成図をセットで見せる。「マウス作図から解放された」という体験談込みで日本の技術発信で頻出。
- **いつ使うか**: アーキ図・フロー・関係図を含むレポート。エンジニア向けノート発信。再現性(コードをコピーできる)で保存を狙う時。
- **実装の要点**: Obsidian 標準対応。```mermaid 内に `graph TD; A-->B` (フロー) / `sequenceDiagram` / `gantt`。完成図スクショ + コード片を画像 or テキストで添付し「コピペで使える」を訴求。
- 出典: [note.com](https://note.com/minn_1092/n/n4975691a5c99) `✅出典確認`

### 「AI に作らせた」レポート/ドキュメント公開 (Claude × Obsidian)
Claude/AI でデータ分析→整形レポート or second brain を生成した過程と成果物を見せる型。「Build a second brain w Claude + obsidian」系が IG/X で高エンゲージ。プロンプト or ワークフロー公開で再現性を付ける。
- **いつ使うか**: AI でレポート自動生成・ノート整理を自動化した成果を見せる時。AI 活用×PKM の掛け合わせ層に刺す。
- **実装の要点**: Claude にデータ分析→ドキュメント/デッキ生成させた画面 or 出力 md を Obsidian で描画してスクショ。「プロンプトはこれ↓」とリプ欄 or 画像で配布。callout/表/Mermaid で清書すると映える。
- 出典: [www.instagram.com](https://www.instagram.com/p/DYDFpA-mHTD/) `✅出典確認`

### Vault/ダッシュボードツアー (build in public)
自分のノートシステム全体・ダッシュボードを「現在進行形で公開」する型。kepano の Flexoki 配色 web app 可視化のように、進捗・トラッキングを見せ続けて関心を蓄積する。
- **いつ使うか**: 継続発信でファンを育てる時。1回バズより長期的なアカウント成長狙い。dataview/Bases でホーム画面を作り込んだ時。
- **実装の要点**: Obsidian の dataview/Bases でホーム note(MOC)を構築 → 定期的にスクショ更新を投稿。「99% の仕事は記録の追跡」のように哲学を添える。Flexoki 等の統一配色で一貫したブランド感を出す。
- 出典: ❌ **撤回** (2026-05-30 検証で内容不一致のハルシネーションと判明)。型は実在・要再ソース

### Contrarian / 通説否定フック
「君が教わったことは全部間違い」「フォルダ整理は時間の無駄」のように既存の常識に挑戦し、反論・議論を誘発する型。X は like より reply を高く評価するため会話を生むフックが伸びる。
- **いつ使うか**: PKM の方法論論争(フォルダ vs リンク、PARA vs Zettelkasten 等)で立場を取る時。思想リーダー化を狙う時。
- **実装の要点**: 「Everything about [topic] is wrong. Here's why」テンプレ。kepano 流「chaos と laziness を受け入れる」のように直感に反する主張 → 根拠スレッドで回収。炎上ではなく建設的議論になる線を狙う。
- 出典: [www.zebracat.ai](https://www.zebracat.ai/post/how-viral-twitter) `✅出典確認`

### 1ルール=哲学の言語化 (collapse decisions)
kepano の「個人ルールを1つ決めると未来の数百の判断が1つに畳まれる」のように、運用の背後にある原則を1文に凝縮して提示する。具体テクより記憶に残り引用されやすい。
- **いつ使うか**: ノート術の単発ポスト。ハウツーより「考え方」で差別化したい時。引用RT・スレッド冒頭の格言として。
- **実装の要点**: 「YYYY-MM-DD dates everywhere」「内部リンクを惜しみなく使う」のような行動可能な1原則を太字 or 画像中央に大きく。理由を1〜2文で補足。視覚的に「標語」として見せる。
- 出典: [stephango.com](https://stephango.com/vault) `✅出典確認`

### スパルタン整形 (短文・改行・箇条書き)
1文を短く、頻繁な改行、箇条書き、絵文字での視覚アンカーで「スマホで読みやすい」テキスト塊を作る。読む時間=滞在時間がアルゴリズム評価に直結。
- **いつ使うか**: 全テキスト投稿・スレッド本文。特に情報密度の高いノウハウ系で離脱を防ぐ時。
- **実装の要点**: 1アイデア1行、空行で区切る。先頭に絵文字/番号でアンカー(✅ → ▸ 1.)。冗長な接続詞を削る。X 本文でもこの整形を、画像内でも「1行15文字以内・行間1.5倍」を踏襲。
- 出典: [usevisuals.com](https://usevisuals.com/blog/writing-effective-twitter-threads-2025) `✅出典確認`

### 再現性パッケージ (コピペできる素材を渡す)
見せて終わりでなく「そのまま使える」テンプレ/クエリ/プロンプト/コードを添える。再現性が保存・ブックマーク・フォローの最大ドライバー。日本の技術発信(Qiita/Zenn/note)でも王道。
- **いつ使うか**: ノウハウ系全般。特にエンジニア/PKM 実践層に「明日から使える」を訴求する時。
- **実装の要点**: dataview クエリ、callout テンプレ、Mermaid コード、frontmatter テンプレ、AI プロンプトをコードブロック or 画像で提示。GitHub/Gist/note にフル版を置きリンク。「コピペで動く」を明記。
- 出典: [qiita.com](https://qiita.com/YUM_3/items/80cf5705a54f70ad7e5b) `◎広く知られる慣行`

### CTA + 保存促し + 会話誘発のクロージング
スレッド/ポスト末尾で要点を1ツイートに要約 → 保存・RT を依頼 → 質問で会話を誘う。X は reply を重視するため、議論を呼ぶ問いかけが拡散を後押しする。
- **いつ使うか**: 全スレッドの最終ツイート、単発ポストの末尾。エンゲージメントを最大化したい時。
- **実装の要点**: 「① まとめ1ツイート ② 役立ったら保存&RT ③ あなたの vault 構成は?と問いかけ」の3点。先頭ツイートを引用して再掲(thread の入口に戻す導線)も併用。
- 出典: [www.tweetarchivist.com](https://www.tweetarchivist.com/how-to-write-viral-twitter-threads) `✅出典確認`

## このプロジェクト発の記事アングル案 (synthesis)

### 1. Claude が吐いた素のレポートを、Obsidian で「読まれる資料」に変える 7 つの型 🧵
- **切り口**: AI 生成レポート → 整形のビフォーアフターを軸に、再現可能な型として配布。「AI に作らせた」×PKM の掛け合わせ層に刺す
- **形式**: numbered thread (7 ツイート) + 3〜4 ツイートごとに before/after スクショ画像
  - 1 枚目: 散らかった素レポ vs callout/Mermaid で清書したレポの左右対比 (4:5 縦長)
  - BLUF: 結論を冒頭 `> [!success]` に出すだけで「読まれ率」が変わる
  - callout は意味で固定 (success=確定 / warning=留保 / question=未解決)
  - embed `![[Note#section]]` で二重管理を消す = 司令塔が陳腐化しない
  - Mermaid でフロー図 (PowerPoint 不要・コピペで動く)
  - 末尾: callout/frontmatter テンプレを Gist で配布 + 「あなたの清書術は?」で会話誘発

### 2. 「全部太字にする人」が一生レポート下手なまま終わる理由。強調は希少資源です。
- **切り口**: Contrarian / 通説否定フック。Tufte「引く美学」+ kepano「1 ルールで数百の判断を畳む」を 1 原則に凝縮
- **形式**: 単発ポスト + 標語画像 1 枚 (原則を中央に大きく)
  - 原則「グレー基調 + 1 色だけ強調」を画像中央に大きく配置
  - 全部強調 = 何も強調していない (data-ink ratio の話を平易に)
  - Obsidian なら danger callout を閾値超えだけに使う実例スクショ
  - 色覚多様性 4% への配慮も 1 文添える
  - 引用 RT されやすい「標語」として設計

### 3. セキュリティ報告書の型は、実は全部のビジネスレポートに効く。OWASP/SANS から盗んだ 5 つ。
- **切り口**: 意外な転用 (security → 一般レポート)。BLUF・二層化・finding 固定テンプレ・深刻度マトリクス・attack narrative を非エンジニアにも
- **形式**: numbered thread (6 ツイート) + Mermaid attack narrative 図と callout のスクショ
  - 1 枚目: 「ハッカーの報告書の書き方、経営報告に流用したら強すぎた」
  - BLUF = 結論先出し (軍・諜報・SANS の標準)
  - 経営層サマリ↔技術詳細を物理分離する二層化
  - 1 件 = 影響→再現→推奨 の固定順 (記載漏れが消える)
  - 深刻度マトリクス (可能性×影響) を 🔴🟠🟡🟢 で可視化
  - 末尾: finding callout テンプレ配布 + 保存促し

### 4. 手で索引表を更新してる人へ。frontmatter + Dataview で「メタを直せば表が自動追従」する vault の作り方
- **切り口**: drift 撲滅。再現性パッケージ (Dataview クエリ + frontmatter テンプレ) をそのまま配る「Steal my system」型
- **形式**: 図解ポスト (1〜4 枚カルーセル) + コピペできるクエリ画像
  - 手書き一覧表は必ず古くなる = drift の温床
  - frontmatter 6 フィールド (project/type/status/last_updated…) のテンプレ
  - `TABLE status, last_updated FROM #report WHERE status != done` 実物
  - Bases (公式) なら プラグイン依存ゼロで永続
  - DataCards でカード/カンバン表示に化ける見栄えスクショ
  - GitHub にフルテンプレ配置 → リンクで配布

### 5. 同じ分析を「経営層 BLUF 版」と「ハッカー finding 版」で書き分けたら、別物になった (実例 4 連発)
- **切り口**: 1 つの分析 × 4 スタイルの書き分けショーケース。v2 実験バリアントをそのままネタ化 (商材は伏せる)
- **形式**: 図解ポスト 4 枚 (各スタイル 1 枚) + Vault ツアー的に見せる
  - 同じデータが「読み手」で全く違う資料になることを 4 枚で対比
  - BLUF 版: 結論 1 callout + 根拠 3 柱 + foldable
  - ダッシュボード版: Dataview + Mermaid KPI ツリー
  - finding 版: 深刻度マトリクス + 影響→再現→推奨
  - ポストモーテム版: timeline + blameless 3 callout
  - 「どれが好き?」で reply 誘発・保存促し

### 6. kepano 直伝「file over app」。プラグインが滅んでも 10 年読めるレポートの書き方
- **切り口**: 哲学の言語化で差別化 (長期ファン化)。公式機能優先・diagrams as code・wikilink > フォルダ を 1 思想に束ねる
- **形式**: 単発ポスト + 標語画像 + 補足スレッド (任意)
  - 「長期に壊れない」= callout/embed/Mermaid/Bases の Obsidian 組み込みだけで組む
  - 図はテキストで持つ (スクショ画像は検索も diff も効かない)
  - フォルダ階層より wikilink で多重所属を表現
  - 日付は YYYY-MM-DD で everywhere
  - 1 原則を太字標語にして引用されやすく
