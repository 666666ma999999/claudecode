# Docker安全ルール

## Docker-Only開発

依存管理・ビルド・実行はDocker経由。ホスト上 `pip install`, `npm install`, `npx` 等は禁止。
適用除外: MCP設定、Claude Codeツール拡張、スキル検索（`npx skills find`）。
