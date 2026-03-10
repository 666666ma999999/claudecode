# BE アーキテクチャルール

BEプロジェクト共通の設計原則。Python / Node.js / Go 全対象。

## 適用条件

- `backend/` または `src/` 配下にPythonサービスコードがある → 本ルール適用
- `config/extensions.yaml` あり → `be-extension-pattern` スキルと併用
- BE判定は FEの `config/extensions.json` 有無とは独立

## Single Mutation Pipeline（副作用経路一本化 — `20-code-quality.md` Dual-Path禁止のBE具体化）

- 同一ユースケースの状態変更は1つのservice/pipelineに集約する
- **禁止**: 既存pipelineと同目的の別route/service経路を追加すること
- **必須**: 既存pipelineを拡張（引数追加、hook追加、段階追加）して対応する

## Command/Query 分離（BE版）

### Command（副作用あり — 既存pipeline経由必須）
DB更新・外部API呼び出し・ファイル書き込み・セッション更新を伴う処理。

### Query（読み取り専用 — 直接実装OK）
データ取得・検索・集計など、副作用のない処理。

### 判定基準
以下を**全て**満たす場合のみQuery:
1. read-only（サーバー状態を変更しない）
2. 外部サービスへの書き込みなし
3. セッション/DB/ファイルの更新なし

判断に迷う場合は **Command扱い**。

## Canonical Owner

- 定数・業務判定・バリデーション・タイムアウト計算はownerモジュールを1つに固定
- **禁止**: owner以外で同等ロジックを再定義
- プロジェクトごとに `development.md` 等でCanonical Module Tableを定義すること

## 実装前ゲート

1. 対象ユースケースの既存 route/service を `rg` で探索したか
2. 既存pipeline拡張で対応可能か検討したか
3. 新規経路が必要な場合、不可避理由を明示したか
4. 追加後に旧経路との責務重複がないか確認したか

## Red Flags

以下のパターンを発見したら即修正:

- 同じ入力を受ける route が複数あり、副作用処理が分岐している
- 同名/同義の判定関数が複数ファイルに存在する
- 定数値が router, service, utils に散在する
- `re.compile()` や `re.sub()` がCanonical Owner以外で定義されている
- プロンプトファイル読み込みがCanonical Owner以外で実装されている
