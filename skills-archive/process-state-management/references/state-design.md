# 状態設計パターン詳細

## コンテキスト設計原則

### データ紐付けの原則

**問題**: 関連するデータを別々に保存し、実行時に文字列操作で結合しようとすると失敗しやすい

```python
# ❌ Bad: 関連データが分離、実行時に文字列で紐付け
context = {
    "text": "01\t本文内容...",           # テキストだけ
    "metadata": {"01": "追加情報"}        # 別管理
}
# 実行時: text.replace("01\t本文", f"01\t{metadata['01']}\t本文")
# → 空白・改行の違いで失敗、エラー検知困難

# ✅ Good: 最初から構造的に紐付け
context = {
    "structured_data": {
        "items": [
            {"code": "01", "metadata": None, "body": "本文内容"}
        ]
    }
}
# 実行時: items[0]["metadata"] = "追加情報"
# → フィールド直接更新、失敗は例外で検知可能
```

### 設計スメルの検知

以下のパターンが見られたら、データモデルの再設計を検討：

| スメル | 症状 | 解決策 |
|--------|------|--------|
| 文字列置換で結合 | `replace()` で関連データを結合 | 構造化データで紐付け |
| 正規表現で抽出 | 実行時に `regex` でデータを取り出す | パース済みフィールドで保持 |
| IDで別オブジェクト参照 | `data1[id]` と `data2[id]` を突合 | 1オブジェクトにまとめる |
| 同期ずれ | 片方だけ更新されて不整合 | 単一データソースで管理 |

### 構造化コンテキストの例

```python
# ProcessRecordのcontext設計例
class ProcessContext(BaseModel):
    # ❌ 避けるべき: フラットで関連性が見えない
    # manuscript_text: str
    # subtitle_list: List[str]
    # summary_map: Dict[str, str]

    # ✅ 推奨: 構造的に紐付け
    structured_manuscript: Optional[Dict[str, Any]] = Field(
        default=None,
        description="構造化原稿データ（小見出し・コード・本文を紐付け）"
    )
    # structured_manuscript = {
    #     "subtitles": [
    #         {
    #             "order": 1,
    #             "title": "小見出し",
    #             "codes": [
    #                 {"code": "01", "summary": None, "body": "本文"}
    #             ]
    #         }
    #     ]
    # }
```

## ステップ間データ共有原則

### 問題: テキスト変換→再パースの罠

Step NからStep N+1へデータを渡す際、テキスト形式に変換して再パースすると情報が失われるリスクがある。

```
❌ Bad: テキスト経由
STEP 1: 構造化データ生成 → テキストに変換 → 保存
STEP 2: テキスト取得 → 再パース → 使用
問題: 空白・改行・フォーマットの違いでパース失敗

✅ Good: 構造化データ直接渡し
STEP 1: 構造化データ生成 → そのまま保存
STEP 2: 構造化データ取得 → そのまま使用
利点: データの一貫性保証、変換エラーなし
```

### 実装パターン

**セッションでの保存**:
```javascript
// STEP 1: 構造化データを保存
await updateSession({
    context: {
        structured_data: generatedData,  // 構造化データ（メイン）
        text_version: buildText(generatedData)  // テキスト版（表示用）
    }
});
```

**APIでの受け渡し**:
```python
# API: 構造化データを優先、テキストはフォールバック
class StepRequest(BaseModel):
    structured_data: Optional[Dict[str, Any]] = None  # 優先
    text_content: str = ""  # フォールバック

@router.post("/api/step2")
async def step2(request: StepRequest):
    if request.structured_data:
        # 構造化データから直接処理（推奨）
        data = request.structured_data
    elif request.text_content:
        # フォールバック: テキストをパース（後方互換）
        data = parse_text(request.text_content)
```

**FEでの送信**:
```javascript
// STEP 2: 構造化データを優先して送信
const response = await fetch('/api/step2', {
    method: 'POST',
    body: JSON.stringify({
        structured_data: sessionRecord.context.structured_data,  // 優先
        text_content: sessionRecord.context.text_version  // フォールバック
    })
});
```

### チェックリスト

- [ ] Step間でテキスト変換→再パースしている箇所を特定
- [ ] APIが構造化データを直接受け入れるよう拡張
- [ ] FEが構造化データを優先して送信
- [ ] テキスト版はフォールバック・表示用として残す

## STEP間共通データの永続化

### 問題

複数STEPで共通して使用するデータが、セッション中断→再開時に失われる。

**よくある失敗パターン:**
```javascript
// STEP 1で生成
let productTitle = extractedData.title;  // ローカル変数

// STEP 2-7で使用
// → セッション中断後、productTitleはundefined
```

### 解決策：グローバル変数 + セッション保存 + 復元

**1. グローバル変数を定義:**
```javascript
// ファイル先頭でグローバル変数を定義
let productTitle = '';       // 商品タイトル
let guideResult = null;      // 商品紹介文
let categoryCodeResult = null;  // カテゴリコード
```

**2. セッション保存時にグローバル変数を含める:**
```javascript
// STEP 1完了時
productTitle = extractedData.title;  // グローバル変数に保存

await updateSession({
    product: {
        title: productTitle,          // ← 必ず含める
        manuscript: generatedManuscript
    },
    distribution: {
        guide_text: guideResult?.guide_text,
        category_code: categoryCodeResult?.category_code
    }
});
```

**3. セッション復元時にグローバル変数を復元:**
```javascript
function restoreFromSession(record) {
    if (record.product?.title) {
        productTitle = record.product.title;  // ← グローバル変数を復元
    }
    if (record.distribution?.guide_text) {
        guideResult = { success: true, guide_text: record.distribution.guide_text };
    }
}
```

### STEP間共通データの設計例

| データ | 生成STEP | 使用STEP | 保存先 |
|--------|----------|----------|--------|
| productTitle | STEP 1 | STEP 2-7 | product.title |
| guide_text | STEP 1 | STEP 3 | distribution.guide_text |
| category_code | STEP 1 | STEP 3 | distribution.category_code |
| price | STEP 1 | STEP 3 | distribution.price |
| ppv_id | STEP 1 | STEP 2-7 | ids.ppv_id |
| menu_id | STEP 2 | STEP 3-7 | ids.menu_id |

### チェックリスト

- [ ] 複数STEPで使用するデータをリストアップ
- [ ] 各データにグローバル変数を用意
- [ ] セッション保存にすべてのグローバル変数を含める
- [ ] セッション復元でグローバル変数を復元
- [ ] 各STEPでグローバル変数を参照（ローカル変数にコピーしない）

## セッション復元時の注意点

### グローバル変数復元後はUI更新関数を呼ぶ

セッションからグローバル変数（例: `komiTypeResult`）を復元した場合、変数への代入だけではUIに反映されない。復元直後に対応する表示関数（例: `displayKomiTypes()`）を必ず呼び出すこと。

```javascript
// BAD: 変数復元のみ → UIに反映されない
komiTypeResult = { success: true, results: [...] };

// GOOD: 変数復元 + UI更新
komiTypeResult = { success: true, results: [...] };
displayKomiTypes(komiTypeResult);
```

### 派生フィールドはセッションに保存する

`KOMI_GENERATE_MODES[type].name`のようにマスターデータから導出される値は、セッション保存時に一緒に保存しておく。復元時にマスターデータの読み込みタイミングに依存しなくて済む。ただしフォールバックとしてマスターデータ参照も残す。

```javascript
// 保存時: 導出値も含める
{ komi_type: 'komi_special', komi_name: '特殊' }

// 復元時: 保存値優先、フォールバックでマスター参照
komiName: s.komi_name || KOMI_GENERATE_MODES[s.komi_type]?.name || '通常'
```

### Getter/Setter によるセッション即時同期パターン

**問題**: グローバル変数への直接代入では、セッション（`registrationRecord`）との同期が漏れやすい。セッション保存時に初めて同期するため、途中でページリロードすると中間状態が失われる。

**解決策**: getter/setter関数を通じてグローバル変数とregistrationRecordを同時に更新する。

```javascript
// Setter: グローバル変数 + registrationRecordを同時更新
function setMyResult(result) {
    myResult = result;  // グローバル変数更新
    // registrationRecordにも即時反映
    if (registrationRecord?.path) {
        registrationRecord.path.data = result?.field || null;
    }
    // nullクリア時はregistrationRecordもクリア
    if (!result && registrationRecord?.path) {
        registrationRecord.path.data = null;
    }
}

// Getter: registrationRecord優先、グローバル変数にフォールバック
function getMyResult() {
    if (registrationRecord?.path?.data) {
        return { success: true, field: registrationRecord.path.data };
    }
    return myResult;
}

// セッション復元時もsetterを使用
function restoreFromSession(record) {
    if (record.path?.data) {
        setMyResult({ success: true, field: record.path.data });
        displayMyResult(getMyResult());  // getterで取得→表示
    }
}
```

**setter/getter設計の3つの注意点**:

1. **Getterに`success`フィールドを含める**: display関数が`result.success`をチェックするパターンが多いため、registrationRecordから再構築する際に`success: true`を付与すること。
2. **Setterでnullクリア時にregistrationRecordもクリア**: `setMyResult(null)`で`registrationRecord.path.data`もnullにしないと、次回getterが古いデータを返してしまう。
3. **配列型データのclearer**: 配列変数（例: `komiRegeneratedResults`）には`clear*()`関数を用意し、registrationRecordの各エントリのフィールドもクリアする。

詳細な実装パターンは `rohan-ui-patterns` スキル セクション4-B を参照（rohanプロジェクト限定）。
