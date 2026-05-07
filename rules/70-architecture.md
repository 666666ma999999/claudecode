# FE/BE アーキテクチャルール

FE (vanilla JS / React / Vue) と BE (Python / Node.js / Go) 共通の設計原則。
共通骨格 (Canonical Module / Dual-Path 禁止) は `20-code-quality.md` 参照。本ファイルは FE/BE 差分のみ。

## 適用条件

- **FE 適用**: `config/extensions.json` なし かつ `frontend/*.html`+JS / `src/` に `.tsx|.jsx|.vue` あり
  - `extensions.json` あり → `fe-extension-pattern` スキル優先、本ルールは Command/Query・Mediator・Single Pipeline のみ補助適用
- **BE 適用**: `backend/` または `src/` 配下、ルート直下に Python/Node.js/Go サービスコードあり
  - `extensions.yaml` あり → `be-extension-pattern` スキル併用

## Command/Query 分離（共通）

**Command（副作用あり — 既存経路必須）**: 状態変更・DB 書込・外部 API・ファイル書込・セッション更新・連鎖実行トリガー
**Query（読み取り専用 — 直接実装 OK）**: 取得・検索・集計・履歴表示

判定基準（全て満たす場合のみ Query。迷ったら **Command 扱い**）:
- read-only でサーバー状態を変更しない
- **FE**: 連鎖実行トリガーなし / 中央コールバック副作用を含まない
- **BE**: 外部サービス書込なし / セッション・DB・ファイル更新なし

## Single Pipeline / Mutation Pipeline（Dual-Path 禁止の具体化）

- 同一意図/ユースケースの実行経路は 1 本に集約
- **禁止**: 既存 pipeline と同目的の別 fetch シーケンス・別 route/service 経路の追加
- **必須**: 既存 pipeline を拡張（hook 追加・引数追加・段階追加・パラメータ化）

## FE 固有

### Mediator 原則
UI 操作 → API 呼び出しは既存共通モジュール経由。ボタンハンドラから直接 `fetch('/api/...')` → 独自 result 構築 → 手動コールバック禁止。
理由: オーケストレータがコールバック連鎖・UI 更新・エラー処理を一元管理。バイパスで副作用欠落。

### Callback Contract
中央コールバック (`onCheckResult`, `onBatchComplete` 等) の副作用を手動再実装禁止。新処理は既存コールバック内へ追記。

### Callback Migration Gate
直接実装 → コールバックベース共通関数移行時:
1. 共通関数の**成功・失敗・例外**3 パスでコールバックが呼ばれるか確認
2. 呼ばれないパスがあれば呼び出し元で戻り値（null/undefined）処理
3. ブラウザで実エラーケース発生確認（成功パスだけ不可）

### API Surface Boundary
Command 系 API はオーケストレータ経由限定。デバッグ用エンドポイントを FE ボタンから直接呼ばない。新規エンドポイント: 副作用あり → オーケストレータ、デバッグ → 環境変数ガード必須。

### Browser Verification（FE 変更後必須）
**Playwright 4 点セット**を順に実行:
1. `browser_navigate` — HTTP 200 系（タイムアウト不可）
2. `browser_wait_for` — セレクタ/テキストで描画完了待機（`sleep` 不可）
3. `browser_console_messages` — **error 0 件 かつ warning 0 件**
4. `browser_take_screenshot` — 変更箇所が写るスクショ保存

`mcp__playwright__*` / `mcp__playwright-mkb__*` / `mcp__plugin_playwright_playwright__*` いずれでも可。
**禁止**: AST/構文チェックのみで完了報告 / 1〜3 個のみで「確認済み」。

## BE 固有

### Canonical Owner（Canonical Module 原則の BE 具体化）
定数・業務判定・バリデーション・タイムアウト計算は owner モジュールに固定。owner 以外で同等ロジック再定義禁止。プロジェクトごとに `development.md` で Canonical Module Table を定義。

## 実装前ゲート（共通 — `20-code-quality.md` 変更時ゲートに加えて）

1. 追加処理を Command/Query 分類した
2. Command なら既存 pipeline/オーケストレータの拡張案を先に検討
3. FE: 新規 `fetch('/api/...')` を UI ハンドラへ書いていない / 中央コールバック副作用を維持
4. BE: 旧経路との責務重複なし

満たせない場合 → `10-git-and-execution-guard.md` ブロッカープロトコルで停止しユーザー確認。

## Red Flags（汎用は `20-code-quality.md` 参照）

**FE 固有**:
- `addEventListener(... async () => { fetch('/api/...') ... })` で Command 系
- `onCheckResult/onBatchComplete` の手動直接呼出（コールバック登録経由でない）
- 既存パイプラインと同目的の別 API 呼出シーケンス新設
- 同じ result オブジェクトを複数箇所で独立構築

**BE 固有**:
- 同入力を受ける route が複数あり副作用処理が分岐
- 同名/同義の判定関数が複数ファイルに存在
- 定数値が router/service/utils に散在
- `re.compile()`/`re.sub()` が Canonical Owner 以外で定義
- プロンプトファイル読込が Canonical Owner 以外で実装
