# Claude × Obsidian 統合仕様（claude-obsidian 方式）

`~/.claude/rules/40-obsidian.md` の詳細 reference。コマンド使用例・vault 構造・スキル一覧・典型ワークフローのカタログ。
不変ルール・禁止・hooks 仕様は `rules/40-obsidian.md` を正典とする。

## 全体像

- 方式: AgriciDaniel/claude-obsidian の Karpathy LLM Wiki パターン
- vault パス: `~/Documents/Obsidian Vault/`
- 構成要素: 11 skills + 4 slash commands + 2 agents + 4 hooks + 1 MCP server (mcpvault)
- 目的: Obsidian vault を Claude Code の第二の脳として運用、セッション間で文脈・知見を継承

## Vault 構造

```
~/Documents/Obsidian Vault/
├── .obsidian/                    Obsidian 設定（既存）
├── .raw/                         immutable sources（取り込み元の生データ、append-only）
│   ├── material-bank-*.{md,jsonl}  改善素材（Material Bank）
│   └── lessons/                    各プロジェクトの lessons.md コピー
├── wiki/                         LLM-maintained 知識ベース
│   ├── concepts/                   抽象概念・用語ノート
│   ├── entities/                   人・組織・製品の固有名詞ノート
│   ├── sources/                    取り込み元へのリファレンス
│   ├── meta/                       vault 自体のメタ情報
│   ├── canvases/                   Canvas ファイル群
│   ├── hot.md                      500字 session cache（SessionStart で自動 cat）
│   ├── index.md                    wiki 全体の index
│   └── log.md                      更新ログ
├── _templates/                   Obsidian Templater 雛形
└── (既存 142 件の md ノート)      無変更で grandfather 保持
```

## スラッシュコマンド

### `/wiki`

- 引数なし
- 動作: ① Obsidian インストール確認 → ② `.obsidian/` 検出 → ③ MCP server (`mcpvault`) 確認 → ④ 「この vault は何用？」を 1 回だけ質問 → ⑤ 構造を scaffold して提示
- vault 設定済みなら最近の ingest を確認して「続きから」を提案

### `/save [name]`

| 形式 | 動作 |
|---|---|
| `/save` | 会話全体から最も価値ある内容を抽出して保存 |
| `/save [name]` | タイトル指定保存 |
| `/save session` | セッションサマリ保存 |
| `/save concept [name]` | `wiki/concepts/` に concept ページとして保存 |
| `/save decision [name]` | decision record として保存 |

同名ノート存在時は上書き / 更新を確認。

### `/canvas [op]`

| 操作 | 用途 |
|---|---|
| `/canvas` | ステータス確認（node 数 / zone 一覧） |
| `/canvas new [name]` | `wiki/canvases/` に新規 canvas |
| `/canvas add image [path\|url]` | 画像追加（URL は download、vault 外は copy） |
| `/canvas add text [content]` | テキストカード追加 |
| `/canvas add pdf [path]` | PDF ノード追加 |
| `/canvas add note [page]` | wiki ページをカード化 |
| `/canvas zone [name] [color]` | ラベル付き zone group 追加 |
| `/canvas list` | 全 canvas を node 数付きで一覧 |
| `/canvas from banana` | 最近生成された画像を検出して追加 |

デフォルト canvas: `wiki/canvases/main.canvas`。

### `/autoresearch <topic>`

- 引数で指定したトピックを autonomous loop で調査（search → fetch → synthesize → file）
- 引数省略時: DragonScale Mechanism 4（boundary-first / agenda-control / opt-in）があれば top 5 候補を提示、なければ「何を調査？」を質問
- 完了後: `wiki/index.md` `wiki/log.md` `wiki/hot.md` を自動更新
- 制約読み込み: `~/.claude/skills/autoresearch/references/program.md`

## 自然言語トリガー（スラッシュなし）

| フレーズ | 用途 | スキル |
|---|---|---|
| `ingest <file\|url>` | ソースを `.raw/` に取り込み → `wiki/` に 8-15 ページ自動分解 | `wiki-ingest` |
| `lint the wiki` | orphan / dead link / gap 検出 | `wiki-lint` |
| `update hot cache` | `wiki/hot.md` を最新会話文脈で刷新 | `wiki` |
| `query the wiki ...` | wiki 内検索（filename / 内容） | `wiki-query` |
| `fold ...` | 重複ノート統合 | `wiki-fold` |

## MCP Server (mcpvault)

- 登録名: `mcpvault`
- パッケージ: `@bitbonsai/mcpvault@latest`
- 環境変数: `MCPVAULT_PATH=${HOME}/Documents/Obsidian Vault`
- 設定ファイル: `~/.claude/.mcp.json`
- 確認: `claude mcp list` で `mcpvault: connected` 表示

## スキル一覧（11 種）

`~/.claude/skills/` 配下:

| スキル | 役割 |
|---|---|
| `wiki` | vault セットアップ・scaffold・hot 更新 |
| `save` | 会話 → wiki ノート保存 |
| `wiki-ingest` | ソース取込み → 8-15 ページ自動分解 |
| `wiki-query` | wiki 検索 |
| `wiki-lint` | リンク健全性検証 |
| `wiki-fold` | 重複統合 |
| `autoresearch` | 自律調査ループ |
| `canvas` | Canvas 操作 |
| `obsidian-markdown` | Obsidian 拡張 markdown 仕様 |
| `obsidian-bases` | Obsidian Bases (DB-like) 操作 |
| `defuddle` | Web ページ → 整形 markdown |

各スキルの引数・出力例・失敗パターンの正典は対応 `SKILL.md`。

## Agents（2 種）

`~/.claude/agents/`:

- `wiki-ingest` — ingest 処理を非同期に委託する subagent
- `wiki-lint` — lint 処理を委託する subagent

## 典型ワークフロー

| 場面 | 操作 |
|---|---|
| 新規 vault 構築 | `/wiki` → 用途を 1 回答えて scaffold |
| 良い会話を保存 | `/save concept ◯◯` または `/save decision ◯◯` |
| 外部資料取り込み | `ingest path/to/file.md` または `ingest https://...` |
| トピック深掘り | `/autoresearch ◯◯` |
| 構造を視覚化 | `/canvas new map` → `/canvas add note ◯◯` を繰り返す |
| 健全性確認 | `lint the wiki` |
| セッション再開 | hot.md が SessionStart で自動 cat されるので何もしなくてよい |

## 関連ファイル

- 設計 SSoT: `~/.claude/plan.md`
- 実装記録: `~/.claude/tasks/p-a-claude-obsidian-integration.md`
- 不変ルール: `~/.claude/rules/40-obsidian.md`
- vault バックアップ: `~/.claude/state/vault-backup-20260424/`（手動削除まで保持）
- vault 内スナップショット: `<vault>/wiki/meta/claude-obsidian-integration-20260424.md`
