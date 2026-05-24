# ストレージバックエンド別の引き継ぎ手順

`data-sources.md` の `storage_backend` / `storage_locator` の具体実装。
スキルの骨格（4 分類モデル・2 文書・gitignore 監査・push 前監査）は **provider 非依存**。
本ファイルが provider 差分を担う。新しい backend を使う場合はここに節を足す。

## 共通原則

- 台帳には `storage_backend`（種別）と `storage_locator`（所在）を**分けて**記録する。
  `Drive File ID` のような特定 provider 固定の列名にしない。
- PII を含む raw は**アクセス制御できる**ストレージに置く。「リンクを知る人全員」方式は PII では使わない。
- 認証情報そのものは secrets 扱い（台帳の storage には書かない・別経路）。

## Google Drive（`gog` CLI）

- `storage_backend`: `google-drive`
- `storage_locator`: `file_id=<ID>` または `folder_id=<ID>`
- 認証確認: `gog auth list --check`
- 取得（単体）: `gog drive download <file_id> --out <出力先フルパス>`
  （**ディレクトリ指定は不可** — `--out <dir>/` だと `<dir>/<fileid>_<名前>` と File ID 接頭辞が付く）
- 取得（フォルダ一括）: 一括 DL は File ID 接頭辞が付くため、ID を列挙して 1 件ずつフルパス指定で取得:
  ```bash
  gog drive ls --parent <folder_id> --json | jq -r '.files[].id'   # ID 一覧を確認
  gog drive download <file_id> --out <出力先フルパス>               # 1 件ずつ取得
  ```
- アップロード: `gog drive upload <path> --parent <folder_id> --json`（返却 file.id を台帳へ）
- 注意: File ID は private repo なら docs に記載可。Drive フォルダの共有は**限定共有**にする。

## Amazon S3

- `storage_backend`: `s3`
- `storage_locator`: `s3://<bucket>/<key>`
- 取得: `aws s3 cp s3://<bucket>/<key> <dir>/`
- フォルダ: `aws s3 sync s3://<bucket>/<prefix>/ <dir>/`
- 認証: AWS profile / IAM ロール。認証情報は secrets（別経路）。
- 注意: bucket は非公開・IAM で最小権限。

## 共有フォルダ / NAS

- `storage_backend`: `shared-folder`
- `storage_locator`: マウントパス or 共有リンク
- マウント前提（接続先・認証）を `setup-runbook.md` の前提ツールに明記する。

## 選定指針

| データ | 推奨 backend |
|---|---|
| 顧客 PII を含む raw | Google Drive（限定共有）/ S3（IAM 制限） |
| 大容量だが非機密 | 任意（S3 / Drive / NAS） |
| secrets | ストレージに置かない → パスワードマネージャ等 |
