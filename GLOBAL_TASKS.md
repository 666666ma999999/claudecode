# グローバル環境タスク

Claude Code のグローバル環境（`~/.claude/`）およびプロジェクト横断で扱うべきタスクを記録する。プロジェクト固有タスクは各プロジェクトの `tasks/` へ。

---

## NOW

### エクステンション化ルールの適用整備

**背景**: 
- グローバルルール `~/.claude/rules/60-cms-and-extension-pattern.md` はマーカーファイル検出方式（`config/extensions.yaml` or `config/extensions.json`）で自動発動する設計
- 現状、`~/Desktop/biz/` 配下のプロジェクト棚卸し結果:
  - `make_article`: マーカーなし / extensions ディレクトリなし → ルール未適用
  - `influx`: `extensions/` dir のみ（マーカーファイルなし） → ルール未適用
  - `pokeca-invest`: `extensions/` dir のみ（マーカーファイルなし） → ルール未適用
  - `chacha`, `stock_analytics`: 両方なし

**論点**:
- art_012/013 で議論した「extension化で2台並列開発」は抽象論で、実環境には適用されていない
- `extensions/` ディレクトリがある influx / pokeca-invest は、マーカーファイルを置けば自動でエクステンションルール適用対象になる

**やるべき判断**:
1. 各プロジェクトで extension化するか決める（BE: `config/extensions.yaml` 設置、FE: `config/extensions.json` 設置）
2. extension化しないプロジェクトは `~/.claude/rules/70-fe-architecture.md` / `75-be-architecture.md` のみ適用
3. art_012/013 の extension化セクションは「実体験」ではなく「一般ガイド」として位置づけを明記するか、削除

**参照**:
- `~/.claude/rules/60-cms-and-extension-pattern.md`
- `~/.claude/rules/30-routing.md`（エクステンション設計の分岐）
- スキル: `be-extension-pattern` / `fe-extension-pattern` / `fe-be-extension-coordination`

---

## DONE

（NOW→DONE 移動時は h5 見出し + 元プロンプト全文保存 + `**結果:**` マーカーで追記すること。詳細は `obsidian-now-done` スキル参照）

##### SQLite FTS5 索引化 MVP (2026-04-20)

中長期投資4件実行の依頼:「全て実行して」

**結果:** MVP完成。
- `~/.claude/scripts/ingest-jsonl-to-sqlite.py` — 冪等 ingest（998ファイル/63,807メッセージを3.8秒）
- `~/.claude/archives/index.db` — FTS5索引 (64.5MB)
- `~/.claude/scripts/search-history.sh` — 簡易検索CLI
- 検索性能: 全文 8ms / tool_use集計 108ms / フレーズ検索 18ms
- Phase 2（未実装）: SessionStart hookに ingest 自動化、tool_uses事前集計テーブル

##### skill/hook CI MVP (2026-04-20)

**結果:** MVP完成。
- `~/.claude/scripts/validate-skills-hooks.sh` — ローカル validation（47 skills + 43 hooks 全てPASS）
- `~/.claude/.github/workflows/validate.yml` — GitHub Actions PR時実行
- チェック: SKILL.md YAML / hook bash構文 / 名前重複 / allowed-tools 妥当性
- Phase 2（未実装）: GitHub push 後のActions動作検証（~/.claude を push する運用はまだ）

##### dotfiles repo init (2026-04-20)

**結果:** `~/dotfiles/` repo作成。
- `~/.zshrc` / `~/.gitconfig` をコピー配置
- `.zshrc.local` は `.gitignore` で除外（シークレット分離済み）
- README.md に 2台目Mac セットアップ手順記載
- Phase 2（未実装）: GitHub private repo化、symlink 化への切替、iTerm2/nvim/tmux 追加

##### scripts 共通化 分析 (2026-04-20)

**結果:** 棚卸し完了（実装は Phase 2）。
- 5プロジェクトのうち scripts/ 存在は3プロジェクトのみ（make_article/influx/pokeca-invest）
- chacha/stock_analytics は scripts/ なし（app構造）
- 真の横断重複は 2件のみ:
  1. **JSONL load/append/write ユーティリティ**（make_article + influx で Canonical Module 違反）— 高優先
  2. **xstock-vnc pre-flight チェック**（make_article + influx で重複）— 高優先
- pokeca-invest は TypeScript 単独なのでプロジェクト内 `scripts/lib/` で完結
- Phase 2（未実装）: `~/.claude/scripts/lib/python/jsonl_io.py` + `shell/vnc_preflight.sh` 実装、各プロジェクト書換え
