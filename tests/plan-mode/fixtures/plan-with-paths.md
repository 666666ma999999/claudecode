# Plan: Drift Test

Execution Strategy: Delivery

## Goal
drift検知のfixture。

## Architecture
既存の構造を維持。

## 成功基準
テストが通る。

## Tasks
- T1: backend/routers/foo.py を編集
- T2: frontend/widgets/bar.js を編集

## Verification
- pytest PASS
- ブラウザで動作確認

ファイル: backend/routers/foo.py, frontend/widgets/bar.js
