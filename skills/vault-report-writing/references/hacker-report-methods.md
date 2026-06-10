# 報告が上手い人・ハッカーのレポート手法 (PTES / OWASP / OSCP / postmortem)

ペネトレーションテスト・障害報告・finding writeup の型。説得力と再現性の出し方。

> 構文そのものの詳細は [[obsidian-markdown]] skill に委譲。本ファイルは「**いつ・何のために使うか**」のカタログ。

### BLUF (結論先出し) で冒頭を書く
レポート/各 finding の冒頭に『結論・最重要判断・取るべき行動』を 1-3 行で置く。読み手は最初の数秒で全体を掴め、続きは詳細の裏取りになる。軍・諜報・SANS pentest report が標準採用する『逆ピラミッド』型。
- **いつ使うか**: 経営層向けエグゼクティブサマリーの冒頭、各 finding のタイトル直下、障害報告の最上部。多忙な意思決定者が読む全レポートに。
- **実装の要点**: Obsidian: 冒頭に `> [!important] BLUF` callout を置き『〇〇により本番 DB の全顧客 PII が外部から取得可能。即時パッチ要 (Critical)。』のように Who/What/Impact/Action を 1 文で。本文 H2 より前に配置。
- 出典: [en.wikipedia.org](https://en.wikipedia.org/wiki/BLUF_(communication)) `✅出典確認`

### 経営層 / エンジニアの二層化レポート
同じ事実を『Executive Summary (非技術・ビジネスインパクト・戦略提言)』と『Technical Findings (再現手順・証拠・修正詳細)』に物理的に分離。OWASP WSTG・PTES・SANS が共通要求。読み手ごとに最適化され、両者が必要箇所だけ読める。
- **いつ使うか**: ペンテスト報告書・セキュリティ監査・四半期セキュリティレビューなど、決裁者と実装者の両方が読むレポート全般。
- **実装の要点**: Obsidian: `## 経営層サマリー` (深刻度別件数表 + 1 行所見 + 推奨) と `## 技術詳細` を H2 で完全分割。前者は表 + callout、後者は finding ごとの定型テンプレ。冒頭に目次 (`[[#技術詳細]]` リンク)。
- 出典: [owasp.org](https://owasp.org/www-project-web-security-testing-guide/stable/5-Reporting/README) `✅出典確認`

### finding 固定テンプレ (影響→再現→推奨)
各脆弱性を『タイトル / 深刻度 / 説明 / 影響 / 再現ステップ / PoC / 推奨修正』の同一順序で記述。OWASP WSTG の必須要素 (Reference ID・Title・Exploitability・Impact・Severity・Description・Remediation) に対応。構造の学習効果で読みやすく、記載漏れも防ぐ。
- **いつ使うか**: 脆弱性が複数ある全報告書。バグバウンティ提出。社内セキュリティ指摘票。
- **実装の要点**: Obsidian: 1 finding = 1 `> [!bug] F-01: タイトル` callout。内部を `**影響**:` `**再現手順**:` (番号リスト) `**推奨**:` の太字ラベルで小見出し化。Templater でスニペット定型化。Reference ID (F-01 等) で相互参照。
- 出典: [owasp.org](https://owasp.org/www-project-web-security-testing-guide/stable/5-Reporting/README) `✅出典確認`

### 深刻度マトリクス (可能性 × 影響) と色分け
深刻度を『可能性 (Likelihood) × 影響 (Impact)』で算出する OWASP Risk Rating 方式、または CVSS、Bugcrowd VRT (P1-P5) を使う。主観でなく定義済みスケール + 計算根拠を提示。色/絵文字で優先順位がひと目で分かる。
- **いつ使うか**: finding が多く優先順位付けが要るとき。決裁者に『どれから直すか』を伝えるとき。VRT/CVSS が要求される bug bounty。
- **実装の要点**: Obsidian: `## リスク評価` に Likelihood×Impact の 5×5 表 (Markdown table)、セルに 🔴🟠🟡🟢 絵文字。各 finding 見出しに `🔴 Critical (CVSS 9.1)` をプレフィックス。深刻度定義は付録 callout に。
- 出典: [owasp.org](https://owasp.org/www-community/OWASP_Risk_Rating_Methodology) `✅出典確認`

### PoC 証拠の『改竄不能な見せ方』
主張を必ずスクショ・ログ・コマンド出力で裏付ける。OSCP は『同じターミナルに flag (cat proof.txt) と IP (ip addr) を同時表示』を要求 — 別々のスクショは無効。証拠が本物だと一目で分かる見せ方をする。
- **いつ使うか**: 権限取得・データ取得を主張する全 finding。OSCP 試験。bug bounty の PoC。RCE/権限昇格の証明。
- **実装の要点**: Obsidian: スクショは `![[poc-f01.png]]` で埋め込み、直前に『図1: IP と proof.txt を同一画面で表示』のキャプション。コマンド出力は fenced code block (```bash)。動画は添付ファイル直リンク (外部 URL 不可)。
- 出典: [github.com](https://github.com/noraj/OSCP-Exam-Report-Template-Markdown/blob/master/src/OSCP-exam-report-template_OS_v2.md) `✅出典確認`

### 強いタイトルの書き方 (場所+種類+影響)
『XSS あり』のような曖昧タイトルを禁止し、『プロフィール欄の Stored XSS によりプロフィール閲覧時に任意スクリプト実行』のように〈脆弱性種別 + 発生箇所 + 結果〉を 1 行で。トリアージ担当が一読で理解でき処理が速い。
- **いつ使うか**: bug bounty 提出 (HackerOne/Bugcrowd)。finding 見出し。チケットタイトル。
- **実装の要点**: Obsidian: finding の H3/callout タイトルを `[種別] + [箇所] + allows + [影響]` 形式で統一。チェーン攻撃は `[初期ベクタ] → [ピボット] → [影響]` 矢印形式。
- 出典: [docs.hackerone.com](https://docs.hackerone.com/en/articles/8475116-quality-reports) `✅出典確認`

### 番号付き再現ステップ (URL/パラメータ/ロール明示)
再現手順を番号付きで、URL・対象パラメータ・必要な権限ロール・正確な payload を明記。『一般ユーザでログイン → 設定へ → payload 挿入 → 挙動を観察』のように誰でも追える粒度。曖昧な一般論を排除。
- **いつ使うか**: 全 finding の再現セクション。triager/エンジニアが手元で再現する必要がある全報告。
- **実装の要点**: Obsidian: `**再現手順**:` 直下に番号リスト (1. 2. 3.)。payload は inline code (`<script>...`)、リクエストは fenced code block (```http)。前提 (ロール・環境) を `> [!note] 前提条件` callout で先頭に。
- 出典: [docs.hackerone.com](https://docs.hackerone.com/en/articles/8475116-quality-reports) `✅出典確認`

### 期待挙動 vs 実際挙動の対比
『本来こうあるべき (期待)』と『実際こうなった (脆弱)』を並べて示す。安全動作からの逸脱が明確になり、なぜ問題かが論理的に伝わる。バグ報告・テスト報告で誤解を防ぐ。
- **いつ使うか**: ロジック欠陥・認可バイパスなど『正常そうに見える』脆弱性。QA/テスト報告。
- **実装の要点**: Obsidian: 2 列表 (`| 期待 | 実際 |`) または `> [!success] 期待される挙動` と `> [!failure] 実際の挙動` の 2 callout を並置。差分を太字強調。
- 出典: [docs.hackerone.com](https://docs.hackerone.com/en/articles/8475116-quality-reports) `✅出典確認`

### attack narrative (攻撃連鎖の物語化)
個別脆弱性を孤立列挙せず『[初期侵入]→[横移動]→[特権昇格]→[最終影響]』の物語で繋ぐ。小さな穴の合わせ技が critical になることを示し、実ビジネス被害 (PII 流出・資金移動・アカウント乗っ取り) を語る。人間テスターの価値が出る部分。
- **いつ使うか**: Red Team/AD ペンテスト報告。複数脆弱性を連鎖させた bug bounty。経営層に『なぜ怖いか』を伝えるエグゼクティブサマリー。
- **実装の要点**: Obsidian: `## 攻撃シナリオ` に mermaid フローチャート (`graph LR; 初期侵入-->横移動-->昇格-->影響`)。各ノードを finding へ `[[#F-01]]` リンク。OSCP の AD セクションのように lateral movement 手段 (pass-the-hash 等) を明記。
- 出典: [www.intigriti.com](https://www.intigriti.com/blog/business-insights/chaining-in-action-techniques-terminology-and-real-world-impact-on-business) `✅出典確認`

### blameless postmortem 構造 (障害報告)
Google SRE の定型: Summary / Impact / Root Causes / Trigger / Resolution / Detection / Action Items / Lessons Learned (うまくいった点・まずかった点・運が良かった点) / Timeline。人を『役割』で書き個人を責めない。心理的安全性で真因が出る。
- **いつ使うか**: 本番障害・インシデントの事後分析。セキュリティインシデント対応報告。再発防止が目的の全レポート。
- **実装の要点**: Obsidian: 上記 9 セクションを H2 で固定テンプレ化 (Templater)。Lessons Learned は `> [!success] うまくいった` `> [!warning] まずかった` `> [!info] 運が良かった` の 3 callout。Action Items は owner と期日付きチェックボックス (`- [ ] @担当 期日`)。
- 出典: [sre.google](https://sre.google/sre-book/example-postmortem/) `✅出典確認`

### 時系列タイムライン (Timeline)
事象を時刻付きで時系列に並べる。検知→対応→解決の流れと『検知が遅れた箇所・対応のボトルネック』が可視化され、改善点が特定できる。postmortem と incident report の核。
- **いつ使うか**: 障害・インシデント報告。長時間に渡る攻撃の追跡。対応プロセス改善が目的のとき。
- **実装の要点**: Obsidian: タイムスタンプ付き表 (`| 時刻 | 出来事 | 対応 |`)、または mermaid `timeline` / `gantt`。重要分岐は 🔴 マーク。タイムゾーンを冒頭明記。
- 出典: [sre.google](https://sre.google/sre-book/example-postmortem/) `✅出典確認`

### ツール出力を整形して付録へ隔離
nmap/Burp/scanner の raw dump を本文に貼らず、要点だけ抽出して本文に、生データは付録へ。OWASP WSTG は『出力を整形せよ・ただ捨てるな (clean, don't dump)』と明示。本文の認知負荷を下げ可読性が上がる。
- **いつ使うか**: スキャナ/列挙ツールを多用するペンテスト報告。長大なログを伴う全技術報告。
- **実装の要点**: Obsidian: 本文には要点表のみ。生ログは `## 付録 A: ツール出力` に `> [!example]- 折りたたみ` callout (末尾 `-` で初期折りたたみ) + fenced code block。長文は別ノート化し `![[appendix-nmap]]` 埋め込み。
- 出典: [owasp.org](https://owasp.org/www-project-web-security-testing-guide/stable/5-Reporting/README) `✅出典確認`

### 具体的・実行可能な推奨 (patch X を where から)
『パッチを当てよ』で終わらせず『どのパッチを・どこから入手し・適用時の副作用は何か』まで具体化。OWASP は『エンジニアが行動できる十分な情報を』と要求。能動態・短文・現在の脅威文脈での意義も添える (SANS)。
- **いつ使うか**: 全 finding の Remediation セクション。修正担当に渡す報告。retest を前提とする報告。
- **実装の要点**: Obsidian: `**推奨**:` に番号付き手順 + 関連リンク (CVE/ベンダ advisory)。優先度を `🔴 即時 / 🟡 短期 / 🟢 中期` で。retest 用に `- [ ] 修正確認` チェックボックス。受動態を避け命令形で。
- 出典: [www.sans.org](https://www.sans.org/blog/tips-for-creating-a-strong-cybersecurity-assessment-report) `✅出典確認`

### 深刻度別サマリ表 + ダッシュボード化
冒頭に『Critical 2 / High 5 / Medium 8 ...』の件数表と、視覚要素 (チャート・色) でリスク全体像を一目で示す。経営層が digest しやすく、優先順位の合意形成が速い。多くの pentest report ガイドが共通推奨。
- **いつ使うか**: finding が多い報告のエグゼクティブサマリー。定期セキュリティレビュー。複数システム横断監査。
- **実装の要点**: Obsidian: サマリ表 (`| 深刻度 | 件数 | 代表 finding |`) に絵文字。件数の視覚化は mermaid `pie` チャート。Dataview を使うなら finding を個別ノート化し `TABLE severity FROM #finding SORT severity` で自動集計。
- 出典: [www.sans.org](https://www.sans.org/blog/tips-for-creating-a-strong-cybersecurity-assessment-report) `◎広く知られる慣行`

## 核心原則

- 二層構造 (経営層 vs エンジニア) を必ず分ける: 同じ事実を『ビジネスインパクト・要約 (非技術)』と『再現手順・証拠 (技術)』の 2 レイヤーで書く。OWASP WSTG / PTES / SANS が共通要求する最重要原則。Obsidian では H2 + callout で物理分離。
- BLUF (結論先出し): 最重要判断を冒頭に置き、多忙な読み手が数秒で『何が起きたか・何をすべきか』を掴めるようにする。軍・諜報分析・SANS pentest report の標準。
- 1 finding = 影響 → 再現手順 → 推奨 の固定テンプレで毎回同じ順序に。構造の学習効果で読みやすく、記載漏れも防ぐ (OWASP WSTG 必須要素)。
- 主張は必ず証拠 (PoC) で裏付ける。スクショ・ログ・コマンド出力を改竄不能な形で (OSCP: 同一画面に IP と flag)。証拠なき主張は検証不能。
- 深刻度は再現可能な物差しで (CVSS / OWASP Risk=可能性×影響 / Bugcrowd VRT P1-P5)。主観でなく定義済みスケール + 計算根拠 + 色分けで優先順位を即伝達。
- blameless で書く (Google SRE)。人を『役割』で書き原因を仕組みに帰す。心理的安全性が真因と再発防止策を引き出す。障害/インシデント報告で必須。
- 個別脆弱性を孤立させず attack narrative ([初期侵入]→[横移動]→[影響]) で繋ぎ、小さな穴の合わせ技が critical になる実ビジネス被害を語る。
