# Plan: Missing Success Criteria (Delivery)

Execution Strategy: Delivery

## Goal
機能Y追加。

## Architecture
既存のpipelineを拡張。

## Tasks
- T1: src/bar.py に関数追加
  - verify: `pytest`

## 影響範囲
- src/bar.py

## 変更禁止ファイル
- src/core/pipeline.py

## Verification
- pytest PASS
