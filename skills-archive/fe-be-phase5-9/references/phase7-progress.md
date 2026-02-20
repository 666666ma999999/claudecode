# Phase 7: 進捗追跡統合 - 詳細リファレンス

## 実装パターン

```python
# BE: progress.py
# インメモリセッションストア
_progress_store: Dict[str, SessionProgress] = {}

# ステップ定義（FE/BE共通）
STEP_DEFINITIONS = {
    1: {"name": "原稿生成", "timeout_ms": 300000, "estimated_ms": 60000},
    2: {"name": "メニュー登録", "timeout_ms": 120000, "estimated_ms": 30000},
    # ...
}

@router.get("/api/progress/{session_id}")
async def get_progress(session_id: str):
    session = _progress_store.get(session_id)
    return ProgressResponse(
        current_step=session.current_step,
        steps=[...],  # 各ステップの状態
        percentage=...,
        estimated_remaining_ms=...
    )
```

## 重要: FastAPIルート順序

```python
# 静的パスは動的パス（{session_id}）より先に定義
@router.get("/api/progress/definitions")  # ← 先に定義
async def get_definitions(): ...

@router.get("/api/progress/{session_id}")  # ← 後に定義
async def get_progress(session_id: str): ...
```
