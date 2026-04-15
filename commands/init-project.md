# /init-project

$ARGUMENTS をプロジェクト名 or 概要として使用。引数なしなら現在の cwd を初期化対象とする。

このコマンドは **`project-bootstrap`** スキルを起動します。**チェックリスト全項目・シークレット管理手順・Docker 設定詳細は** `~/.claude/skills/project-bootstrap/SKILL.md` を参照してください (複製しない — 常に skill 側が正)。

## 起動後の最初のアクション

1. `~/.claude/skills/project-bootstrap/SKILL.md` を Read で読み込む
2. `~/.claude/templates/project/` 配下のテンプレート一覧を確認
3. skill のチェックリスト順 (基本ファイル → シークレット → Docker → テスト/lint → task.md) に実行
4. プロジェクト固有のシークレットは `~/.zshrc` 追記、`.mcp.json` では `${VAR}` 参照

## 用途の要約 (1 行)

新プロジェクトの `.gitignore` / `CLAUDE.md` / `.mcp.json` / Docker 設定 / テスト定義を一括初期化。完了後は `/new-feature` で初回機能追加へ。
