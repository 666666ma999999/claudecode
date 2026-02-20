# 構造化データ管理パターン

## 概要

文字列置換によるデータ更新は、空白・改行・エンコーディングの違いで失敗しやすい。
構造化データ管理では、データをフィールドとして管理し、直接更新することで信頼性を向上させる。

## 問題パターン

### 文字列置換の失敗例

```javascript
// ❌ Bad: 文字列置換
const original = "01\t本文内容です";
const withSummary = original.replace("01\t本文", "01\tサマリー\t本文");

// 問題1: 空白の違い
// original = "01\t 本文内容です" (本文前にスペース)
// → replace失敗

// 問題2: 改行コードの違い
// original = "01\t本文内容です\r\n"
// → replace失敗

// 問題3: エラー検知困難
// replaceは失敗しても例外を投げない
if (withSummary === original) {
    // 置換失敗したが、どこが問題か特定困難
}
```

### 構造化データで解決

```javascript
// ✅ Good: フィールド更新
const structured = {
    codes: [
        { code: "01", summary: null, body: "本文内容です" }
    ]
};

// 直接フィールドを更新
structured.codes[0].summary = "サマリー";

// 失敗検知が明確
if (!structured.codes[0]) {
    throw new Error("コード01が見つかりません");
}
```

## 設計パターン

### 1. データ構造設計

関連するデータを1つのオブジェクトにまとめる：

```javascript
// 原稿データの構造化
const structuredManuscript = {
    subtitles: [
        {
            order: 1,                    // 順番
            title: "運命の出会い",        // 小見出しタイトル
            is_opening_closing: false,   // 冒頭/締めフラグ
            codes: [
                {
                    code: "01",          // コード番号
                    summary: null,       // サマリー（後から追加）
                    body: "本文..."      // 原稿本文
                },
                {
                    code: "02",
                    summary: null,
                    body: "本文..."
                }
            ]
        }
    ],
    opening: {                          // 冒頭（オプション）
        title: "【冒頭/あいさつ】",
        body: "冒頭テキスト..."
    },
    closing: {                          // 締め（オプション）
        title: "【締め/メッセージ】",
        body: "締めテキスト..."
    }
};
```

### 2. パース関数（テキスト → 構造化）

```python
# BE: text_analysis.py
def parse_manuscript_structured(text: str) -> Dict[str, Any]:
    """原稿テキストを構造化データにパース"""
    result = {
        "subtitles": [],
        "opening": None,
        "closing": None
    }

    lines = text.split('\n')
    current_subtitle = None
    current_codes = []

    for line in lines:
        # [小見出しN] パターン
        if re.match(r'^\[小見出し\d+\]$', line.strip()):
            if current_subtitle:
                save_subtitle(result, current_subtitle, current_codes)
            current_codes = []
            # 次の行がタイトル
            continue

        # コード行パターン: 01\t本文 or 01\tサマリー\t本文
        code_match = re.match(r'^(\d{2}[A-Z]?)\t(.*)$', line)
        if code_match:
            code = code_match.group(1)
            rest = code_match.group(2)
            parts = rest.split('\t', 1)

            if len(parts) == 2:
                # サマリー付き
                current_codes.append({
                    "code": code,
                    "summary": parts[0],
                    "body": parts[1]
                })
            else:
                # サマリーなし
                current_codes.append({
                    "code": code,
                    "summary": None,
                    "body": rest
                })

    return result
```

### 3. 再構築関数（構造化 → テキスト）

```python
# BE: text_analysis.py
def build_manuscript_text(structured: Dict[str, Any]) -> str:
    """構造化データからテキストを再構築"""
    lines = []

    # 冒頭
    if structured.get("opening"):
        lines.append(structured["opening"]["title"])
        lines.append(structured["opening"]["body"])
        lines.append("")

    # 小見出し
    for i, subtitle in enumerate(structured.get("subtitles", []), 1):
        lines.append(f"[小見出し{i}]")
        lines.append(subtitle["title"])
        lines.append("")

        for code_data in subtitle.get("codes", []):
            code = code_data["code"]
            summary = code_data.get("summary")
            body = code_data.get("body", "")

            if summary:
                lines.append(f"{code}\t{summary}\t{body}")
            else:
                lines.append(f"{code}\t{body}")

        lines.append("")

    # 締め
    if structured.get("closing"):
        lines.append(structured["closing"]["title"])
        lines.append(structured["closing"]["body"])

    return '\n'.join(lines)
```

### 4. フィールド更新関数

```javascript
// FE: フィールド更新（文字列置換ではない）
function updateStructuredWithSummary(structured, subtitleOrder, summaryText) {
    if (!structured || !structured.subtitles) {
        return { success: false, updatedCount: 0, errors: ['構造化データが未初期化'] };
    }

    // 対象の小見出しを検索
    const subtitle = structured.subtitles.find(s => s.order === subtitleOrder);
    if (!subtitle) {
        return { success: false, updatedCount: 0, errors: [`小見出し${subtitleOrder}が見つかりません`] };
    }

    // サマリーテキストをパース（01\tサマリー\t本文 形式）
    const summaryLines = summaryText.split('\n').filter(line => line.trim());
    const errors = [];
    let updatedCount = 0;

    for (const line of summaryLines) {
        const match = line.match(/^(\d{2}[A-Z]?)\t(.*)$/);
        if (!match) continue;

        const code = match[1];
        const rest = match[2];
        const parts = rest.split('\t', 1);

        // 対応するコードを検索して更新
        const codeData = subtitle.codes.find(c => c.code === code);
        if (codeData) {
            if (parts.length >= 1) {
                codeData.summary = parts[0];
                if (parts.length >= 2) {
                    codeData.body = parts.slice(1).join('\t');
                }
                updatedCount++;
            }
        } else {
            errors.push(`コード${code}が小見出し${subtitleOrder}に見つかりません`);
        }
    }

    return {
        success: updatedCount > 0,
        updatedCount,
        errors
    };
}
```

## エラーハンドリング

### エラー収集パターン

```javascript
// 複数の更新でエラーを収集
const summaryErrors = [];

for (const komi of komiTypesToProcess) {
    try {
        const result = await generateSummary(komi);
        const updateResult = updateStructuredWithSummary(
            structuredManuscript,
            komi.order,
            result.text
        );

        if (!updateResult.success) {
            summaryErrors.push(`${komi.order}: ${updateResult.errors.join(', ')}`);
        }
    } catch (error) {
        summaryErrors.push(`${komi.order}: ${error.message}`);
    }
}

// エラー表示
if (summaryErrors.length > 0) {
    console.error(`サマリー生成で ${summaryErrors.length}件のエラー:`, summaryErrors);
    showWarningUI(summaryErrors);
}
```

### UI警告表示

```javascript
// エラーがあってもUIに警告表示して処理継続
if (summaryErrors.length > 0) {
    const warningDiv = document.getElementById('warnings');
    warningDiv.innerHTML = `
        <div class="warning-box">
            ⚠️ サマリー埋め込みエラー: ${summaryErrors.length}件
            <br><small>${summaryErrors.slice(0, 3).join('<br>')}</small>
        </div>
    `;
    warningDiv.style.display = 'block';
}
```

## セッション永続化

### FE側

```javascript
// セッション保存時に両方を保存
await updateRegistrationSession({
    product: {
        // テキスト版（後方互換・表示用）
        manuscript: buildManuscriptFromStructured(structuredManuscript),
        // 構造化データ（メイン管理用）
        structured_manuscript: structuredManuscript
    }
});
```

### BE側モデル

```python
# BE: registration_session.py
class ProductInfo(BaseModel):
    """商品情報"""
    title: Optional[str] = None
    manuscript: Optional[str] = None  # テキスト版
    structured_manuscript: Optional[Dict[str, Any]] = None  # 構造化データ
    subtitles: List[SubtitleInfo] = Field(default_factory=list)
```

## 移行手順

1. **現状分析**: 文字列置換で更新している箇所を特定
2. **データ構造設計**: 紐付けるべきフィールドを決定
3. **BEパース関数**: テキスト → 構造化データ
4. **BE再構築関数**: 構造化データ → テキスト
5. **FE更新関数**: フィールド直接更新
6. **エラーハンドリング**: エラー収集・表示
7. **セッション拡張**: 構造化データフィールド追加
8. **テスト**: 成功・失敗ケース両方

## 適用例

### Rohanプロジェクト

- **対象**: 原稿へのサマリー埋め込み
- **Before**: `manuscript.replace(original, withSummary)`
- **After**: `structuredManuscript.subtitles[i].codes[j].summary = value`
- **効果**: 空白・改行による置換失敗を解消、エラー検知可能に
