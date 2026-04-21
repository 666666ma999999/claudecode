---
name: env-factcheck
description: Claude Code 環境についての定量主張（MCP使用回数・ツール頻度・セッション数・編集ファイル数・スキル起動回数）を、JSONL ログから正しく裏取りする。grep だけの安易な集計で artifact に騙されるのを防ぐ。週次アーカイブ: `~/.claude/state/weekly-metrics-archive.sh`（JSONL 14日消失前のスナップショット永続化、`~/.claude/metrics/weekly/YYYY-Www.json`）。
user_invocable: false
allowed-tools:
  - Read
  - Bash
  - Grep
  - Glob
---

# 環境ファクトチェックスキル

## 起動トリガー

以下のような定量主張が出たとき:
- 「この MCP を N 回使った」
- 「この週は X ファイル編集した」
- 「このスキル Y を何回呼んだ」
- 「セッション数は Z」
- 「どのコマンドが一番使われているか」

**記事・レポート・プレゼン資料で数値を出す前に必ず実行**。

## ❌ やってはいけないこと（アンチパターン）

### 禁止1: JSONL を grep だけで集計

```bash
# NG - 偽陽性が大量に混ざる
grep -hoE 'mcp__[a-z_-]+' ~/.claude/projects/**/*.jsonl | sort | uniq -c
```

**理由**: JSONL には実使用以外にも以下が含まれる:
- `attachment.type = "deferred_tools_delta"` — セッション開始時の MCP ツールカタログ一覧（全ツール名が毎セッション記録される）
- `system-reminder` メッセージ内の skill/tool 一覧
- Agent 呼び出しプロンプト内のツール名引用
- ToolSearch 結果のツール名引用

実例: postgresql の14サブツールが**全部きっかり 82回**ヒット → 82セッション × 1カタログ announcement だった（実使用は 1 回）。

### 禁止2: スキル名/コマンド名だけでの検索

スキル一覧は毎セッション system-reminder に注入されるため、grep すると **セッション数**をカウントしてしまう。

### 禁止3: 「数値がもっともらしい」で検証を止めること

2,896 / 2,460 / 1,645 … のように綺麗に並んでいても、artifact の可能性を疑う。**同じような桁の数字が並んだら要注意**（catalog 列挙の典型パターン）。

## ✅ 正しい方法（Core Recipe）

### Recipe 1: MCP 実使用回数

```bash
python3 ~/.claude/skills/env-factcheck/count_tool_uses.py --days 30 --type mcp
```

内部で以下を実行:
- `~/.claude/projects/**/*.jsonl` を JSON として parse
- `d['message']['content'][]` から `type == 'tool_use'` のみ抽出
- `name.startswith('mcp__')` のものをサーバー名ごとに集計

### Recipe 2: 標準ツール（Read/Edit/Bash/Write等）の実使用回数

```bash
python3 ~/.claude/skills/env-factcheck/count_tool_uses.py --days 30 --type builtin
```

### Recipe 3: スキル起動回数

スキル起動は `<command-name>/xxx</command-name>` タグ付きのユーザーメッセージで検出:

```bash
python3 ~/.claude/skills/env-factcheck/count_tool_uses.py --days 30 --type skill
```

### Recipe 4: 編集ファイル数（重複排除）

```bash
python3 ~/.claude/skills/env-factcheck/count_tool_uses.py --days 30 --type edited-files
```

### Recipe 5: セッション数

```bash
find ~/.claude/projects -name "*.jsonl" -mtime -30 \
  | xargs -I{} python3 -c "import json; print(json.loads(open('{}').readline()).get('sessionId',''))" 2>/dev/null \
  | sort -u | wc -l
```

## 検証チェックリスト

数値を報告する前に以下を確認:

- [ ] JSONL を JSON として parse したか（grep ではなく）
- [ ] `type == 'tool_use'` または `type == 'text'`（user message）など、**目的に応じた正しい event type** に絞ったか
- [ ] `attachment` イベント（特に `deferred_tools_delta`）を除外したか
- [ ] `system-reminder` 内のツール/スキル列挙を除外したか
- [ ] 複数サブツールが**同じ回数** 並んでいたら artifact を疑ったか
- [ ] 母集団の期間（`-mtime -N`）を明示したか

## 報告テンプレ

記事・レポートで数値を出す際は次を添える:

```
計測範囲: 直近 N 日（~/.claude/projects/**/*.jsonl）
集計方法: message.content[].type=="tool_use" イベントの name フィールドを集計
除外: attachment（deferred_tools_delta）/ system-reminder 内の列挙
セッション数: X （参考）
```

## 失敗事例（実録）

**2026-04-20 art_014 構想時**:
- 第1次集計: `grep -hoE 'mcp__[a-z_-]+'` → playwright 2,896 / postgresql 1,645 等
- ユーザー指摘で再検証
- 第2次集計（tool_use のみ）: playwright **130** / postgresql **1**
- 乖離 20-100倍。原因は `deferred_tools_delta` の誤カウント

この失敗を記事「MCP実測レポート」の落とし穴セクションに昇格。

## 関連ルール

- `~/.claude/rules/20-code-quality.md`: 事実確認ルール（ツールで実態を確認してから回答）
- `CLAUDE.md`: 「事実確認ルール（最優先）」セクション

## 参考: JSONL の構造

```python
# 典型的な "tool_use" イベント（本物の使用）
{
  "type": "assistant",
  "message": {
    "content": [
      {"type": "tool_use", "name": "mcp__playwright__browser_navigate", "input": {...}}
    ]
  }
}

# カタログ announcement（ツール登録、実使用ではない）
{
  "type": "attachment",
  "attachment": {
    "type": "deferred_tools_delta",
    "addedNames": ["mcp__postgresql__pg_execute_query", ...],
    "addedLines": [...]
  }
}
```
