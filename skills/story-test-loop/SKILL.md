---
name: story-test-loop
description: |
  プロダクトの全機能を「ユーザーストーリー台帳（単一正準CSV）」に棚卸しし、
  全数テスト→エラー文書化→まとめて修正→全数再テスト を台帳が全 pass になるまで回す 4-phase 回帰ループ。
  tomosman のループ概念 (x.com/tomosman/status/2068692611334893582・出所 @MatthewBerman) の当環境移植。
  cwd 非依存・全プロダクト共通。台帳 = tests/<scope>-user-stories.csv がループ進行状態（story status）の唯一の正本
  （task.md の代替ではない・修正作業の実行追跡は rules/05 どおり tasks/*.md）。
  トリガー語: "story-test-loop" / "/story-test-loop" / "ストーリーテスト" / "全機能テスト" /
              "全数テスト" / "ユーザーストーリーでテスト" / "テストループ" / "回帰ループ" /
              "全機能を棚卸ししてテスト" / "full regression loop" / "user story loop"
  NOT for: 単一変更の動作確認 (→ verify / implementation-checklist), 失敗テストの修正のみ (→ test-fixing),
           ユニットテスト設計・TDD (→ test-fixing), 定期実行の器そのもの (→ /loop・本スキルは中身),
           探索的 PoC の検証 (→ research-isolation)
user-invocable: true
argument-hint: "[init [<path>]|test|fix|retest|status] (省略=台帳から現 phase 自動判定)"
---

# story-test-loop — 全機能ユーザーストーリー回帰ループ

## 概念（元ネタ原文）

> "/goal go over every single feature in this app create a user story with expected behaviour based on the code keep a single canonical spreadsheet tracking the features status
> - when done switch loop to testing every user story and documenting all errors
> - when done fix every logistical error or ux error
> - test every user behaviour again post fix"
> — @tomosman 2026-06-21 (概念は @MatthewBerman 由来)

核心 3 点:

1. **機能ではなくユーザーストーリー単位** — 「コードの現実装から導いた期待挙動」を明文化してからテストする
2. **単一正準台帳** — ループ進行状態は CSV 1 枚だけが持つ。セッションを跨いで再開可能な状態機械
3. **テストと修正のフェーズ分離** — テスト中は修正しない（文書化に徹する）→ まとめて修正 → 全数再テスト

## 台帳（ループ進行状態の唯一の正本）

- 台帳: `<scope>/tests/<scope-basename>-user-stories.csv`（rules/41 scope-prefix 既定に準拠）
- **scope 決定則**: 単一プロダクト repo なら git root。rules/41 型の monorepo（例 `prime_suite/prime_ad`
  のように配下ディレクトリが自前の CLAUDE.md / plan.md / tasks/ / tests/ を持つ）なら **sub-project
  ディレクトリを scope** にする（git root の 1 枚台帳に複数プロダクトを混載しない）。曖昧なら
  AskUserQuestion。`/story-test-loop init <path>` で明示指定も可。決定した scope は log md 冒頭に記録
- エラー詳細・Harness Map・Round 履歴: `<scope>/tests/<scope-basename>-story-loop-log.md`
- CSV 列（**読み書きは必ず python3 stdlib `csv` + temp ファイル→`os.replace` の原子的置換**。
  手の文字列連結・sed 編集・部分追記は禁止）:

```
id,area,story,expected,status,error_ref,evidence,last_run
```

- キー仕様: `id` = `<AREA>-<3桁連番>`（追記のみ・欠番再利用禁止）/ `error_ref` = log md 内アンカー
  `#e-<id>-r<round>` / `last_run` = ISO8601（Round 開始時刻との比較に使うため形式固定）/
  `evidence` = 実行コマンド + 観測出力の要点（またはスクショ参照）
- status 状態機械:

```
untested → pass | fail | blocked
fail     → (Phase 3 修正後) retest          ※ fail から pass へ直接書き換え禁止
retest   → (Phase 4 再テスト) pass | fail
pass     → (Phase 4 再実行で regression 検出) fail   ※ 再現手順を log md に文書化
blocked  → (依存解消時) untested
fail | blocked → (ユーザー明示承認のみ) wontfix（終端）
blocked  = 外部依存・認証等で実行不能。理由を error_ref に必記 + 代替検証の実行結果を evidence に必記
```

- **single-writer 原則**: 台帳への書き込みは main セッションのみ。SubAgent/Workflow は結果を構造化して
  返すだけ（mistakes.md「稼働中状態の別プロセス直書き」対策）
- **保全**: バッチ/Phase 境界ごとに台帳 + log md を明示パスで git commit（これが唯一のバックアップ）。
  破損検知時は git 履歴から復元 → 不可能な場合のみユーザー承認を得て再生成（「再生成禁止」の唯一の例外）
- **rules/05 との境界**: 台帳は story status の正本であって task.md の代替ではない。Phase 3 の修正が
  標準タスク規模（3 ファイル以上/複数セッション）なら rules/05 どおり `tasks/*.md` を起こし、
  task.md から台帳・log md へリンクする（同じ情報の重複記載禁止）

## Phase 自動判定（引数省略時・**上から順に優先評価**）

| # | 台帳の状態 | 現 Phase |
|---|---|---|
| 1 | 台帳ファイルなし | Phase 0+1 |
| 2 | log md に集計行のない open Round がある | Phase 4 継続（`last_run` < Round 開始時刻の行を再実行。fail が併存しても Round 完走が先） |
| 3 | untested が残っている | Phase 2 |
| 4 | retest がある | Phase 4 |
| 5 | fail がある | Phase 3 |
| 6 | 全行が pass / 理由+代替検証 evidence 付き blocked / ユーザー承認済み wontfix | 完了処理 |

## Phase 0: BOOTSTRAP（初回のみ）

1. **scope を決定**（§台帳の決定則。monorepo は sub-project 単位・曖昧なら AskUserQuestion）し、
   `<scope>/tests/` の有無を確認（なければ作成）
2. プロダクト型を判定し test harness を決めて log md 冒頭 `## Test Harness Map`（scope も明記）に記録:
   - BE/API → curl 疎通 + pytest（Docker 経由・ホスト pip 禁止）
   - FE → ブラウザ実操作（claude-in-chrome / Playwright MCP）+ コンソールエラー 0
   - CLI/スクリプト → 対象 project の Docker 環境経由で実行 + 出力検証（ホスト直接実行は stdlib-only の
     入出力検証に限る。scratchpad は入出力ファイルの置き場としてのみ使う）
   - データパイプライン → fixture dry-run + スキーマ/件数検証（実行は Docker 経由・同上）
   - cron/launchd/hook → ジョブが叩くスクリプト本体を実行検証 + 登録状態を `launchctl list` /
     hook 設定ファイルの存在確認で検証（スケジュール発火の待機は不要）
   - 秘密情報・本番データを踏む story は blocked 扱いにして代替検証を書き、その実行結果を evidence に残す
3. **既存台帳があれば再生成禁止**。そのまま resume する（例外は §台帳「保全」の破損時のみ）

## Phase 1: INVENTORY（全機能棚卸し → ストーリー化）

- 機能の列挙元 5 種: ① ルーティング/API エンドポイント ② UI ページ・操作 ③ CLI・scripts/ ④ cron/launchd・hooks ⑤ 設定駆動の挙動
- 1 機能 = 1 行以上。story は「<誰>が<操作>すると<期待挙動>」を**コードの現実装から**導く（願望仕様ではない）
- 大規模なら area ごとに SubAgent 並列列挙 → 台帳書き込みは main 単独
- 完了条件: 列挙元 5 種を全走査し「漏れゾーンはないか」を自問してから Phase 2 へ

## Phase 2: TEST（全数テスト・修正禁止）

- untested を上から順に harness で実行。**このフェーズでは直さない**（test-fixing / debugging-guide の
  修正フローもここでは発動しない → Phase 3 で）
- fail は再現手順 + 実観測を log md（アンカー `#e-<id>-r<round>`）に文書化して status=fail、次の story へ
- **evidence 必須**: 実行コマンド + 観測出力の要点（またはスクショ参照）。観測なしの pass 記入は禁止
  （mistakes.md「completion-by-self-report」対策）
- 重い出力は `~/.claude/docs/verification-filters.md` のフィルタで要点化。100 行超 raw は SubAgent に隔離
- 並列化は **harness 別**: curl/CLI/pipeline 系のみ 10 story/SubAgent 程度で fan-out 可（ultracode 時は
  Workflow）。**ブラウザ操作系は直列**（main または専任 SubAgent 1 体。並列が必要な時のみ
  `browser-automation-parallelization` 参照）。回収結果の台帳反映は main のみ

## Phase 3: FIX（まとめて修正）

- fail をロジック/動線エラーと UX エラーに分類し、優先度順に修正。既存則を厳守:
  - バッチ検証ループ（最大 3 タスク or 3 編集ごとに検証・hook 強制）
  - 3-Fix Limit（同一 story 3 回失敗で停止 → ブロッカープロトコル）
  - 修正が 3 ファイル以上/複数セッションに及ぶなら rules/05 どおり `tasks/<slug>.md` を起こす
    （台帳=テスト状態の SSoT / task.md=修正作業の実行追跡・Session Handoff、と役割分離）
  - 根本原因分析は `debugging-guide`、テスト修正法は `test-fixing`
- 修正した story は status=retest にする。**pass へ直接書き換えない**

## Phase 4: RETEST（再テスト・2 段構え）

- **Round 開始時に必ず先に** log md へ `## Round N — started: <ISO8601> — scope: targeted|full` を書く
  （集計行のない Round = 進行中。中断してもここから resume できる）
- **中間 Round（scope: targeted）**: retest 行 + 修正が触れたファイル/area と同じ area の story を再実行
- **最終 Round（scope: full）**: 完了処理の直前に 1 回だけ**全 story を再実行**（tomosman の
  「test every user behaviour again post fix」はここで担保。regression 検出のため pass 行も対象）
- regression で pass→fail が出たら再現手順を log md に文書化。**Round を完走してから** Phase 3 へ戻る
- Round 完走時に log md の同見出しへ集計（pass/fail/blocked 件数・終了時刻）を追記して close する

## 完了処理

1. 最終 Round（scope: full）が完走済みで、台帳の全行が pass / blocked / wontfix のいずれか
2. **blocked 行の全リスト（id・理由・代替検証 evidence）を AskUserQuestion でユーザーに提示し、
   明示承認を得るまで完了報告禁止**（wontfix も同様にユーザー判断のみ）
3. `implementation-checklist` STEP 1-4 を実行してから完了報告
4. ループ中に得た再発防止知見は `/save mistake` / repo の `tasks/lessons.md` へ

## 実行モード

- 単発: `/story-test-loop` を phase ごとに手動実行（既定）
- 常駐: `/loop /story-test-loop`（self-paced）。Codex の「/goal + loop」相当は「台帳 + 本スキル + /loop」で担う
- ultracode: Phase 2/4 の story 実行を Workflow fan-out（harness 別制約・single-writer 原則は不変）

## 適用の目安（全部・常時ではない）

コスト実測（2026-07-03 rohan/prime_ad 初適用）: 棚卸し=60〜115万 tokens/回、全数テスト=数百万 tokens+数時間
（session limit に当たり得る）。よって**フル回帰を常用しない**。使い分け:

| レベル | 何をやるか | いつ |
|---|---|---|
| 台帳だけ（Phase 0-1） | 棚卸し台帳を作る・増分更新 | **全プロダクト 1 回**。仕様の写像＝資産。安い |
| targeted（部分実行） | 変更した area の story だけテスト | 日常。既存の verify/バッチ検証の補完 |
| フル回帰（Phase 2-4 全数） | 全 story 実行→修正→full Round | **節目だけ**: 大規模リファクタ後・リリース前・品質不明の引き継ぎ時 |

- 台帳は untested が残ったまま中断・再開自由（状態機械）なので、全数テストも「1 日 1 area」の分割消化で成立する。一気に回す必要はない
- 日常の 1 変更の検証は既存則（verify / バッチ検証 / implementation-checklist）で足りる。本ループはそれを**置き換えない**（NOT for 参照）
- 休眠プロダクトは台帳保持のみで可。フル回帰は再開時に

## Rollout（各プロダクトへの適応）

グローバル配置（本ファイル + `/story-test-loop`）のため**プロダクト側の追加設定は不要**。
各プロダクト repo のセッションで `/story-test-loop init` を 1 回叩けば Phase 0-1 が走って台帳が生まれ、
以後どのセッションでも台帳から自動 resume する。
**完了後に機能が増えたら** Phase 1 を増分モードで再実行し、新規行のみ untested で追記する（既存行は不変）。

## Red Flags（このループの禁じ手）

- **対象プロダクトの実運用作業中に Phase 2/3 を回す**（2026-07-03 rohan 実 incident 由来）: dev-reload 構成
  （uvicorn --reload 等）ではコード編集が即 reload になり、ユーザーが走らせている実バッチ/生成を殺す・API を
  無応答化させる。開始前に「いま実作業が走っていないか」（実行中バッチ state・直近リクエストログ・ユーザー確認）を
  チェックし、走っていたら完了まで対象ディレクトリへの書込を一切しない
- **prod-write エンドポイントへの「ガード観測」実射**（2026-07-03 rohan 実 incident 由来）: 403/認可ガードの観測は、
  まず設定/env で**そのガードが当環境で有効かを確認してから**。処理され得る有効/空 body を送らない —
  「処理前に必ず 4xx になる入力」（Pydantic 型違反等）のみ許可。ガードが無効な環境では実行そのものが本番操作になる
- Phase 2 でその場修正を始める / test-fixing・debugging-guide の修正フローを Phase 2 中に発動する
- 観測 evidence なしで pass を記入する
- 台帳を複数プロセス/SubAgent が同時に書く
- 既存台帳があるのに作り直す（例外は破損時・ユーザー承認必須）
- fail → pass の直接遷移（retest を飛ばす）
- blocked が全体の 15% を超える → Phase 2 の時点で停止しユーザー相談（blocked 濫用による完了偽装防止）
- 最終 Round（full）を飛ばして完了報告する
