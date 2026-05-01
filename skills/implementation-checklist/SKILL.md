---
name: implementation-checklist
description: |
  コード修正・機能追加完了後の必須チェックリスト。サーバー再起動、Codexレビュー（2段階）、Sentryチェック、テスト同期確認、スキル化判断、セッション記録、完了報告のSTEP 1-4を順番に実行する。
  実装完了時・コードレビュー時・`/verify-step`コマンド実行時に自動発動。
  キーワード: 実装完了, チェックリスト, Codexレビュー, スキル化判断, STEP完了
  計画段階や実装開始前には使用しない。
allowed-tools: [Read, Glob, Grep, Bash, Agent]
license: proprietary
metadata:
  author: masaaki-nagasawa
  version: 1.0.0
  category: workflow-automation
  tags: [checklist, code-review, quality-assurance]
---

# 実装完了チェックリスト

コード修正・機能追加が完了したら、完了報告の前に以下を全て実行する。

**重要: 「ブラウザで確認してください」等のユーザー丸投げは禁止。** AI側で実行可能な検証を先に全て済ませること。
- BE: `curl` でAPIエンドポイント疎通 + `tail server.log` でエラー確認
- FE: Playwright MCPで `browser_navigate` → `browser_console_messages` → `browser_snapshot`
- 検証ツールが利用不可の場合: どのSTEPが何の不足で実行不能かを列挙し、ユーザーに報告（完了扱いにしない）

## 中間バッチ検証（実装中）vs 最終チェックリスト（実装完了後）

| | 中間バッチ検証 | 本チェックリスト |
|--|---------------|-----------------|
| **タイミング** | 各Batch終了後（3編集ごと） | 全実装完了後 |
| **発動** | verify-step-guard.sh が自動ブロック | implementation-checklist-pending.sh が警告 |
| **範囲** | fast_verify（最短検証のみ） | Final Verify（全体検証 + Codexレビュー + スキル化判断） |
| **解除** | 検証コマンド実行で自動リセット | `rm ~/.claude/state/implementation-checklist.pending` |

中間バッチ検証をパスしていても、本チェックリストは省略不可。

## STEP 1: サーバー再起動（該当する場合）

backend/main.py・フロントエンド・設定ファイルを編集した場合のみ実行。**確認なしで自動実行**。

```
1. プロジェクトのサーバー再起動スクリプトを実行
2. ヘルスチェックエンドポイントで正常応答を確認
3. 動作確認
```

**FE変更時の追加検証**（HTML/JS/CSS編集時は必須）:
- Playwright MCP等でブラウザを開き、変更したページをリロード
- JavaScriptコンソールエラーがゼロであることを確認
- 変更した機能を実際に操作して動作確認
- **構文チェック（AST/import/grep）だけでは検証完了としない**

**強制ルール**:
- 修正直後の再起動は省略不可。「後でまとめて」は禁止
- ヘルスチェックで200確認前に完了報告禁止
- テスト実行中にエラー → 即停止しブラウザ維持してユーザーに報告（自動修正・自動リトライ禁止）

## STEP 2: Codexレビュー（必須・1段統合）

**1 回の `mcp__codex__codex` 呼び出しで仕様準拠 + コード品質の両観点を取得する。** 従来の Stage 1/Stage 2 別呼び出しは廃止（トークン節約のため `/review` コマンドで 1 段統合済み）。

**スキップ条件**:
- 1〜2 ファイル / 100 行未満の小修正で、認証 / 認可 / 外部入力 / 秘密情報 / 外部 API 連携を含まないもの → **Codex レビュー不要**（`implementation-checklist-pending.sh` 側でも閾値ガード済み）
- 上記スキップ時は STEP 3 へ進んで OK

**通常実行**:
- `/review` コマンドを実行（推奨。デフォルトで 1 段統合プロンプト）
- もしくは `mcp__codex__codex` を直接呼び、以下を依頼:
  ```
  以下の変更を、仕様準拠とコード品質の両観点で 1 度にレビューせよ。
  ## 変更内容
  {git diff}
  ## A. 仕様準拠（task.md の成功基準との整合、入出力、エッジケース、パラメータ伝搬）
  ## B. コード品質（バグ・セキュリティ・パフォーマンス・可読性・テスト・設計）
  Critical Issues / Warnings / Suggestions / Good Points / 総合判定 の形式で 1 度に報告。
  ```
- Critical Issues に **[SPEC]** が含まれる → 修正してから再レビュー → STEP 1 に戻る
- Critical Issues に **[QUALITY]** のみ → 修正後の再レビューは任意

**パラメータチェーン検証**（パラメータ追加・変更時は必須）:
1. 追加パラメータの定義箇所（関数シグネチャ）を特定
2. 呼び出す全箇所をGrepで検索
3. 各呼び出し箇所でパラメータが実際に渡されているか確認
4. 値の出所（`self.xxx`、引数、定数）が正しいか確認
- Codex プロンプトに追記: 「追加・変更されたパラメータについて、定義→dispatcher→実メソッドの全チェーンで値が正しく伝搬しているか検証せよ。Optional パラメータでデフォルト値に隠れて未接続になっているケースを重点検出せよ。」

### STEP 2.3: Sentryリグレッションチェック（任意）

Sentry MCP有効時のみ: `list_issues`で新規エラー確認 → 検出時は即修正

### STEP 2.5: テストコード同期確認（該当する場合）

- `自動テストコード`のセレクタ・待機条件が修正内容と整合しているか確認
- 不整合発見時は即修正

## STEP 3: スキル化判断（必須・毎回実行・スキップ厳禁）

**重複防止**: `~/.claude/state/skill-review.done` が存在する場合、TaskCompleted hookで自動スキルレビュー済み。STEP 3.5へ進んでよい。

`skill-lifecycle-reference`スキルの「スキル化判断フロー」に従って判断・実行。

**チェックリスト（全て実行すること）**:
1. プロジェクトスキル検索: `project/.claude/skills/` 配下で関連キーワードをGrep
2. グローバルスキル検索: `~/.claude/skills/` 配下で関連キーワードをGrep
3. 該当スキルあり → 内容を読み、今回の変更で更新が必要か判断 → 必要なら更新
4. 該当スキルなし → Q1-Q3フローで新規スキル化を判断

**注意**: STEP 2（Codexレビュー）→ バージョン更新と流れるとSTEP 3をスキップしがち。STEP 2完了後に必ずSTEP 3を実行してからSTEP 4へ進むこと。

### STEP 3.5: セッション記録（30分以上の作業完了時）

教訓・知見の書き込み先スコープ判定:

| 知見の性質 | 書き込み先 |
|-----------|-----------|
| 全プロジェクト共通のワークフロー教訓 | `~/.claude/rules/` の該当ファイル |
| 全プロジェクト共通の技術パターン | `~/.claude/skills/` の該当スキル |
| 特定プロジェクト固有の知見 | プロジェクトMEMORY.md |

**判定基準**: 「この教訓は別プロジェクトでも同じか？」→ YES → グローバル環境。

### STEP 3.6: 改善キャプチャ判定

このセッションで定量的な改善があったか確認:
1. Token/Cost 削減（20%以上）
2. Speed 改善（30%以上）
3. 保守堅牢性 向上（LOC 10%減 or カバレッジ10pt増）
4. DX 向上（新スキル/hook/自動化でステップ50%減）

該当する場合: `/capture-improvement [改善の要約]` でMaterial Bankに登録。
該当しない場合: STEP 4へ進む。

## STEP 4: 完了報告

上記を全て実施後:
1. pending状態を解除: `rm -f ~/.claude/state/implementation-checklist.pending`
2. ユーザーへ報告（検証結果を含めること）
