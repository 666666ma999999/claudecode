---
name: fe-be-phase5-9
description: |
  FE/BE統合 Phase 5〜9の詳細実装パターン。ファイル検証統合、正規表現パース統合、進捗追跡統合、コードクリーンアップ、構造化データ管理の具体的な実装手順とコード例を提供する。
  使用タイミング:
  (1) 添付ファイルのバリデーション・タイプ検出をBE側に統合するとき（Phase 5: ファイル検証統合）
  (2) FE/BE間で重複している正規表現パース処理を統合するとき（Phase 6: 正規表現パース統合）
  (3) FE側の推定進捗をBE側の実測値ベースに置き換えるとき（Phase 7: 進捗追跡統合）
  (4) FE/BE統合後の不要コードを整理・削除するとき（Phase 8: コードクリーンアップ）
  (5) 文字列置換方式からフィールド操作方式へ移行するとき（Phase 9: 構造化データ管理）
  (6) フォールバック廃止（成熟段階）の判断・実装をするとき
  キーワード: ファイル検証統合, 正規表現パース統合, 進捗追跡統合, コードクリーンアップ, 構造化データ管理, ファイルタイプ検出, ダウンロード関数統合, フォールバック廃止, 文字列置換からの移行
disable-model-invocation: true
metadata:
  author: masaaki-nagasawa
  version: 1.0.0
---

# FE/BE統合 Phase 5〜9

このスキルはPhase 5（ファイル検証統合）からPhase 9（構造化データ管理）までの実装パターンを提供します。

## Phase概要

| Phase | 目的 | キーパターン | 詳細 |
|-------|------|-------------|------|
| Phase 5 | ファイル検証統合 | detect_file_type API | `references/phase5-file-validation.md` |
| Phase 6 | 正規表現パース統合 | extract-subtitles API | `references/phase6-regex-parsing.md` |
| Phase 7 | 進捗追跡統合 | /api/progress/{session_id} | `references/phase7-progress.md` |
| Phase 8 | コードクリーンアップ | 3段階削除, フォールバック廃止 | `references/phase8-cleanup.md` |
| Phase 9 | 構造化データ管理 | フィールド操作方式 | `references/phase9-structured-data.md` |

### Phase 5: ファイル検証統合

**目的**: 添付ファイルのバリデーションとタイプ検出をBE側に統合

```
[Before]
FE: validateAttachedFiles() でMIME判定・枚数チェック
BE: _filter_text_files() で同じ処理

[After]
BE: POST /api/attachments/validate でファイル検証
FE: API結果でUI更新、処理はBEに委譲
```

サブフェーズ: 5-A ファイルタイプ判定API、5-B ダウンロード関数統合

→ 詳細: `references/phase5-file-validation.md`

### Phase 6: 正規表現パース統合

**目的**: FE/BE両方で使用している正規表現パースをBE側に統合

```
[Before]
FE: 複数の正規表現で小見出し抽出
BE: extract_subtitles_from_fortune_result() で同じ処理

[After]
BE: POST /api/fortune/extract-subtitles でパース結果を返す
FE: API結果を使用、正規表現コードを削除
```

→ 詳細: `references/phase6-regex-parsing.md`

### Phase 7: 進捗追跡統合

**目的**: FE側の推定進捗をBE側の実測値ベースに置き換え

```
[Before]
FE: ProgressAnimator で推定時間表示（estimatedSecondsPerCandidate=40）
BE: StepExecutionTracker で実測時間を記録

[After]
BE: GET /api/progress/{session_id} で実測進捗を返す
FE: API進捗をそのまま表示
```

注意: FastAPIルート順序（静的パスを動的パスより先に定義）

→ 詳細: `references/phase7-progress.md`

### Phase 8: コードクリーンアップ

**目的**: 統合後に不要になったFEコードを整理

```
[Before]
FE: ローカル関数・ハードコード定数・フォールバック付きAPI呼び出し

[After]
Phase A: 定数ハードコード削除 → API読み込み必須化
Phase B: ローカル版関数を完全削除 → API版に統一
Phase C: フォールバック用コードの最小化・統合
Phase 8-D: フォールバック完全廃止（成熟段階）
```

→ 詳細: `references/phase8-cleanup.md`

### Phase 9: 構造化データ管理

**目的**: 文字列操作からフィールド操作への移行で、データ更新の信頼性向上

```
[Before - 文字列置換方式]
原稿テキスト: "01\t本文内容..."
サマリー追加: text.replace("01\t本文", "01\tサマリー\t本文")
問題: 空白・改行の違いで置換失敗、エラー検知困難

[After - 構造化データ方式]
構造化データ: { codes: [{ code: "01", summary: null, body: "本文" }] }
サマリー追加: codes[0].summary = "サマリー"
テキスト再構築: buildTextFromStructured(data)
利点: フィールド直接更新、失敗検知可能
```

含む: データ構造設計、FEフィールド更新、エラー検知、セッション保存

→ 詳細: `references/phase9-structured-data.md`

## 関連スキル

- **fe-be-phase0-4**: Phase 0-4（定数統合、ロジック統合、バリデーション統合、ファイル名生成統合）
- **coding-standards**: 言語別命名規則、CamelCaseModelの基本説明
- **process-state-management**: 複数ステップのプロセス管理、ログ記録、中断・再開機能
- **text-parser-patterns**: テキストパーサー実装、エッジケース処理、デバッグ手法
- **playwright-browser-automation**: ブラウザ自動化、フォームフィールド調査

## 詳細リファレンス

| ファイル | 内容 |
|---------|------|
| `references/phase5-file-validation.md` | Phase 5: 基本実装、5-A ファイルタイプ判定API、5-B ダウンロード関数統合 |
| `references/phase6-regex-parsing.md` | Phase 6: extract-subtitles API実装パターン |
| `references/phase7-progress.md` | Phase 7: 進捗API実装パターン、FastAPIルート順序 |
| `references/phase8-cleanup.md` | Phase 8: 3段階クリーンアップ、8-D フォールバック廃止、移行チェックリスト |
| `references/phase9-structured-data.md` | Phase 9: データ構造設計、FEフィールド更新、エラー検知、セッション保存、移行チェックリスト |
