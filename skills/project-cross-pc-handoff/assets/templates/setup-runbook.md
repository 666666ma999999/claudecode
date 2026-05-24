# <project> 別 PC セットアップ runbook

別 PC でこのプロジェクトを継続するための完全手順。
原則: **コードは Git / raw データは外部ストレージ / 派生データは再生成 / secrets は別経路**。
データ分類の詳細は [`data-sources.md`](./data-sources.md) を参照。

## 前提ツール

- git / <言語ランタイムと依存（例: Python 3 + pandas）>
- <ストレージ CLI（例: gog / aws）> 認証済み

## 手順

### 1. clone

```bash
git clone https://github.com/<owner>/<repo>.git
cd <repo>/<project>
```

> SSH URL（`git@github.com:...`）は pre-commit hook がメールアドレスと誤検知することがある。
> runbook には HTTPS URL を書く。

### 2. 着手前の安全確認

```bash
ls .git/hooks/pre-commit              # pre-commit hook の存在を確認
git ls-files <機密ゾーン>             # 何も出ないこと（PII が未追跡であること）
```

### 3. raw データ取得

[`data-sources.md`](./data-sources.md) の台帳 `storage_locator` に従って取得。

### 4. secrets（必要時のみ・別経路）

パスワードマネージャ等から受領し配置。**Git・共有ストレージ経由は禁止**。

### 5. 派生データ再生成

`data-sources.md` の `regen_command` を順に実行。派生データ（pkl 等）は Git にも
共有ストレージにも無いため、必ず再生成する。

### 6. 検証

- 再生成物の row count / checksum が台帳の値と一致
- テストスイートが全 PASS

## セキュリティ禁止事項

- `<機密ゾーン>`（data/raw・secrets 等）を commit しない
- `git add -A` / `git add .` 禁止 — 必ずファイル名を明示
- `git commit --no-verify` 禁止 — pre-commit hook をバイパスしない
- 顧客実データ（生 SQL 結果・CSV・DataFrame head）を外部 LLM に貼らない
