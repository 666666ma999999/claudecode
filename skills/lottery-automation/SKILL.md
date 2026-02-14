---
name: lottery-automation
description: |
  抽選サイトへの自動応募をPlaywrightで実行する。応募実行、履歴確認、新サイト追加、スケジュール管理を提供する。
  使用タイミング:
  (1) 「抽選に応募して」「ポケモンの抽選に申し込んで」など抽選応募を実行するとき
  (2) 「応募履歴を確認」「過去の応募を見せて」など応募履歴を確認するとき
  (3) 「新しい抽選サイトを追加」「別のサイトも自動化したい」など対応サイトを追加するとき
  (4) 「抽選のスケジュールを確認」「自動応募の状態を見せて」などシステム状態を確認するとき
  (5) 「抽選のセットアップ」「lottery環境を構築」など環境構築・初期設定をするとき
  キーワード: 抽選に応募して, 応募履歴を確認, 新しい抽選サイトを追加, ポケモンオンライン抽選, ポケモンセンター, lottery, 自動応募, スケジュール管理, 2FA, TOTP
compatibility: "requires: Playwright browser automation, TOTP for 2FA"
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
metadata:
  author: masaaki-nagasawa
  version: 1.0.0
---

# 抽選自動応募スキル

抽選サイトへの自動応募を管理するスキルです。Playwrightで録画しながら自動化を実行します。

## クイックスタート

```bash
cd /Users/masaaki/Desktop/prm/lottery

# 初回セットアップ
./lottery setup

# ダッシュボードを開く
open http://localhost:5173

# 手動で応募を実行
./lottery run pokemonOnline
```

## メインCLI コマンド一覧

```bash
./lottery <command>

Commands:
  setup           初期セットアップを実行
  start           サービスを起動
  stop            サービスを停止
  restart         サービスを再起動
  status          システムステータスを表示
  logs [service]  ログを表示
  run <site>      手動で抽選応募を実行
  add-site        新サイトを追加（ウィザード）
  history         応募履歴を表示
  sites           登録サイト一覧
  schedules       スケジュール一覧
  db              データベースに接続
```

## 機能一覧

### 1. 抽選応募実行

```bash
# CLIから実行
./lottery run pokemonOnline

# 特定の抽選を指定
./lottery run pokemonOnline --lottery="ピカチュウ"

# ブラウザを表示して実行（デバッグ用）
docker compose exec playwright-worker node dist/run.js --site=pokemonOnline --headless=false
```

### 2. 環境構築

```bash
# ワンコマンドセットアップ
./lottery setup

# 手動セットアップ
cp env.example .env
# .envを編集
docker compose up -d
```

### 3. 履歴・進捗確認

```bash
# Webダッシュボード
open http://localhost:5173

# CLIで確認
./lottery status      # 全体ステータス
./lottery history     # 応募履歴
./lottery sites       # 登録サイト一覧
./lottery schedules   # スケジュール一覧
```

### 4. 新サイト追加

```bash
# ウィザードで追加
./lottery add-site

# 手動で追加
cp config/sites/_template.yaml config/sites/newsite.yaml
# newsite.yamlを編集
```

### 5. ログ確認

```bash
./lottery logs                    # 全サービス
./lottery logs playwright-worker  # Playwright
./lottery logs backend           # API
./lottery logs scheduler         # スケジューラー
```

## ワークフロー

### 抽選応募フロー
1. **ログイン**: サイトにログイン（2FA対応可）
2. **検索**: 抽選画面を検索・遷移
3. **応募**: フォーム入力・送信
4. **確認**: 完了確認・スクリーンショット保存
5. **記録**: 履歴をDBに保存、録画ファイル保存

### 対応サイト
| サイト | 設定ファイル | 状態 |
|--------|-------------|------|
| ポケモンセンターオンライン | `config/sites/pokemonOnline.yaml` | 設定中 |

## ディレクトリ構造

```
/Users/masaaki/Desktop/prm/lottery/
├── lottery                 # メインCLI
├── setup.sh               # セットアップスクリプト
├── docker-compose.yml     # Docker構成
├── env.example            # 環境変数テンプレート
├── docker/
│   ├── Dockerfile.playwright
│   ├── Dockerfile.backend
│   ├── Dockerfile.frontend
│   └── nginx.conf
├── automation/            # Playwright自動化
│   ├── src/
│   │   ├── core/         # 共通機能
│   │   ├── domains/      # サイト固有実装
│   │   └── workers/      # ジョブワーカー
│   └── tests/            # テスト
├── dashboard/
│   ├── frontend/         # React ダッシュボード
│   └── backend/          # NestJS API
├── config/
│   ├── default.yaml      # 共通設定
│   └── sites/            # サイト設定
├── scripts/
│   └── add-site.sh       # サイト追加スクリプト
├── artifacts/
│   ├── recordings/       # 録画ファイル
│   └── logs/            # ログファイル
├── db/
│   └── migrations/       # DBマイグレーション
└── skills/
    └── lottery-automation/
        └── SKILL.md      # このファイル
```

## API エンドポイント

```
GET  /api/applications          # 応募一覧
POST /api/applications          # 新規応募
GET  /api/applications/:id      # 応募詳細
GET  /api/applications/stats    # 統計

GET  /api/sites                 # サイト一覧
GET  /api/schedules             # スケジュール一覧
POST /api/schedules             # スケジュール作成

WS   /ws/progress               # リアルタイム進捗
```

## トラブルシューティング

### bot検知でログインできない

サイトがPlaywrightを検知してログインをブロックする場合：

**→ `playwright-browser-automation` スキルの「リモートChrome接続（CDP）によるbot検知回避」を参照**

簡易手順：
```bash
# 1. Chrome終了
pkill -9 Chrome

# 2. デバッグモードで起動
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --remote-debugging-port=9222 --user-data-dir=/tmp/chrome-debug &

# 3. Chromeで手動ログイン

# 4. PlaywrightでCookie取得
python -c "
from playwright.sync_api import sync_playwright
import json

with sync_playwright() as p:
    browser = p.chromium.connect_over_cdp('http://localhost:9222')
    cookies = browser.contexts[0].cookies()
    # フィルタして保存
    with open('cookies.json', 'w') as f:
        json.dump(cookies, f)
    browser.close()
"
```

### サービスが起動しない
```bash
# Dockerが起動しているか確認
docker info

# ログを確認
./lottery logs
```

### ブラウザが起動しない
```bash
# 共有メモリ確認
docker compose exec playwright-worker df -h /dev/shm
# 2GB以上あることを確認
```

### 認証エラー
```bash
# 環境変数確認
docker compose exec playwright-worker env | grep POKEMON

# .envファイル確認
cat .env | grep POKEMON
```

### 録画が保存されない
```bash
# ディレクトリ権限確認
ls -la artifacts/recordings/

# 書き込み権限を付与
chmod 755 artifacts/recordings/
```

### データベースエラー
```bash
# DBに接続
./lottery db

# テーブル確認
\dt

# データ確認
SELECT * FROM applications ORDER BY created_at DESC LIMIT 5;
```

## セレクタの調べ方

### セレクタ調査ツールを使う（推奨）

```bash
cd /Users/masaaki/Desktop/prm/lottery/automation

# URLを指定して開く
npx ts-node src/tools/selector-finder.ts --url=https://example.com/login

# サイト設定を読み込んで開く
npx ts-node src/tools/selector-finder.ts --site=pokemonOnline
```

ツール内コマンド:
- `login` - ログインフォーム要素を自動検出
- `forms` - フォーム要素を一覧表示
- `buttons` - ボタン要素を一覧表示
- `find <text>` - テキストを含む要素を検索

### 手動で調べる

1. ブラウザでサイトを開く
2. 開発者ツールを開く (F12 または Cmd+Option+I)
3. 要素を選択 (Cmd+Shift+C)
4. 右クリック → Copy → Copy selector

**より安定したセレクタ:**
- id属性: `#login-form`
- name属性: `input[name="username"]`
- data-*属性: `[data-testid="submit-btn"]`
- クラス名は変わりやすいので注意

## 2FA (二段階認証) の設定

### 1. TOTPシークレットの取得

サイトの2FA設定画面で:
1. QRコードの代わりに「手動入力」「セットアップキー」を選択
2. Base32形式のシークレットキーを取得（例: `JBSWY3DPEHPK3PXP`）

### 2. 環境変数に設定

```bash
# .env に追加
POKEMON_TOTP=JBSWY3DPEHPK3PXP
```

環境変数名の規則: `{SITE_NAME}_TOTP`
（`{SITE_NAME}_ID` の `_ID` を `_TOTP` に置き換え）

### 3. サイト設定でTOTPセレクタを指定

```yaml
# config/sites/xxx.yaml
login:
  selectors:
    totpInput: "input[name='totp']"  # 2FA入力フィールド
```

### 注意事項

- TOTPコードは30秒ごとに更新されます
- システムは残り5秒未満の場合、次のコードを待機します
- サーバーの時刻同期（NTP）を確認してください
