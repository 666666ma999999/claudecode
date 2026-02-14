---
metadata:
  author: masaaki-nagasawa
  version: 1.0.0
---

# ファイルエンコーディング変換スキル

name: file-encoding-converter
description: ファイル読み込み時に任意のエンコーディングをUTF-8に自動変換する実装パターン集。Shift_JIS、EUC-JP、ISO-2022-JP、UTF-16など日本語エンコーディングに対応。

## 使用タイミング

以下の場面で自動発動：
- ファイル読み込み機能の実装時
- テキストファイルのエンコーディング問題への対処
- 「文字化け」「エンコーディング」「Shift_JIS」などのキーワード

## 対応エンコーディング

| エンコーディング | 用途 |
|-----------------|------|
| UTF-8 | 現代の標準 |
| Shift_JIS | 古い日本語ファイル |
| CP932 (windows-31j) | Windows日本語（①②㈱など拡張文字対応） |
| EUC-JP | Unix/Linux日本語 |
| ISO-2022-JP | メール、古いシステム |
| UTF-16 LE/BE | Windows Unicode |

## 実装パターン

### フロントエンド（JavaScript）

```javascript
/**
 * ファイルをテキストとして読み込む（エンコーディング自動検出）
 * @param {File} file - 読み込むファイル
 * @returns {Promise<string>} UTF-8テキスト
 */
function readFileAsText(file) {
    return new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.onload = (e) => {
            const buffer = e.target.result;

            // 試行するエンコーディングのリスト（優先順）
            // windows-31j = CP932（①②㈱など拡張文字対応）
            const encodings = ['utf-8', 'windows-31j', 'shift_jis', 'euc-jp', 'iso-2022-jp'];

            for (const encoding of encodings) {
                try {
                    const decoder = new TextDecoder(encoding, { fatal: true });
                    const text = decoder.decode(buffer);

                    // 制御文字や不正な文字がないかチェック
                    if (!text.includes('\uFFFD') && !hasInvalidChars(text)) {
                        if (encoding !== 'utf-8') {
                            console.log(`📝 "${file.name}" を ${encoding} として読み込みました`);
                        }
                        resolve(text);
                        return;
                    }
                } catch (e) {
                    // このエンコーディングでは失敗、次を試す
                    continue;
                }
            }

            // 全て失敗した場合はUTF-8（fatal: false）で読み込む
            const fallbackDecoder = new TextDecoder('utf-8', { fatal: false });
            console.warn(`⚠️ "${file.name}" のエンコーディング検出に失敗、UTF-8として読み込み`);
            resolve(fallbackDecoder.decode(buffer));
        };
        reader.onerror = (e) => reject(e);
        reader.readAsArrayBuffer(file);
    });
}

/**
 * 不正な制御文字をチェック
 */
function hasInvalidChars(text) {
    // NULL文字や一部の制御文字（タブ、改行以外）
    return /[\x00-\x08\x0B\x0C\x0E-\x1F]/.test(text);
}
```

### バックエンド（Python）

```python
import chardet
from typing import Tuple

def read_file_as_utf8(file_path: str) -> Tuple[str, str]:
    """
    ファイルを読み込み、UTF-8テキストとして返す

    Args:
        file_path: ファイルパス

    Returns:
        Tuple[str, str]: (テキスト内容, 検出されたエンコーディング)
    """
    with open(file_path, 'rb') as f:
        raw_data = f.read()

    # chardetでエンコーディングを検出
    detected = chardet.detect(raw_data)
    encoding = detected['encoding'] or 'utf-8'
    confidence = detected['confidence']

    # 日本語エンコーディングの正規化
    encoding_map = {
        'SHIFT_JIS': 'cp932',
        'Windows-1252': 'cp932',  # 誤検出対策
        'ISO-8859-1': 'cp932',    # 誤検出対策
    }
    encoding = encoding_map.get(encoding.upper(), encoding)

    try:
        text = raw_data.decode(encoding)
    except (UnicodeDecodeError, LookupError):
        # フォールバック: 複数のエンコーディングを試行
        for enc in ['utf-8', 'cp932', 'euc-jp', 'iso-2022-jp']:
            try:
                text = raw_data.decode(enc)
                encoding = enc
                break
            except UnicodeDecodeError:
                continue
        else:
            # 全て失敗した場合はエラーを無視してUTF-8で読む
            text = raw_data.decode('utf-8', errors='replace')
            encoding = 'utf-8 (with errors)'

    return text, encoding


def convert_file_to_utf8(input_path: str, output_path: str = None) -> str:
    """
    ファイルをUTF-8に変換して保存

    Args:
        input_path: 入力ファイルパス
        output_path: 出力ファイルパス（Noneの場合は上書き）

    Returns:
        str: 検出されたエンコーディング
    """
    text, detected_encoding = read_file_as_utf8(input_path)

    output_path = output_path or input_path
    with open(output_path, 'w', encoding='utf-8', newline='\n') as f:
        f.write(text)

    return detected_encoding
```

### Base64エンコードされたコンテンツの処理（API用）

```python
import base64
import chardet

def decode_base64_text(content: str, is_base64: bool = False) -> str:
    """
    Base64エンコードされた可能性のあるテキストをデコード

    Args:
        content: コンテンツ（Base64またはプレーンテキスト）
        is_base64: Base64エンコードされているかどうか

    Returns:
        str: UTF-8テキスト
    """
    if not is_base64:
        return content

    try:
        raw_data = base64.b64decode(content)

        # エンコーディング検出
        detected = chardet.detect(raw_data)
        encoding = detected['encoding'] or 'utf-8'

        # Shift_JIS系の正規化
        if encoding.upper() in ('SHIFT_JIS', 'SHIFT-JIS'):
            encoding = 'cp932'

        return raw_data.decode(encoding)
    except Exception:
        return content  # 失敗したら元のまま返す
```

## 依存関係

### Python
```bash
pip install chardet
```

### JavaScript
- TextDecoder API（ブラウザ標準、IE非対応）

## 注意事項

1. **chardetの精度**: 短いテキストでは誤検出する可能性がある
2. **cp932 vs shift_jis**: Windowsの拡張文字（①②など）はcp932で対応
3. **BOM**: UTF-8 with BOMは自動で処理される
4. **改行コード**: CR+LF、LF、CRは別途正規化が必要な場合あり
