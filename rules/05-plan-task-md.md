# plan.md / task.md 運用ルール

全標準タスクは **plan.md（設計 SSoT）+ task.md（実行追跡）の 2 層構造** で管理する。
`CLAUDE.md` の「標準ワークフロー」の前提ルール。

## 役割分担

| ファイル | 役割 | 粒度 | 寿命 |
|---------|------|------|------|
| **plan.md** | feature/プロジェクト全体の設計 SSoT（Why/Who/成功基準/Phase 分解/影響範囲） | feature 単位 | feature 完了まで永続 |
| **task.md** | 個別実行の追跡（Scope/Progress/Stuck/Session Handoff） | 1 セッション〜数セッション | タスク完了で done、その後 archive |
| **task-light.md** | 単発タスクの軽量版 | 1 セッション完結 | done 後 archive |

### plan.md が担う

- Why / Who / 非ゴール / 成功基準
- 構成案（アプローチ / Phase 分解 / 技術選定）
- 影響範囲 / 変更禁止ファイル
- Phase 跨ぎの意思決定ログ

### task.md が担う

- Metadata（Status / 開始日 / 優先度）
- Current Agreed Scope（Must / Nice-to-have / Descoped）
- Progress Snapshot（Blocked / Next）
- Failures / Stuck Context
- Session Handoff（再開ポイント / 試した失敗 / 確認済み事実）
- Decision Log

### 重複禁止

- 同じ情報を両方に書かない。plan.md が親、task.md が子
- task.md から plan.md の該当セクションへリンク（`plan.md#成功基準` 等）
- plan.md に書くべき「設計判断」を task.md に書かない（task.md は実行記録に徹する）

## トリガー条件（必須／任意の判定）

### plan.md が必須

- 新 feature / MVP 立ち上げ
- 複数 Phase にまたがる開発
- アーキテクチャ変更を含むタスク
- 3 ファイル以上の変更が予想される標準タスク
- 既存 plan.md に収まらない新方針の決定

### task.md が必須

- 標準タスク（即答タスク以外のすべて）
- Plan Mode（`EnterPlanMode`）を使うすべてのタスク
- 複数セッションにまたがる作業
- stuck / blocker 発生時（その場で task.md を起こして Handoff を書く）

### 省略可（= task-light.md でよい）

- 1 ファイル数行の修正
- 事実確認 / Yes-No 質問
- 既存 task.md の派生子タスク（親で追跡可能な場合）

### plan.md 不要・task.md のみでよい

- 既存 plan.md の範囲内の個別 Slice / Batch 実行
- バグ修正で設計判断を伴わないもの
- 既存 feature の小幅改修（plan.md の「構成案」に影響しない）

## 配置場所

- `<project-root>/plan.md` — プロジェクト全体の plan.md（1 プロジェクト 1 枚が原則）
- `<project-root>/src/features/<name>/plan.md` — feature 単位の plan.md（Feature Extension 構成時）
- `<project-root>/tasks/<task-name>.md` — task.md（複数枚 OK）
- `<project-root>/tasks/phase-tracker.md` — Phase 進捗の横串トラッカー（plan.md の Phase 分解に対応）
- `<project-root>/tasks/archive/` — 完了済み task.md の退避先

## Phase ↔ task.md 紐付け方式（B+ ハイブリッド軽量方式）

plan.md に書いた Phase と `tasks/*.md` を紐付けるための運用ルール。
小〜中規模プロジェクト（task 数 <30、貢献者 ≤2、Phase 数 ≤5）はこの軽量方式で十分。

### 命名規則（タスクファイル名プレフィックス）

```
p<N>-<slug>.md       → Phase N のタスク（例: p1-ebay-setnumber.md）
sprint<N>-<slug>.md  → Sprint/Tech Debt タスク（例: sprint2-mercari-phase1-run.md）
bl-<N>-<slug>.md     → Blocker 記録（例: bl-1-arbitrage-filter-fix.md）
<slug>.md            → Phase 非依存（phase-tracker.md / lessons.md 等の管理ファイル）
```

**利点**: `ls tasks/p1-*.md` / `rg "^##### " tasks/sprint2-*.md` で Phase 別一覧が可能。

### task.md 冒頭の固定 2 行（必須）

タイトル直後に Phase と phase-tracker への双方向リンクを配置する:

```markdown
# Task: [タスク名]

**Phase:** [Phase N — <Phase タイトル>](../plan.md#phase-<N>)
**Tracker:** [phase-tracker §Phase N](./phase-tracker.md#phase-<N>)

## Execution Strategy
...
```

### plan.md / phase-tracker.md 側の安定アンカー

名称変更に伴うリンク切れを防ぐため、各 Phase 見出し直後に明示アンカーを配置:

```markdown
### Phase 1: データ foundation 固め
<!-- phase-id: phase-1 — tasks/p1-*.md から参照される安定アンカー -->
<a id="phase-1"></a>
```

**アンカー命名**: `phase-<N>` / `phase-sprint-<N>` / `phase-<feature>` 等。見出し日本語に依存しない。

### phase-tracker 側の逆リンク（推奨）

各進捗項目から tasks/*.md への逆参照:

```markdown
- [x] eBay setNumber 充填 → [p1-ebay-setnumber](./p1-ebay-setnumber.md)
- [ ] Mercari 本番 run → [sprint2-mercari-phase1-run](./sprint2-mercari-phase1-run.md)
```

### 壊れたリンクの検知

月 1 回手動で:
```bash
npx markdown-link-check tasks/*.md plan.md --config .mlc.json
```
plan.md の見出し変更時のみ:
```bash
rg "plan.md#phase-" tasks/
```

### 規模超過時の自動化方式（将来の案 A 昇格）

tasks/phase-tracker.md 冒頭に下記コメントで監視する:
```markdown
<!-- 軽量紐付け方式の継続条件:
     - tasks/*.md 数: < 30
     - 貢献者数: ≤ 2
     - Phase 数: ≤ 5 + Sprint 枠
     超過したら自動生成方式（frontmatter + build-phase-tracker.ts）へ段階移行 -->
```

超過条件:
- task.md 40 件以上 → frontmatter + CI 検証が必要
- Phase 10 個以上 → `p01-` ゼロ埋めでプレフィックス衝突回避
- 貢献者 3 名以上 → 命名規則違反を機械検知する必要あり
- Phase 再編が月次 → 手動 rename コストが自動化投資を上回る

## テンプレート

- `~/.claude/templates/plan.md` — plan.md の雛形
- `~/.claude/templates/task.md` — task.md フル版（複数セッション・PM 管理向け）
- `~/.claude/templates/task-light.md` — task.md 軽量版（1 セッション完結向け）

テンプレ選択:
- 迷ったら `task-light.md` で開始
- 要件変更追跡・Decision Log が必要になったら `task.md` フル版に昇格

## ワークフロー統合（`CLAUDE.md` の標準ワークフローと連動）

### セッション開始時

1. `ls plan.md tasks/*.md 2>/dev/null` で既存を検出
2. plan.md → Phase 分解 / 成功基準を確認
3. 該当タスクの task.md → Session Handoff / Stuck Context を確認
4. 前回 stuck の原因を必ず確認してから作業開始

### 新規標準タスク着手時

1. plan.md が必要か判定（上記トリガー条件）
   - 必要 → plan.md を作成または既存を更新
   - 不要 → 既存 plan.md の該当 Phase を参照
2. task.md を起こす（軽量版から開始可）
3. `## 成功基準` を task.md に定義（`CLAUDE.md` Execution Strategy ルール）
4. `EnterPlanMode` で Plan Mode へ

### セッション終了時（必須）

- task.md の Session Handoff 更新（CLAUDE.md L150-153 に連動）
- Progress Snapshot の Blocked / Next を最新化
- 未完了タスクがあるのに Failures/Stuck Context が空なら **終了禁止**
- plan.md の Phase 完了があれば phase-tracker.md に反映

## 禁止事項

- plan.md / task.md を作らずに 3 ファイル以上の変更に入ること
- task.md 未作成のまま「memory 更新で足りる」と判断すること（memory は横断知見、task.md は再開ポイント）
- plan.md の成功基準が無いまま `EnterPlanMode` を呼ぶこと（`plan-quality-check.sh` フックが検知）
- plan.md の「変更禁止ファイル」を触ること（`plan-drift-warn.sh` フックが PreToolUse で auto-block）
- 完了済み task.md をルート直下に残すこと（archive/ へ退避）

## Red Flags（発見したら即修正）

- `tasks/` ディレクトリが空または存在しないのに複数ファイル変更が進行中
- task.md が 1 週間以上 Status=active のまま更新されていない
- plan.md に書いていない「新 feature」が突然コードに現れる
- 同じ設計判断が plan.md と task.md に二重記載されている
- Session Handoff が「作業継続中」だけで、Start Here / Avoid Repeating / Key Evidence が空

## スキル参照

- `task-planner` — 要件 → task.md 分解
- `task-progress` — task.md の Read/Write Protocol（Session Handoff 運用）
- `new-feature` — 新 feature 立ち上げ時の plan.md 生成
- `plan-adversarial-review` — plan.md 策定中の敵対的レビュー

## 優先順位

`CLAUDE.md` > 本ルール（`05-plan-task-md.md`）> 他 rules/ > スキル。
本ルールと他 rules/ が競合した場合は本ルールが優先（全標準タスクの前提条件のため）。
