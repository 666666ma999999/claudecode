# Phase 9: 構造化データ管理 - 詳細リファレンス

## いつ使うか

- 複数の関連データ（ID、タイトル、本文など）を紐付けて管理したい
- 文字列置換でデータ更新しているが、失敗することがある
- データ更新の成功/失敗を確実に検知したい

## データ構造設計パターン

```python
# BE: text_analysis.py
def parse_structured(text: str) -> Dict[str, Any]:
    """テキストを構造化データにパース"""
    return {
        "subtitles": [
            {
                "order": 1,
                "title": "小見出しタイトル",
                "codes": [
                    {"code": "01", "summary": None, "body": "本文..."},
                    {"code": "02", "summary": None, "body": "本文..."},
                ]
            }
        ],
        "opening": {"title": "...", "body": "..."},
        "closing": {"title": "...", "body": "..."}
    }

def build_text_from_structured(data: Dict[str, Any]) -> str:
    """構造化データからテキストを再構築"""
    lines = []
    for subtitle in data["subtitles"]:
        lines.append(f"[小見出し{subtitle['order']}]")
        lines.append(subtitle["title"])
        for code_data in subtitle["codes"]:
            if code_data["summary"]:
                lines.append(f"{code_data['code']}\t{code_data['summary']}\t{code_data['body']}")
            else:
                lines.append(f"{code_data['code']}\t{code_data['body']}")
    return '\n'.join(lines)
```

## FEでのフィールド更新パターン

```javascript
// FE: structured data management
let structuredData = null;  // メインデータ管理用

// 構造化パース（BE API）
async function parseStructuredAPI(text) {
    const response = await fetch('/api/parse-structured', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ content: text })
    });
    return (await response.json()).result;
}

// フィールド更新（文字列置換ではない）
function updateFieldInStructured(structured, subtitleOrder, fieldName, value) {
    const subtitle = structured.subtitles.find(s => s.order === subtitleOrder);
    if (!subtitle) {
        return { success: false, error: `小見出し${subtitleOrder}が見つかりません` };
    }

    // 直接フィールドを更新
    const errors = [];
    let updatedCount = 0;

    for (const codeData of subtitle.codes) {
        if (value[codeData.code]) {
            codeData[fieldName] = value[codeData.code];
            updatedCount++;
        } else {
            errors.push(`コード${codeData.code}の値が見つかりません`);
        }
    }

    return {
        success: updatedCount > 0,
        updatedCount,
        errors
    };
}

// テキスト再構築
function buildTextFromStructured(structured) {
    const lines = [];
    for (const subtitle of structured.subtitles) {
        lines.push(`[小見出し${subtitle.order}]`);
        lines.push(subtitle.title);
        for (const codeData of subtitle.codes) {
            if (codeData.summary) {
                lines.push(`${codeData.code}\t${codeData.summary}\t${codeData.body}`);
            } else {
                lines.push(`${codeData.code}\t${codeData.body}`);
            }
        }
    }
    return lines.join('\n');
}
```

## エラー検知と表示

```javascript
// フィールド更新時のエラー収集
const updateErrors = [];

for (const item of itemsToUpdate) {
    const result = updateFieldInStructured(structuredData, item.order, 'summary', item.values);
    if (!result.success) {
        updateErrors.push(`${item.order}: ${result.errors.join(', ')}`);
    }
}

// エラーがあればUI表示
if (updateErrors.length > 0) {
    showWarning(`更新エラー: ${updateErrors.length}件`, updateErrors);
}

// テキスト再構築（エラーの有無に関わらず）
finalText = buildTextFromStructured(structuredData);
```

## セッション保存

```javascript
// 構造化データとテキスト両方を保存
await updateSession({
    product: {
        manuscript: buildTextFromStructured(structuredData),  // テキスト版（後方互換）
        structured_manuscript: structuredData  // 構造化データ（メイン管理用）
    }
});
```

## BE側セッションモデル

```python
# BE: session.py
class ProductInfo(BaseModel):
    manuscript: Optional[str] = None  # テキスト版（後方互換）
    structured_manuscript: Optional[Dict[str, Any]] = None  # 構造化データ
    # ...
```

## 移行チェックリスト

- [ ] 既存の文字列置換箇所を特定
- [ ] データ構造を設計（どのフィールドを紐付けるか）
- [ ] BEにパース関数・再構築関数を実装
- [ ] FEにフィールド更新関数を実装
- [ ] エラー収集・表示ロジックを追加
- [ ] セッションモデルに構造化データフィールドを追加
- [ ] テスト：更新成功ケース、更新失敗ケース
