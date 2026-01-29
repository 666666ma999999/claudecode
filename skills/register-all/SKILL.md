---
name: register-all
description: |
  全STEP連続実行（商品登録フル自動化）
  STEP 1～8 を連続して実行し、商品登録を完全自動化する。
  各STEPのスキルを順番に呼び出す。
  キーワード: 全STEP, 連続実行, フル自動化, 商品登録
---

# 全STEP連続実行（商品登録フル自動化）

## 概要

STEP 1～8 を連続して実行し、占い商品の登録を完全自動化する。

## 実行フロー（確認込み）

```
STEP 1: 原稿生成・PPV ID発行
    ↓ ✓ 確認: ppv_id, menu_id が生成されたか
STEP 2: メニュー登録（原稿管理CMS）
    ↓ ✓ 確認: UP済み一覧にppv_idが表示されるか
STEP 3: PPV情報登録（価格・誘導設定）
    ↓ ✓ 確認: price, guide, affinityが保存されたか
STEP 4: メニュー設定（表示フラグ・画数設定）
    ↓ ✓ 確認: 表示フラグ=1, 画数設定が正しいか
STEP 5: 売上集計登録（MKB）※VPN必須
    ↓ ✓ 確認: 「X件保存しました」メッセージ
STEP 6: 原稿本番アップ（izumo同期）
    ↓ ✓ 確認: 同期完了メッセージ、ppv_id同期済み
STEP 7: 小見出し登録（izumo反映）
    ↓ ✓ 確認: menu_idが反映済み
STEP 8: 従量自動更新
    ↓ ✓ 確認: ppv_idが自動更新一覧に表示
完了
```

## 各STEP完了確認コマンド

各STEP実行後、確認を実行:

```
/verify-step {STEP番号} --ppv-id {ppv_id} --site-id {site_id}
```

全STEP一括確認:

```
/verify-step --all --ppv-id {ppv_id} --site-id {site_id}
```

## 前提条件

1. ローカルサーバーが起動していること
2. Playwright MCP が有効であること
3. 認証情報が環境変数に設定済みであること
4. VPN接続が有効であること（STEP 5用）

## 必要な入力データ

| パラメータ | 必須 | 説明 |
|-----------|------|------|
| `site_id` | Yes | サイトID |
| `site_name` | Yes | サイト名 |
| `ppv_id` | Yes | PPV ID（5桁数字） |
| `ppv_title` | Yes | 商品タイトル |
| `manuscript_type` | Yes | 原稿タイプ（ppv, monthly, free） |
| `subtitles` | Yes | 小見出し情報（CSVまたはJSON） |
| `price` | No | 価格（デフォルト: 2000） |
| `guide` | No | 商品紹介文 |
| `affinity` | No | 0=1人用, 1=2人用（デフォルト: 0） |

## 各STEPの処理

### STEP 1: 原稿生成・PPV ID発行

- **スキル**: `/step1`
- **処理**: API呼び出しで原稿生成
- **出力**: ppv_id, menu_id, subtitles

### STEP 2: メニュー登録

- **スキル**: `/step2`
- **処理**: 原稿管理CMSに原稿を登録
- **出力**: 登録完了、menu_id確定

### STEP 3: PPV情報登録

- **スキル**: `/step3`
- **処理**: 価格・誘導設定を登録
- **出力**: 設定完了

### STEP 4: メニュー設定

- **スキル**: `/step4`
- **処理**: 表示フラグ・画数設定を登録
- **出力**: 設定完了

### STEP 5: 売上集計登録

- **スキル**: `/step5`
- **処理**: MKBにCSVアップロード
- **前提**: VPN接続必須
- **出力**: アップロード完了

### STEP 6: 原稿本番アップ

- **スキル**: `/step6`
- **処理**: izumo CMSで本番同期
- **出力**: 同期完了

### STEP 7: 小見出し登録

- **スキル**: `/step7`
- **処理**: izumo CMSで小見出し反映
- **出力**: 反映完了

### STEP 8: 従量自動更新

- **スキル**: `/step8`
- **処理**: izumo CMSで自動更新実行
- **出力**: 更新完了

## 重要: 順次実行ルール

**全STEPは必ず順次実行すること。並列実行は厳禁。**

### 全STEP依存関係マップ

```
STEP 1: 原稿生成（API）
    ↓ ppv_id, menu_id, subtitles を引き渡し
STEP 2: メニュー登録（原稿管理CMS）
    ↓ 同じCMS、セッション維持
STEP 3: PPV情報登録（?p=cms_ppv）⚠️ 並列禁止
    ↓ 同じCMS、セッション維持
STEP 4: メニュー設定（?p=cms_menu）⚠️ 並列禁止
    ↓ システム切り替え
STEP 5: 売上集計登録（MKB）※VPN必須
    ↓ システム切り替え
STEP 6: 原稿本番アップ（izumo同期）⚠️ 並列禁止
    ↓ 同じCMS、同期完了待ち
STEP 7: 小見出し登録（izumo反映）⚠️ 並列禁止
    ↓ 同じCMS、反映完了待ち
STEP 8: 従量自動更新（izumo更新）⚠️ 並列禁止
```

### 特に注意が必要なSTEP（並列実行禁止）

| 連続STEP | 同じシステム | 理由 |
|----------|-------------|------|
| STEP 2 → 3 | ○ 原稿管理CMS | menu_id引き渡し、セッション維持 |
| STEP 3 → 4 | ○ 原稿管理CMS | 同じCMS、異なるページ。データ競合 |
| STEP 6 → 7 | ○ izumo CMS | 同期完了後に反映。順序逆転でデータ不整合 |
| STEP 7 → 8 | ○ izumo CMS | 反映完了後に更新。順序逆転でデータ不整合 |

### 各STEP間の待機

各STEPの完了を確認してから次のSTEPを開始すること：
- 成功メッセージの確認（"保存しました"、"登録完了"、"反映完了" 等）
- スクリーンショットの取得
- 次STEPへの明示的な遷移
- **絶対に複数STEPを同時に開始しない**

## エラーハンドリング

### STEPごとの継続判断

| STEP | 失敗時の対応 |
|------|-------------|
| STEP 1 | 中断（原稿がないと続行不可） |
| STEP 2 | 中断（CMSへの登録必須） |
| STEP 3 | **中断推奨**（STEP 4が保存不可になる） |
| STEP 4 | 警告して続行（後で手動設定可） |
| STEP 5 | VPN確認後リトライ、または続行 |
| STEP 6 | 警告して続行（後で手動同期可） |
| STEP 7 | 警告して続行（後で手動反映可） |
| STEP 8 | 警告して終了（オプション処理） |

### 重要な依存関係エラー

| エラーパターン | 原因 | 解決方法 |
|---------------|------|---------|
| STEP 4で`{status: error}`保存失敗 | STEP 3が未完了 | STEP 3を先に実行 |
| cms_menuで保存ボタンがエラー | cms_ppvで「未登録」状態 | STEP 3でPPV情報を登録 |
| 「従量登録」クリック後「未登録」表示 | STEP 3スキップ | STEP 3から再実行 |

### 途中から再開

```
/register-from 3

※ STEP 3 から再開
※ STEP 1-2 の結果（ppv_id, menu_id）が必要
```

## 使用例

### フル実行

```
/register-all

入力:
- site_id: 482
- site_name: izumo
- ppv_id: 10001
- ppv_title: 【恋愛占い】彼の本音
- manuscript_type: ppv
- subtitles_csv: /path/to/subtitles.csv
- price: 2000
```

### 途中から再開

```
/register-from 5

入力:
- site_id: 482
- ppv_id: 10001
- menu_id: monthlyAffinity001.001
```

## 進捗表示

```
✓ STEP 1: 原稿生成完了 (ppv_id: 10001, menu_id: monthlyAffinity001.001)
✓ STEP 2: メニュー登録完了
✓ STEP 3: PPV情報登録完了
✓ STEP 4: メニュー設定完了
⏳ STEP 5: 売上集計登録中...
  STEP 6: 原稿本番アップ (待機中)
  STEP 7: 小見出し登録 (待機中)
  STEP 8: 従量自動更新 (待機中)
```

## 出力

- `success`: 全STEP成功/一部失敗
- `completed_steps`: 完了したSTEPリスト
- `failed_steps`: 失敗したSTEPリスト
- `ppv_id`: 登録されたPPV ID
- `menu_id`: 登録されたmenu_id
- `screenshots`: 各STEP完了時のスクリーンショット

## 補足

### 所要時間の目安

| STEP | 所要時間 |
|------|---------|
| STEP 1 | 30-60秒（原稿生成） |
| STEP 2 | 30-60秒 |
| STEP 3 | 10-20秒 |
| STEP 4 | 10-20秒 |
| STEP 5 | 20-30秒 |
| STEP 6 | 20-30秒 |
| STEP 7 | 10-20秒 |
| STEP 8 | 10-20秒 |
| **合計** | **約3-5分** |

### VPN接続について

STEP 5 ではMKBへのアクセスにVPN接続が必須。
VPN未接続の場合はSTEP 5 をスキップして続行し、後で手動実行も可能。

---

## 自動確認フロー（必須）

**各STEP実行後、自動で確認を行うこと。確認に失敗した場合は次STEPに進まない。**

### 確認実行パターン

```
STEP X 実行
    ↓
browser_snapshot または API呼び出し
    ↓
確認項目チェック（snapshotから検索）
    ↓
✅ OK → STEP X+1 へ
❌ NG → 対処してリトライ
```

### 確認コードテンプレート

各STEP完了後に以下を実行：

```javascript
// 共通確認関数
function verifyStep(stepNumber, snapshot, expectedTexts) {
    const results = expectedTexts.map(text => ({
        text,
        found: snapshot.includes(text)
    }));

    const allPassed = results.every(r => r.found);

    console.log(`STEP ${stepNumber} 確認結果:`, results);

    if (!allPassed) {
        const missing = results.filter(r => !r.found).map(r => r.text);
        throw new Error(`STEP ${stepNumber} 確認失敗: ${missing.join(', ')} が見つかりません`);
    }

    console.log(`✅ STEP ${stepNumber} 完了確認OK`);
    return true;
}

// 使用例
verifyStep(2, snapshot, ['48200038', '登録済み']);
verifyStep(5, snapshot, ['件保存しました']);
```

### 確認を自動化するルール

1. **各STEP実行直後**: 必ず `browser_snapshot` を取得
2. **snapshot解析**: 成功条件のテキストを検索
3. **判定**: 全条件を満たせばOK、1つでも失敗ならNG
4. **NG時**: 対処法を実行してリトライ、リトライ上限（3回）を超えたら中断

---

## 各STEP確認項目一覧

### STEP 1: 原稿生成・PPV ID発行

| 確認項目 | 成功条件 |
|---------|---------|
| ppv_id | 8桁数字が発行された |
| menu_id | 形式: `{prefix}{number}.{subtitle}` |
| 原稿テキスト | 小見出し数が期待値と一致 |

### STEP 2: メニュー登録

| 確認項目 | 成功条件 |
|---------|---------|
| UP済み一覧 | ppv_idが表示される |
| ステータス | 「登録済み」表示 |
| 小見出し数 | 期待値と一致 |

### STEP 3: PPV情報登録

| 確認項目 | 成功条件 |
|---------|---------|
| price | 設定値（例: 2000） |
| guide | 商品紹介文が入力済み |
| affinity | 0 or 1 が設定済み |
| yudo_ppv_id_01 | 誘導先が設定済み |
| dmenu_sid | `00073734509` |

### STEP 4: メニュー設定

| 確認項目 | 成功条件 |
|---------|---------|
| 表示フラグ | 1 |
| 画数設定 | monthlyAffinity: 2, fixedCode: 設定なし |
| 蔵干取得 | monthlyAffinity: 1 |
| 保存結果 | `{status: error}` でないこと |

### STEP 5: 売上集計登録

| 確認項目 | 成功条件 |
|---------|---------|
| 結果メッセージ | 「X件保存しました」 |
| エラー | public_dateエラーなし |

### STEP 6: 原稿本番アップ

| 確認項目 | 成功条件 |
|---------|---------|
| 同期結果 | 「同期完了」メッセージ |
| ppv一覧 | ppv_idが同期済み |

### STEP 7: 小見出し登録

| 確認項目 | 成功条件 |
|---------|---------|
| 反映結果 | 「反映完了」メッセージ |
| メニュー一覧 | menu_idが反映済み |

### STEP 8: 従量自動更新

| 確認項目 | 成功条件 |
|---------|---------|
| 登録結果 | 「登録しました」メッセージ |
| 一覧確認 | ppv_idが表示される |
| テーマ | カテゴリコードに対応したテーマが選択済み |

---

## 確認失敗時の対処

| STEP | よくある失敗 | 対処法 |
|------|-------------|--------|
| 3 | キャリア固定値が空 | dmenu_sid等を手動入力 |
| 4 | 保存でerror | STEP 3が未完了。戻って実行 |
| 5 | 0件保存+エラー | CSVを原稿管理CMSから再ダウンロード |
| 5 | public_dateエラー | 日付を当日以降に修正 |
| 7 | menu_id見つからない | STEP 6の同期を再実行 |
| 8 | ppv_id選択不可 | STEP 6,7を先に完了させる |
