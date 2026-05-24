# <project> データソース台帳

`.gitignore` 対象の機密データ・派生データの所在と引き継ぎ方法。
別 PC セットアップの完全手順は [`setup-runbook.md`](./setup-runbook.md) を参照。

## 資産台帳

| asset_name | classification | storage_backend | storage_locator | source_of_truth | regen_command | verification | checksum_or_row_count | updated_at | owner | notes |
|---|---|---|---|---|---|---|---|---|---|---|
| 例: raw_export.xlsx | raw | google-drive | `file_id=1xxxxx` | （raw 自身）| — | 取得後サイズ確認 | 134MB | 2026-05-21 | 管理者 | 元データ |
| 例: features.pkl | derived | （置かない）| — | raw + code | `python3 scripts/build.py` | test 実行 | 84,687 行 | 2026-05-21 | — | 再生成物 |

**列の定義**:
- `classification`: `code` / `raw` / `derived` / `secret`
- `storage_backend`: `git` / `google-drive` / `s3` / `shared-folder` / `password-manager`
- `storage_locator`: backend ごとの所在（Drive=`file_id=...`、S3=`s3://bucket/key`、等）。
  backend 別の取得方法は handoff スキルの `references/storage-backends.md`
- `source_of_truth`: その資産の正本（derived は「raw + code」等）
- `regen_command`: derived の再生成コマンド（**空欄禁止**）
- `checksum_or_row_count`: 再生成・取得の正しさを照合する値

## secrets

> 値そのものは絶対に書かない。「何が必要か」と「どこから受け取るか」だけ。

| secret_name | 用途 | 受け渡し経路 |
|---|---|---|
| 例: service-account.json | 〜API 認証 | パスワードマネージャ |

## 新規データ追加時

1. ローカルの gitignore 対象ゾーンに配置
2. ストレージへアップロード
3. 本台帳に行を追記
4. メタデータのみ commit（実ファイルは gitignore で除外）
