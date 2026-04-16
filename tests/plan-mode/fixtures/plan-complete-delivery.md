# Plan: Complete Delivery

Execution Strategy: Delivery

## Goal
ユーザー認証を追加する。

## Architecture
FastAPIに認証ミドルウェアを追加し、JWTを発行する。

## 成功基準
- `/auth/login` が 200 を返し JWT を含む
- 既存のテスト全て PASS

## Tasks
- T1: backend/auth/middleware.py に AuthMiddleware を追加
  - verify: `pytest backend/tests/test_auth.py`
- T2: backend/routers/auth.py に /login を追加
  - verify: `curl -X POST localhost:8000/auth/login`

## 影響範囲
- backend/auth/middleware.py
- backend/routers/auth.py

## 変更禁止ファイル
- backend/core/config.py

## Verification
- pytest: 全件 PASS
- curl で 200 確認
