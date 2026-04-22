---
name: plan-adversarial-review
description: |
  Plan Mode中のアーキテクチャ判断に対する敵対的レビュー。
  opponent-reviewの計画特化版。Builder vs Scope Challenger で
  過剰設計・見落とし・よりシンプルな代替案を発見する。
  キーワード: プラン検証, 設計レビュー, リスク分析, 計画品質, 敵対的プラン
  NOT for: 実装後のコードレビュー（→ /simplify, /adversarial-review）、セキュリティ監査（→ security-twin-audit）
allowed-tools: [Read, Glob, Grep, Agent]
license: proprietary
metadata:
  author: masaaki-nagasawa
  version: 1.0.0
  category: quality-assurance
  tags: [plan, adversarial, architecture, risk]
---

# Plan Adversarial Review

## 概要

EnterPlanMode 中にアーキテクチャ判断がある場合、2つの対立する視点で計画を検証する。
opponent-review の計画フェーズ特化版。

## 発動条件

以下のいずれかに該当する場合、Plan Mode 中に使用を検討:
- 3ファイル以上の変更を伴う計画
- 「AかBか」の設計二択がある場合
- 新しいアーキテクチャパターンの導入
- 既存パターンからの逸脱が必要な場合

## ペア定義

| Agent A（Builder） | Agent B（Scope Challenger） |
|-------------------|---------------------------|
| 計画の実現可能性と価値を主張 | YAGNI違反・スコープ肥大を指摘 |
| 実装コスト・スケジュールの観点 | よりシンプルな代替案を提示 |
| 選択したアーキテクチャの利点 | 既存パターン（30-routing.md）で解決できないか検証 |

## 実行手順

### Step 1: 2つのSubAgentを並列起動

```
Agent A（Builder）:
「あなたはBuilderです。以下の計画について、実現可能性・価値・利点を主張してください。
ただし、弱点も認識している場合は正直に述べてください。
計画: [プラン内容]
論点: [判断が必要な内容]」

Agent B（Scope Challenger）:
「あなたはScope Challengerです。以下の計画について、以下の観点から分析してください:
1. YAGNI違反はないか（本当に今必要か）
2. よりシンプルな代替案はないか
3. 既存のスキル・パターンで解決できないか（30-routing.md参照）
4. スコープが肥大していないか
計画: [プラン内容]
論点: [判断が必要な内容]」
```

### Step 2: 統合レポート

```markdown
## Plan Adversarial Review Report

### 論点
[判断が必要だった内容]

### Builder の主張
- [要点]

### Scope Challenger の主張
- [要点]

### 合意点
- [両者が一致した点]

### 対立点と判断
| 論点 | Builder | Challenger | 判断 |
|------|---------|------------|------|

### プランへの反映
[統合結果に基づくプラン修正点]
```

### Step 3: プランに反映

対立点の判断結果をプランの Architecture セクションに記載。
却下した代替案も「却下理由」として残す（将来の参照用）。

## 簡易版（SubAgent 1つ）

コスト・時間の制約がある場合、1つのSubAgentに Devil's Advocate ロールを割り当て:

```
「以下の計画について、意図的に反対の立場から分析してください。
この計画の弱点・過剰設計・見落としを指摘し、よりシンプルな代替案があれば提示してください。
特に以下を重点的にチェック:
1. 既存スキル/パターンで解決できないか
2. ファイル数を減らせないか
3. 成功基準を達成するための最小実装は何か
計画: [プラン内容]」
```
