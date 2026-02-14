# Phase 4: ファイル名生成統合 - 詳細

## 実装パターン

```python
# BE: config.py
FILENAME_PATTERNS = {
    "manuscript": "{prefix}_{timestamp}.txt",
    "csv": "{prefix}_{timestamp}.csv",
}

@router.get("/api/timestamp/filename/{file_type}")
async def get_download_filename(file_type: str, prefix: str = "download"):
    timestamp = format_timestamp_for_filename("datetime")
    pattern = FILENAME_PATTERNS.get(file_type, "{prefix}_{timestamp}.txt")
    return {"filename": pattern.format(prefix=prefix, timestamp=timestamp)}
```
