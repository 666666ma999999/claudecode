# シークレット管理ルール

## 基本方針

- `.mcp.json` へのシークレット直書き**禁止**。`${VAR}` プレースホルダー必須
- アーキテクチャ: direnv (.envrc) → シェル環境変数 → .mcp.json の `${VAR}` 展開
- 共通キー: `~/.envrc.shared` に集約、各 `.envrc` から `source_env_if_exists ~/.envrc.shared`
- 新プロジェクト: `.envrc` 作成 → `source_env_if_exists` 記載 → 固有変数追記 → `direnv allow`
- `.envrc`, `.envrc.shared`, `.mcp.json` は git管理対象外
- 詳細手順: `secret-management` スキル参照
