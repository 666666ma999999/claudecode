---
name: project-cross-pc-handoff
description: |
  gitignore 対象の機密データ（顧客 PII・認証情報・大容量データ）を含む既存プロジェクトを、
  別 PC / 別 Mac で安全に継続できる状態へ移すための設計・監査・手順化スキル。
  資産の 5 分類（Code / Raw PII data / Derived data / Secrets / Runtime）、docs/data-sources.md
  と docs/setup-runbook.md の整備、gitignore allowlist 落とし穴の検査、ランタイムの Docker
  ピン留め、push 前セキュリティ監査、明示 git add 運用、別環境での実機 end-to-end 検証を扱う。
  キーワード: 別PC引き継ぎ, クロスPC, 別Macで続き, 既存プロジェクト移行, handoff,
  raw data 受け渡し, 再生成手順, データ台帳, data-sources.md, setup-runbook.md,
  gitignore 引き継ぎ, pandas バージョン不整合, ランタイム固定, Docker 化
  NOT for: 新しい Mac 全体の初期構築（→ machine-bootstrap）、新規プロジェクト初期化
  （→ project-bootstrap）、secrets 保管基盤そのものの構築（→ secret-vault-setup）
user_invocable: true
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep]
---

# project-cross-pc-handoff

gitignore 対象の機密データを持つ既存プロジェクトを、別 PC で `git clone` した後に
「分析・開発が**同じ結果で**再現できる状態」へ引き継ぐためのスキル。

## いつ使うか

- 「このプロジェクトを別 PC でも進められるようにしたい」
- 「gitignore してあるデータを次の PC にどう渡すか」
- 「他のマシン / 2 台目の Mac で作業を続けたい」

**前提（Prerequisite）**: 別 PC 自体が未整備なら、先に `machine-bootstrap`（Claude/Codex/MCP
環境構築）。本スキルはその後、**プロジェクトごと**に実行する。役割分担:

| | machine-bootstrap | 本スキル |
|---|---|---|
| 対象 | PC そのものの開発環境 | 個別プロジェクトのデータ・コード・ランタイム |
| 単位 | 1 台につき 1 回 | プロジェクトごと |
| 失敗モード | ツール install 漏れ | PII 漏洩・再現不能・誤 push・結果が PC ごとに違う |

**NOT for**: 新 Mac の環境構築（`machine-bootstrap`）/ 新規プロジェクト作成（`project-bootstrap`）/
secrets 保管基盤の構築（`secret-vault-setup`）。

## 成果物（Outcome）

完了時に以下が揃う:
- `docs/data-sources.md` — データ資産台帳（分類・保管先・再生成手順）
- `docs/setup-runbook.md` — 別 PC 完全手順（clone → データ取得 → 再生成 → 検証）
- ランタイム固定の仕組み（Dockerfile + 依存の exact pin、または lockfile）
- `.gitignore` の検証結果（機密は確実にブロック・コードは追跡）
- push 前セキュリティ監査の結果
- **別環境での end-to-end 実行成功の確認** — これが無いと「完了」ではない

## 5 分類モデル（Asset Model）

プロジェクトの全資産を 5 つに分類し、それぞれ別経路で扱う:

| 分類 | 例 | 引き継ぎ方法 |
|---|---|---|
| **Code** | スクリプト・設定テンプレ・docs・runbook | **Git**（clone で入手） |
| **Raw data** | 顧客 PII の CSV/Excel・元データ | **外部ストレージ**（Drive/S3 等）。Git 禁止 |
| **Derived data** | 集計済 pkl・キャッシュ・特徴量 | **再生成**。source of truth にしない・Git/共有ストレージに載せない（一時ローカルキャッシュは可） |
| **Secrets** | API キー・サービスアカウント JSON・認証情報 | **別経路**（パスワードマネージャ等）。Drive 禁止 |
| **Runtime** | 言語・ライブラリのバージョン（Python/pandas 等） | **Docker でピン留め**（base image + 依存を exact `==`）。`>=` 範囲指定は別 PC で別版が入り再現性が崩れる |

判定に迷ったら:
- 生データに戻れない中間物でも、再生成可能なら Derived
- PII を含む CSV/Excel は Raw
- 認証情報を含むものは Secrets（Code に混ぜない）
- 「動くが結果が PC ごとに違う」なら Runtime 未固定を疑う

## 手順

### Phase 1 — 棚卸しと分類
- プロジェクト内の資産を洗い出し、5 分類へマッピング
- 各 Raw/Derived の source of truth を明確化

### Phase 2 — ドキュメント化
- `docs/data-sources.md` 作成（テンプレ: `assets/templates/data-sources.md`）
- `docs/setup-runbook.md` 作成（テンプレ: `assets/templates/setup-runbook.md`）
- 空欄禁止フィールド: `storage_locator` / `source_of_truth` / `regen_command`（Derived）

### Phase 3 — Git 境界監査
- `.gitignore` で `data/raw`・`secrets`・機密拡張子が確実にブロックされるか `git check-ignore -v` で検証
- **allowlist 方式の落とし穴**: デフォルト `*` 全拒否の allowlist で `!scripts/` を許可しても、
  サブディレクトリを `!scripts/**/` で再 include しないと、gitignore 仕様「親ディレクトリが
  除外されると子ファイルは再 include 不可」によりサブディレクトリ配下のコードが全除外される。
  `git check-ignore -v <subdir>/file.py` で確認し、必要なら `!scripts/**/` を追加。
- コード（.py 等）は追跡・データ（.pkl/.csv/.xlsx 等）は拒否、の両方を check-ignore で確認

### Phase 4 — 転送設計・ランタイム固定
- Raw data の取得経路を定義（ストレージ別: `references/storage-backends.md`）
- Derived data の再生成コマンドを `data-sources.md` に記録
- Secrets の別経路を `setup-runbook.md` に明記（具体的な値は書かない）
- **Runtime を Docker でピン留め**: Dockerfile + requirements を exact pin（`==`）。
  既存の検証済み結果を出した環境のバージョンに合わせる。`>=` 範囲指定は別 PC で別版が
  入り「動くが結果が変わる」を招く。

### Phase 5 — push 前セキュリティ監査
push 直前に必ず:
- `git diff --cached` の PII/秘密パターンスキャン（メール・電話・password・api_key・private key・接続文字列）
- staged にデータ拡張子（xlsx/csv/pkl/key/env/sql/db）が混入していないか
- `git diff --cached --stat` をユーザーに提示（チェックポイント）
- **明示 `git add <file>` のみ**（`git add -A`・`git add .` 禁止）
- **`git commit --no-verify` 禁止**（pre-commit hook をバイパスしない）

## よくある落とし穴（実例ベース）

| 罠 | 症状 | 対策 |
|---|---|---|
| gitignore allowlist のサブディレクトリ除外 | `!scripts/` を許可してもコードが git に入らない | `!scripts/**/` を追加。`git check-ignore -v` で確認 |
| ランタイム未固定 | clone しても別 PC で結果が再現しない（pandas 版差等） | Docker 化 + 依存 exact pin |
| 派生データを Git/共有ストレージに置く | 容量肥大・schema drift・PII 残存 | 再生成方式（raw + code から） |
| `gog drive download --out <dir>/` | ファイル名が `<fileid>_名前` になる | `--out` はフルパス指定 |
| pre-commit hook の誤検知 | `git@github.com`（SSH URL）をメール誤検知し commit block | runbook の clone URL は HTTPS 形式 |
| pandas `str` dtype での `.astype(str)` no-op | NaN(float) が残り後段で `'float' has no 'lower'` | 要素ごと `str()` で変換 |
| 設計レビューだけで完了扱い | 別環境で実行して初めて version drift・データ品質バグが出る | **必ず別環境で end-to-end 実行して検証** |

## 検証

**「別環境で実際に end-to-end 実行して成功」までが完了。** clone できた・設計レビューが通った
だけでは不十分（version drift・データ品質バグはそこでしか出ない）:
- `git clone` でコード一式が揃う
- raw data の取得先（locator）が解決する
- Docker build でランタイムが再現する
- derived data が `regen_command` で再生成でき、row count / checksum / golden 値が一致
- テスト・パイプラインが別環境で完走する
- secrets が Git にも共有ストレージにも混入していない

## Red Flags（検知したら停止）

- Raw data（PII）が Git に入っている / staged にある
- Secrets が Drive・共有ストレージに置かれている
- Derived data が source of truth 化している（再生成できない）
- ランタイム（言語/ライブラリ版）が固定されていない・`>=` 範囲指定のまま
- `git add .` / `git add -A` を前提にした手順
- runbook が人依存の曖昧記述（「適宜」「いい感じに」等）
- 別環境で 1 度も実行検証せずに「引き継ぎ完了」と報告

## 関連スキル

- `machine-bootstrap` — 新 PC の環境構築（本スキルの前提）
- `project-bootstrap` — 新規プロジェクトの初期化
- `secret-management` / `secret-vault-setup` — secrets の管理基盤（参照のみ）
- `git-safety-reference` — git 安全操作
