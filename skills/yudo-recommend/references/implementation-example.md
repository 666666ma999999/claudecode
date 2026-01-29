# 実装例: 誘導メニューレコメンド（rohanプロジェクト）

## 概要

占いサイトのメニューCSVから、誘導先メニュー（yudo_ppv_id_01/02, yudo_menu_id_01/02）を自動推定する機能。

## データ構造

```
ppv_id: 001
title: 口コミ殺到！【究極の"自分知り"鑑定】あなたという人間/特別な魅力
guide: あなたの人生の中で最も大きな転機が近づいているわ...
yudo_ppv_id_01: ppv003
yudo_menu_id_01: boin001.027
yudo_ppv_id_02: ppv012
yudo_menu_id_02: boinGyoun001.036
```

## 分析結果

### カテゴリ分布
- 恋愛片思い: 263件（90%）
- 結婚: 10件
- 自分知り: 7件
- 年運: 6件
- 仕事: 3件

### 誘導パターン
- 同カテゴリ内誘導が主流（94%）
- 人気誘導先TOP3: ppv009（23回）, ppv002（18回）, ppv011（15回）

### セット関係
- yudo_ppv_id と yudo_menu_id は1対1または1対多
- 1対多の場合は最頻出のmenu_idを使用

## 実装ファイル

### 推定モジュール
`/Users/masaaki/Desktop/prm/rohan/backend/utils/yudo_predictor.py`

主要クラス・関数:
- `MenuItem`: データクラス
- `YudoTarget`: 推定結果（ppv_id + menu_id）
- `YudoPredictor`: 推定クラス
- `build_ppv_to_menu_mapping()`: ID→menu_idマッピング構築
- `build_few_shot_prompt()`: プロンプト構築

### APIエンドポイント
`/Users/masaaki/Desktop/prm/rohan/backend/routers/registration.py`

```python
@router.post("/api/yudo-recommend")
async def recommend_yudo_menu(request: YudoRecommendRequest):
    # title, guide から yudo_ppv_id_01/02, yudo_menu_id_01/02 を推定
```

### フロントエンド
`/Users/masaaki/Desktop/prm/rohan/frontend/auto.html`

- グローバル変数: `yudoRecommendResult`
- 表示関数: `displayYudoRecommend()`
- 表示エリア: `#yudo-recommend-inline`

## API仕様

### リクエスト
```json
{
  "title": "商品タイトル",
  "guide": "商品紹介文",
  "csv_path": "/path/to/data.csv"
}
```

### レスポンス
```json
{
  "success": true,
  "yudo_ppv_id_01": "ppv003",
  "yudo_menu_id_01": "boin001.027",
  "yudo_ppv_id_02": "ppv012",
  "yudo_menu_id_02": "boinGyoun001.036",
  "model_used": "gemini-2.5-pro",
  "message": "レコメンド完了 (17857ms)"
}
```

## テスト方法

```bash
curl -X POST http://localhost:5558/api/yudo-recommend \
  -H "Content-Type: application/json" \
  -d '{
    "title": "口コミ殺到！【究極の自分知り鑑定】",
    "guide": "あなたの人生の中で最も大きな転機が近づいているわ。"
  }'
```

## 精度

- yudo_ppv_id_01 一致率: 40-60%（サンプルによる）
- カテゴリ内誘導は正確に学習
- 近隣番号への誘導パターンは学習困難（56%が近隣番号誘導）
