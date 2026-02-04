---
name: gemini-image-generation
description: Gemini Native Image Generation (Nano Banana) のAPIパターン、対応モデル、パラメータ仕様、トラブルシューティング
---

# Gemini画像生成スキル

## SDK

```python
from google import genai
from google.genai import types

client = genai.Client(api_key=API_KEY)
```

**パッケージ**: `google-genai`（pip install google-genai）
**最低バージョン**: `>=1.47.0`（ImageConfig対応）
**注意**: `google-generativeai` とは異なる新SDK

## 対応モデル

### Nano Banana（テキスト+画像同時生成）
| モデル | 用途 | 状態 |
|--------|------|------|
| `gemini-2.5-flash-image` | 高速・高効率（推奨） | GA |
| `gemini-3-pro-image-preview` | 高品質・推論重視、Google Search grounding対応 | Preview |

### 非推奨モデル（使わないこと）
| モデル | 状態 |
|--------|------|
| `gemini-2.0-flash-exp` | 2026/3/31 廃止予定。画像生成が不安定 |
| `gemini-2.0-flash-preview-image-generation` | 旧プレビュー、2.5に置き換え済み |

### Imagen（画像専用生成）
| モデル | 用途 |
|--------|------|
| `imagen-4.0-generate-001` | 高品質画像生成 |

## 基本パターン

### Nano Banana（推奨）
```python
response = client.models.generate_content(
    model="gemini-2.5-flash-image",
    contents=[prompt_text],  # テキスト + 参考画像のリスト
    config=types.GenerateContentConfig(
        response_modalities=["TEXT", "IMAGE"],
        image_config=types.ImageConfig(
            aspect_ratio="1:1",
            # image_size は Python SDK v1.47.0 では未実装（JS SDKのみ対応）
        ),
    ),
)

# レスポンス処理
for part in response.candidates[0].content.parts:
    if part.inline_data and part.inline_data.mime_type.startswith("image/"):
        image_bytes = part.inline_data.data
    elif part.text:
        text_response = part.text
```

### Imagen
```python
response = client.models.generate_images(
    model="imagen-4.0-generate-001",
    prompt=prompt_text,
    config=types.GenerateImagesConfig(
        number_of_images=1,
        aspect_ratio="1:1",
    ),
)

for img in response.generated_images:
    image_bytes = img.image.image_bytes
```

## 参考画像の使い方

```python
from PIL import Image

# PIL.Image.open() で読み込んでcontentsに含める
ref_img = Image.open("reference.png")
contents = [ref_img, "この画像のスタイルで猫を描いて"]

# 最大14枚まで
```

**重要ルール:**
- 参考画像は最大14枚
- PIL.Image.open()で読み込む
- contentsリストにテキストと混在可能
- 参考画像を先、プロンプトテキストを後に配置するのが効果的

## アスペクト比（全10種）

`1:1`, `2:3`, `3:2`, `3:4`, `4:3`, `4:5`, `5:4`, `9:16`, `16:9`, `21:9`

## 画像サイズ

`1K`, `2K`, `4K`（大文字K必須。小文字はエラーになる）

## image_config の重要ポイント

- `types.ImageConfig` で `aspect_ratio` と `image_size` を同時指定可能
- `response_modalities` に `"IMAGE"` を含めないと画像が返らない
- Geminiは画像のみ返すことはできない。常にテキスト+画像のペアで返る

## エラーパターン・トラブルシューティング

### よくあるエラー
| エラー | 原因 | 対策 |
|--------|------|------|
| `SAFETY` ブロック | コンテンツポリシー違反 | プロンプトを調整 |
| `RECITATION` | 著作権関連 | 独自表現に変更 |
| 画像なしレスポンス | モデルがテキストのみ返した | プロンプトに「画像を生成して」を明示 |
| API quota exceeded | レート制限 | リトライ間隔を設ける |
| 旧モデルで画像が出ない | gemini-2.0-flash-expは画像生成不安定 | gemini-2.5-flash-image以降を使用 |

### デバッグ手順
1. response.candidates を確認
2. finish_reason を確認（STOP以外は問題あり）
3. parts の内容を確認（text/image の有無）

## 知見蓄積エリア

- 2026-02-04: gemini-2.0-flash-expでは画像生成が出ないケースあり。gemini-2.5-flash-image以降が必須
- 2026-02-04: image_configのimage_sizeは大文字K必須（"1K" OK, "1k" NG）
- 2026-02-04: APIエンドポイントではaspect_ratio/image_size/modelをサーバーサイドで許可値バリデーションすること。無効値をGemini APIに渡すと500エラーになる
- 2026-02-04: フロントエンドのフォールバック（API失敗時のハードコードモデルリスト）は最新モデルに合わせること。旧モデルが残ると生成失敗する
