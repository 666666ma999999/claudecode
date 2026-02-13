---
name: fe-be-advanced
description: |
  FE/BE統合の分析手順、チェックリスト、状態管理パターン、CMS連携、Phase 0実装済みサービス層。
disable-model-invocation: true
---

# FE/BE統合アーキテクチャ - 上級リファレンス

## 設計原則

### 1. BE側が正（Single Source of Truth）
- 定数・ロジック・バリデーションルールはBE側で定義
- FEはBEのAPIを呼び出して取得・実行

### 2. グレースフルフォールバック
- API失敗時はローカル処理にフォールバック
- ユーザー体験を損なわない

### 3. 後方互換性維持
- 既存の同期関数は残す（ラッパーとして機能）
- 段階的な移行が可能

### 4. エラーと警告の分離
- errors: 処理を中断すべき問題
- warnings: 確認を促すが処理は継続可能

## 分析手順

重複コードを特定するための手順:

1. **定数の重複検索**
```bash
# FE側の定数定義
grep -r "const.*=" frontend/ --include="*.js" --include="*.html"
# BE側の定数定義
grep -r "^[A-Z_]+ = " backend/ --include="*.py"
```

2. **関数名の類似検索**
```bash
# 同じ処理をしていそうな関数名
grep -r "parse\|validate\|convert\|format" frontend/ backend/
```

3. **Codex MCPでの分析**
```
Codex MCPを使って、FEとBEで同じ処理をしている関数を特定し、
BE側で統合するアーキテクト案を作成してください。
```

## チェックリスト

### 統合前
- [ ] 重複している定数を特定
- [ ] 重複しているロジックを特定
- [ ] 重複しているバリデーションを特定
- [ ] **同義語・重複変数名を特定**（同じ値に異なる名前がないか）
- [ ] 優先度を決定（定数→ロジック→バリデーション）

### 統合中
- [ ] BEにAPIエンドポイント追加
- [ ] Pydanticモデルでリクエスト/レスポンス定義
- [ ] **変数名統一**（FE/BEで同じ値には同じ名前、case変換のみ）
- [ ] FEにAPI呼び出し関数追加
- [ ] フォールバック処理実装
- [ ] 既存関数をラッパーに変更
- [ ] 外部システム境界のパラメータ名はコメントで明記

### 統合後
- [ ] APIエンドポイントのテスト
- [ ] FE側のフォールバック動作確認
- [ ] バージョン履歴更新
- [ ] ドキュメント更新

### クリーンアップ（Phase 8）
- [ ] Codex MCPで冗長コード分析
- [ ] Phase A: 定数ハードコード削除
- [ ] Phase B: 不要関数削除（API版に統合）
- [ ] Phase C: 残存コード簡略化
- [ ] サーバー再起動・ヘルスチェック
- [ ] 削減効果の記録（行数・関数数）

### 構造化データ管理（Phase 9）
- [ ] 文字列置換箇所を特定
- [ ] 構造化データ設計（フィールド紐付け）
- [ ] BE: パース関数・再構築関数実装
- [ ] FE: フィールド更新関数実装
- [ ] エラー収集・表示ロジック追加
- [ ] セッションモデルに構造化データフィールド追加
- [ ] テスト（成功・失敗ケース）

## 実装上の注意点

### FastAPIルート順序
動的パス（`{session_id}`など）を含むルートは、静的パスより**後**に定義する。
```python
# ❌ Bad: definitionsがsession_idにマッチしてしまう
@router.get("/api/progress/{session_id}")
@router.get("/api/progress/definitions")

# ✅ Good: 静的パスを先に定義
@router.get("/api/progress/definitions")
@router.get("/api/progress/{session_id}")
```

### インメモリストアの設計
進捗追跡などでインメモリストアを使う場合:
```python
# グローバルストア
_progress_store: Dict[str, SessionProgress] = {}

# クリーンアップ関数を用意
def cleanup_old_sessions(max_age_hours: int = 24):
    now = datetime.now()
    for session_id, session in list(_progress_store.items()):
        if (now - session.created_at).hours > max_age_hours:
            del _progress_store[session_id]
```

### ファイルタイプ検出の優先順位
1. 拡張子ベース（高速・信頼性高）
2. MIMEタイプベース（拡張子不明時）
3. コンテンツベース（最終手段）

## Codex MCPを使った分析

重複コード特定にCodex MCPを活用:
```
Codex MCPを使って、現環境のFEとBEの関数で同じ処理をしている関数を
BE側で統合して保守性を高め、コード量を減らせるアーキテクト案を作成して下さい。
```

Codexが返す分析結果:
- 重複箇所（FEファイル:行番号 ↔ BEファイル:行番号）
- 統合実装案（API設計、レスポンス形式）
- 優先度の提案

## 状態管理パターン

### グローバル変数の問題

FEでグローバル変数を使った状態管理は以下の問題がある:
- **ページリロードで消失**: 処理途中でリロードすると全データ損失
- **複数箇所での参照**: どこで変更されたか追跡困難
- **テスト困難**: モック化が難しい

```javascript
// ❌ Bad: グローバル変数依存
let generatedResult = null;
let ppvId = null;
let menuId = null;
// ... 処理途中でリロード → 全て消失
```

### セッションベース状態管理

**解決策**: BE側でセッション状態を管理し、FEはAPIで状態を取得・更新

```javascript
// ✅ Good: セッションベース
let sessionRecord = null;

async function createSession(context) {
    const response = await fetch('/api/session/create', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(context)
    });
    sessionRecord = (await response.json()).record;
    return sessionRecord;
}

async function updateSession(partialData) {
    await fetch(`/api/session/${sessionRecord.record_id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(partialData)
    });
}

// リロード後も復元可能
async function resumeSession(recordId) {
    const response = await fetch(`/api/session/${recordId}`);
    sessionRecord = (await response.json()).record;
    restoreUIFromSession(sessionRecord);
}
```

### 共通ヘルパー関数の抽出

複数箇所で同じパラメータを抽出している場合、ヘルパー関数に統合:

```javascript
// ❌ Bad: 同じコードが3箇所に
// 場所A
const yudoPpvId01 = yudoResult?.success ? yudoResult.ppv_id_01 : null;
const yudoMenuId01 = yudoResult?.success ? yudoResult.menu_id_01 : null;
// 場所B, 場所C でも同じコード...

// ✅ Good: ヘルパー関数で統一
function getYudoParams() {
    // セッションから取得（優先）
    if (sessionRecord?.distribution?.yudo) {
        return sessionRecord.distribution.yudo;
    }
    // フォールバック: グローバル変数
    return {
        ppv01: yudoResult?.ppv_id_01 || null,
        menu01: yudoResult?.menu_id_01 || null,
        // ...
    };
}

// 使用箇所
const yudo = getYudoParams();
await registerMenu({ yudo_ppv_id_01: yudo.ppv01, ... });
```

**詳細なセッション管理パターンは `process-state-management` スキルを参照**

## 参照ファイル

- `../fe-be-integration/references/api-patterns.md` - APIエンドポイント設計パターン
- `../fe-be-integration/references/fallback-patterns.md` - フォールバック実装パターン
- `../fe-be-integration/references/validation-patterns.md` - バリデーション設計パターン
- `../fe-be-integration/references/progress-patterns.md` - 進捗追跡パターン
- `../fe-be-integration/references/cleanup-patterns.md` - 統合後のコードクリーンアップパターン
- `../fe-be-integration/references/structured-data-patterns.md` - 構造化データ管理パターン（文字列置換からの移行）

## デバッグTip: セッションファイルによるデータフロー追跡

FE→BE→FEのデータ変換で「N個指定したのにM個しか処理されない」問題が発生した場合：

```bash
# セッションファイルで各段階のデータを確認
python3 << 'EOF'
import json
with open('data/sessions/reg_xxx.json') as f:
    data = json.load(f)

# 1. 入力段階（FE→BE）
print(f"入力: {len(data['product']['subtitles'])}件")

# 2. 処理結果（BE内部）
print(f"処理後: {len(data['product']['structured_manuscript']['subtitles'])}件")

# 3. どこで減ったか特定 → パーサーのログを確認
EOF
```

**詳細なパーサーデバッグは `text-parser-patterns` スキルを参照**

## 外部システム/CMSのフィールドマッピング調査

### 問題

外部CMS・APIのフォームフィールド名が想定と異なる場合、自動化が失敗する。

```
想定: input[name='user_id'], input[name='password']
実際: input[name='user'], input[name='pass']
→ ログインが失敗、原因特定に時間がかかる
```

### 解決策: 実装前にフィールド構造を調査

```python
# Playwrightで実際のフォーム構造を調査
async def discover_form_fields(page, url):
    await page.goto(url)
    await page.wait_for_load_state('networkidle')

    return await page.evaluate('''
        () => {
            const result = { inputs: [], textareas: [], selects: [] };
            document.querySelectorAll('input[name]').forEach(el => {
                result.inputs.push({
                    name: el.name,
                    type: el.type,
                    placeholder: el.placeholder
                });
            });
            document.querySelectorAll('textarea[name]').forEach(el => {
                result.textareas.push({ name: el.name });
            });
            document.querySelectorAll('select[name]').forEach(el => {
                result.selects.push({ name: el.name });
            });
            return result;
        }
    ''')
```

### フィールドマッピング設計パターン

```python
# 外部システムのフィールド名を設定で管理
CMS_FIELD_MAPPINGS = {
    "hayatomo_cms": {
        "login": {
            "user_field": "user",      # 実際のname属性
            "pass_field": "pass",
            "submit_selector": "button:has-text('Login')"
        },
        "ppv_detail": {
            "guide_field": "guide",
            "price_field": "price",
            "affinity_field": "affinity"
        }
    },
    "other_cms": {
        "login": {
            "user_field": "user_id",
            "pass_field": "password",
            "submit_selector": "button[type='submit']"
        }
    }
}

# 使用時
async def login(page, cms_type, username, password):
    mapping = CMS_FIELD_MAPPINGS[cms_type]["login"]
    await page.fill(f"input[name='{mapping['user_field']}']", username)
    await page.fill(f"input[name='{mapping['pass_field']}']", password)
    await page.click(mapping['submit_selector'])
```

### チェックリスト

新しい外部システム/CMSと連携する際：

- [ ] Playwrightでログインページのフィールド構造を調査
- [ ] 対象フォームページのフィールド構造を調査
- [ ] フィールドマッピング設定を作成
- [ ] input/textarea/select の3種類すべてを考慮
- [ ] デバッグログで「見つからなかったフィールド」を出力

**詳細なPlaywright操作パターンは `playwright-browser-automation` スキルを参照**

## Phase 0 実装済み: BEサービス層（v1.44.0）

### サービス層構成
```
backend/services/
├── __init__.py              # 全サービスのエクスポート
├── text_transform.py        # remove_html_tags, sanitize_for_cms, format_text_to_html, escape_html
├── validation.py            # InputValidationError, validate_registration_input
├── category_infer.py        # CATEGORY_KEYWORDS, infer_category_from_keywords, infer_category_with_gemini, detect_pattern_type, _normalize_to_halfwidth
├── manuscript_transform.py  # text_analysisファサード + parse_and_format
└── postprocess.py           # (既存)
```

### HTMLフィールド追加パターン
レスポンスモデルに `_html` サフィックス付きフィールドを追加し、エンドポイントで `format_text_to_html()` を適用:
```python
class SomeResponse(CamelCaseModel):
    text: str = ""
    text_html: str = ""  # → JSON: "textHtml"

# エンドポイント内
return SomeResponse(text=result, text_html=format_text_to_html(result))
```

### Gemini DI パターン
サービス層のGemini関数はグローバル `_model` を参照せず、`model` 引数で受け取る:
```python
# services/category_infer.py
def infer_category_with_gemini(product_name: str, model=None) -> Dict:
    if model is None:
        return {"success": False, "message": "Gemini APIが初期化されていません"}

# routers/registration.py (呼び出し側)
result = infer_category_with_gemini(product_name, model=_model)
```

### 後方互換性パターン
browser_automation.pyからの関数移動時、同名で再エクスポート:
```python
# utils/browser_automation.py
from services.text_transform import sanitize_for_cms as _sanitize_for_cms
sanitize_for_cms = _sanitize_for_cms  # 既存の呼び出し元はそのまま動作
```

## 関連スキル

- **coding-standards**: 言語別命名規則、CamelCaseModelの基本説明
- **process-state-management**: 複数ステップのプロセス管理、ログ記録、中断・再開機能
- **text-parser-patterns**: テキストパーサー実装、エッジケース処理、デバッグ手法
- **playwright-browser-automation**: ブラウザ自動化、フォームフィールド調査
