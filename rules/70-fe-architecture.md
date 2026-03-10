# FE アーキテクチャルール

FEプロジェクト共通の設計原則。フレームワーク非依存（vanilla JS / React / Vue 全対象）。

## 適用条件

- `config/extensions.json` なし **かつ** `frontend/*.html` + JS あり → 本ルール全体を適用
- `config/extensions.json` あり → `fe-extension-pattern` スキルを優先。本ルールからは以下のみ補助適用:
  - Command/Query 分離（ext内のコード設計指針として）
  - Mediator原則（ext内のUI→API呼び出し設計として）
  - Single Pipeline（ext内で実行パスを増殖させない原則として）
  - ※ ext構造・テスト隔離・マニフェスト等はスキル側のルールが優先
- FE判定は BEの `config/extensions.yaml` 有無とは独立（判定フロー詳細は `30-routing.md` 参照）

## Command/Query 分離

### Command（副作用あり — オーケストレータ経由必須）
状態変更・Playwright起動・連鎖実行トリガー・DB書込を伴うAPI呼び出し。
UIイベントハンドラから直接 `fetch()` しない。既存の共通モジュール関数を経由する。

### Query（読み取り専用 — 直接fetchOK）
メタデータ取得・ログ復元・履歴表示など、副作用のないAPI呼び出し。
ただし中央コールバックの副作用処理（連鎖実行・UI状態遷移）を混在させない。

### 判定基準
以下を **全て** 満たす場合のみQuery:
1. read-only（サーバー状態を変更しない）
2. 連鎖実行トリガーなし
3. 中央コールバックの副作用処理を含まない

判断に迷う場合は **Command扱い**。

## Mediator原則（オーケストレータ経由）

- UI操作→API呼び出しは、既存の共通モジュール関数を経由する
- **禁止**: ボタンハンドラから直接 `fetch('/api/...')` → 独自result構築 → 手動コールバック呼び出し
- **理由**: オーケストレータはコールバック連鎖・UI更新・エラー処理を一元管理。バイパスすると副作用が欠落する

## Single Pipeline（実行パス一本化 — `20-code-quality.md` Dual-Path禁止のFE具体化）

- 同じ意図（チェック実行、課金テスト等）に対して複数の実行パスを作らない
- **禁止**: 既存パイプラインと同じ結果を得る別経路のfetchシーケンスを新設
- **必須**: 既存パイプラインを拡張（hook追加、パラメータ化）して再利用

## Callback Contract（コールバック契約遵守）

- 中央コールバック（`onCheckResult`, `onBatchComplete`等）の副作用を手動で再実装しない
- **禁止**: コールバックを呼ばずに同等のUI更新を個別に書くこと
- コールバックに新しい処理を追加する場合、既存コールバック内の適切な位置に追記

## Implementation Gate（実装前チェック — `20-code-quality.md` 変更時ゲートに加えて以下を確認）

Command系の処理を追加する際、以下を全て確認すること:

1. 追加する処理は Command か Query か分類したか
2. Command なら既存オーケストレータの拡張案を先に検討したか
3. 新規に `fetch('/api/...')` を UIハンドラへ書いていないか
4. 中央コールバックの副作用（進捗更新・連鎖実行・warning処理）を維持できるか

## Red Flags（FE固有 — 汎用Red Flagsは `20-code-quality.md` を参照）

以下のパターンを発見したら即修正:

- `addEventListener(... async () => { fetch('/api/...') ... })` で Command系API呼び出し
- `onCheckResult(...)` / `onBatchComplete(...)` の手動直接呼び出し（コールバック登録経由でない）
- 既存パイプラインと同目的の別API呼び出しシーケンス新設
- 同じ result オブジェクトを複数箇所で独立に構築

## API Surface Boundary

- FEから呼ぶ Command系API はオーケストレータ経由に限定
- 内部/デバッグ用エンドポイントを FEボタンから直接呼ばない
- 新規エンドポイント追加時: 副作用あり → オーケストレータ経由、デバッグ用 → 環境変数ガード必須
