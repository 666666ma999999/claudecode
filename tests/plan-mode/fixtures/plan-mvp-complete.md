# Plan: MVP Complete

Execution Strategy: Delivery

## Why
ユーザーがAPIを通じてデータを取得できるようにするため。

## Who
バックエンドエンジニア / フロントエンドエンジニア

## 非ゴール
認証機能の追加は今回のスコープ外。

## 成功基準
- `GET /api/data` が 200 を返す
- フロントエンドウィジェットにデータが表示される

## 影響範囲
- backend/api.py
- frontend/widget.js

## 変更禁止ファイル
- backend/core/engine.py

## Tasks
- T1: backend/api.py に /api/data エンドポイント追加
  - verify: `curl localhost:8000/api/data`
- T2: frontend/widget.js にデータ表示ロジック追加
  - verify: ブラウザで確認

## Verification
- curl で 200 確認
- Playwright でコンソールエラーゼロ
