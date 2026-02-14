# Phase 6: 正規表現パース統合 - 詳細リファレンス

## 実装パターン

```python
# BE: registration.py
@router.post("/api/fortune/extract-subtitles")
async def extract_subtitles_api(request: ExtractSubtitlesRequest):
    # 複数フォーマットに対応したパース
    # パターン1: ・小見出しN: タイトル
    # パターン2: N. タイトル（番号付きリスト）
    # パターン3: 【小見出し】セクション内のテキスト
    subtitles, subtitle_map, matched_pattern = _extract_subtitles_from_text(request.fortune_result)
    return ExtractSubtitlesResponse(
        success=True,
        subtitles=subtitles,
        matched_pattern=matched_pattern
    )
```
