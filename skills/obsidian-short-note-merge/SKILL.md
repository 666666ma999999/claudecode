---
name: obsidian-short-note-merge
description: |
  Obsidian Vault内の短文MD/DONEエントリの統合先選定と追記Markdown設計スキル。
  Codex+Explore並列分析で移動先候補と整形ブロックを提案（検出・編集は不実施）。
  キーワード: 移動先選定, 統合先提案, MDマージ, Obsidian, 断片整理, DONEエントリ再配置。
  NOT for: 検出・Edit・削除実行, NOW→DONE移動（→ obsidian-now-done）
allowed-tools: "Read Glob Grep Bash Agent mcp__codex__codex mcp__codex__codex-reply"
license: proprietary
metadata:
  author: masaaki-nagasawa
  version: 2.2.0
  category: workflow-automation
  tags: [obsidian, md-merge, destination-selection, writing-design, done-redistribution]
---

# Obsidian 短文ノート統合設計スキル

Obsidian Vault内の短文MDを既存ノートへ統合する際、**移動先ファイル選定**と**最終Markdownブロックの書き方**を並列エージェントで設計する。**提案のみ行い、ファイルの編集・削除は行わない**。

## スコープ

| 範囲 | 担当 |
|---|---|
| 短文MD検出（文字数カウント等） | **ユーザー** |
| **移動先候補の選定** | **本スキル** |
| **最終Markdownブロックの設計** | **本スキル** |
| Edit実行・元ファイル削除 | **ユーザー** |

## 発動条件

以下のいずれかに該当:
- 「この`<source>.md`の移動先を考えて」
- 「`<source>.md`を統合したい、適切な既存ファイルを探して」
- 「`<source>.md`を`<dest>.md`に移す時の書き方を考えて」
- 「この DONEエントリの移動先を考えて」「DONE を再配置して」
- 移動先が未定 or 書式整形の方針が欲しい場合

## 入力パターン

### パターン1: sourceのみ指定（移動先未定）
```
入力: source_path = "00_Inbox/memo_plan.md"
出力: 移動先候補トップ3 + 各候補への挿入イメージ
```

### パターン2: source + dest 指定
```
入力: source_path = "00_Inbox/クレーム.md", dest_path = "02_ai/AIshift.md"
出力: 挿入先セクション + 最終Markdownブロック全文
```

### パターン3: N→1マージ（複数source → 新規/既存1ファイルへ統合）
```
入力: sources = ["01_Biz/BizFormat_summury.md",
                 "01_Biz/BizFormat_新規コンテンツの制作 改革案(draft).md"]
      dest = "01_Biz/Format/BizFormat_summury.md" （新規 or 既存）
出力: 統合後の完成形Markdownファイル全文 + 旧ファイル削除リスト
```

### パターン4: DONEエントリ入力（ファイル内の特定エントリを再配置）
```
入力: source_file = "02_ai/rohan/auto_regist_Uranaiitem.md"
      entry_heading = "##### test3: hayatomo 職場不倫 (2026-04-10)"
      （または entry_range = "L47-L50"）
出力: 該当エントリから抽出した「再利用可能な知見」の移動先候補 + 書き方
```

**パターン4の特殊処理**:
- DONEエントリは `##### ` 見出し + 元プロンプト + `**結果:**` の3層構造
- 移動先に渡すのは**「結果から抽出した確定知見」**であって、元プロンプト全文ではない
- 元プロンプトは元ファイルのDONEに残したまま、知見のみ別MDへ転記する
- 出力Markdownブロックには `<!-- extracted-from: <source_file>#<heading> -->` マーカーを含める
- 転記後も元DONEは削除しない（履歴ログとして保持）

**パターン3の特殊処理**:
- 性質の異なる複数sourceを1ファイルにまとめる場合、セクション分離設計が必須
- 例: 汎用テンプレ vs 具体ドラフト → `## 汎用フォーマット` + `## Draft: <名前>` に分離
- frontmatter に `aliases:` を設定し、旧ファイル名の wikilink 互換を維持
- 各sourceブロックの先頭に `<!-- merged-from: <path> -->` を個別に埋込
- 被リンク1件以上持つsourceは basename 維持を優先（新規ファイル名の決定ルール）

## 実行フロー（2段構え）

### Step 1: source 内容の把握

`Read` で source を読み、以下を抽出:
- 主題の1行要約
- 主要キーワード（3-5個）
- コンテンツ種別（プロンプト雛形 / メモ / アイデア / 仕様 / todo 等）
- 既存のwikilink/タグ

**パターン4（DONEエントリ）の場合**:
1. `entry_heading` を受け取ったら、`source_file` から該当 `##### ` セクション範囲を特定:
   ```bash
   awk -v h="$entry_heading" '
     $0 == h { found=1; print; next }
     found && /^##### / { exit }
     found && /^## / { exit }
     found { print }
   ' "$source_file"
   ```
2. エントリ本文を「元プロンプト部分」と「`**結果:**` 以降の結果部分」に分離
3. **再利用可能な知見のみ**を結果部分から抽出（時系列イベント・個別商品ID等は除外）
   - 確定した設定値・コマンド・制約条件・教訓 → 抽出対象
   - 特定日のテスト結果・一時的なID・実行ログ → 除外
4. 抽出した知見を「source_content」として扱い、以降のフローに流す

### Step 2: 分岐

#### パターン1の場合: 移動先選定フェーズへ
#### パターン2の場合: 書き方設計フェーズへ直行
#### パターン4の場合: 抽出した知見を source として移動先選定フェーズへ

---

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
## 提案

**挿入先**: <dest_path> の L<行番号> 付近
**セクション**: ## xxx > ### yyy の直前/直後
**見出し名**: ### <新見出し>
**見出しレベル**: ###（理由: 既存最深が ### のため）
**書式方針**: <既存スタイル準拠 or 素のまま>

## 最終Markdownブロック

​```md
### <見出し>

<整形済み本文>

<!-- merged-from: <source_path> -->
​```

---

この内容で Edit してよいか確認してください。編集とsource削除はユーザー側で実施をお願いします（本スキルは提案のみ）。
```

## 出力ルール

1. **提案のみ**: Editツール・rm・git操作は**一切呼ばない**
2. **idempotencyマーカー必須**: 最終ブロックには必ず `<!-- merged-from: <source_path> -->` を含める
3. **書式は2択提示可**: 整形/素のまま判断が拮抗する場合、両案を並べてユーザーに選ばせる
4. **複数候補拮抗**: トップ候補が僅差の場合、1つに絞らずトップ3提示
5. **非確定情報はconfidence明示**: 「低確信度」「要確認」を付記
6. **ハルシネーション禁止（最重要）**: source/dest に存在しない内容を Codex が補完した場合、**必ず検出して除去**する。最終ブロックをユーザーに提示する前に「元ファイルに存在する内容のみか」を確認する。空セクションは空のまま維持し、`<!-- TODO -->` で明示する
7. **スタイル矛盾時の裁定**: Codex と Explore Agent で見出しスタイルが食い違った場合、**実ファイルReadで確定**し、Explore側（実ファイル観測ベース）を優先する

## エッジケース

| 状況 | 対応 |
|---|---|
| 移動先未定 & 候補が見つからない | 「適切な統合先が見つかりません。単独ノート維持を推奨」と返す |
| 候補が完全拮抗（僅差3件以上） | 自動絞り込みせずトップ3全部提示、ユーザーに委ねる |
| dest に既存の merged-from マーカーあり | 「既に統合済みの可能性あり」と警告 |
| source が空 or 見出しのみ | 「統合価値なし、削除を推奨」と返す（削除は実行しない） |
| source が `templates/` 配下 | 「雛形なので統合対象外」と返す |
| dest が日次/月次ノート | 「ログノートへの統合は非推奨」と警告、代替候補を提示 |

## 典型的な呼び出しフレーズ

- 「`00_Inbox/memo_plan.md` の移動先を考えて、codex と agent team で」
- 「`<source>.md` を `<dest>.md` に移す時の書き方を設計して」
- 「このInboxノート、どの既存ファイルに入れるのが最適か提案して」
- 「書き方を codex と agent team で考えて」

## 関連スキル

- `obsidian-now-done` — NOW→DONE移動。DONE蓄積後、本スキル（パターン4）でVault内の適切なMDへ知見を分散配置する
- `codex-delegate` — 汎用Codex委譲
- `opponent-review` — 対立検証（候補が拮抗して判断が難しい時に併用可）
