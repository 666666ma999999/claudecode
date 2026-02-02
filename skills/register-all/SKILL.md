---
name: register-all
description: |
  全STEP連続実行（商品登録フル自動化）
  STEP 1～8 を連続して実行し、商品登録を完全自動化する。
  セッションJSON駆動で途中再開・リトライ制御を備える。
  キーワード: 全STEP, 連続実行, フル自動化, 商品登録
---

# 全STEP統合オーケストレーター

## 実行モード

```
■ 新規:     /register-all --site-id 482 --input-a "..." --input-b "..."
■ 再開:     /register-all --resume {record_id}
■ 途中から: /register-all --from {step} --session {record_id}
```

## 制御フロー（全STEP共通）

```python
# 疑似コード: エージェントが従うべきフロー
for step in range(start_step, 9):
    # 1. ガード条件チェック
    guard = GET /api/step/{step}/guard?session_id={record_id}

    if not guard.canProceed:
        # 前提STEP未完了 → 停止してユーザー通知
        NOTIFY f"STEP {step} 実行不可: {guard.message}"
        BREAK

    if guard.loopDetected:
        # ループ検出 → PAUSE → ユーザー通知
        NOTIFY f"STEP {step} ループ検出（同一パターンで{LOOP_THRESHOLD}回以上）"
        BREAK

    if guard.retryInfo.anyLimitExceeded:
        # リトライ上限超過 → PAUSE → ユーザー通知
        NOTIFY f"STEP {step} リトライ上限超過: {guard.retryInfo.counts}"
        BREAK

    # 2. 待機
    if guard.waitSeconds > 0:
        SLEEP guard.waitSeconds

    # 3. STEP実行
    if step == 1:
        # STEP 1: BEパイプラインAPI（ブラウザ不要）
        result = POST /api/step1/execute {
            session_id, input_a, input_b, mode, site_id,
            file_paths, generate_opening_closing, price
        }
    else:
        # STEP 2-8: 各STEPスキル呼び出し（Playwright MCP操作）
        result = /step{step} --session {record_id}

    # 4. 結果判定
    if result.success:
        CONTINUE  # → 次STEPへ
    else:
        # 失敗 → リトライ判定
        guard2 = GET /api/step/{step}/guard?session_id={record_id}
        if guard2.retryInfo.anyLimitExceeded:
            NOTIFY f"STEP {step} 失敗・リトライ上限超過"
            BREAK
        else:
            RETRY step  # 同じSTEPを再実行
```

## STEP一覧

| STEP | 処理 | 実行方法 | スキル |
|------|------|---------|--------|
| 1 | 原稿生成・PPV ID発行 | `POST /api/step1/execute` | - |
| 2 | メニュー登録（原稿管理CMS） | Playwright MCP | `/step2` |
| 3 | PPV情報登録（従量登録） | Playwright MCP | `/step3` |
| 4 | メニュー設定（従量管理詳細） | Playwright MCP | `/step4` |
| 5 | 売上集計登録（MKB） | Playwright MCP | `/step5` |
| 6 | 原稿本番アップ（izumo同期） | Playwright MCP | `/step6` |
| 7 | 小見出し登録（izumo反映） | Playwright MCP | `/step7` |
| 8 | 従量自動更新（izumo更新） | Playwright MCP | `/step8` |

## STEP 1 API詳細

```
POST /api/step1/execute
Body: {
    "session_id": "reg_20260131...",
    "input_a": "占い商品情報テキスト",
    "input_b": "ロジック・原稿仕様テキスト",
    "mode": "auto",         // "auto" or "manual"
    "site_id": 482,
    "file_paths": [],       // 添付ファイルパス（オプション）
    "generate_opening_closing": true,
    "price": 2000
}

Response: {
    "success": true,
    "sessionId": "reg_...",
    "recordId": "reg_...",
    "ppvId": "48200039",
    "menuId": "001.045",
    "subtitleCount": 20,
    "hasManuscript": true,
    "hasOpeningClosing": true,
    "error": null
}
```

## ガードAPI詳細

```
GET /api/step/{step}/guard?session_id={record_id}

Response: {
    "step": 2,
    "canProceed": true,
    "requiredStep": 1,
    "requiredStatus": "SUCCESS",
    "actualStatus": "success",
    "description": "STEP1完了かつppv_id/menu_idが発行済み",
    "customCheckPassed": true,
    "customCheckMessage": null,
    "message": "STEP2実行可能",
    "waitSeconds": 0,
    "loopDetected": false,        // ← NEW
    "retryInfo": {                // ← NEW
        "counts": {},
        "anyLimitExceeded": false
    }
}
```

## 前提条件

1. ローカルサーバーが起動していること（http://localhost:5558）
2. Playwright MCP が有効であること（STEP 2-8）
3. Squidプロキシ経由でMKBにアクセス可能であること（STEP 5）
4. セッションが作成済みであること（STEP 1 実行前に `POST /api/registration-session/create`）

## 再開フロー

```
/register-all --resume {record_id}

1. GET /api/registration-session/{record_id}
2. resume_step = session.progress から最後の SUCCESS の次を算出
3. start_step = resume_step
4. 制御フローを start_step から実行
```

## エラーハンドリング

### STEPごとの継続判断

| STEP | 失敗時 |
|------|--------|
| 1 | 中断（原稿がないと続行不可） |
| 2 | 中断（CMS登録必須） |
| 3 | 中断推奨（STEP 4 が保存不可） |
| 4 | 警告して続行可 |
| 5 | **status: "error"を保持**。スキップして続行可（STEP6-8はSTEP5非依存） |
| 6 | 警告して続行可 |
| 7 | 警告して続行可 |
| 8 | 警告して終了 |

### リトライ上限

| STEP | エラータイプ | 上限 |
|------|-------------|------|
| 1 | TIMEOUT_ERROR | 3回 |
| 1 | API_ERROR | 2回 |
| 2 | LOGIN_ERROR | 3回 |
| 2 | ELEMENT_NOT_FOUND | 2回 |
| 3-4 | SAVE_FAILED | 1回 |
| 5 | UPLOAD_FAILED | 2回 |
| 6 | SYNC_FAILED | 2回 |
| 7 | REFLECT_FAILED | 2回 |
| 8 | UPDATE_FAILED | 2回 |

### ループ検出パターン

| パターン | 対象STEP | 閾値 |
|---------|---------|------|
| S3_S4 | STEP 3-4 | 3回 |
| S6_S7 | STEP 6-7 | 3回 |
| S6_S7_S8 | STEP 8 | 3回 |

## 各STEP確認項目

### STEP 1
- ppv_id: 8桁数字が発行された
- menu_id: 形式 `{prefix}{number}.{subtitle}`
- 原稿テキスト: 小見出し数が期待値と一致

### STEP 2
- UP済み一覧にppv_idが表示
- ステータスが「登録済み」

### STEP 3
- price, guide, affinityが保存済み
- yudo_ppv_id_01 が設定済み

### STEP 4
- 表示フラグ = 1
- 画数設定が正しい

### STEP 5
- 「X件保存しました」メッセージ

### STEP 6
- 「同期完了」メッセージ

### STEP 7
- 「反映完了」メッセージ

### STEP 8
- 「登録しました」メッセージ
- ppv_idが一覧に表示

## データストア

セッションJSON: `data/sessions/{record_id}.json`
- product: 原稿・小見出し・冒頭締め
- distribution: カテゴリ・紹介文・価格・誘導設定
- progress: 各STEP実行状態
- loop_counters: ループ・リトライカウント
- step_transactions: STEP横断トランザクション記録（入力→送信→応答→検証）

## STEPトランザクション記録

各STEPの「入力→送信→応答→検証」を`step_transactions`に記録。

### BE側での記録（record_step_phase）
```python
from routers.registration_session import record_step_phase
record_step_phase(record_id, step_no, step_name, phase, actor, detail, status)
# phase: "input", "request", "response", "verification"
```

### FE側での記録（API）
```javascript
await fetch(`/api/registration-session/${recordId}/step-transaction`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
        step_no: 2, step_name: "メニュー登録", phase: "input",
        actor: "frontend", detail: { ... }
    })
});
```

### 現在の記録ポイント
| STEP | phase | 記録場所 | actor |
|------|-------|---------|-------|
| 2 | input | FE auto.html（API呼び出し直前） | frontend |
| 2 | response | BE registration.py（register_manuscript完了後） | cms_playwright |
| 3 | response | BE browser_automation.py（fill_fields完了後） | cms_ppv |
| 4 | input | FE auto.html（/api/cms-menu/register直前） | frontend |
| 4 | response | BE registration.py（register_cms_menu完了後） | cms_menu |
| 5 | input | FE auto.html（/api/sales/register直前） | frontend |
| 5 | response | BE registration.py（register_sales完了後） | mkb_upload |
| 6 | input | FE auto.html（/api/izumo/sync-production直前） | frontend |
| 6 | response | BE registration.py（sync_izumo_production完了後） | izumo_sync |
| 7 | input | FE auto.html（/api/izumo/reflect-menu-all直前） | frontend |
| 7 | response | BE registration.py（reflect_all完了後） | izumo_reflect |
| 8 | response | BE registration.py（auto_update完了後） | izumo_auto_update |
