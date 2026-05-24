## A. 移動先選定フェーズ（dest未指定時）

### A-1: 候補絞り込み（ユーザーと対話）

まず探索範囲をユーザーに確認:

```
AskUserQuestion:
Q: 移動先候補を探す範囲は?
- 同一ディレクトリ内（最小）
- 親ディレクトリ配下（中）
- トピック領域全体（広域、例: 01_Biz/ 全体）
- Vault全体（最大、遅い）
```

### A-2: 候補ファイル収集

指定範囲内の `.md` ファイルのうち、以下を除外した上で**サイズ>1KB**の既存ノートを候補化:
- `templates/`, `.git/`, `.obsidian/`
- Daily/Monthly ログ系
- source 自身

```bash
find <scope> -name "*.md" -size +1k -type f \
  -not -path "*/templates/*" -not -path "*/Daily/*"
```

### A-3: 並列分析（Codex + Explore Agent）

#### Codex呼び出しテンプレ

```
あなたはObsidian Vault整理担当です。以下の短文ノートの「統合先」を提案してください。

source path: {source_path}
source 要約: {source_summary}
source キーワード: {source_keywords}
source 内容:
```md
{source_content}
```

候補ファイル一覧（パス + サイズ + 1行要約）:
{candidate_list}

以下を返してください:
1. 統合先トップ3（優先順位付き、理由付き）
2. 各候補について「挿入先セクション」と「見出しレベル」の初期案
3. 単独ノートとして残すべきか統合すべきかの判断（confidence 0-1）

300語以内。
```

#### Explore Agent呼び出しテンプレ

```
以下のsourceノートについて、Obsidian Vault内の最適な統合先を調査してください。

source: {source_path}
内容: {source_content}
キーワード: {source_keywords}

調査項目:
1. 指定スコープ {scope} 配下の既存MD（>1KB）を列挙
2. source のキーワードが出現する既存ファイルを grep で特定
3. 同一ディレクトリ → 親ディレクトリ → トピック領域の順に親和性を評価
4. 候補トップ3を提示（パス、理由、挿入先見出し案）
5. 推奨1件を根拠付きで提示

500語以内。
```

### A-4: 結果統合

両エージェントの結果を統合し、**候補トップ3** をユーザーに提示:

```
候補1: <path> （推奨度: 高）
  理由: ...
  挿入先見出し案: ## xxx > ### yyy

候補2: <path> （推奨度: 中）
  ...

候補3: <path> （推奨度: 低）
  ...

→ どの候補で進めますか? 選択後、書き方設計フェーズに進みます。
```

ユーザーが1つ選択したら → **書き方設計フェーズ** へ。

---

## B. 書き方設計フェーズ（dest確定後）

### B-1: dest構造の解析

`Read` で dest 全文を読む。以下を把握:
- 見出し階層（## と ### のみでOK）
- **見出しスタイル**: `##`/`###` 標準Markdown か、`[section]` 角括弧独自記法か、`# (tag)` 混在か
- 既存のプロンプトテンプレ流儀（`{変数}` 型か素のままか、コードフェンスの使い方）
- コメントマーカーの慣例

#### ⚠️ スタイル矛盾時の必須確認ルール

**Codex と Explore Agent の結果が見出しスタイルで矛盾した場合、必ず実ファイルを Read して確定する。**

- 例: Codex が `## banner concept` を提案、Explore が「既存は `[section]` 角括弧」と報告 → **Exploreを優先し、実ファイルで裏取り**
- Codex は標準Markdownへ正規化したがる傾向がある。独自スタイルのファイルでは実ファイル優先
- 矛盾を放置したまま最終ブロックを生成すると、既存スタイルを破壊する

### B-2: 並列設計（Codex + Explore Agent）

#### Codex呼び出しテンプレ

```
source を dest に統合します。最終Markdownブロックを設計してください。

source path: {source_path}
source content:
```md
{source_content}
```

dest path: {dest_path}
dest 見出し階層:
```text
{dest_outline}
```

dest 既存テンプレ流儀の例:
```md
{dest_style_sample}
```

以下を返してください:
1. 挿入先セクション（既存のどの見出しの下か）
2. 見出しレベル（既存最深に合わせる）
3. 書式方針（既存スタイルに合わせる / 素のまま / 部分整形）
4. 最終Markdownブロック全文（コードフェンスで囲む）
5. ブロック冒頭に `<!-- merged-from: {source_path} -->` を含める
6. 既存の wikilink/タグ規約を尊重
7. 見出し文言の選定理由（英語 vs 日本語、既存命名との整合性）

⚠️ 厳守: source に**存在しない項目・サンプル値・例示を勝手に追加しない**。
空セクション（例: `# LP` 見出しのみで本文なし）は空のまま維持し、`<!-- TODO -->` コメントで明示する。
架空の項目（value proposition, target, problem 等）を補完してはならない。

300語以内。
```

#### Explore Agent呼び出しテンプレ

```
{dest_path} を読んで、以下を調査してください。

目的: source「{source_summary}」を dest に追記する最適な挿入位置を特定したい。

調査項目:
1. dest の ## と ### 見出し階層マップ（行番号付き）
2. source キーワード {source_keywords} の既存出現箇所（grep）
3. 最も親和性の高い挿入候補トップ3（優先順位付き）
4. 推奨挿入ポイント1つ（セクションパス + 行番号 + 理由）
5. 既存のプロンプトテンプレ流儀（あれば例を引用）

500語以内。
```

### B-3: 結果統合とユーザー提示

両結果を統合し、以下のフォーマットで提示:

```
