---
name: image-collection
description: 参考画像（教師データ）の収集方法・ベストプラクティス。手動収集からPlaywright自動化まで。
---

# 参考画像収集スキル

## 収集元分類

### 1. 自社既存画像
- 既存プロジェクトの成果物
- 社内アーカイブ
- **フロー**: フォルダ一括インポート → タグ付け → カテゴリ分類

### 2. Web収集（手動DL）
- Pinterest、Google画像検索、Unsplash等
- **フロー**: 手動DL → メタデータ記録 → インポート

### 3. AI生成画像
- 他の生成AIの出力を参考にする場合
- **注意**: 利用規約を確認

## 収集時の必須メタデータ

| フィールド | 必須 | 説明 |
|-----------|------|------|
| source_url | 推奨 | 原典URL |
| source_name | 推奨 | 収集元サービス名 |
| category | 推奨 | カテゴリ（人物/風景/イラスト等） |
| tags | 任意 | 特徴タグ（カンマ区切り） |
| description | 任意 | 画像の説明 |

## 画像品質チェックリスト

- [ ] 解像度: 最低512x512以上推奨
- [ ] アスペクト比: 目的に合っているか
- [ ] 色調: 参考にしたいスタイルが明確か
- [ ] 構図: 参考にしたい要素が含まれているか
- [ ] ノイズ: 圧縮アーティファクトが少ないか

## 著作権・利用規約注意事項

### 安全に使える画像
- 自社撮影/作成画像
- CC0 / Public Domain
- 商用利用可能なストック写真
- AI生成画像（自社生成）

### 注意が必要
- Pinterest: 個人利用のみ、再配布不可
- Google画像検索: ライセンス確認必要
- SNS投稿画像: 著作権は投稿者に帰属

### 推奨フロー
1. 画像を保存
2. 原典URLを記録
3. ライセンス/利用規約を確認
4. メタデータとともにインポート
5. 社内参考用途のみに限定

## makeimgでのインポート方法

### API経由
```bash
curl -X POST http://localhost:5560/api/references \
  -H "x-api-token: makeimg_dev_token" \
  -F "file=@image.png" \
  -F "source_url=https://example.com" \
  -F "source_name=manual" \
  -F "category=illustration" \
  -F "tags=style,colorful" \
  -F "description=参考スタイル"
```

### Web UI
1. 「Generate」タブの右パネル（将来: 参考画像管理画面追加予定）
2. ドラッグ&ドロップまたはファイル選択
3. メタデータ入力

## 将来拡張

### Playwright自動収集（Phase 3）
- Pinterest ボード → 画像一括DL
- Google画像検索 → フィルタ付き収集
- 自動タグ付け（BLIP/CLIP）

## 知見蓄積エリア

<!-- 新しい発見はここに追記 -->
