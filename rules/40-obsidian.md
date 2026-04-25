# Claude × Obsidian 連携仕様（claude-obsidian 方式）

CLAUDE.md「行動原則 §Obsidian」の詳細仕様。2026-04-24 以降の運用ルール。
本ファイルが claude-obsidian 統合の **Single Source of Truth**。

## 1. 全体像

- **方式**: AgriciDaniel/claude-obsidian の Karpathy LLM Wiki パターン
- **vault パス**: `~/Documents/Obsidian Vault/`
- **構成要素**: 11 skills + 4 slash commands + 2 agents + 4 hooks + 1 MCP server (mcpvault)
- **目的**: Obsidian vault を Claude Code の第二の脳として運用し、セッション間で文脈・知見を継承する

## 2. Vault 構造

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
│   ├── meta/                      vault 自体のメタ情報
│   ├── canvases/                  Canvas ファイル群
│   ├── hot.md                     500字 session cache（SessionStart で自動 cat）
│   ├── index.md                   wiki 全体の index
│   └── log.md                     更新ログ
├── _templates/                   Obsidian Templater 雛形
└── (既存 142 件の md ノート)      無変更で grandfather 保持
```

## 3. スラッシュコマンド（4 種）

| コマンド | 用途 | 詳細仕様 |
|---|---|---|
| `/wiki` | vault セットアップ確認 / 初期 scaffold / 続きから再開 | `~/.claude/skills/wiki/SKILL.md` |
| `/save [name]` | 現在の会話を wiki ノートとして保存 | `~/.claude/skills/save/SKILL.md` |
| `/canvas [op]` | Canvas に画像/テキスト/PDF/ノート追加、zone 分割 | `~/.claude/skills/canvas/SKILL.md` |
| `/autoresearch <topic>` | iterative web research → wiki/ に filing | `~/.claude/skills/autoresearch/SKILL.md` |

### 3.1 `/wiki`

- 引数なし
- 動作: ① Obsidian インストール確認 → ② `.obsidian/` 検出 → ③ MCP server (`mcpvault`) 確認 → ④ 「この vault は何用？」を 1 回だけ質問 → ⑤ 構造を scaffold して提示
- vault 設定済みなら最近の ingest を確認して「続きから」を提案

### 3.2 `/save [name]`

- `/save` — 会話全体から最も価値ある内容を抽出して保存
- `/save [name]` — タイトル指定保存
- `/save session` — セッションサマリ保存
- `/save concept [name]` — `wiki/concepts/` に concept ページとして保存
- `/save decision [name]` — decision record として保存
- 同名ノート存在時: 上書き / 更新を確認

### 3.3 `/canvas [op]`

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

- デフォルト canvas: `wiki/canvases/main.canvas`

### 3.4 `/autoresearch <topic>`

- 引数で指定したトピックを autonomous loop で調査（search → fetch → synthesize → file）
- 引数省略時: DragonScale Mechanism 4 (boundary-first / agenda-control / opt-in) があれば top 5 候補を提示、なければ「何を調査？」を質問
- 完了後: `wiki/index.md` `wiki/log.md` `wiki/hot.md` を自動更新
- 制約読み込み: `~/.claude/skills/autoresearch/references/program.md`

## 4. 自然言語トリガー（スラッシュなし）

| フレーズ | 用途 | スキル |
|---|---|---|
| `ingest <file\|url>` | ソースを `.raw/` に取り込み → `wiki/` に 8-15 ページ自動分解 | `wiki-ingest` |
| `lint the wiki` | orphan / dead link / gap 検出 | `wiki-lint` |
| `update hot cache` | `wiki/hot.md` を最新会話文脈で刷新 | `wiki` |
| `query the wiki ...` | wiki 内検索（filename / 内容） | `wiki-query` |
| `fold ...` | 重複ノート統合 | `wiki-fold` |

## 5. Hooks（自動挙動）

`~/.claude/settings.json` に登録済み。**全 hook は `[ -d wiki ] && [ -d .git ]` ガード付き**で vault 外プロジェクトでは no-op。

| Event | Matcher | 挙動 |
|---|---|---|
| SessionStart | startup\|resume | `wiki/hot.md` を自動 `cat` してコンテキストに注入 |
| PostToolUse | Write\|Edit | vault かつ `.git` 存在時、`wiki/` `.raw/` を auto-commit |
| Stop | (vault 内) | `wiki/` 変更があれば `hot.md` 更新を勧めるプロンプト注入 |
| PreCompact | * | compact 直前に `wiki/hot.md` を再読み込み（context 喪失対策） |

退避済み（旧 hook）: `~/.claude/hooks/_deprecated/{obsidian-now-done-guard.sh, obsidian-session-reminder.sh}` — NOW→DONE 運用廃止に伴い無効化、物理削除はせず保持。

## 6. MCP Server (mcpvault)

- 登録名: `mcpvault`
- パッケージ: `@bitbonsai/mcpvault@latest`
- 環境変数: `MCPVAULT_PATH=${HOME}/Documents/Obsidian Vault`
- 設定: `~/.claude/.mcp.json`
- 確認: `claude mcp list` で `mcpvault: connected` 表示

## 7. スキル一覧（11 種）

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

## 8. Agents（2 種）

`~/.claude/agents/`:

- `wiki-ingest` — ingest 処理を非同期に委託する subagent
- `wiki-lint` — lint 処理を委託する subagent

## 9. 不変ルール（禁止・制約）

### 9.1 既存ノート保護

- vault 直下の既存 142 件 md ノートは **無変更**。触らない
- `.obsidian/{workspace,community-plugins,core-plugins,types,templates}.json` は変更禁止
- `.obsidian/plugins/` 配下の既存プラグインは変更禁止

### 9.2 NOW→DONE 運用の廃止

- 2026-04-24 以降、NOW→DONE refs/分離 運用は廃止
- セッション保存は `/save` に一本化
- 既存 NOW/DONE エントリは grandfather 扱いで無編集保持

### 9.3 ディレクトリ規律

- `.raw/` は **append-only**。過去ソースを書き換えない
- `wiki/` は LLM 自動メンテナンス領域（人手編集も可、ただし PostToolUse hook で auto-commit 発生）
- 他プロジェクトでの Write/Edit が vault に誤コミットされないこと（hook の vault 限定 guard が保証）

### 9.4 シンボリックリンク禁止

- `~/.claude/` 配下、vault 配下とも symlink 不使用。スキル更新もコピー方式

## 10. 典型ワークフロー

| 場面 | 操作 |
|---|---|
| 新規 vault 構築 | `/wiki` → 用途を 1 回答えて scaffold |
| 良い会話を保存 | `/save concept ◯◯` または `/save decision ◯◯` |
| 外部資料取り込み | `ingest path/to/file.md` または `ingest https://...` |
| トピック深掘り | `/autoresearch ◯◯` |
| 構造を視覚化 | `/canvas new map` → `/canvas add note ◯◯` を繰り返す |
| 健全性確認 | `lint the wiki` |
| セッション再開 | hot.md が SessionStart で自動 cat されるので何もしなくてよい |

## 11. 関連ファイル

- 設計 SSoT: `~/.claude/plan.md`
- 実装記録: `~/.claude/tasks/p-a-claude-obsidian-integration.md`
- vault バックアップ: `~/.claude/state/vault-backup-20260424/`（手動削除まで保持）

## 12. 優先順位

`CLAUDE.md` > 本ルール（`40-obsidian.md`）> 他 rules/ > 各スキル `SKILL.md`。
コマンド使用例・引数詳細・失敗時挙動は SKILL.md が正典。本ルールはカタログと共通制約のみを定義する。
