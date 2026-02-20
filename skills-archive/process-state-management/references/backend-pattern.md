# Backend Implementation Pattern

## 1. Pydanticモデル定義

```python
from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any
from datetime import datetime
from enum import Enum
import uuid

class ProcessStatus(str, Enum):
    PENDING = "pending"
    RUNNING = "running"
    COMPLETED = "completed"
    ERROR = "error"
    INTERRUPTED = "interrupted"

class StepStatus(str, Enum):
    PENDING = "pending"
    RUNNING = "running"
    SUCCESS = "success"
    ERROR = "error"
    SKIPPED = "skipped"

class LogLevel(str, Enum):
    DEBUG = "debug"
    INFO = "info"
    WARN = "warn"
    ERROR = "error"

class ErrorInfo(BaseModel):
    code: str                           # エラーコード（TIMEOUT, NETWORK_ERROR等）
    message: str                        # エラーメッセージ
    details: Optional[Dict[str, Any]] = None  # 詳細情報
    stack_trace: Optional[str] = None   # スタックトレース（開発用）
    recoverable: bool = True            # 再開可能か
    suggested_action: Optional[str] = None  # 推奨アクション

class LogEntry(BaseModel):
    timestamp: str = Field(default_factory=lambda: datetime.now().isoformat())
    level: LogLevel = LogLevel.INFO
    step: Optional[int] = None          # 関連ステップ
    message: str
    data: Optional[Dict[str, Any]] = None

class StepProgress(BaseModel):
    step: int
    name: str
    status: StepStatus = StepStatus.PENDING
    started_at: Optional[str] = None
    completed_at: Optional[str] = None
    result: Optional[Dict[str, Any]] = None
    error: Optional[ErrorInfo] = None
    retry_count: int = 0

class ProcessRecord(BaseModel):
    record_id: str = Field(default_factory=lambda: f"proc_{datetime.now().strftime('%Y%m%d%H%M%S')}_{uuid.uuid4().hex[:8]}")
    created_at: str = Field(default_factory=lambda: datetime.now().isoformat())
    updated_at: str = Field(default_factory=lambda: datetime.now().isoformat())
    status: ProcessStatus = ProcessStatus.PENDING
    current_step: int = 0
    steps: List[StepProgress] = []
    context: Dict[str, Any] = {}        # プロジェクト固有のコンテキスト
    logs: List[LogEntry] = []
    interrupt_reason: Optional[str] = None

# リクエスト/レスポンスモデル
class CreateProcessRequest(BaseModel):
    context: Optional[Dict[str, Any]] = {}

class UpdateStepRequest(BaseModel):
    step: int
    status: StepStatus
    result: Optional[Dict[str, Any]] = None
    error: Optional[ErrorInfo] = None

class AddLogRequest(BaseModel):
    level: LogLevel = LogLevel.INFO
    step: Optional[int] = None
    message: str
    data: Optional[Dict[str, Any]] = None

class InterruptRequest(BaseModel):
    reason: str
    error_code: Optional[str] = None
```

## 2. ProcessStore クラス

```python
import json
import os
from pathlib import Path
from typing import Dict, Optional, List
from datetime import datetime

class ProcessStore:
    """プロセス状態の管理（メモリ + ファイル永続化）"""

    def __init__(self, data_dir: str, step_definitions: Dict[int, Dict]):
        self.data_dir = Path(data_dir) / "processes"
        self.data_dir.mkdir(parents=True, exist_ok=True)
        self.step_definitions = step_definitions
        self._store: Dict[str, ProcessRecord] = {}
        self._load_from_disk()

    def _load_from_disk(self):
        """起動時にディスクから読み込み"""
        for file in self.data_dir.glob("*.json"):
            try:
                with open(file) as f:
                    data = json.load(f)
                    record = ProcessRecord(**data)
                    self._store[record.record_id] = record
            except Exception as e:
                print(f"Warning: Failed to load {file}: {e}")

    def _save_to_disk(self, record: ProcessRecord):
        """レコードをディスクに保存"""
        file_path = self.data_dir / f"{record.record_id}.json"
        with open(file_path, "w") as f:
            json.dump(record.dict(), f, ensure_ascii=False, indent=2)

    def create(self, context: Dict = None) -> ProcessRecord:
        """新規プロセス作成"""
        # ステップ定義から初期ステップリストを生成
        steps = [
            StepProgress(step=step_num, name=step_def["name"])
            for step_num, step_def in sorted(self.step_definitions.items())
        ]

        record = ProcessRecord(
            steps=steps,
            context=context or {},
            current_step=1
        )

        # 初期ログ追加
        record.logs.append(LogEntry(
            level=LogLevel.INFO,
            message="プロセス開始",
            data={"step_count": len(steps)}
        ))

        self._store[record.record_id] = record
        self._save_to_disk(record)
        return record

    def get(self, record_id: str) -> Optional[ProcessRecord]:
        """レコード取得"""
        return self._store.get(record_id)

    def update_context(self, record_id: str, partial_context: Dict) -> Optional[ProcessRecord]:
        """コンテキストを部分更新"""
        record = self._store.get(record_id)
        if not record:
            return None

        # ネストされた辞書のマージ
        def deep_merge(base: Dict, update: Dict) -> Dict:
            for key, value in update.items():
                if key in base and isinstance(base[key], dict) and isinstance(value, dict):
                    deep_merge(base[key], value)
                else:
                    base[key] = value
            return base

        deep_merge(record.context, partial_context)
        record.updated_at = datetime.now().isoformat()
        self._save_to_disk(record)
        return record

    def update_step(self, record_id: str, step: int, status: StepStatus,
                    result: Dict = None, error: ErrorInfo = None) -> Optional[ProcessRecord]:
        """ステップ状態を更新"""
        record = self._store.get(record_id)
        if not record:
            return None

        # 該当ステップを検索
        step_progress = next((s for s in record.steps if s.step == step), None)
        if not step_progress:
            return None

        now = datetime.now().isoformat()
        step_progress.status = status

        if status == StepStatus.RUNNING:
            step_progress.started_at = now
            record.status = ProcessStatus.RUNNING
            record.current_step = step
        elif status == StepStatus.SUCCESS:
            step_progress.completed_at = now
            step_progress.result = result
            # 全ステップ完了チェック
            if all(s.status in [StepStatus.SUCCESS, StepStatus.SKIPPED] for s in record.steps):
                record.status = ProcessStatus.COMPLETED
        elif status == StepStatus.ERROR:
            step_progress.completed_at = now
            step_progress.error = error
            step_progress.retry_count += 1
            record.status = ProcessStatus.ERROR
            record.interrupt_reason = error.message if error else "Unknown error"

        # ログ追加
        log_level = LogLevel.INFO if status == StepStatus.SUCCESS else (
            LogLevel.ERROR if status == StepStatus.ERROR else LogLevel.INFO
        )
        record.logs.append(LogEntry(
            level=log_level,
            step=step,
            message=f"STEP {step} ({step_progress.name}): {status.value}",
            data={"result": result} if result else ({"error": error.dict()} if error else None)
        ))

        record.updated_at = now
        self._save_to_disk(record)
        return record

    def add_log(self, record_id: str, level: LogLevel, message: str,
                step: int = None, data: Dict = None) -> Optional[ProcessRecord]:
        """ログを追加"""
        record = self._store.get(record_id)
        if not record:
            return None

        record.logs.append(LogEntry(
            level=level,
            step=step,
            message=message,
            data=data
        ))
        record.updated_at = datetime.now().isoformat()
        self._save_to_disk(record)
        return record

    def interrupt(self, record_id: str, reason: str, error_code: str = None) -> Optional[ProcessRecord]:
        """プロセスを中断"""
        record = self._store.get(record_id)
        if not record:
            return None

        record.status = ProcessStatus.INTERRUPTED
        record.interrupt_reason = reason
        record.updated_at = datetime.now().isoformat()

        # 実行中のステップをエラーに
        for step in record.steps:
            if step.status == StepStatus.RUNNING:
                step.status = StepStatus.ERROR
                step.error = ErrorInfo(
                    code=error_code or "INTERRUPTED",
                    message=reason,
                    recoverable=True
                )

        record.logs.append(LogEntry(
            level=LogLevel.WARN,
            message=f"プロセス中断: {reason}",
            data={"error_code": error_code}
        ))

        self._save_to_disk(record)
        return record

    def get_incomplete(self) -> List[Dict]:
        """未完了プロセス一覧"""
        incomplete = []
        for record in self._store.values():
            if record.status in [ProcessStatus.RUNNING, ProcessStatus.ERROR, ProcessStatus.INTERRUPTED]:
                # 最新のエラーステップを取得
                error_step = next(
                    (s for s in reversed(record.steps) if s.status == StepStatus.ERROR),
                    None
                )
                incomplete.append({
                    "record_id": record.record_id,
                    "status": record.status.value,
                    "current_step": record.current_step,
                    "current_step_name": self.step_definitions.get(record.current_step, {}).get("name", ""),
                    "interrupt_reason": record.interrupt_reason,
                    "error_info": error_step.error.dict() if error_step and error_step.error else None,
                    "created_at": record.created_at,
                    "updated_at": record.updated_at,
                    "context_summary": self._get_context_summary(record.context)
                })
        return sorted(incomplete, key=lambda x: x["updated_at"], reverse=True)

    def _get_context_summary(self, context: Dict) -> Dict:
        """コンテキストのサマリーを生成（重要な情報のみ）"""
        # プロジェクトに応じてカスタマイズ
        return {k: v for k, v in context.items() if k in ["id", "name", "type"]}

    def can_resume(self, record_id: str) -> Dict:
        """再開可能かチェック"""
        record = self._store.get(record_id)
        if not record:
            return {"can_resume": False, "reason": "Record not found"}

        if record.status == ProcessStatus.COMPLETED:
            return {"can_resume": False, "reason": "Already completed"}

        # エラーステップの再開可能性をチェック
        error_step = next(
            (s for s in record.steps if s.status == StepStatus.ERROR),
            None
        )
        if error_step and error_step.error and not error_step.error.recoverable:
            return {
                "can_resume": False,
                "reason": f"Step {error_step.step} error is not recoverable",
                "suggested_action": error_step.error.suggested_action
            }

        return {
            "can_resume": True,
            "resume_from_step": record.current_step,
            "resume_step_name": self.step_definitions.get(record.current_step, {}).get("name", "")
        }
```

## 3. APIエンドポイント

```python
from fastapi import APIRouter, HTTPException

router = APIRouter()
process_store: ProcessStore = None  # 依存性注入で設定

@router.post("/api/process/create")
async def create_process(request: CreateProcessRequest):
    record = process_store.create(context=request.context)
    return {"success": True, "record": record.dict()}

@router.get("/api/process/{record_id}")
async def get_process(record_id: str):
    record = process_store.get(record_id)
    if not record:
        raise HTTPException(status_code=404, detail="Process not found")
    return {"success": True, "record": record.dict()}

@router.patch("/api/process/{record_id}")
async def update_process(record_id: str, partial_context: Dict):
    record = process_store.update_context(record_id, partial_context)
    if not record:
        raise HTTPException(status_code=404, detail="Process not found")
    return {"success": True, "record": record.dict()}

@router.post("/api/process/{record_id}/step")
async def update_step(record_id: str, request: UpdateStepRequest):
    record = process_store.update_step(
        record_id,
        step=request.step,
        status=request.status,
        result=request.result,
        error=request.error
    )
    if not record:
        raise HTTPException(status_code=404, detail="Process not found")
    return {"success": True, "record": record.dict()}

@router.post("/api/process/{record_id}/log")
async def add_log(record_id: str, request: AddLogRequest):
    record = process_store.add_log(
        record_id,
        level=request.level,
        message=request.message,
        step=request.step,
        data=request.data
    )
    if not record:
        raise HTTPException(status_code=404, detail="Process not found")
    return {"success": True}

@router.post("/api/process/{record_id}/interrupt")
async def interrupt_process(record_id: str, request: InterruptRequest):
    record = process_store.interrupt(record_id, request.reason, request.error_code)
    if not record:
        raise HTTPException(status_code=404, detail="Process not found")
    return {"success": True, "record": record.dict()}

@router.get("/api/process/{record_id}/can-resume")
async def can_resume(record_id: str):
    result = process_store.can_resume(record_id)
    return {"success": True, **result}

@router.get("/api/process/incomplete/list")
async def list_incomplete():
    sessions = process_store.get_incomplete()
    return {"success": True, "count": len(sessions), "processes": sessions}

@router.get("/api/process/{record_id}/logs")
async def get_logs(record_id: str, level: str = None, step: int = None):
    record = process_store.get(record_id)
    if not record:
        raise HTTPException(status_code=404, detail="Process not found")

    logs = record.logs
    if level:
        logs = [l for l in logs if l.level.value == level]
    if step is not None:
        logs = [l for l in logs if l.step == step]

    return {"success": True, "logs": [l.dict() for l in logs]}
```
