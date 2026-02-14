---
name: Docker Project Bootstrap
description: 新規プロジェクト作成時にDockerfile/docker-compose.yml/各種設定を自動生成する。「新しいプロジェクトを作って」「プロジェクトを初期化して」等の指示で自動発動。
allowed-tools: "Bash Read Write Edit Glob Grep"
metadata:
  author: masaaki-nagasawa
  version: 1.0.0
---

# Docker Project Bootstrap

## 使用タイミング
- 新規プロジェクトのディレクトリ作成時
- 「新しいプロジェクトを作って」「初期化して」等の指示

## 手順

### 1. プロジェクト種別を確認
AskUserQuestionで以下を確認：
- 言語/フレームワーク（Python/Node.js/混合）
- Python の場合: FastAPI / Flask / Django / スクリプト
- Node.js の場合: React / Next.js / Express / Vanilla

### 2. Dockerfile 生成

**Python (FastAPI) の場合:**
```dockerfile
FROM python:3.12-slim

WORKDIR /workspace

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential git curl \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

CMD ["uvicorn", "backend.main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]
```

**Node.js の場合:**
```dockerfile
FROM node:22-slim

WORKDIR /workspace

COPY package*.json ./
RUN npm ci

COPY . .

CMD ["npm", "run", "dev"]
```

### 3. docker-compose.yml 生成

```yaml
services:
  dev:
    build: .
    volumes:
      - .:/workspace
      - node_modules:/workspace/node_modules    # Node.jsの場合
      - py_packages:/workspace/.venv             # Pythonの場合
    ports:
      - "${PORT:-8000}:8000"
    environment:
      - PYTHONDONTWRITEBYTECODE=1
    command: sleep infinity    # 開発時はshell接続用

volumes:
  node_modules:
  py_packages:
```

### 4. .dockerignore 生成

```
.git
__pycache__
*.pyc
node_modules
.venv
venv
.env
*.egg-info
dist
build
```

### 5. 初期ファイル生成
- `requirements.txt`（Pythonの場合）
- `package.json`（Node.jsの場合）
- `.env.example`

### 6. 起動確認
```bash
docker compose build
docker compose up -d
docker compose exec dev bash  # 接続確認
```

## 既存プロジェクトのDocker移行（venv → Docker）

### チェックリスト
- [ ] `docker-compose.yml`: ポートは `127.0.0.1:PORT:PORT` にバインド（dev環境）
- [ ] `docker-compose.yml`: `env_file: .env` で環境変数を一括注入（個別列挙しない）
- [ ] `docker-compose.yml`: ソースコードを bind mount（`./backend:/app/backend` 等）
- [ ] `docker-compose.yml`: `command:` で `--reload` 付き起動（dev用）
- [ ] `docker-compose.yml`: テストディレクトリも mount（`./tests:/app/tests`）
- [ ] `Dockerfile`: HEALTHCHECK は compose に任せる（重複回避）
- [ ] シェルスクリプト: `set -euo pipefail` + 適切な終了コード
- [ ] `docker compose exec` に `-T` フラグ（CI/非TTY対応）
- [ ] `.env.example`: 全環境変数を網羅
- [ ] `venv/` 削除前にローカルサーバー停止を確認

### start/stop スクリプトテンプレート（Docker用）
```bash
# start_server.sh
#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
if ! docker compose up -d --build; then exit 1; fi
# ヘルスチェック待機ループ（最大60秒）
for i in $(seq 1 30); do
    if docker compose ps --format json | grep -q '"healthy"'; then
        echo "Server started successfully"
        exit 0
    fi
    sleep 2
done
echo "Error: Health check timeout"
exit 1
```
