---
name: new-feature
description: |
  新機能/新プロジェクト着手時のブリーフ収集→壁打ち→Plan mode 起動の統合スキル。
  Why/Who/非ゴール/成功基準の4項目を対話収集し、構成案（アプローチ・Phase分解・技術選定）を
  壁打ちで合意してから Plan mode に入る。
  キーワード: 新機能, 新プロジェクト, MVP, ブリーフ, Plan mode 起動, /new-feature
  NOT for: 1ファイル修正, バグ修正 (→ debugging-guide), リファクタリング (→ refactoring-guide)
triggers:
  - 新機能を作りたい
  - 新プロジェクト
  - /new-feature
  - MVP 開始
  - 機能着手
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion]
---

# New Feature Workflow

新機能/新プロジェクト着手時のブリーフ収集 → Plan mode 起動の統合エントリポイント。

## Phase 0: Discovery

1. マーカーファイル検出でプロジェクト種別を判別:
   - `extensions.yaml` あり → BE エクステンションプロジェクト
   - `extensions.json` あり → FE エクステンションプロジェクト
   - 両方あり → ハイブリッド (`60-cms-and-extension-pattern.md` 適用)
   - なし → 汎用プロジェクト
2. 既存 `tasks/` ディレクトリ、`plan.md`、`MEMORY.md` があれば読み込む。
3. 既存プロジェクトなら `Glob tasks/**/*.md` で feature 一覧を取得し、重複着手を防ぐ。

## Phase 1: Brief 収集

`AskUserQuestion` で以下4項目を収集する。**3項目以上が空の場合は Phase 2 に進まず警告する。**

```
質問1 — Why (動機)
「この機能を作る理由を1-2行で教えてください。
例: 手動でやっている○○を自動化したい / ユーザーから△△の要望が多い」

質問2 — Who (想定ユーザー)
「誰が使いますか？（自分 / 社内 / エンドユーザー / 特定ペルソナ）」

質問3 — 非ゴール (multiSelect 可)
「今回やらないと決めることを選んでください（複数可）:
- 管理画面UI
- モバイル対応
- 多言語対応
- パフォーマンス最適化
- 既存機能の変更
- その他（自由記述）」

質問4 — 成功基準
「完了をどう判断しますか？観測可能な条件で教えてください。
例: `pytest tests/xxx.py` が全 PASS / ブラウザで○○が表示される / curl で200が返る」
```

収集後、feature-slug (英小文字・ハイフン区切り) をユーザーに1単語で確認する。

`~/.claude/templates/plan.md` が存在しない場合はエラーを出力して停止する。

4項目を収集したら `tasks/{slug}.md` を作成する。以下を実行する前に、必ず:

1. **cwd 確認**: `git rev-parse --show-toplevel 2>/dev/null || pwd` でプロジェクトルート推定。別ディレクトリにいる場合は `cd` でプロジェクトルートに移動する
2. **プレースホルダ置換**: 以下のコマンドで `{slug}` を Phase 1 で確認した feature-slug (例: `ad-revenue-mvp`) にリテラル置換してから Bash 実行 (山括弧 `<>` は使わない — シェル リダイレクト誤爆防止)

```bash
# 実行前に {slug} を実際のスラッグに置換すること (例: {slug} → ad-revenue-mvp)
mkdir -p tasks
cp ~/.claude/templates/plan.md tasks/{slug}.md
```

その後 `tasks/{slug}.md` の各セクション（Why/Who/非ゴール/成功基準）を Edit ツールで埋める。

## Phase 1.5: 壁打ち（構成の対話設計）

Brief 収集後、**Plan mode に入る前に**ユーザーと全体構成を対話で固める。

### Claude が提示するもの

Brief（Why/Who/非ゴール/成功基準）+ コードベース情報をもとに、以下の初期案を提示する:

1. **アプローチ**: 全体の作り方（1-3行）
2. **Phase 分解**: やることの順序 + MVP ライン（どこまでで最小限動くか）
3. **技術・デザイン選定**: 新規採用する技術があれば明示。なければ「既存スタック踏襲」

### 対話ルール

- ユーザーが「OK」「これでいい」「進めて」等の合意を示すまで繰り返す
- Claude は代替案やトレードオフを積極的に提示する（「Aでもいけるが、Bのほうがシンプル」等）
- 壁打ち中に非ゴールや成功基準が変わったら `tasks/{slug}.md` を即更新する

### 合意後

`tasks/{slug}.md` の「構成案」セクション（アプローチ / Phase 分解 / 技術・デザイン）を Edit で埋める。

**構成案セクションが空のまま Phase 2 に進まない。**

## Phase 2: Plan Mode 起動

`EnterPlanMode` を呼ぶ。Phase 1.5 で合意した構成案をベースに、Claude が以下を実行する:

1. **影響範囲の提案**: `Grep`/`Glob` でコードベースをスキャンし、変更が及ぶファイル/ディレクトリを列挙して `tasks/{slug}.md` の「影響範囲」セクションに追記する。
2. **変更禁止ファイルの提案**: `core/`・`shared/`・設定ファイル等のクリティカルファイルを特定し「変更禁止ファイル」セクションに追記する。
3. **実装計画策定**: `task-planner` スキルに準拠したバッチ構成（Batch 1-N + fast_verify）を plan に追記する。

`ExitPlanMode` 前に `plan-quality-check.sh` が成功基準/影響範囲/変更禁止ファイルの3セクション存在を検査する。

## Phase 3: 実装

`ExitPlanMode` 後:

- `execution-patterns` スキル（バッチ実行・SubAgent委託）に従い実装する。
- 変更禁止ファイルへの変更は `plan-drift-warn.sh` が PreToolUse でブロックする。
- バッチ検証ループ: 各バッチ終了後に fast_verify を実行してから次バッチに進む。

## Phase 4: 完了

1. `implementation-checklist` スキル STEP 1-4 を実行する。
2. Obsidian NOW→DONE 移動は `obsidian-now-done` スキルに従う。
3. `tasks/{slug}.md` の Session Handoff セクションを更新する（`task-progress` スキル参照）。

## 既存スキルとの関係

| スキル | 使い分け |
|--------|---------|
| `feature-dev-hybrid` | 3並列設計比較が必要な大規模機能。new-feature はその軽量版 |
| `project-bootstrap` | 完全新規プロジェクトの `.gitignore`/Docker初期化。new-feature は機能設計に集中 |
| `task-planner` | Phase 2 の計画策定で内部参照する |
| `task-progress` | Phase 1 で生成した `tasks/{slug}.md` はこのスキルの管理対象になる |
| `execution-patterns` | Phase 3 のバッチ実行・SubAgent委託ルールを提供 |
| `implementation-checklist` | Phase 4 の完了ゲートを提供 |

## Execution Strategy

このスキルは常に **Delivery モード** で動作する。成功基準は Phase 1 で確定させ、`tasks/{slug}.md` の「成功基準」セクションに記載する。成功基準が定義できない場合は `AskUserQuestion` で確認し、必要なら **Clarify モード** に切り替える。
