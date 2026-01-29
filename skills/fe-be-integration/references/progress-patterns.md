# 進捗追跡パターン

## 1. セッションベース進捗管理

### データモデル

```python
from pydantic import BaseModel
from typing import Dict, Optional, List
from datetime import datetime

class StepProgress(BaseModel):
    """ステップ進捗"""
    step: int
    name: str
    status: str = "pending"  # pending, running, success, error
    started_at: Optional[str] = None
    completed_at: Optional[str] = None
    elapsed_ms: int = 0
    timeout_ms: Optional[int] = None
    message: str = ""
    error: str = ""

class SessionProgress(BaseModel):
    """セッション進捗"""
    session_id: str
    current_step: int = 0
    total_steps: int = 7
    status: str = "pending"  # pending, running, completed, error
    steps: Dict[int, StepProgress] = {}
    created_at: str = ""
    updated_at: str = ""
```

### ステップ定義

```python
# ステップ定義（FE/BE共通、BEで一元管理）
STEP_DEFINITIONS = {
    1: {
        "name": "原稿生成",
        "timeout_ms": 300000,      # 5分
        "estimated_ms": 60000      # 推定1分
    },
    2: {
        "name": "メニュー登録",
        "timeout_ms": 120000,      # 2分
        "estimated_ms": 30000      # 推定30秒
    },
    # ... 他のステップ
}
```

## 2. インメモリストア管理

### 基本構造

```python
from typing import Dict
from datetime import datetime, timedelta

# グローバル進捗ストア
_progress_store: Dict[str, SessionProgress] = {}

def create_session(session_id: str, total_steps: int = 7) -> SessionProgress:
    """セッションを作成"""
    now = datetime.now().isoformat()
    session = SessionProgress(
        session_id=session_id,
        total_steps=total_steps,
        status="pending",
        created_at=now,
        updated_at=now
    )
    _progress_store[session_id] = session
    return session

def get_session(session_id: str) -> Optional[SessionProgress]:
    """セッションを取得"""
    return _progress_store.get(session_id)
```

### クリーンアップ

```python
def cleanup_old_sessions(max_age_hours: int = 24):
    """古いセッションをクリーンアップ"""
    now = datetime.now()
    to_delete = []

    for session_id, session in _progress_store.items():
        created = datetime.fromisoformat(session.created_at)
        age_hours = (now - created).total_seconds() / 3600
        if age_hours > max_age_hours:
            to_delete.append(session_id)

    for session_id in to_delete:
        del _progress_store[session_id]

    return len(to_delete)
```

## 3. ステップ操作

### ステップ開始

```python
def start_step(session_id: str, step: int, timeout_ms: Optional[int] = None) -> Optional[StepProgress]:
    """ステップを開始"""
    if session_id not in _progress_store:
        create_session(session_id)

    session = _progress_store[session_id]
    definition = STEP_DEFINITIONS.get(step, {"name": f"STEP{step}", "timeout_ms": 120000})

    step_progress = StepProgress(
        step=step,
        name=definition["name"],
        status="running",
        started_at=datetime.now().isoformat(),
        timeout_ms=timeout_ms or definition.get("timeout_ms", 120000)
    )

    session.steps[step] = step_progress
    session.current_step = step
    session.status = "running"
    session.updated_at = datetime.now().isoformat()

    return step_progress
```

### ステップ完了

```python
def complete_step(
    session_id: str,
    step: int,
    success: bool = True,
    message: str = "",
    error: str = ""
) -> Optional[StepProgress]:
    """ステップを完了"""
    if session_id not in _progress_store:
        return None

    session = _progress_store[session_id]
    if step not in session.steps:
        return None

    step_progress = session.steps[step]
    now = datetime.now()

    step_progress.completed_at = now.isoformat()
    step_progress.status = "success" if success else "error"
    step_progress.message = message
    step_progress.error = error

    # 経過時間計算
    if step_progress.started_at:
        start = datetime.fromisoformat(step_progress.started_at)
        step_progress.elapsed_ms = int((now - start).total_seconds() * 1000)

    session.updated_at = now.isoformat()

    # 全ステップ完了チェック
    completed = [s for s in session.steps.values() if s.status == "success"]
    if len(completed) >= session.total_steps:
        session.status = "completed"

    return step_progress
```

## 4. APIエンドポイント

### 進捗取得

```python
@router.get("/api/progress/{session_id}")
async def get_progress(session_id: str) -> ProgressResponse:
    """セッションの進捗を取得"""
    session = get_session(session_id)

    if not session:
        return ProgressResponse(
            session_id=session_id,
            status="not_found",
            steps=[]
        )

    # ステップ情報をリスト化（未実行ステップも含む）
    steps_list = []
    for step_num in range(1, session.total_steps + 1):
        if step_num in session.steps:
            step = session.steps[step_num]
            steps_list.append(step.dict())
        else:
            # 未実行ステップはデフォルト値
            definition = STEP_DEFINITIONS.get(step_num, {})
            steps_list.append({
                "step": step_num,
                "name": definition.get("name", f"STEP{step_num}"),
                "status": "pending",
                "elapsed_ms": 0,
                "timeout_ms": definition.get("timeout_ms", 120000)
            })

    # 進捗率計算
    completed = len([s for s in session.steps.values() if s.status in ("success", "error")])
    percentage = int((completed / session.total_steps) * 100)

    # 残り時間推定
    estimated_remaining_ms = sum(
        STEP_DEFINITIONS.get(i, {"estimated_ms": 30000}).get("estimated_ms", 30000)
        for i in range(session.current_step + 1, session.total_steps + 1)
    )

    return ProgressResponse(
        session_id=session_id,
        current_step=session.current_step,
        total_steps=session.total_steps,
        status=session.status,
        steps=steps_list,
        percentage=percentage,
        estimated_remaining_ms=estimated_remaining_ms
    )
```

### 進捗更新（内部API）

```python
@router.post("/api/progress/{session_id}/update")
async def update_progress(session_id: str, request: UpdateProgressRequest):
    """進捗を更新（内部API）"""
    if request.action == "start":
        start_step(session_id, request.step, request.timeout_ms)
    elif request.action == "complete":
        complete_step(
            session_id,
            request.step,
            success=request.success,
            message=request.message,
            error=request.error
        )

    return {"success": True, "session_id": session_id}
```

## 5. フロントエンド連携

### 進捗ポーリング

```javascript
class ProgressTracker {
    constructor(sessionId, options = {}) {
        this.sessionId = sessionId;
        this.interval = options.interval || 2000;
        this.onUpdate = options.onUpdate || (() => {});
        this.onComplete = options.onComplete || (() => {});
        this.onError = options.onError || (() => {});
        this.polling = null;
    }

    async start() {
        this.polling = setInterval(() => this.poll(), this.interval);
        await this.poll();  // 即座に1回実行
    }

    stop() {
        if (this.polling) {
            clearInterval(this.polling);
            this.polling = null;
        }
    }

    async poll() {
        try {
            const response = await fetch(`/api/progress/${this.sessionId}`);
            const data = await response.json();

            this.onUpdate(data);

            if (data.status === 'completed') {
                this.stop();
                this.onComplete(data);
            } else if (data.status === 'error') {
                this.stop();
                this.onError(data);
            }
        } catch (e) {
            console.error('Progress poll error:', e);
        }
    }
}

// 使用例
const tracker = new ProgressTracker('session-123', {
    interval: 2000,
    onUpdate: (data) => {
        updateProgressUI(data.percentage, data.steps);
    },
    onComplete: (data) => {
        showNotification('処理が完了しました', 'success');
    }
});
tracker.start();
```

### 進捗表示UI

```javascript
function updateProgressUI(percentage, steps) {
    // プログレスバー更新
    const progressBar = document.getElementById('progress-bar');
    progressBar.style.width = `${percentage}%`;
    progressBar.textContent = `${percentage}%`;

    // ステップリスト更新
    const stepList = document.getElementById('step-list');
    stepList.innerHTML = steps.map(step => {
        const statusIcon = {
            'pending': '⏳',
            'running': '🔄',
            'success': '✅',
            'error': '❌'
        }[step.status] || '⏳';

        const elapsed = step.elapsed_ms ? `(${(step.elapsed_ms / 1000).toFixed(1)}s)` : '';

        return `<div class="step ${step.status}">
            ${statusIcon} ${step.name} ${elapsed}
        </div>`;
    }).join('');
}
```

## 6. 注意点

### メモリ管理
- インメモリストアはサーバー再起動で消失
- 長期保存が必要な場合はRedisやDBを使用
- 定期的なクリーンアップで肥大化を防止

### 並行性
- 複数リクエストからの同時更新に注意
- 必要に応じてロックを実装
```python
import asyncio
_lock = asyncio.Lock()

async def safe_update_step(session_id: str, step: int):
    async with _lock:
        return complete_step(session_id, step)
```

### タイムアウト検出
- クライアント側でタイムアウトを監視
```javascript
function checkTimeout(step) {
    if (step.status === 'running' && step.timeout_ms) {
        const elapsed = Date.now() - new Date(step.started_at).getTime();
        if (elapsed > step.timeout_ms) {
            return true;  // タイムアウト
        }
    }
    return false;
}
```
