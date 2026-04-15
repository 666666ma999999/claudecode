# /new-feature

$ARGUMENTS を feature-slug (英小文字・ハイフン区切り) または feature 概要として使用。引数なしの場合は Phase 1 の最初で確認する。

このコマンドは `new-feature` スキルのフロー (Phase 0-4) を起動します。詳細手順は `~/.claude/skills/new-feature/SKILL.md` に記載。

## 実行手順

### Phase 0: Discovery
1. マーカーファイル検出 (`extensions.yaml` / `extensions.json`) でプロジェクト種別を判別
2. 既存 `tasks/`, `plan.md`, `MEMORY.md` を読み込む
3. 既存プロジェクトなら `Glob tasks/**/*.md` で feature 重複を確認

### Phase 1: Brief 収集 (必須)

`AskUserQuestion` で以下 4 項目を収集:

1. **Why (動機)**: 「この機能を作る理由を1-2行で教えてください」
2. **Who (想定ユーザー)**: 「誰が使いますか? (自分 / 社内 / エンドユーザー / ペルソナ)」
3. **非ゴール (multiSelect)**: 「今回やらないと決めることを選んでください」
4. **成功基準**: 「完了をどう判断しますか? (観測可能な条件)」

feature-slug (英小文字・ハイフン区切り) をユーザーに確認後:

```bash
# {slug} を Phase 1 で確認した feature-slug にリテラル置換してから実行
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
mkdir -p tasks
cp ~/.claude/templates/plan.md tasks/{slug}.md
```

`~/.claude/templates/plan.md` が存在しない場合はエラー出力して停止。

その後 `tasks/{slug}.md` の Why/Who/非ゴール/成功基準セクションを Edit ツールで埋める。

### Phase 2: Plan Mode 起動

`EnterPlanMode` を呼び、Plan mode 内で:

1. 影響範囲の提案: `Grep`/`Glob` で codebase スキャン → `tasks/{slug}.md` に追記
2. 変更禁止ファイルの提案: core/shared/critical 特定 → 追記
3. 実装計画策定 (バッチ構成 + fast_verify)

`ExitPlanMode` で `plan-quality-check.sh` が成功基準/影響範囲/変更禁止ファイル 3 セクション検査。

### Phase 3: 実装

- `execution-patterns` スキル (バッチ実行・SubAgent 委託) に従う
- 変更禁止ファイルへの編集は `plan-forbidden-block.sh` が PreToolUse で auto-block

### Phase 4: 完了

- `implementation-checklist` STEP 1-4 実行
- Obsidian NOW→DONE は `obsidian-now-done` スキル
- `tasks/{slug}.md` の Session Handoff を更新

## Execution Strategy

常に **Delivery モード**で動作。成功基準は Phase 1 で確定。定義できない場合は **Clarify モード**に切替えて再質問する。
