# verify-production

name: 本番チェックフロー確認
description: STEP 1-8で登録した情報が本番サイトに正しく反映されているか確認する。Playwright MCPまたはブラウザ自動化で23項目を自動チェック。

## 発動条件

以下のキーワードで発動：
- 「本番チェック」「本番確認」「反映確認」
- 「チェックフロー」「verify」
- 「STEP完了後の確認」
- 「PPV登録確認」

## 概要

MB従量登録（STEP 1-8）完了後に、本番サイトで以下を確認：
- 従量メニューが正しく表示されるか
- 小見出し・価格・ガイド文が正しいか
- エラーがないか
- 新着枠に表示されるか

## 使用ツール

### Web UI
```
http://localhost:5558/check.html?ppv_id={PPV_ID}
```

### 変数トレーサビリティ（Detection System）
```
http://localhost:5558/detect.html?ppv_id={PPV_ID}
```
STEP 1-8の変数がどのチェック項目に流れるかを可視化する補完ツール。
check.htmlが「本番の正しさ」を確認するのに対し、detect.htmlは「変数の流れ」を追跡する。

**機能**:
- 3パネル表示: 変数レジストリ / STEP I/O タイムライン / ステートマシン(Mermaid)
- トレーサビリティマトリクス: 19チェック項目の期待値vs実績
- 5秒自動ポーリング（ACTIVEセッション時ON、COMPLETED時自動停止）
- STEP詳細パネル展開状態はポーリング中も維持される
- JSONエクスポート機能

### Playwright MCP（手動実行時）
```
browser_navigate → browser_snapshot → 内容確認
```

## チェック項目（全23項目）

### ■ログイン（2項目）
| # | 項目 | URL | 自動 |
|---|------|-----|------|
| 1 | サイトアクセス | https://izumo.uranow.jp/sp/ | ○ |
| 2 | キャリアログイン | career_login.html | ○（フォーム構造検証） |

### ■従量結果（6項目）
| # | 項目 | 確認内容 | 自動 |
|---|------|---------|------|
| 3 | URLアクセス | ppv.do?id=ppvXXX&mode=confirm | ○ |
| 4 | 一人用/二人用 | personType表示 | ○ |
| 5 | アイコン | 画像表示 | ○ |
| 6 | 価格 | 登録価格と一致 | ○ |
| 7 | ガイド文 | テキスト存在 | ○ |
| 8 | 小見出し | 登録小見出しと一致 | ○ |

### ■一部無料結果（3項目）
| # | 項目 | 確認内容 | 自動 |
|---|------|---------|------|
| 9 | 小見出し表示 | 全件表示 | ○ |
| 10 | 原稿なし非表示 | 「原稿がありません」がない | ○ |
| 11 | エラー非表示 | エラー文言がない | ○ |

### ■鑑定結果（5項目）
| # | 項目 | 確認内容 | 自動 |
|---|------|---------|------|
| 12 | 課金額 | 課金画面の価格・購入ボタン検証 | ○（構造確認: 最大conf 4 / 課金テスト: conf 5可） |
| 13 | 小見出し表示 | 全件表示 | ○ |
| 14 | 原稿なし非表示 | 「原稿がありません」がない | ○ |
| 15 | エラー非表示 | エラー文言がない | ○ |
| 16 | 誘導従量 | 誘導PPV表示 | ○ |

### ■新着枠（1項目）
| # | 項目 | 確認内容 | 自動 |
|---|------|---------|------|
| 17 | 新着メニュー | ?ymd=YYYYMMDDで表示 | ○ |

### ■アクセス解析（2項目）
| # | 項目 | 確認内容 | 自動 |
|---|------|---------|------|
| 18 | 購入カウント | MKB解析画面 | ○（プロキシ経由自動アクセス） |
| 19 | メニュー情報 | 名前・価格表示 | ○（プロキシ経由自動アクセス） |

## 信頼度判定

| レベル | 意味 | 自動判定条件 |
|--------|------|-------------|
| 5 | 完全確認 | 全要素が期待値と一致 |
| 4 | ほぼ確認 | 主要要素一致、軽微差異 |
| 3 | 要目視 | 一部不一致 |
| 2 | 問題可能性 | 複数不一致 |
| 1 | 要調査 | 要素未検出/エラー |

## 実行手順

### 方法1: Web UI（推奨）

1. check.html を開く
   ```
   http://localhost:5558/check.html?ppv_id={PPV_ID}
   ```

2. PPV ID入力 → 「登録データ読込」

3. 「全項目一括チェック」または個別「自動確認」

4. 結果確認 → 「チェック結果を保存」

5. 必要に応じて「Excelエクスポート」

### 方法2: Playwright MCP（手動）

1. ブラウザを起動
   ```
   browser_navigate url="https://izumo.uranow.jp/sp/"
   ```

2. 各URLにアクセスしてスナップショット
   ```
   browser_navigate url="https://izumo.uranow.jp/sp/ppv.do/?id=ppv{PPV_ID}&mode=confirm"
   browser_snapshot
   ```

3. 内容を目視確認

## 関連ファイル

| ファイル | 場所 |
|---------|------|
| check.html | rohan/frontend/check.html |
| check.py | rohan/backend/routers/check.py |
| check_playwright.py | rohan/backend/routers/check_playwright.py |
| ステートマシン図 | chk/check_state_machine_viewer.html |

## WebMoney課金テスト（E2E）

### 概要
WebMoneyプリペイドカードを使って実際に課金を行い、決済後の結果ページを検証する。
自動チェック（構造確認のみ）では最大confidence=4だが、課金テスト完了後はconfidence=5が可能。

### 安全機構
| 機構 | 実装 |
|------|------|
| opt-in専用 | `POST /api/check/payment-test`（auto-checkからは呼ばれない） |
| バッチ除外 | ボタンclass=`payment-test-btn`（`auto-check-btn`ではない） |
| 二重確認 | JS側 `confirm()` x 2回（金額+最終確認） |
| 残高事前チェック | `remaining_balance >= price_with_tax` 検証後に実行 |
| 価格上限 | `safety.max_price_yen` ハードキャップ（デフォルト3000円） |
| PPV ID検証 | 正規表現 `^\d{5,12}$` で形式検証 |
| 使用追跡 | 決済後に残高減算・used_count増加・last_used記録 |

### 決済フロー（8ステップ）
```
Step 1: confirm画面アクセス (/open/ppv.do/?id=ppv{id}&mode=confirm)
Step 2: WebMoneyボタン検出・クリック（セレクタ3段階フォールバック）
Step 3: www.webmoney.ne.jp でプリペイド番号入力
Step 4: 「お支払いを行う」クリック（※ここから不可逆）
Step 5: 管理番号・残高確認（テキスト抽出）
Step 6: 「ご利用サイトに戻る」クリック
Step 7: 「特別鑑定開始」クリック
Step 8: mode=view到達確認
```

### 決済後の自動検証
決済完了後、以下のチェック項目を自動実行しconfidence=5を返却可能：
- `paid-subtitle`: 購入セッション付きcheckerで包括検証（タイトル一致 + 原稿テキスト全文照合 + コーナー数検証）
- `free-komi-type`: 無料ページの特殊小見出しCSS検証（独立チェック、check_komi_type_css()）
- `paid-komi-type`: 課金ページの特殊小見出しCSS検証（独立チェック、check_komi_type_css()）
- `paid-no-error`: 購入セッション付きcheckerでエラー非表示確認
- `paid-yudo`: 購入セッション付きcheckerで誘導PPV確認

### 関連ファイル
| ファイル | 内容 |
|---------|------|
| check_payment.py | WebMoneyPaymentExecutor（決済自動化コア） |
| webmoney_prepaid.json | プリペイド番号・残高設定（data/下、gitignore対象） |

### プリペイド管理API
- `GET /api/check/prepaid-status` — カード一覧と残高（番号はマスク表示）
- `POST /api/check/prepaid-update` — 残高手動修正

### 実行手順
1. check.html を開く → PPV ID入力 → 登録データ読込
2. 「課金テストパネル」でプリペイド番号を入力
3. 残高確認（自動表示）
4. 「課金テスト実行」クリック → 二重確認ダイアログ
5. 8ステップが順次実行（進捗バー表示）
6. 完了後: paid-subtitle/paid-no-error/paid-yudo が confidence=5 に更新
7. webmoney_prepaid.json の残高が自動更新される

### エラーハンドリング
| ステップ | 失敗時 | リカバリ |
|---------|--------|---------|
| Step 1-3 | 即エラー返却 | 残高変更なし |
| Step 4 | 60sタイムアウト | 手動確認促す |
| Step 5-8 | 部分成功 | 残高は減算済み、スクリーンショットで手動検証 |

## 注意事項

- **プロキシ自動化**: アクセス解析（#18, #19）はSquidプロキシ経由で自動アクセス（VPN不要）
- **MKBフォーム操作**: アクセス解析ページはデフォルトimode表示。自動チェックではsite_id選択（onchange auto-submit）→ carrier=open選択（value=110, label fallback）→更新ボタンクリックの3段階フォーム操作を実行
- **課金画面**: #12は構造確認（auto-check、最大conf 4）と課金テスト（E2E、conf 5可）の2モード
- **キャリアログイン**: #2はフォーム要素+入力欄+キーワード検出で自動検証
- **二人用**: 相手情報登録済みでないと鑑定不可

## komi_type 命名変換マッピング

rohan登録時のkomi_typeとizumo本番サイトのCSSクラス名には表記の揺れがある。

| rohan登録値 | izumo web CSS class | h3 class | 変換ルール |
|------------|-------------------|----------|-----------|
| komi_normal | komi_normal | tit_komi_normal | 完全一致 |
| komi_jyuyou1 | komi_juyo | tit_komi_juyo | 末尾`1`削除 + `jyuyou`→`juyo` |
| komi_ura1 | komi_ura | *(特殊レイアウト)* | 末尾`1`削除 |
| komi_honne1 | komi_honne | tit_komi_honne | 末尾`1`削除 |
| komi_yesno | komi_yesno | tit_komi_yesno | 完全一致 |

変換は `_convert_komi_type()` 静的メソッドで実装済み（check_playwright.py）。
`subtitleDetails` フィールドが registered-data API に追加済み（title + komiType）。

### komi_ura 特殊レイアウト
- h3は装飾ヘッダー「出雲の母には隠せない！あの人の裏本音」+画像
- 実際の小見出しテキストはh4で表示（h3ではない）
- ●●●プレースホルダーがリスト項目として表示

### Phase 3 拡張チェック手順（一部無料ページ）
1. PPVページ → 「一部無料で読む」クリック → 中間ページでタイトル・アイコン一致確認
2. 「一部無料鑑定を開始」クリック → 無料結果ページでタイトル・アイコン一致確認
3. 各小見出しセクションのCSSクラスがrohan登録komi_typeと一致するか確認（上記変換ルール適用）
4. 小見出しテキストが登録データと一致するか確認

## トラブルシューティング

| 問題 | 対処 |
|------|------|
| ページ読込タイムアウト | 再実行、ネットワーク確認 |
| 要素が見つからない | セレクタ確認、ページ構造変更チェック |
| 信頼度が低い | スクリーンショットで目視確認 |
| VPNエラー | VPN接続確認後に再実行 |
| PPVページがトップにリダイレクトされる | 認証が必要。check.htmlの「認証取得」ボタンまたはPlaywright MCPでログインして認証状態を保存する |
| 認証バッジが「期限切れ」 | 60分以上経過。再度「認証取得」を実行する |

## 認証状態管理

### 認証が必要な理由
PPVページ（`/open/ppv.do/`）はログイン済みユーザーのみアクセス可能。非認証でアクセスすると`/open/index.html`にリダイレクトされる。

### 認証状態API
- `GET /api/check/auth-status?site_code=482` - 認証状態確認（available/ageMinutes/stale）
- `POST /api/check/auth-capture?site_code=482` - 非headlessブラウザでログイン→認証状態保存

### 認証状態ファイル
- 保存先: `data/auth_states/auth_state_{site_code}.json`
- 有効期限: 60分（超過で`stale`判定）
- 自動チェック時: ファイルが存在すれば自動的に使用

### check.html認証バッジ
- 🔴 未認証（auth-none）: 認証状態ファイルなし
- 🟢 認証済（auth-ok）: 有効な認証状態あり
- 🟡 期限切れ（auth-stale）: 60分超過

### 認証取得手順（Playwright MCP）
1. ログインページにナビゲート: `https://izumo.uranow.jp/open/regist/career_login.html`
2. 「占いID」でログイン（メールアドレス/パスワード）
3. ログイン成功後、`page.context().storageState({path: '...'})` で認証状態保存
4. 保存先: `/data/auth_states/auth_state_482.json`
