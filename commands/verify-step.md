# /verify-step - STEP完了確認コマンド

各STEPの登録結果を確認し、次STEPへ進めるか判定する。

## 引数

```
/verify-step [STEP番号] [オプション]
```

| 引数 | 説明 |
|------|------|
| STEP番号 | 1-8 の確認対象STEP |
| --all | 全STEPを順番に確認 |
| --ppv-id ID | 対象PPV ID指定 |
| --site-id ID | 対象サイトID指定 |

## 各STEPの確認項目

### STEP 1: 原稿生成・PPV ID発行

| 確認項目 | 方法 | 成功条件 |
|---------|------|---------|
| PPV ID発行 | auto.html レスポンス確認 | ppv_id が8桁数字 |
| menu_id生成 | auto.html レスポンス確認 | menu_id が生成されている |
| 原稿生成 | 原稿テキスト確認 | 小見出し数が期待値と一致 |

```javascript
// 確認コード
const result = await fetch('/api/registration-state/auto-generated');
const data = await result.json();
console.assert(data.ppv_id, 'PPV ID未発行');
console.assert(data.menu_id, 'menu_id未生成');
```

### STEP 2: メニュー登録（原稿管理CMS）

| 確認項目 | 方法 | 成功条件 |
|---------|------|---------|
| 原稿登録 | UP済み一覧確認 | ppv_idが一覧に表示 |
| 小見出し数 | 詳細画面確認 | 期待する小見出し数と一致 |
| ステータス | 一覧のステータス列 | 「登録済み」表示 |

```
URL: https://hayatomo2-dev.ura9.com/manuscript/?p=up&site_id={site_id}

確認手順:
1. UP済み一覧にアクセス
2. ppv_idで検索
3. 該当行が存在することを確認
4. ステータスが「登録済み」であること
```

### STEP 3: PPV情報登録（従量登録）

| 確認項目 | 方法 | 成功条件 |
|---------|------|---------|
| 価格設定 | ?p=cms_ppv画面 | price = 設定値 |
| 誘導設定 | 誘導フィールド確認 | yudo_ppv_id_01, yudo_menu_id_01 が設定済み |
| guide | テキストエリア確認 | 商品紹介文が入力済み |
| affinity | セレクト確認 | 0 or 1 が設定済み |

```
URL: ?p=cms_ppv&site_id={site_id}&ppv_id={ppv_id}

確認手順:
1. PPV詳細画面にアクセス
2. 各フィールドの値を取得
3. 期待値と比較
```

### STEP 4: メニュー設定（従量管理詳細）

| 確認項目 | 方法 | 成功条件 |
|---------|------|---------|
| 表示フラグ | ?p=cms_menu画面 | inputs[21] = 1 |
| 画数設定 | カラム40確認 | monthlyAffinityの場合: 2 |
| 蔵干設定 | カラム94,95確認 | monthlyAffinityの場合: 1 |

```
URL: ?p=cms_menu&site_id={site_id}&ppv_id={ppv_id}

確認手順:
1. メニュー設定画面にアクセス
2. テーブルの各カラム値を取得
3. menu_idプレフィックスに応じた期待値と比較
```

### STEP 5: 売上集計登録（MKB）

| 確認項目 | 方法 | 成功条件 |
|---------|------|---------|
| CSV登録 | 結果メッセージ確認 | 「X件保存しました」表示 |
| エラー確認 | エラーメッセージ確認 | エラーなし |

```
URL: http://swan-manage.aws.mkb.local/csvs/csv_in/SitePpv/

確認手順:
1. インポート結果ページのメッセージ取得
2. 「保存しました」が含まれることを確認
3. エラーメッセージがないことを確認
```

### STEP 6: 原稿本番アップ（izumo同期）

| 確認項目 | 方法 | 成功条件 |
|---------|------|---------|
| 同期完了 | 同期結果画面 | 「同期完了」メッセージ |
| PPV確認 | ppv一覧 | ppv_idが同期済み |

```
URL: https://{user}:{pass}@izumo-dev.uranai-gogo.com/admin/

確認手順:
1. 同期結果を確認
2. PPV一覧でppv_idを検索
3. 同期日時が更新されていること
```

### STEP 7: 小見出し登録（izumo反映）

| 確認項目 | 方法 | 成功条件 |
|---------|------|---------|
| 反映完了 | 反映結果画面 | 「反映完了」メッセージ |
| menu_id確認 | メニュー一覧 | menu_idが反映済み |

```
URL: https://{user}:{pass}@izumo-dev.uranai-gogo.com/admin/menu.html

確認手順:
1. menu_idで検索
2. 該当行の「反映」状態を確認
3. 反映済みであること
```

### STEP 8: 従量自動更新

| 確認項目 | 方法 | 成功条件 |
|---------|------|---------|
| 登録完了 | 登録結果画面 | 「登録しました」メッセージ |
| 一覧確認 | 自動更新一覧 | ppv_idが一覧に表示 |
| テーマ確認 | 詳細確認 | 設定したテーマが選択済み |

```
URL: https://{user}:{pass}@izumo-dev.uranai-gogo.com/admin/ppv_automation_opener.html

確認手順:
1. 一覧ページにアクセス
2. ppv_idで検索
3. 該当行が存在することを確認
4. テーマ、公開日が正しいこと
```

## 出力フォーマット

```markdown
## STEP X 確認結果

**対象**: PPV ID {ppv_id} / Site ID {site_id}

| 確認項目 | 結果 | 詳細 |
|---------|------|------|
| 項目1 | ✅ OK | 値: xxx |
| 項目2 | ❌ NG | 期待: xxx, 実際: yyy |
| 項目3 | ⚠️ WARN | 確認推奨 |

**判定**: ✅ STEP X 完了 / ❌ STEP X 未完了

**次のアクション**:
- ✅の場合: STEP X+1 へ進む
- ❌の場合: 問題を修正して再実行
```

## 全STEP確認（--all）

```
/verify-step --all --ppv-id 48200037 --site-id 482

出力:
## 全STEP確認結果

| STEP | 名称 | 結果 |
|------|------|------|
| 1 | 原稿生成・PPV ID発行 | ✅ |
| 2 | メニュー登録 | ✅ |
| 3 | PPV情報登録 | ✅ |
| 4 | メニュー設定 | ✅ |
| 5 | 売上集計登録 | ✅ |
| 6 | 原稿本番アップ | ✅ |
| 7 | 小見出し登録 | ✅ |
| 8 | 従量自動更新 | ✅ |

**総合判定**: 全STEP完了 ✅
```

## 注意事項

- 各STEPの確認にはPlaywright MCPを使用
- VPN接続が必要なSTEP（5）は事前に確認
- Basic認証が必要なSTEP（6,7,8）はURL埋め込みで対応
- 確認に失敗しても自動修正は行わない（報告のみ）
