# 本番チェック用URLテンプレート

## サイト別ベースURL

| サイトコード | サイト名 | ベースURL |
|-------------|---------|-----------|
| 482 | 出雲の母 | https://izumo.uranow.jp/sp |

## URL生成テンプレート

### 従量メニュー（購入画面）
```
{BASE_URL}/ppv.do/?id=ppv{PPV_ID}&mode=confirm
```
例: https://izumo.uranow.jp/sp/ppv.do/?id=ppv48200008&mode=confirm

### 鑑定結果（課金後）
```
{BASE_URL}/ppv.do/?id=ppv{PPV_ID}
```
例: https://izumo.uranow.jp/sp/ppv.do/?id=ppv48200008

### 新着枠確認
```
{BASE_URL}/pay/?ymd={YYYYMMDD}
```
例: https://izumo.uranow.jp/sp/pay/?ymd=20260131

### ログイン
```
{BASE_URL}/
{BASE_URL}/regist/career_login.html
```

### 一部無料鑑定
```
{BASE_URL}/ppv.do/index.html?spmode=spppvstart&abid={ABID}&id=ppv{PPV_ID}&ad=paytop&mode=index_free&email=
```
※ABIDは自動生成

### アクセス解析（VPN必須）
```
http://swan-manage.aws.mkb.local/analyzemobiles/ppv/
```

## WebMoneyテストコード

```
taar6jecngxkq438
```
※テスト用プリペイド番号

## 確認用クエリパラメータ

| パラメータ | 用途 | 例 |
|-----------|------|-----|
| ?ymd=YYYYMMDD | 特定日の新着表示 | ?ymd=20260131 |
| &mode=confirm | 購入確認画面 | ppv.do?id=ppvXXX&mode=confirm |
