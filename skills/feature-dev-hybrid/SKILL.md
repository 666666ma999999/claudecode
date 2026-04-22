---
name: feature-dev-hybrid
description: |
  feature-devプラグインのPhase 1-4（設計）と既存環境のPhase 5-7（実装・検証）を統合する
  ハイブリッドワークフロー。hook衝突なしでfeature-devの設計力と既存環境の品質保証を両立。
  キーワード: 機能開発, feature-dev, 設計比較, アーキテクチャ設計, 新機能ワークフロー
  NOT for: 1ファイル修正, バグ修正, リファクタリング（既存スキルを使用）
triggers:
  - 新機能開発
  - feature development
  - 機能設計
  - アーキテクチャ比較
  - 設計フェーズ
allowed-tools: [Read, Glob, Grep, Bash, Agent]
---

# Feature-Dev Hybrid Workflow

feature-dev プラグイン（Phase 1-4: 設計）+ 既存環境（Phase 5-7: 実装・検証）の統合ワークフロー。

## なぜハイブリッドか

| フェーズ | feature-dev の強み | 既存環境の強み | 採用 |
|---------|-------------------|--------------|------|
| 1-4 設計 | 3並列エージェント比較, 能動的要件解消 | — | **feature-dev** |
| 5 実装 | — | バッチ検証, SubAgent委託, Docker隔離 | **既存環境** |
| 6 検証 | — | /review + /review-security + checklist | **既存環境** |
| 7 完了 | — | task-progress + Session Handoff | **既存環境** |

## 実行手順

### STEP 1: feature-dev で設計（Phase 1-4）

```
/feature-dev:feature-dev <機能の説明>
```

feature-dev が以下を自動実行する（全て read-only、hook 衝突なし）:
- **Phase 1 Discovery**: 要件整理、TodoWrite 作成
- **Phase 2 Exploration**: code-explorer ×2-3 並列でコードベース解析
- **Phase 3 Clarification**: 曖昧さの能動的解消（CRITICAL: DO NOT SKIP）
- **Phase 4 Architecture**: code-architect ×2-3 並列で設計案比較

**Phase 4 完了時にユーザーが設計を選択したら、ここで feature-dev を停止する。**

### STEP 2: 設計引き継ぎ（Phase 4→5 ブリッジ）

Phase 4 の出力から以下を抽出し、task.md を作成する:

```markdown
## 機能概要
（Phase 1 の要件サマリー）

## 成功基準
（Phase 3 で確定した受け入れ条件）

## 選択した設計
（Phase 4 でユーザーが選択したアーキテクチャ）

### 設計の根拠
- 選択理由:
- 却下した代替案:
- トレードオフ:

## 実装計画
### 変更ファイル一覧
（code-architect の Implementation Map から抽出）

### ビルド順序
（code-architect の Build Sequence から抽出）

## Phase 2 で特定された重要ファイル
（code-explorer が返したキーファイル一覧）
```

### STEP 3: 既存ワークフローで実装（Phase 5）

task.md を入力として既存の Execution Strategy (Delivery モード) に移行:

1. **EnterPlanMode** で task.md の実装計画をレビュー
2. **ExitPlanMode** 後、SubAgent 委託ルールに従い実装
   - 変更2ファイル以上 → SubAgent 必須（Explore + Implement + Verify）
   - バッチ検証ループ: 3編集ごとに中間検証
   - Docker-Only 開発ルール適用
3. 全 hook が通常通り稼働（verify-step, block-host-installs 等）

### STEP 4: 既存ワークフローで検証（Phase 6）

実装完了後、以下を順次実行:

1. `/review` — Codex コードレビュー（2段階: spec compliance + code quality）
2. `/review-security` — セキュリティ差分監査（対象条件に該当する場合）
3. `implementation-checklist` スキル — STEP 1-4 完了ゲート

### STEP 5: 完了サマリー（Phase 7）

task.md の Session Handoff セクションを更新:

```markdown
## 完了サマリー
- 構築した機能:
- 主要な設計決定と根拠:
- 変更ファイル:
- 却下した代替設計:
- 残課題・次ステップ:
```

## feature-dev を直接使う場合との使い分け

| 状況 | 推奨 |
|------|------|
| 新機能で設計判断が重要 | **このハイブリッドワークフロー** |
| 小〜中規模の機能追加（設計は明確） | 既存の Delivery モード |
| 要件が曖昧で探索が必要 | `/prototype` → 固まったら Delivery |
| 既存コードの理解が目的 | `/feature-dev` Phase 1-2 のみ |
| 1ファイル修正・バグ修正 | 即答タスク（直接対応） |

## 注意事項

- feature-dev の Phase 5-7 は**使用しない**（hook 衝突回避）
- Phase 4 でユーザーが設計を選択した後、「ここから先は既存ワークフローで実装します」と宣言する
- feature-dev の code-reviewer エージェントは Phase 6 では使用しない（既存の /review が上位互換）
- feature-dev の TodoWrite は Phase 1-4 のトラッキングに使用し、Phase 5 以降は task.md に移行する
