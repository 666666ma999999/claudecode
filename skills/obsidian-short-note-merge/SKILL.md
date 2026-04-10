---
name: obsidian-short-note-merge
description: |
  Obsidian Vault内の短文MDファイル（断片）を既存ノートへ安全に統合するスキル。
  Codex + Explore Agentの並列分析で挿入先セクション・見出しレベル・書式整形を設計し、
  ユーザー承認後にidempotencyマーカー付きで追記、元ファイルは削除またはstub化する。
  キーワード: 短文統合, 断片整理, Obsidian, Vault整理, MDマージ, short note merge, fragment consolidation
  NOT for: 新規ノート作成（→ Edit直接）、NOW→DONE移動（→ obsidian-now-done）、task.md更新（→ task-progress）、非Obsidian環境のMD編集
allowed-tools: "Read Edit Glob Grep Bash Agent mcp__codex__codex mcp__codex__codex-reply"
license: proprietary
metadata:
  author: masaaki-nagasawa
  version: 1.0.0
  category: workflow-automation
  tags: [obsidian, md-merge, fragment-consolidation, vault-organization]
---

# Obsidian 短文ノート統合スキル

Obsidian Vault内の短いMarkdownノート（断片）を既存の大きなノートへ安全に統合する。**propose-first, edit-on-approval** が原則。

## 発動条件

以下のいずれかに該当:
- 「Vault内の短いノートを整理したい」「断片MDを統合したい」
- 「この`<source>.md`を`<dest>.md`に移して」
- 「N文字以下のMDを検出して1件ずつ統合提案して」
- 00_Inbox/配下の断片を適切なトピックフォルダへ移動したい

## 絶対ルール

1. **propose-first**: 実際の編集前に必ず最終Markdownブロックをユーザーに提示し承認を得る
2. **idempotencyマーカー必須**: 追記ブロックに `<!-- merged-from: <source_path> -->` を埋込
3. **被リンク保護**: `[[source_basename]]` が他ファイルにあれば削除せず **stub化**
4. **templates/除外**: `templates/` 配下は統合対象にも削除対象にもしない
5. **日次/月次ノート除外**: `Daily/` `Monthly/` 等のログノートは明示指示がない限り対象外
6. **git状態確認**: 大量の未コミット変更があれば警告
7. **移動先ファイルが存在しないなら停止**: 新規作成は本スキルの範囲外

## Phase フロー

### Phase A: Detect（検出）

ユーザーが文字数閾値を指定した場合:

```bash
cd ~/Documents/"Obsidian Vault" && find . -name "*.md" -type f \
  -not -path "./.git/*" -not -path "./.obsidian/*" \
  -not -path "./templates/*" -print0 2>/dev/null | \
while IFS= read -r -d '' f; do
  chars=$(wc -m < "$f" 2>/dev/null | tr -d ' ')
  if [ -n "$chars" ] && [ "$chars" -le <THRESHOLD> ]; then
    printf "%4d %s\n" "$chars" "$f"
  fi
done | sort -n
```

結果を表示してユーザーに1件選ばせる。

### Phase B: Select（選択）

ユーザーに確認:
- **source**: 移動元ファイルパス
- **dest**: 移動先ファイルパス（既存必須）
- **mode**: `dry-run`（提案のみ）/ `apply`（承認後に実行）

移動先が存在しなければ停止して再指定を求める。
既に `<!-- merged-from: <source> -->` が移動先にあれば **idempotent no-op** として停止。

### Phase C: Design（並列設計）

Codex と Explore Agent を **並列** 起動する。

#### Codex呼び出しテンプレ

```
あなたは短文Obsidianノートを既存ノートに統合する役割です。

source path: {source_path}
source content:
```md
{source_content}
```

destination path: {dest_path}
destination outline(主要見出し):
```text
{dest_outline}
```

以下を返してください:
1. 最適な挿入セクション（既存のどの見出しの下か）
2. 見出しレベル（##/###/####。既存の最深レベルに合わせる）
3. 書式整形方針（既存スタイルに合わせるか素のままか）
4. 最終Markdownブロック全文（コードフェンスで囲む）
5. ブロック冒頭に `<!-- merged-from: {source_path} -->` を埋込

既存のwikilink/タグ規約を尊重。300語以内。
```

#### Explore Agent呼び出しテンプレ

```
{dest_path} を読んで以下を調査:

1. ## と ### の見出し階層マップ（行番号付き）
2. source関連キーワード {keywords} の既存出現箇所
3. 最も親和性の高い挿入候補トップ3（優先順位付き）
4. 推奨案1つ（セクションパス・挿入方式・理由）

source要約: {source_summary}
300語以内。
```

両結果を統合して一つの推奨案にまとめる。

### Phase D: Approve（承認）

必ず以下を提示:
- 挿入先セクション名と行番号
- 見出しレベル
- **最終Markdownブロック全文**（実際に挿入される内容）
- 元ファイルの扱い（delete / stub）

`dry-run` モードならここで停止。

被リンク検出:
```bash
grep -rn "\[\[$(basename {source_path} .md)\]\]" --include="*.md" <vault_root>
```
1件でもヒットしたら **デフォルトで stub化** を提案。

### Phase E: Apply（実行）

ユーザー承認後:

1. **Edit** で移動先の確定位置に追記ブロックを挿入
   - `old_string`: 挿入位置直後の既存見出し（例: `### holiday`）
   - `new_string`: 新ブロック + 既存見出し
2. **元ファイル処理**:
   - 被リンクなし → `rm {source_path}`
   - 被リンクあり → 中身を `→ [[{dest_basename}]]` のstubに置き換え
3. **git status** で差分確認
4. コミットはユーザー明示指示があるまで保留

## エッジケース

| 状況 | 対応 |
|---|---|
| 移動先ファイル不在 | 停止。ユーザーに再指定を求める |
| 既存マーカー検出 | idempotent no-op、スキップ |
| `templates/`配下 | 除外（対象外） |
| Daily/Monthly ログ | デフォルト除外。`--include-logs` 明示指示で解除 |
| 被wikilinkあり | stub化をデフォルト提案 |
| 複数候補セクションが拮抗 | 自動決定せずユーザーに3候補提示 |
| 未コミット変更多数 | 警告表示後にユーザー確認 |
| source が空ファイル or 見出しのみ | 削除のみ実行（統合不要） |

## 典型的な呼び出しフレーズ

- 「Obsidian Vaultの200字以下MDを検出して1件ずつ統合提案して」
- 「`00_Inbox/クレーム.md` を `02_ai/AIshift.md` に移して。書き方はCodexとagent teamで考えて」
- 「この短文ノートを既存のどこに入れるか考えて、dry-runで見せて」
- 「Inboxの断片を適切なトピックフォルダのMDへ統合整理して」

## 関連スキル

- `obsidian-now-done` — NOW→DONE移動（本スキルとは別フロー）
- `task-progress` — task.md管理
- `organize-desktop` — デスクトップファイル整理（類似の分類ワークフロー）
