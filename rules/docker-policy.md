# Docker-Only 開発ポリシー（全プロジェクト共通）

## 原則

**ホスト環境（macOS）を一切変更しない。** 全ての依存管理・ビルド・実行はDocker経由で行う。

## 禁止コマンド（ホスト上での実行）

以下のコマンドはホスト上で直接実行してはならない：

| カテゴリ | 禁止コマンド |
|---------|-------------|
| Python | `pip install`, `pip3 install`, `python -m pip`, `python -m venv`, `virtualenv`, `uv pip`, `uv venv`, `poetry install`, `poetry add`, `conda install`, `conda create` |
| Node.js | `npm install`, `npm i`, `npx`, `yarn`, `pnpm`, `bun install`, `bun add` |
| 環境有効化 | `source venv/bin/activate`, `. .venv/bin/activate` |

## 正しい実行方法

```bash
# 依存インストール
docker compose exec dev pip install -r requirements.txt
docker compose exec dev npm ci

# 新しいパッケージ追加
docker compose exec dev pip install <package>
docker compose exec dev npm install <package>

# テスト実行
docker compose exec dev pytest
docker compose exec dev npm test

# venv作成（Docker内で）
docker compose exec dev python -m venv .venv
```

## 新規プロジェクト作成時

1. `Dockerfile` と `docker-compose.yml` を最初に作成する
2. `docker compose up -d` でコンテナを起動する
3. 全ての開発作業はコンテナ内で行う
4. ホスト側にはソースコードのみ配置（volumes mount）
5. `node_modules/` や `.venv/` はnamed volumeで管理

## Docker テンプレート構成

新規プロジェクトでは以下を必ず生成すること：

```
project-root/
├── Dockerfile
├── docker-compose.yml
├── .dockerignore
└── .claude/
    └── settings.json    # プロジェクト固有設定（必要に応じて）
```

## 強制メカニズム

- `~/.claude/settings.json` の `permissions.deny` で主要コマンドをブロック
- `~/.claude/hooks/block-host-installs.py` で `bash -c` 経由のすり抜けもブロック
- ブロックされた場合、Docker経由のコマンドを自動提案すること
