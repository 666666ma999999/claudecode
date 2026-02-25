# CMS命名規約（ドメイン略称方式）

各CMSはドメインのサブドメイン部分から一意な識別子を導出する。

## CMS一覧

| 識別子 | 正式名 | ドメイン | 用途 | プロジェクト |
|--------|--------|---------|------|-------------|
| hayatomo | 原稿管理CMS | hayatomo2-dev.ura9.com/manuscript/ | 原稿登録・PPV管理 | chk, rohan |
| izumo-dev | izumo開発CMS | izumo-dev.uranai-gogo.com/admin/ | 小見出し・従量更新 | rohan |
| izumo-chk | izumo検証CMS | izumo-chk.uranai-gogo.com/admin/ | 本番同期確認 | rohan |

## 命名パターン

| コンテキスト | パターン | 例 |
|-------------|---------|-----|
| config定数 | `{CMS_ID}_CMS_{用途}` | `HAYATOMO_CMS_BASE_URL` |
| env var | `{CMS_ID}_CMS_{用途}` | `HAYATOMO_CMS_USER` |
| ログタグ | `[CMS:{cms_id}]` | `[CMS:hayatomo]` |
| ドキュメント | `{cms_id} CMS` | `hayatomo CMS` |
| 会話 | 文脈明確なら「CMS」可、複数文脈では識別子必須 | |

## 新CMS追加

1. サブドメインから識別子導出 → 上記テーブルに追加
2. config.pyに `{ID}_CMS_*` 定数追加
3. MEMORY.mdに記載

## 禁止

- 汎用名 `CMS_*`（識別子プレフィックス必須）
- 識別子なしの `[CMS]` ログタグ（`[CMS:{id}]` を使う）
