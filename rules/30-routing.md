# スキルルーティング（インデックス）

詳細表（全カテゴリの完全リスト）: `~/.claude/docs/routing-table.md` を必要時のみ Read。
高頻度トリガーのみ以下に抜粋:

| トリガー | スキル |
|---|---|
| 新機能/MVP・4項目ブリーフ | `new-feature` |
| 完了報告前・検証完了 | `implementation-checklist` |
| Plan前スキル検索 | `find-skills` |
| Plan中アーキ判断・設計リスク | `plan-adversarial-review` |
| BE新機能/API/HookPoint | `be-extension-pattern` |
| FE新機能/ページ/ウィジェット | `fe-extension-pattern` |
| FE+BE連携・APIコントラクト | `fe-be-extension-coordination` |
| デバッグ・根本原因 | `debugging-guide` |
| 行き詰まり・stuck引渡 | `/rescue` |
| リファクタ戦略/安全性 | `refactoring-guide` / `refactoring-safety` |
| テスト失敗・TDD | `test-fixing` |
| セキュリティ監査 | `security-twin-audit` |
| git commit/push/事故 | `git-safety-reference` |
| .mcp.json/APIキー | `secret-management` |
| Obsidian NOW→DONE/`/done` | `obsidian-now-done` |
| `/save` `/wiki` `/canvas` `/autoresearch` | claude-obsidian 系 |
| Web リサーチ | `~/.claude/docs/web-research-tools.md` |
| Google Workspace | `gog-cli`（WebFetch禁止） |
| 叩き台/探索/UI試作 | `/prototype` |
| task細分化/進捗/復帰 | `task-planner` / `task-progress` / `project-recall` |
| SubAgent委譲判断 | `execution-patterns` |

その他のカテゴリ（KPI・データ可視化・ダッシュボード・売上分析・スクレイピング・X Articles 12種・スキル管理・設定診断・Codex委譲 ほか）は `routing-table.md` 参照。

## エクステンション設計の分岐

| extensions.yaml | extensions.json | 適用ルール |
|:-:|:-:|---|
| あり | あり | 同一リポ → `60-cms-and-extension-pattern.md` ハイブリッド + 各スキル併用。分離リポ → `fe-be-extension-coordination` |
| あり | なし | BE: `be-extension-pattern`。FE: Step 2 |
| なし | あり | FE: `fe-extension-pattern`。BE: Step 2 |
| なし | なし | Step 2 |

Step 2: `backend/`/`src/` Python あり → `75-be-architecture.md` / `frontend/*.html`+JS → `70-fe-architecture.md` / 不明 → ユーザー確認。

優先順: `CLAUDE.md` > `rules/` > スキル。マーカー有スキル > マーカー無アーキ。競合は限定的なルールを優先。

## シークレット管理（要約）

`.mcp.json` シークレット直書き禁止。`${VAR}` プレースホルダー必須。値は `~/.zshrc` で `export`、Claude Code はターミナル起動。詳細: `secret-management` スキル。

## スキル化判断（要約）

完了時: ① 新機能/再発バグ → ② 繰返し使う知見 → ③ 既存スキル追加可。詳細: `skill-lifecycle-reference` スキル。
