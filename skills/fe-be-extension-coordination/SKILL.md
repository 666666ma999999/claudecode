---
name: fe-be-extension-coordination
description: |
  FE+BE分離型リポジトリプロジェクトでエクステンション間の調整を指導するスキル。
  共有エクステンション設定、APIコントラクト、一貫したExtension ID、デプロイ協調、
  イベントコントラクト共有のガイド。FE+BE連携・APIコントラクト設計時に使用。
  キーワード: FE+BE連携, APIコントラクト, 共有Extension ID, デプロイ協調, イベントコントラクト
  NOT for: FE単体実装, BE単体実装, インフラ構成
allowed-tools: [Read, Glob, Grep]
license: proprietary
metadata:
  category: guide-reference
  tags: [fullstack, architecture, coordination, api-contract]
---

# FE+BE Extension Coordination Guide

## 1. 共有エクステンション設定

FEとBEで共有するエクステンション定義を一元管理するnpmパッケージ（またはgit submodule）。

詳細（ディレクトリ構成・EXTENSION_IDS 定数・extensions.yaml・ランタイム設定サービス）→ `references/shared-extension-config.md`

## 2. APIコントラクト調整

### OpenAPI spec per extension

各エクステンションが自身のOpenAPI specを持つ。
詳細（OpenAPI spec 例・CI型生成ワークフロー）→ `references/api-contract-examples.md`

## 3. 一貫したExtension ID

### 命名規則

| 項目 | ルール | 例 |
|------|--------|-----|
| Extension ID | kebab-case | `user-management` |
| FE ディレクトリ | kebab-case | `extensions/user-management/` |
| BE ディレクトリ (Python) | snake_case | `extensions/user_management/` |
| BE ディレクトリ (Node.js) | kebab-case | `extensions/user-management/` |
| API prefix | kebab-case | `/api/user-management/` |
| Event prefix | kebab-case + colon | `user:created` |
| DB table prefix | snake_case | `ext_user_management_*` |
| EXTENSION_IDS key | UPPER_SNAKE_CASE | `USER_MANAGEMENT` |

詳細（CI検証スクリプト）→ `references/extension-id-validation.md`

## 4. デプロイ協調

### BE-first for breaking changes

```
1. BE: 新エンドポイント追加（後方互換）→ デプロイ
2. FE: 新エンドポイントに切り替え → デプロイ
3. BE: 旧エンドポイント廃止 → デプロイ
```

詳細（Compatibility Matrix・CI Pipeline 連携）→ `references/deploy-coordination-examples.md`

## 5. イベントコントラクト共有

詳細（SharedEvents interface・FE/BEでの使用例）→ `references/event-contract-examples.md`

## 6. 10のルール

| # | ルール | 違反例 | 正解 |
|---|--------|--------|------|
| 1 | Extension IDは `extension-contracts` で一元管理 | FE/BEで別々にID定義 | EXTENSION_IDS 定数から参照 |
| 2 | extensions.yamlがSSoT | FEとBEで別のconfig | 1つのyamlから両方生成 |
| 3 | APIコントラクトはOpenAPI specで定義 | 口頭合意やドキュメントのみ | per-ext openapi.yaml |
| 4 | FE向け型はCI自動生成 | 手動で型を同期 | openapi-typescript で自動生成 |
| 5 | イベント型は `SharedEvents` で共有 | FE/BEで別々にイベント型定義 | extension-contracts に定義 |
| 6 | Breaking changeはBE-first | FE/BE同時デプロイ前提 | 後方互換 → FE切替 → 旧API廃止 |
| 7 | Python BE dirはsnake_case、他はkebab-case | 命名不統一 | 変換テーブル参照 |
| 8 | DB table prefixは `ext_{snake_id}_` | ext間でテーブル名衝突 | `ext_user_management_profiles` |
| 9 | 各ext PRにFE/BE影響チェック | BE変更がFE未考慮 | PR templateに影響チェック欄 |
| 10 | Compatibility matrixで互換性管理 | バージョン依存が不明 | compatibility.yaml 更新 |
