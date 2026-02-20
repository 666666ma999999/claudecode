# Git Safety ルール

## 1. 禁止コマンド一覧

以下のgitコマンドは**絶対に実行禁止**。permissions.deny + hookで二重ブロック済み。

### Force Push（全形式）

| 禁止コマンド | 理由 | 代替手段 |
|-------------|------|---------|
| `git push --force` | リモート履歴の破壊 | `git push --force-with-lease`（他者の変更を上書きしない） |
| `git push -f` | 同上 | 同上 |
| `git push origin +main` | +refspecによるforce-push回避パターン | `git push --force-with-lease` |
| `git push *+*:*` | 任意の+refspec形式 | 通常のpush |

### 履歴破壊

| 禁止コマンド | 理由 | 代替手段 |
|-------------|------|---------|
| `git reset --hard` | コミット済み変更の喪失 | `git stash` → `git reset --soft` |
| `git checkout .` / `git checkout -- .` | 全ファイルの変更破棄 | 個別ファイル指定: `git checkout -- <file>` |
| `git restore .` / `git restore --staged .` | 同上 | 個別ファイル指定 |
| `git clean -f` / `-df` / `-fd` | 未追跡ファイルの完全削除 | `git clean -n`（ドライラン）で確認後、個別削除 |
| `git branch -D` | マージ済み確認なしのブランチ削除 | `git branch -d`（マージ済みのみ削除） |

### 共有ブランチ操作

| 禁止コマンド | 理由 | 代替手段 |
|-------------|------|---------|
| `git rebase *main*` | 共有ブランチの履歴改変 | `git merge main` |
| `git rebase *master*` | 同上 | `git merge master` |

### 参照直接操作

| 禁止コマンド | 理由 | 代替手段 |
|-------------|------|---------|
| `git update-ref` | gitの内部参照を直接書き換え | 通常のgitコマンドを使用 |

## 2. コミット禁止ファイル（14カテゴリ）

以下のファイルは**絶対にgitにコミットしない**。`~/.gitignore_global` + `file-protection.sh` + `security-scan.sh`で三重防御。

| # | カテゴリ | パターン | 理由 |
|---|---------|---------|------|
| 1 | 環境変数 | `.env`, `.env.*`, `.env.local`, `.envrc`, `.direnv/` | API鍵・DB接続情報を含む |
| 2 | クラウド認証 | `credentials.csv`, `google-service-account.json`, `*.tfvars`, `*.tfplan`, `*.tfstate*` | クラウドアカウントへの不正アクセス |
| 3 | SSH/TLS鍵 | `id_rsa*`, `id_ed25519*`, `*.pem`, `*.key`, `*.p12`, `*.pfx` | 秘密鍵漏えい |
| 4 | DBダンプ | `*.sqlite3`, `*.sqlite`, `dump.sql`, `*.dump`, `*.db-wal`, `*.db-shm` | 全データ漏えい |
| 5 | 依存パッケージ | `node_modules/`, `vendor/`, `__pycache__/`, `.venv/`, `venv/` | リポジトリ肥大化 |
| 6 | OS生成 | `.DS_Store`, `Thumbs.db`, `Desktop.ini`, `*~` | ノイズ |
| 7 | IDE設定 | `.idea/`, `*.swp`, `*.swo` | 個人設定 |
| 8 | ビルド成果物 | `dist/`, `build/`, `*.class`, `*.o`, `*.so`, `*.dll` | 再生成可能 |
| 9 | ログ | `*.log`, `npm-debug.log*`, `yarn-debug.log*`, `yarn-error.log*` | 大量データ・機密含有可能性 |
| 10 | 個人メモ | `memo.txt`, `scratch.*` | 個人ファイル |
| 11 | コンテナ/K8s認証 | `.docker/config.json`, `.kube/config`, `kubeconfig*` | コンテナレジストリ・クラスタ認証 |
| 12 | パッケージマネージャ認証 | `.npmrc`, `.pypirc`, `.netrc`, `auth.json` | パッケージレジストリ認証 |
| 13 | モバイル署名鍵 | `*.jks`, `*.keystore`, `google-services.json` | アプリ署名鍵 |
| 14 | 退避/一時ファイル | `*.bak`, `*.old` | 不要ファイル |

## 3. ステージング方針

| 禁止 | 理由 | 代替 |
|------|------|------|
| `git add -A` | 全ファイル一括追加で機密ファイル混入リスク | `git add <個別ファイル>` |
| `git add .` | 同上 | `git add <個別ファイル>` |

**必須**: ファイルを個別に指定してステージングすること。

## 4. 事故発生時の緊急対応

**最優先**: 漏えいした鍵・シークレットの**無効化・ローテーション**。履歴からの削除は二の次。

### 対応手順

1. **即座に鍵を無効化**（AWS IAM/GitHub Settings/クラウドコンソール等）
2. **新しい鍵を発行**し、必要なサービスに設定
3. **影響範囲を調査**（アクセスログ確認）
4. **git履歴からの削除**（`git filter-branch` or BFG Repo-Cleaner）
5. **全collaboratorに通知**し、re-clone依頼

### 注意事項

- git履歴の削除だけでは不十分（クローン済みリポジトリ、GitHubキャッシュに残る）
- GitHub Secret Scanning Alertが通知された場合も同手順

## 5. .vscode/ 運用ガイドライン

`.vscode/` はグローバルgitignoreで一律除外**しない**。プロジェクトごとに判断する。

### 共有すべきファイル

| ファイル | 理由 | 例 |
|---------|------|-----|
| `.vscode/settings.json` | プロジェクト共通設定（formatter、Marp themes等） | `markdown.marp.themes`, `editor.defaultFormatter` |
| `.vscode/extensions.json` | 推奨拡張機能リスト | `recommendations` |

### 除外すべきファイル

| ファイル | 理由 |
|---------|------|
| `.vscode/launch.json` | 個人のデバッグ設定 |
| `.vscode/*.code-workspace` | 個人のワークスペース設定 |

### 運用ルール

- `settings.json` にはプロジェクト共通設定のみ記載
- 個人設定はユーザープロファイル（`~/Library/Application Support/Code/User/settings.json`）で管理
- Marp等でワークスペース設定が必須な場合は `.vscode/settings.json` をコミット対象にする

## 6. リモート側推奨事項

ローカル防御だけでは回避時に止められない。以下のリモート側設定を推奨:

### GitHub設定

- **Push Protection**: Settings → Code security → Push protection を有効化
- **Secret Scanning**: Settings → Code security → Secret scanning を有効化
- **Branch Protection**: main/masterへの直接push禁止、force-push禁止を設定

### CI/CD

- **Secret Scanner**: gitleaks等をCI/CDパイプラインに組み込み
- **Pre-receive Hook**: サーバーサイドでの機密ファイル検知

## 7. 既追跡ファイルの注意

`.gitignore` は**既にgit追跡中のファイルには効かない**。

既追跡の機密ファイルを除外するには:
```bash
git rm --cached <file>  # ファイルをgit追跡から除外（ローカルファイルは残る）
git commit -m "Remove tracked sensitive file"
```

## 8. ホワイトリスト管理

正当な理由でgitignoreの例外が必要な場合:
- `git add -f <file>` で個別に強制追加
- **必須**: 理由・期限・レビュア承認を記録
- 例: `*.log` がプロジェクトのサンプルデータとして必要な場合
