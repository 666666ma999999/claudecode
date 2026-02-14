---
name: fe-be-phase1-4
description: |
  FE/BE統合 Phase 1〜4の詳細実装パターン。定数統合、ロジック統合、バリデーション統合、ファイル名生成統合の具体的な実装手順とコード例を提供する。
  使用タイミング:
  (1) FE/BE間で重複している定数をBE側に一元化するとき（Phase 1: 定数統合）
  (2) FE/BEで同じ変換・パース処理を統合するとき（Phase 2: ロジック統合）
  (3) CamelCaseModelの導入・命名規則不整合の検出・修正をするとき
  (4) FE→BE間のデータ受け渡し（camelCase/snake_case変換、Order番号ずれ、セッション欠損）を修正するとき
  (5) 入力バリデーションをBE側に一元化するとき（Phase 3: バリデーション統合）
  (6) ファイル名・タイムスタンプ生成をBE側に統合するとき（Phase 4: ファイル名生成統合）
  キーワード: 定数統合, ロジック統合, バリデーション統合, ファイル名生成統合, CamelCaseModel, 同義語統一, Async Wrapper, snake_case変換, Order番号ずれ, Pre-STEP Validator
allowed-tools: "Read Glob Grep"
disable-model-invocation: true
license: proprietary
metadata:
  author: masaaki-nagasawa
  version: 1.1.0
---

## 統合アプローチ（Phase 1-4 概要）

| Phase | 目的 | キーパターン | 詳細 |
|-------|------|-------------|------|
| Phase 1 | 定数統合 | /api/config配信 | `references/phase1-constants.md` |
| Phase 2 | ロジック統合 | CamelCaseModel, Async Wrapper | `references/phase2-logic.md` |
| Phase 3 | バリデーション統合 | Pre-STEP Validator | `references/phase3-validation.md` |
| Phase 4 | ファイル名生成統合 | /api/timestamp/filename | `references/phase4-filename.md` |

---

### Phase 1: 定数統合

**目的**: FE/BE両方で定義されている定数をBE側で一元管理

```
[Before]
FE: const TYPES = { a: 1, b: 2 }
BE: TYPES = { "a": 1, "b": 2 }

[After]
BE: /api/config で定数を配信
FE: 起動時にAPIから取得、ローカル変数に格納
```

→ 詳細: `references/phase1-constants.md`

---

### Phase 2: ロジック統合

**目的**: FE/BE両方で実装されている変換・パース処理をBE側に統合

```
[Before]
FE: parseData(text) → { ... }
BE: parse_data(text) → { ... }

[After]
BE: POST /api/parse で処理を提供
FE: API優先、失敗時はローカルフォールバック
```

**サブセクション一覧**:

| ID | テーマ | 概要 |
|----|--------|------|
| 2-A | 同義語・重複変数名の統一 | FE/BEで同じ値に異なる名前がある問題を検出・統一 |
| 2-B | CamelCaseModel パターン | BE内部snake_case / APIレスポンスcamelCase統一 |
| 2-C | Async Wrapper パターン | FE同期関数→API呼び出し+フォールバック |
| 2-D | 標準実装パターン | BE router + FE API優先の基本形 |
| 2-E | 命名規則不整合の検出・修正 | CamelCaseModel導入後の残存snake_case参照を体系的に修正 |
| 2-F | FE→BEデータ受け渡し3大落とし穴 | camelCase/snake_case変換漏れ、Order番号ずれ、セッション欠損 |

→ 詳細: `references/phase2-logic.md`

---

### Phase 3: バリデーション統合

**目的**: 入力検証をBE側で一元化、エラー/警告の分離

```
[Before]
FE: if (!value) { alert('必須です'); return; }
BE: if not value: raise HTTPException(...)

[After]
BE: POST /api/validate でバリデーション結果を返す
FE: 登録前にAPIでチェック、結果に応じてUI表示
```

→ 詳細: `references/phase3-validation.md`

---

### Phase 4: ファイル名生成統合

**目的**: タイムスタンプやファイル名フォーマットをBE側で一元管理

```
[Before]
FE: formatTimestampLocal() でYYYYMMDD形式生成
BE: format_timestamp_for_filename() で同じ処理

[After]
BE: /api/timestamp/filename/{file_type} でファイル名を生成
FE: API結果をそのまま使用
```

→ 詳細: `references/phase4-filename.md`

---

## 詳細リファレンス

| ファイル | 内容 | 行数目安 |
|---------|------|---------|
| `references/phase1-constants.md` | 定数統合の実装パターン、ブラウザキャッシュの落とし穴 | ~35 |
| `references/phase2-logic.md` | ロジック統合の全サブセクション (2-A〜2-F) | ~340 |
| `references/phase3-validation.md` | バリデーション統合、Pre-STEP Validator | ~50 |
| `references/phase4-filename.md` | ファイル名生成統合の実装パターン | ~15 |
