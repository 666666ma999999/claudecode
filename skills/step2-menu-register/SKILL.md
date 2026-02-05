---
name: step2-menu-register
description: |
  STEP 2: メニュー登録（原稿管理CMS）
  原稿管理CMSにログインし、新規原稿を登録する。
  Playwright MCPを使用してブラウザ操作を自動化。
  キーワード: STEP2, メニュー登録, 原稿管理, CMS, Playwright MCP
---

# STEP 2: メニュー登録

## 概要

原稿管理CMS（hayatomo2-dev.ura9.com）にログインし、商品原稿を登録する。

## 対象システム

- **URL**: `https://hayatomo2-dev.ura9.com/manuscript/`
- **認証**: フォームログイン
- **認証情報**: 環境変数 `MANUSCRIPT_CMS_USER`, `MANUSCRIPT_CMS_PASSWORD`

## 前提条件

1. Playwright MCP (`mcp__playwright-mkb__*`) が有効
2. 以下の入力データが必要:
   - `site_id`: サイトID
   - `ppv_id`: PPV ID
   - `ppv_title`: 商品タイトル
   - `subtitles`: 小見出しリスト（タイトル、本文、mid_id）

## 実行フロー

### 1. ログイン

```
URL: https://hayatomo2-dev.ura9.com/manuscript/?p=login

1. browser_navigate → ログインページ
2. browser_snapshot → フォーム要素確認
3. browser_type (ref: ユーザーID入力欄) → ユーザーID入力
4. browser_type (ref: パスワード入力欄) → パスワード入力
5. browser_click (ref: ログインボタン) → ログイン実行
6. browser_wait_for (text: "サイト選択") → ログイン完了確認
```

### 2. サイト選択・新規原稿作成

```
URL: https://hayatomo2-dev.ura9.com/manuscript/?p=site&site_id={site_id}

1. browser_navigate → サイトページ
2. browser_snapshot → メニュー確認
3. browser_click (ref: "新規原稿作成") → 新規作成画面へ
```

### 3. 原稿情報入力

```
URL: ?p=save&site_id={site_id}

1. browser_snapshot → 入力フォーム確認
2. browser_type (ref: PPV ID入力欄) → PPV ID入力
3. browser_type (ref: タイトル入力欄) → 商品タイトル入力
4. browser_select_option (ref: 原稿タイプ) → "ppv" 選択
```

### 4. 小見出し登録（ループ）

各小見出しについて:

```
1. browser_click (ref: "小見出し追加") → 小見出し追加
2. browser_type (ref: 小見出しタイトル) → タイトル入力
3. browser_select_option (ref: mid_id) → mid_id選択
4. browser_type (ref: 本文) → 原稿本文入力
5. browser_click (ref: "保存") → 保存
```

### 5. 原稿アップロード

```
1. browser_click (ref: "チェック") → 原稿チェック
2. browser_wait_for (text: "原稿チェック完了") → チェック完了
3. browser_click (ref: "原稿UP") → 原稿アップロード
4. browser_wait_for (text: "アップロード完了") → 完了確認
```

## セレクタ参照

### ログインページ

| 要素 | role/セレクタ | 説明 |
|------|--------------|------|
| ユーザーID | `input[name="user"]` | ユーザーID入力欄（CMSフィールド名: user） |
| パスワード | `input[name="pass"]` | パスワード入力欄（CMSフィールド名: pass） |
| ログインボタン | `button "Click to Login"` | ログイン実行 |

### 原稿登録ページ

| 要素 | role/セレクタ | 説明 |
|------|--------------|------|
| PPV ID | `input[name="target_ppv_id"]` | PPV ID入力 |
| 小見出しタイトル | `input[name="title"]` | 小見出しタイトル |
| mid_id | `select[name="mid_id"]` | mid_id選択 |
| 本文 | `textarea[name="body"]` | 原稿本文 |
| 保存ボタン | `button "保存"` | 保存実行 |
| チェックボタン | `button "チェック"` | 原稿チェック |
| 原稿UPボタン | `button "原稿UP"` | アップロード実行 |

## 出力

- `ppv_id`: 登録されたPPV ID
- `menu_id`: 発行されたmenu_id
- `success`: 成功/失敗
- `screenshot`: 完了時スクリーンショット

## エラーハンドリング

| エラー | 対応 |
|--------|------|
| ログイン失敗 | 即停止・ブラウザ維持・ユーザーに報告 |
| タイムアウト | 即停止・スクリーンショット取得・ブラウザ維持・ユーザーに報告 |
| 要素が見つからない | 即停止・スクリーンショット取得・ブラウザ維持・ユーザーに報告 |

**注意**: バックエンド内部の低レベルリトライ（ネットワーク再接続、ERR_ABORTEDリトライ等）は許可。STEP実行レベルの自動リトライは禁止。

## トラブルシューティング

### 原稿テキスト（30KB超）のtextarea入力

**症状**:
- 大量の原稿テキストをtextareaに入力しようとするとタイムアウトやエラーが発生
- browser_typeやbrowser_evaluateでは大量テキスト（30KB以上）を一度に入力できない

**原因**:
- Playwright MCPのブラウザ操作では、大量テキストの入力が不安定
- フロントエンドからの操作では時間がかかる

**解決方法**:
```
/api/register-manuscript APIを使用する方法が有効

1. バックエンドの /api/register-manuscript エンドポイントを使用
2. 内部でPlaywrightを直接操作して原稿を登録
3. 大量テキストも安定して処理可能

例:
POST /api/register-manuscript
{
  "site_id": "482",
  "ppv_id": "48200038",
  "menu_id": "monthlyAffinity001.001",
  "subtitles": [...],
  "auto_generated": {...}
}
```

**代替手段**:
- browser_run_codeで直接DOM操作
- クリップボード経由での貼り付け（ただし環境依存）
- 小見出し単位で分割して登録

### CMS原稿チェッカーで`<br />`タグエラー

**症状**:
- 原稿チェック画面で「エラーが10個あります。」と表示
- `<br />`タグがオレンジ色でハイライトされる
- 「原稿UP」ボタンが表示されず、保存失敗

**原因**:
- 生成された原稿本文に`<br />`HTMLタグが含まれている
- CMS原稿チェッカーがHTMLタグをエラーとして検出

**解決済み**:
- `browser_automation.py`のL833-834で、CMS入力前に`<br />`を改行文字に変換
- `<br /><br />` → `\n\n`、`<br />` → `\n`

### 原稿チェックエラーがあるのに次STEPに進む

**症状**:
- 原稿UP画面で「特殊小見出しのyes no」等のエラーが表示される
- エラーがあるのに次のSTEPに進んでしまう

**原因**:
- 以前はエラー検出がJSクリックパスでのみ実行されていた
- Playwrightフォールバックパスではエラー検出をスキップしていた
- 「原稿UPボタン」が存在すると、エラーがあっても続行していた

**解決済み（2026-02-03）**:
- 全パス（JSクリック/Playwrightフォールバック）でエラー検出を実行
- エラー検出時は即座に`return False`（一時保存を試みない）
- `keep_browser_on_error`の処理を全エラー検出箇所で統一
- `last_error_reason`属性を追加し、正確なエラーメッセージを呼び出し元に伝達

**エラー検出の動作**:
```python
# browser_automation.py finalize_registration()
# 1. JSクリック成功時: L1121-1148でエラー検出
# 2. Playwrightフォールバック時: L1201-1228でエラー検出
# 3. 原稿UPボタン未発見時: L1417-1427でエラー検出
# すべてのパスでlast_error_reasonを設定し、return False
```

### komi_yesnoの「特殊小見出しのyes no」エラー

**症状**:
- komi_yesnoタイプの小見出しでCMSチェッカーエラー
- 「特殊小見出しのyes no」エラーが表示される

**原因**:
- STEP 1のY/N再生成で`{"code": "01", "summary": "Y", "body": "本文"}`を保存
- しかしSTEP 2でCMSに送信時、summaryが除去されて`code\tbody`形式になっていた
- CMSのkomi_yesnoパターンは`code\tY/N\tbody`の3カラム形式を期待

**解決済み（2026-02-03）**:
- `registration.py` L371-386で、komi_yesnoの場合は常に3カラム形式で出力
- summaryが空の場合は警告ログを出力

```python
# registration.py
if komi_type == "komi_yesno":
    body_lines.append(f"{code}\t{summary}\t{body}")  # 3カラム
else:
    body_lines.append(f"{code}\t{body}")  # 2カラム
```

## 不変条件（Invariants）

**リファクタリング時に絶対に壊してはならない動作仕様。コード変更後は必ず以下を検証すること。**

### I1. mid_id選択はJavaScript evaluate + dispatchEvent
- `select_option()` はCMS SPA内部状態を更新しないため**使用禁止**
- `page.evaluate()` + `dispatchEvent(new Event('change', { bubbles: true }))` で選択すること
- 選択後に100ms待機（SPA microtask完了待ち）
- 選択後に `select.value` を検証し、不一致時は最大3回リトライ
- **根拠**: CMS edit.jsがDOM変更をJSオブジェクトに反映するのは`change`イベント経由のみ

### I2. mid_idオプションロード待機
- `wait_for_selector` ではなく `wait_for_function` でオプションのvalue属性が非空であることを確認
- SPA AJAX完了前にJS選択すると、デフォルト値（1026=fixedCode001）が適用される
- **チェック式**: `sel.options[i].value && sel.options[i].value.trim()` でtrue返却まで待機

### I3. komi_type保持
- `komi_jyuyou1` を含む全komi_typeをそのまま使用（komi_normalへの強制変換禁止）
- spanタグはL941-942で除去済みのため、CMSチェッカーエラーは発生しない
- 冒頭・締めのみ `komi_normal` を強制（I4参照）

### I4. 冒頭・締めの特別扱い
- `is_opening_closing=True` の小見出しは常に `komi_normal` を選択
- `mid_id=1026`（fixedCode001専用）が割り当てられる
- 原稿テキストの`<br />`→改行変換、`<span>`タグ除去はL833-834, L941-942で実施

### I5. komi selectのCSS非表示対応
- CMSのkomi selectは`display:none`のため、Playwrightの通常操作不可
- JavaScript DOM操作で`selectedIndex`を変更し、`change`イベントを発火

### I6. CMS SPA保存フロー
- 「保存」→ダイアログ処理→AJAX→`networkidle`待機の順序を維持
- ダイアログ処理後に`asyncio.sleep(0.5)` + `networkidle`で保存完了を待機

## 使用例

```
/step2

入力:
- site_id: 482
- ppv_id: 10001
- ppv_title: 【恋愛占い】彼の本音
- subtitles: [...]
```

## 完了確認（必須）

**STEP 2 実行後、以下の確認を必ず行うこと：**

### 確認手順

```
1. UP済み一覧にアクセス
   URL: https://hayatomo2-dev.ura9.com/manuscript/?p=up&site_id={site_id}

2. browser_snapshot で一覧を取得

3. 以下を確認:
   - ppv_id が一覧に表示されている
   - ステータスが「登録済み」または「UP済み」
   - 小見出し数が期待値と一致
```

### 確認項目

| 項目 | 成功条件 | 確認方法 |
|------|----------|----------|
| ppv_id表示 | 一覧にppv_idが存在 | snapshot内を検索 |
| ステータス | 「登録済み」「UP済み」 | 該当行のステータス列 |
| 小見出し数 | 期待値と一致 | 詳細画面で確認 |

### 確認コード例

```javascript
// snapshotから確認
const rows = snapshot.match(/48200038.*?(登録済み|UP済み)/);
if (!rows) {
  throw new Error('STEP 2 確認失敗: ppv_idが一覧に見つかりません');
}
console.log('✅ STEP 2 完了確認OK');
```

### 失敗時の対処

| 症状 | 原因 | 対処 |
|------|------|------|
| ppv_id未表示 | 登録未完了 | STEP 2を再実行 |
| ステータスが「未登録」 | 原稿UPが未実行 | 「原稿UP」ボタンをクリック |
| 小見出し数不一致 | 入力漏れ | 詳細画面で追加登録 |

---

### mid_id selectでCMS内部状態が更新されない

**症状**:
- sort=1の冒頭は正しいmid_idだが、sort=2以降が前の値やデフォルト値(1)になる
- DOM上のselectは正しい値だが、POSTデータが異なる

**原因**:
- CMSはSPAフレームワーク（edit.js）で内部状態をJSオブジェクトで管理
- Playwrightの`select_option()`はDOMのvalueを変更するが、CMS内部状態は更新しない
- 保存時にCMSは内部状態からPOSTデータを構築するため、DOM値が無視される

**解決方法**:
- `page.evaluate()` + `dispatchEvent(new Event('change', { bubbles: true }))` を使用
- komi selectと同じパターン（`browser_automation.py` L889-922参照）

**解決済み**: 2026-01-31

**重要**: CMS SPAのselect要素は全て`select_option()`ではなく`page.evaluate()`+`dispatchEvent`で操作すること。

---

### MID_IDのfallbackロジック（common_mid_id）

**概要**:
- `registration.py`の`get_mid_id()`関数がMID_ID割り当てを管理
- `common_mid_id`（フロントエンドの④欄）がfallbackとして使用される
- 冒頭/締めには`use_fallback=False`で専用デフォルト（1026）が適用される

**MID_ID決定の優先順位**:
1. `subtitle_midids`で明示指定されたmid_id（order単位）
2. `common_mid_id`（小見出しのみ、冒頭/締め以外）
3. パラメータデフォルト値（冒頭/締め: 1026、小見出し: 空文字）

**オーケストレーター経由の場合**:
- `record.user_input["common_mid_id"]`からfallback値を取得
- セッション作成時にフロントエンドから保存される

**注意**: 空文字のmid_idはfallbackに委任される（midid_mapに格納しない）

---

### CMSチェッカーでkomi_type関連エラー

**症状**:
- 「特殊小見出し無し」エラー — komi_typeが原稿内容と不一致
- 「エラーが52個あります」— komi_jyuyou1のサマリーに含まれる`<span>`タグがCMSチェッカーで検出

**原因と対策**:
- AI推論 (`infer_komi_type_with_gemini()`) が割り当てるkomi_type（komi_honne1, komi_sp, komi_jyuyou1等）を使用
- komi_jyuyou1のサマリーは`<span>キーワード</span>`形式で生成されるが、CMSチェッカーがHTMLタグをエラーとして検出
- **対策**: `browser_automation.py` L941で`<span>`タグを除去（内部テキストは保持）してからCMS入力
- **v1.42.2**: spanタグ除去済みのため、komi_jyuyou1を含む全komi_typeをそのまま使用（以前はkomi_jyuyou1がkomi_normalに強制変換されていたが修正済み）
- CMSのkomiセレクトはCSS非表示（display:none）のため、JavaScriptのDOM操作で選択する必要がある
- `select[name="komi"]` のindex=18が `komi_normal : -`
- 冒頭・締めは常に`komi_normal`を強制（browser_automation.py L962-965）

**解決済み**: 2026-02-04（spanタグ除去）

---

### チェック・原稿UPボタンのクリックタイムアウト

**症状**:
- 「保存失敗: 原稿UPまたは一時保存ボタンが見つかりませんでした」
- チェックボタンクリック後の`networkidle`が30秒タイムアウト
- 原稿UPボタンのPlaywright `click()` がタイムアウト

**原因**:
- CMS SPAでは`networkidle`状態が安定しない
- 原稿UPボタンはPlaywrightのvisibility/actionabilityチェックに通らないことがある

**対策** (`browser_automation.py`):
1. **チェックボタン**: JSクリック + `wait_for_function`で「エラーが」or「原稿UP」テキストの出現を待つ（L987-1014）
2. **原稿UPボタン**: JSクリック優先（disabled判定付き）、Playwrightは fallback（L1222-1256）
3. **networkidle**: 15秒タイムアウト + 非致命的（タイムアウトしても続行）（L1262-1264）

**解決済み**: 2026-01-30

---

## 統一APIエンドポイント

STEP 2はセッション駆動の統一APIでも実行可能:

```
POST /api/step/2/execute
{
  "session_id": "xxx",
  "overrides": {"headless": true, "slow_mo": 0}  // 任意
}

レスポンス (StepExecuteResponse - camelCase):
{
  "success": true,
  "sessionId": "xxx",
  "step": 2,
  "message": "...",
  "result": {"menuId": "001.045", "ppvId": "48200038", "screenshotPath": "..."}
}
```

- STEP 1がSUCCESSでないと実行不可（ガード条件）
- セッションのmenu_idを自動更新
- 既存API `/api/register-manuscript` も引き続き利用可能

## 依存関係

**STEP 2 は STEP 1 の完了後に実行すること。**
**STEP 2 の完了後に STEP 3 を実行すること。**

### 実行順序
```
STEP 1: 原稿生成・PPV ID発行
    ↓ （完了確認後）
STEP 2: メニュー登録（原稿管理CMS）← このスキル
    ↓ （完了確認後）
STEP 3: PPV情報登録（?p=cms_ppv）
```

### STEP 1からの受け取りデータ
- `ppv_id`: STEP 1で発行されたPPV ID
- `menu_id`: STEP 1で発行されたmenu_id
- `subtitles`: STEP 1で生成された原稿

### STEP 3への引き渡しデータ
- `menu_id`: 登録確定したmenu_id（STEP 3以降で使用）
- セッションは維持されるため、同じブラウザでSTEP 3に進む

### komi_type DB保存成功・本文パターン埋め込み

**症状**:
- 各小見出しにAI判定のkomi_type（komi_honne1, komi_jyuyou1等）を設定したい
- 以前は全てkomi_normalに強制されていた（v1.42.2で修正済み）

**原因と解決**:
- browser_automation.py の`KOMI_TYPES_WITH_SPAN`がkomi_jyuyou1をkomi_normalに強制していた → v1.42.2で削除（spanタグはL941で除去済みのため不要）
- komi selectのオプションがロードされるまで`wait_for_function`で待機
- komi-convertチェックボックスをONにしてからchangeイベント発火 → 本文にkomiパターン埋め込み
- CMS save API (`event.js` L162): `komi: Elements.elm_komi.options[selectedIndex].getAttribute("data-key")` でPOSTされる
- **komi値はDB保存される**（edit APIレスポンスで確認済み）

**CMS komi アーキテクチャ**:
- komi select: 各小見出し保存時に`data-key`がPOSTされDB保存
- 本文テキスト: `code\tkomi_pattern\ttext` 形式でパターン埋め込み（チェッカー検証用）
- komi-convert checkbox: ONの場合のみchangeイベントで本文変換が発動
- `komi_jyuyou1`のパターンに`<span>`タグが含まれ、チェッカーで40エラーになるが「原稿UP」は可能

**解決済み**: 2026-02-02

---

### サイトメニューナビゲーションでERR_ABORTEDエラー

**症状**:
- ログイン成功後、サイトメニューページ（`?p=text&f=menu&site_id={site_id}`）への遷移で`ERR_ABORTED`エラー
- CMSのリダイレクト処理中にPlaywrightが遷移失敗と判定する

**原因**:
- CMSログイン後のリダイレクトチェーンが完了する前にPlaywrightが`goto()`を実行
- CMSのSPA遷移で中間的なリダイレクトが発生し、`ERR_ABORTED`になる

**解決済み（2026-02-04）**:
- サイトメニューナビゲーションに3回リトライを追加（`browser_automation.py` L1560-1570）
- ログイン後の`wait_for_load_state`を`domcontentloaded` → `networkidle`に変更（セッション確立を待機）
- リトライ間に2秒の待機を挿入

```python
# browser_automation.py L1560-1570
for nav_attempt in range(3):
    try:
        await self.page.goto(site_menu_url, wait_until="domcontentloaded", timeout=PAGE_LOAD_TIMEOUT)
        break
    except Exception as nav_err:
        if nav_attempt < 2 and "ERR_ABORTED" in str(nav_err):
            logger.warning(f"サイトメニューナビゲーションリトライ ({nav_attempt + 1}/3)")
            await asyncio.sleep(2)
            continue
        raise
```

---

### CMS SPA保存ダイアログの待機タイミング

**症状**:
- 小見出し保存時にダイアログ処理が完了する前に次の操作が実行される
- 保存が反映されず、次の小見出し入力が前の値で上書きされる

**原因**:
- CMS SPAではダイアログ→AJAX保存のフローであり、`domcontentloaded`では保存完了を待機できない
- `networkidle`はAJAX完了まで待機するため適切

**解決済み（2026-02-04）**:
- `browser_automation.py` L1037-1041でダイアログ処理後の待機を`asyncio.sleep(0.5)` + `networkidle`に変更
- `networkidle`タイムアウトは非致命的として処理

---

### 原稿チェッカーの非ブロッキング警告

**症状**:
- 「特殊小見出しの指定は不要です」が表示されると原稿UPがブロックされる
- しかしこの警告は非ブロッキングであり、原稿UPは可能

**原因**:
- エラー検出パターンが「特殊小見出しの指定は不要です」をブロッキングエラーとして扱っていた

**解決済み（2026-02-04）**:
- `browser_automation.py` L1326-1330で「特殊小見出しの指定は不要です」を非ブロッキング警告として除外
- 残存エラーがあっても原稿UPボタンが存在する場合はアップロード続行（L1345-1361）

---

### PPV更新後に一時保存一覧でedit linkが見つからない

**症状**:
- PPV情報（ppv_id、タイトル、タイプ）入力後「更新」ボタンクリック
- 一時保存一覧（save_lists）に遷移するが、ppv_idに対応する編集リンクが見つからない
- 小見出し入力フォームが表示されず、STEP 2が失敗する

**原因**:
- 「更新」ボタンクリック後、CMS AJAX保存が完了する前に一時保存一覧ページに遷移していた
- `asyncio.sleep(2)` のみで待機しており、AJAX完了を保証できなかった
- 小見出しフォーム未出現時でも `return True` で成功扱いしていた（バグ）

**解決済み（2026-02-05、v1.47.0で安定化強化）**:
- `browser_automation.py` L807-812で「更新」後に`wait_for_load_state("networkidle", timeout=10000)`を追加
- 一時保存一覧でのedit link検索に5回リトライ（`MAX_SAVE_LIST_RETRIES=5`）、指数バックオフ `RETRY_BACKOFF=[3,5,8,10,12]` を適用
- 小見出しフォーム未出現時は`return False`に変更（L920-922）

```python
# browser_automation.py（v1.47.0）
MAX_SAVE_LIST_RETRIES = 5
RETRY_BACKOFF = [3, 5, 8, 10, 12]
for save_list_attempt in range(MAX_SAVE_LIST_RETRIES):
    await self.page.goto(save_lists_url, wait_until="networkidle", timeout=PAGE_LOAD_TIMEOUT)
    clicked = await self.page.evaluate(...)  # 3つの方法でedit link検索
    if clicked and clicked.get('success'):
        break  # 見つかった
    elif save_list_attempt < MAX_SAVE_LIST_RETRIES - 1:
        logger.warning(f"一時保存一覧にppv_id={ppv_id}の編集リンク未検出 (...)")
        await asyncio.sleep(RETRY_BACKOFF[save_list_attempt])
```

### headless安定化ノート（v1.47.0追加）

**save_listsナビゲーション**:
- テーブルDOM出現を `wait_for_selector("table tr, .save-list-item")` で確認してからedit link検索を行う
- headlessモードではDOM描画完了が`networkidle`より遅延するケースがあるため、明示的なDOM待機が必要

**edit link検出**:
- `wait_for_selector` で先にedit linkの存在を確認し、見つからない場合のみ `evaluate` によるJavaScript検索にフォールバック
- headlessではPlaywrightのセレクタベース検出がevaluateよりも安定

**小見出しフォーム検出**:
- `wait_for_selector` で先にフォーム要素の出現を確認
- フォールバックとして2秒間隔のポーリング（最大15ラウンド = 30秒）で出現を待機
- headlessではSPA遷移後のフォーム描画に時間がかかるケースに対応
