---
name: be-extension-pattern
description: |
  BEプロジェクトでエクステンションパターン（プラグインアーキテクチャ）に従った実装を指導するスキル。
  Python (FastAPI) / Node.js (Express/NestJS) / 言語非依存の原則とパターンを提供。
  BE新機能追加・APIエンドポイント追加・BEエクステンション作成時に使用。
  キーワード: BEエクステンション, HookPoint, AsyncEventBus, ExtensionRegistry, FastAPI, NestJS
  NOT for: FE実装, インフラ構成, DB設計（エクステンション構造に関わらない場合）
allowed-tools: "Read Glob Grep"
license: proprietary
metadata:
  category: guide-reference
  tags: [backend, architecture, python, nodejs, extension-pattern]
---

# be-extension-pattern

BEプロジェクトでエクステンションパターン（プラグインアーキテクチャ）に従った実装を指導するスキル。

## Read This First

このファイルには7原則・チートシート・チェックリストを記載。
言語別の実装コード・サンプルは references/ を参照。

タスクに応じて以下のファイルを読むこと:

- Python/FastAPI の実装 → `references/python-fastapi.md`
- Node.js/Express/NestJS の実装 → `references/nodejs-typescript.md`

references/ を読む前に、まずこのファイルの7原則を確認すること。

---

## 1. FE-BE コンセプトマッピング表

FEのエクステンションパターンとBEの対応概念を整理する。
FEスキル (`fe-extension-pattern`) を既に理解している場合、この表で対応関係を把握できる。

| FE概念 | BE対応概念 | 説明 |
|--------|-----------|------|
| MountPoint | HookPoint | コアの拡張ポイント。FEではUI配置、BEではリクエスト処理パイプラインへの注入 |
| EventBus | AsyncEventBus | ext間の非同期通信。BEではasyncio/EventEmitterベース |
| ExtensionManifest | ExtensionManifest | エクステンションのメタデータ。BEではrouter, models, handlers等を宣言 |
| Zustand Store | Extension-scoped State | ext内の状態管理。BEではext-scoped DB table / cache |
| config/extensions.json | config/extensions.yaml | 有効エクステンション一覧 |
| ESLint zones | import-linter / eslint-plugin-import | 隔離ルールの強制 |
| lazy import `() => import()` | Dynamic module loading | 遅延ロード |
| shared/ components | shared/ utilities | 共有ライブラリ |
| core/services | core/services | コアサービス（DB, Auth, Cache等） |
| core/types | core/interfaces | 共通型・インターフェース定義 |

---

## 2. 言語非依存7原則

どの言語・フレームワークでも守るべき普遍的な原則。

### 原則 1: 自己完結モジュール

各extはrouter/models/services/testsを内包する。ext単体で理解可能であること。
ext内のコードだけを読めば、そのextの機能を完全に把握できる状態を目指す。

### 原則 2: 単方向依存

ext → core/shared のみ許可。以下は全て禁止:
- ext → ext（他のextへの直接依存）
- shared → ext（共有ライブラリからextへの逆依存）
- core → ext（コアからextへの逆依存）

### 原則 3: レジストリ駆動

ExtensionRegistryがext一覧を管理する。動的load/unload可能。
ハードコードされたimportではなく、設定ファイルに基づく動的ロードを行う。

### 原則 4: 型付きEventBus

ext間通信は型安全なEventBusのみ。直接import禁止。
イベント名とペイロード型を事前に定義し、型チェックで安全性を担保する。

### 原則 5: ext-scoped永続化

DBテーブル/マイグレーションはext内に閉じる。coreテーブル変更禁止。
各extは自分のテーブルのみを管理し、他extやcoreのテーブルには触れない。

### 原則 6: Feature Flag

config/extensions.yamlでON/OFF。無効extはロードされない。
extを無効化するだけでアプリ全体が正常に動作すること。

### 原則 7: アーキテクチャテスト

import依存方向をCIで自動検証する。
Python: import-linter、Node.js: ESLint zones（import/no-restricted-paths）。

---

## 3. 10のルール（チートシート）

### Python版

| # | ルール | 違反例 | 正解 |
|---|--------|--------|------|
| 1 | `core/` は変更しない | core にヘルパー関数追加 | shared/ または ext 内に定義 |
| 2 | ext 間の直接 import 禁止 | `from extensions.billing import ...` | AsyncEventBus で通信 |
| 3 | 依存方向: ext → core/shared のみ | shared から ext を import | shared は ext を知らない |
| 4 | 各 ext に `__init__.py` (manifest) 必須 | manifest なしの ext | ExtensionManifest を定義 |
| 5 | ルーターは ext 内に閉じる | core の router に ext のエンドポイント追加 | ext 内 APIRouter |
| 6 | DBモデル/マイグレーションは ext 内 | core のマイグレーションに ext テーブル追加 | ext/migrations/ に配置 |
| 7 | テストは ext 内に閉じる | テストで他 ext の fixture を使用 | ext-scoped conftest.py |
| 8 | ext 間通信は AsyncEventBus のみ | 直接関数呼び出し | `event_bus.emit()` / `.on()` |
| 9 | `config/extensions.yaml` で ON/OFF | ハードコードされた import | enabled リストから削除で無効化 |
| 10 | import-linter で隔離を強制 | CI 設定なしでレビュー頼み | `lint-imports` CI ステップ |

### Node.js版

| # | ルール | 違反例 | 正解 |
|---|--------|--------|------|
| 1 | `core/` は変更しない | core に新しい interface 追加 | ext 内に型を定義 |
| 2 | ext 間の直接 import 禁止 | `import { X } from '../notification'` | EventBus で通信 |
| 3 | 依存方向: ext → core/shared のみ | shared から ext を import | shared は ext を知らない |
| 4 | 各 ext に `index.ts` (manifest) 必須 | manifest なしの ext | ExtensionManifest を export |
| 5 | ルーターは ext 内に閉じる | app.ts に ext のルーティング追加 | ext 内 Router |
| 6 | モデル/マイグレーションは ext 内 | 共通マイグレーションに ext テーブル追加 | ext/models/ + ext/migrations/ |
| 7 | テストは ext 内に閉じる | テストで他 ext の mock を共有 | ext-scoped test setup |
| 8 | ext 間通信は EventBus のみ | 直接 import して関数呼び出し | `eventBus.emit()` / `.on()` |
| 9 | `config/extensions.yaml` で ON/OFF | ハードコードされた require/import | enabled リストから削除で無効化 |
| 10 | ESLint zones で隔離を強制 | zone 設定なしでレビュー頼み | `eslint-plugin-import` zones |

---

## 4. 検証チェックリスト

### 隔離性チェック

- [ ] `extensions/{ext}/` 内からの import が `core/`, `shared/`, 自ext内のみ
- [ ] 他の ext ディレクトリからの import がない
- [ ] `core/` を変更していない
- [ ] Python: `lint-imports` でコントラクト違反なし
- [ ] Node.js: ESLint zones で違反なし

### Enable/Disable チェック

- [ ] `config/extensions.yaml` から ext を除外してもアプリ起動できる
- [ ] 他の ext が正常に動作する（依存していない）
- [ ] API エンドポイント、イベント購読、HookPoint が消える

### マニフェストチェック

- [ ] `id` がユニーク（kebab-case）
- [ ] `router` のプレフィックスが他と衝突しない
- [ ] `event_subscriptions` のイベント名が CoreEvents に定義済み
- [ ] `hook_handlers` の HookPoint 名が有効

### テストチェック

- [ ] ext 内のテストが独立して実行可能（`pytest extensions/{ext}/tests/`）
- [ ] 他の ext を有効にしなくてもテストがパスする
- [ ] ext-scoped conftest.py / test setup で fixture を定義
