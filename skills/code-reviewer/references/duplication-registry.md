# 多重定義レジストリ

FE/BE間およびFE内・BE内で多重定義されている定数・関数・設定値の一覧。
新規コード追加時、このリストの値をハードコードしないこと。

## 高リスク（即時対応推奨）

| 定数名 | 正規定義元 | 値 | 多重定義箇所 | リスク |
|--------|-----------|-----|------------|--------|
| REGISTRATION_CONSTANTS["default_price"] | backend/routers/config.py:90 | 2000 | auto.html×3, step1_api.py, app-config.json | 価格変更時に不整合 |
| REGISTRATION_CONSTANTS["opening_marker"] | backend/routers/config.py:92 | 【冒頭/あいさつ】 | registration.py×6, text_analysis.py×4, main.py | マーカー変更時に原稿解析失敗 |
| REGISTRATION_CONSTANTS["closing_marker"] | backend/routers/config.py:93 | 【締め/メッセージ】 | registration.py×6, text_analysis.py×4, main.py | マーカー変更時に原稿解析失敗 |
| REGISTRATION_CONSTANTS["opening_closing_mid_id"] | backend/routers/config.py:87 | 1026 | registration.py×4, browser_automation.py, auto.html×3 | ID変更時にSTEP2-8全体が失敗 |

## 中リスク

| 定数名 | 正規定義元 | 値 | 多重定義箇所 | リスク |
|--------|-----------|-----|------------|--------|
| REGISTRATION_CONSTANTS["site_id_range"] | backend/routers/config.py:88 | {min:1, max:999} | auto.html:2884-2886 | バリデーション不整合 |
| REGISTRATION_CONSTANTS["ppv_id_digits"] | backend/routers/config.py:89 | 5 | app-config.json:375 | ID生成エラー |
| MAX_PROMPT_CHARS | backend/utils/path_constants.py:256 | 5000 | script.js:601, app-config.json:173 | 文字数制限不整合 |
| DEFAULT_SUBTITLE_COUNT | backend/utils/path_constants.py:260 | 10 | app-config.json:175 | 小見出し数不整合 |

## 低リスク（監視対象）

| 定数名 | 正規定義元 | 値 | 多重定義箇所 | リスク |
|--------|-----------|-----|------------|--------|
| FETCH_TIMEOUT (STEP2-7) | frontend/auto.html (AbortController) | 180000 | 6箇所ハードコード | タイムアウト変更時に漏れ |
| RETRY_LIMITS | backend/routers/registration_session.py | dict | step_config.json（一元化済み） | 低（一元化済み） |

## BE内の関数・定義重複

| 関数/定数名 | 正規定義元 | 多重定義箇所 | リスク | 深刻度 |
|------------|-----------|------------|--------|--------|
| is_logic_sheet() | backend/utils/logic_definitions.py:48 | backend/main.py:248（異なるリスト: 10個 vs 13個） | ロジック判定結果が場所により異なる | 高 |
| LOGIC_SHEETS / MAIN_LOGIC_SHEETS | backend/utils/logic_definitions.py:11 | backend/main.py:242（13個 vs 10個で不一致） | ロジック定義の不整合 | 高 |
| get_step_timeout() | backend/utils/timeout_manager.py:211 | backend/utils/step_definitions.py:259 | タイムアウト値が場所により異なる可能性 | 中 |
| save_session() | backend/routers/registration_session.py:244 | backend/routers/check.py:107（異なるシグネチャ） | 名前衝突による混乱 | 中 |
| set_dependencies() | 各router固有 | 8ファイルで同名関数（opening_closing, ppv_ids, postprocess, logic, manuscript_generation, translation, manuscripts, product_development_v2） | 検索時の混乱 | 低 |

## FE内の関数・エンドポイント重複

| 関数/定数名 | 正規定義元 | 多重定義箇所 | リスク | 深刻度 |
|------------|-----------|------------|--------|--------|
| showError() | （未統一） | auto.html:2541, txt_dl.html:363（ほぼ同一実装） | utils.jsで共通化可能 | 中 |
| /api/registration-session/* | （URLハードコード） | auto.html内8箇所以上 | エンドポイント変更時に複数修正 | 高 |
| /api/ppv-ids/* | （URLハードコード） | auto.html:2892, 2912 | エンドポイント変更時に修正漏れ | 中 |
| /api/manuscripts/* | （URLハードコード） | auto.html:2967,3011,3052, script.js:449,694,1262 | 2ファイルに分散 | 中 |
| /generate-all-manuscripts | （URLハードコード） | script.js:491, auto.html:2169 | 2ファイルに同一URL | 中 |
| /api/parse-metadata | （URLハードコード） | script.js:449, 694, 1262（3箇所） | 同一ファイル内3回ハードコード | 中 |

## grepパターン集

新規コード追加時に以下を実行して多重定義を検知：

```bash
# 価格ハードコード
grep -rn "\b2000\b" --include="*.py" --include="*.js" --include="*.html"

# MID ID ハードコード
grep -rn "\b1026\b" --include="*.py" --include="*.js" --include="*.html"

# マーカー文字列ハードコード
grep -rn "【冒頭/あいさつ】\|【締め/メッセージ】" --include="*.py" --include="*.js" --include="*.html"

# タイムアウト値ハードコード
grep -rn "\b180000\b" --include="*.html" --include="*.js"

# プロンプト文字数制限
grep -rn "\b5000\b" --include="*.py" --include="*.js" --include="*.html" --include="*.json"
```

## 更新履歴

- 2026-02-02: 初版作成（12カテゴリ・高リスク4件を含む）
