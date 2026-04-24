---
name: machine-bootstrap
description: 新しい Mac（または2台目）を現環境と同じ Claude Code + Codex CLI + MCP 並列開発環境に揃える。brew/npm/MCP/LaunchAgent の「機械的に入れれば済む層」を bulk 実行し、OAuth・SSH・API keys など「手で握る層」を honesty セクションに明示する。実施記録を inventory-diff.log に残すことで、何が自動化でき何が手動で残ったかを数値で証明する（記事 Fact-check 素材も兼ねる）。
user_invocable: true
allowed-tools:
  - Read
  - Write
  - Bash
  - Glob
---

# machine-bootstrap

## P1 scope（本バージョン）

P1 = 骨組み + 自動化層のみ。以下の **4 STEP** が実装済み:

- **STEP 0**: preflight（macOS/arm64/xcode-select 確認）
- **STEP 1**: brew + npm bulk install
- **STEP 3**: MCP `.mcp.json` 配置
- **STEP 6**: honesty（手動で残るもの）

以下は **P2 で詳細化**（本 skill では placeholder 扱い）:

- STEP 2: shell 環境（oh-my-zsh + nvm 詳細）
- STEP 4: Claude Code / Codex / gh / gcloud OAuth ログイン手順
- STEP 5: VSCode extensions bulk install + LaunchAgents 配置

> P1 で「60% 自動・40% 手動」を観測値として回し切るのが目的。P2 で手動層をどこまで圧縮できるかを確認する。

---

## 起動トリガー

- 新しい Mac を買った / 2台目 Mac を並列環境にしたい
- 既存 Mac で環境を破壊してしまい、復旧に現環境を参照したい
- 別メンバーに「同じ環境を用意してください」と依頼したい

## 対象範囲 / 非対象範囲

### 対象（この skill が面倒を見る）
- Homebrew formulae / casks
- npm グローバルパッケージ（Claude Code / Codex CLI 含む）
- `.mcp.json` の構造コピー（シークレット値は手動）
- `~/.claude/` のスキル・ルール・コマンド一式（rsync）
- `~/Desktop/biz/` 配下の git clone 可能なプロジェクト再配置

### 非対象（明示的に手動）
- OAuth ログイン（Claude Code / Codex / gh / gcloud / grok-search）
- SSH 秘密鍵（新規生成 → GitHub 登録を手動実施）
- GPG 秘密鍵（現状ゼロ件・署名運用なし）
- `~/.zshrc` の export 実値（`envrc.shared` に分離済）
- X / Gmail / Drive の各 Cookie（influx 側 `x_profiles/` は手動コピー）

---

## 事前準備（現行 Mac 側で1回だけ）

### 1. inventory スナップショット更新

新しい Mac へ渡す前に、**送り出し側の最新スナップショット**を取る。

```bash
# brew bundle
brew bundle dump --file=~/.claude/skills/machine-bootstrap/inventory/Brewfile --force

# npm globals
npm ls -g --depth=0 --parseable --json \
  | jq -r '.dependencies | keys[]' \
  > ~/.claude/skills/machine-bootstrap/inventory/npm-globals.txt

# MCP テンプレート（値は ${VAR} 化済のグローバル .mcp.json を雛形に）
cp ~/.claude/.mcp.json \
   ~/.claude/skills/machine-bootstrap/inventory/mcp-template.json

# VSCode extensions
code --list-extensions \
  > ~/.claude/skills/machine-bootstrap/inventory/vscode-extensions.txt

# LaunchAgents 一覧（plist 本体はコピーせず名前だけ）
ls ~/Library/LaunchAgents/ \
  > ~/.claude/skills/machine-bootstrap/inventory/launch-agents.txt
```

### 2. 機密チェック（送る前に必ず）

```bash
grep -E '(api[_-]?key|token|secret|password)' \
  ~/.claude/skills/machine-bootstrap/inventory/*.txt \
  ~/.claude/skills/machine-bootstrap/inventory/Brewfile \
  ~/.claude/skills/machine-bootstrap/inventory/mcp-template.json 2>/dev/null
```

ヒットしたら **その場で止める**。シークレットが inventory に混入している。

---

## STEP 0: preflight（新しい Mac 側）

Claude Code を新 Mac で開いて、このスキルを起動したら最初に確認する。

```bash
# macOS 14 以上か
sw_vers -productVersion

# Apple Silicon か（x86_64 だと brew のビルド互換性が異なる）
uname -m  # → arm64 を期待

# Xcode CLT インストール済か
xcode-select -p 2>&1
# NG なら: xcode-select --install
```

**チェックポイント**
- [ ] macOS 14.x 以上
- [ ] `arm64` を返す（x86_64 なら Rosetta 経由の brew 運用になるため warning 表示）
- [ ] `/Library/Developer/CommandLineTools` が返る

---

## STEP 1: brew + npm bulk install

### Homebrew 本体

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

完了後、PATH 反映のため新しいターミナルを開き直すか `eval "$(/opt/homebrew/bin/brew shellenv)"` を実行。

### formulae + casks を一括投入

```bash
brew bundle --file=~/.claude/skills/machine-bootstrap/inventory/Brewfile
```

**想定時間**: 10〜30分（回線と初回 Xcode ライセンス処理による）。
**途中失敗時**: `brew bundle check` で未導入分のみ再試行できる。

### npm グローバル

```bash
# Node.js は brew か nvm 経由で先に入れる（nvm 派なら先に nvm install --lts）
cat ~/.claude/skills/machine-bootstrap/inventory/npm-globals.txt \
  | xargs -n1 npm install -g
```

**検証**
```bash
claude --version       # 2.1.x 以降を期待
codex --version        # 0.124 以降を期待
```

---

## STEP 2: shell 環境（P2 で詳細化）

骨子のみ:
- oh-my-zsh インストール
- nvm インストール + `.nvmrc` で Node 固定
- `~/.zshrc` は **現 Mac からコピーしない**。テンプレを用意して export キー名だけ同期する（値は手動）

> 詳細は P2 で埋める。P1 では「この辺は手動で .zshrc を書く」だけ記載する。

---

## STEP 3: MCP `.mcp.json` 配置

グローバル MCP 設定（`~/.claude/.mcp.json`）を **構造だけコピー**し、値は空の `${VAR}` のままにする。現環境では 6 サーバー（codex / grok-search / memory / playwright / postgresql / repomix）をグローバル1ファイルで管理しており、プロジェクトごとに `.mcp.json` を置かない運用。

```bash
cp ~/.claude/skills/machine-bootstrap/inventory/mcp-template.json \
   ~/.claude/.mcp.json
```

### シークレット注入（手動）

`~/.zshrc` か `~/Desktop/biz/.envrc.shared` に必要な export を追加する:

```bash
# ~/.zshrc 末尾に追加する雛形（値は手で埋める）
export ANTHROPIC_API_KEY=sk-ant-...
export GROK_API_KEY=xai-...
export POSTGRES_CONNECTION_STRING=postgres://...
# 等
```

**一覧は inventory 側の `zshrc-export-keys.txt` を参照**（KEY 名のみ記録済・値は含まれない）。

### 起動確認

```bash
# Claude Code をターミナルから起動（Launchpad 経由だと .zshrc が読まれない）
cd ~/Desktop/biz/make_article
claude
```

Claude Code 内で `/mcp` を叩いて、6 サーバーが authenticated で揃うこと。

---

## STEP 4: OAuth ログイン（P2 で詳細化）

骨子のみ:
- `claude login` — ブラウザで Anthropic 認証
- `codex` 初回起動 → OAuth ブラウザフロー（手動。`/gemini` と同じ方式）
- `gh auth login` — GitHub OAuth
- `gcloud auth login` — Google Cloud OAuth

> P2 で実測時間 + 各 OAuth の詰まりどころを埋める。

---

## STEP 5: VSCode extensions + LaunchAgents（P2 で詳細化）

骨子のみ:
```bash
# VSCode extensions
cat ~/.claude/skills/machine-bootstrap/inventory/vscode-extensions.txt \
  | xargs -L1 code --install-extension
```

LaunchAgents（例: `org.git-scm.git.daily.plist` 等）は `~/Library/LaunchAgents/` へコピーし、`launchctl load` で有効化。plist の実体は inventory に含めず、`git maintenance start` 等の元コマンドで再生成する方針。

---

## STEP 6: honesty — 手動で残る項目リスト

P1 完了時点で **新 Mac 側で手で握る必要がある項目**を明示する。記事の Fact-check 素材にもなる。

### 必ず手動
| カテゴリ | 項目 | 理由 |
|---|---|---|
| 認証 | SSH 鍵生成 + GitHub 登録 | 秘密鍵は移植しない方針 |
| 認証 | Claude Code / Codex OAuth | ブラウザ必須 |
| 認証 | gh / gcloud OAuth | 同上 |
| 認証 | MCP 各サーバーの API key | `~/.zshrc` か `envrc.shared` に手書き |
| 認証 | X Cookie（influx 用） | `x_profiles/` は手動コピー（`refresh-x-cookies` skill 参照） |
| セキュリティ | GPG 署名設定 | 現状ゼロ件運用。必要ならここで鍵生成 |

### 現環境では未使用だが考慮しておく
| 項目 | 状態 | 備考 |
|---|---|---|
| direnv | 未導入 | 現在は `envrc.shared` を zshrc source で代用 |
| mise / asdf / pyenv | 未導入 | Python は brew `python@3.13`、Node は nvm |
| starship / p10k | 未導入 | oh-my-zsh のデフォルトテーマ運用 |

---

## 検証（STEP 1〜3 終了時に実行）

```bash
# 1. brew + npm
brew bundle check --file=~/.claude/skills/machine-bootstrap/inventory/Brewfile
diff <(npm ls -g --depth=0 --parseable --json | jq -r '.dependencies | keys[]' | sort) \
     <(sort ~/.claude/skills/machine-bootstrap/inventory/npm-globals.txt)

# 2. MCP
claude  # 起動して /mcp で 6 サーバー authenticated を確認

# 3. git maintenance（art_013 で設定した hourly/daily/weekly が動いているか）
launchctl list | grep git-scm
```

### inventory diff 記録（記事の Fact-check 用）

```bash
# 新 Mac で実行した記録を残す
cat > ~/.claude/skills/machine-bootstrap/inventory/diff-$(date +%Y-%m-%d).log <<EOF
bootstrap_date: $(date -u +%Y-%m-%dT%H:%M:%SZ)
macos_version: $(sw_vers -productVersion)
arch: $(uname -m)
node_version: $(node -v)
npm_version: $(npm -v)
claude_version: $(claude --version)
codex_version: $(codex --version)
brew_formulae_installed: $(brew list --formula | wc -l | tr -d ' ')
brew_casks_installed: $(brew list --cask | wc -l | tr -d ' ')
npm_globals_installed: $(npm ls -g --depth=0 --parseable --json | jq '.dependencies | keys | length')
manual_steps_pending: (SSH, OAuth x4, MCP API keys, GPG)
EOF
```

このログが **記事の honesty セクション**（何が自動化でき何を手で握ったか）の一次ソースになる。

---

## 参照

- `~/.claude/state/machine-inventory-2026-04-24.json` — 送り出し側スナップショット（生成日付: 2026-04-24）
- `output/drafts/art_013_2pc_fastdev_tools_2026-04-19.md` — 2台並列運用の実運用記事
- `refresh-x-cookies` skill（influx 側） — X Cookie の手動移行手順

## Decision Log

- **2026-04-24**: P1 起草。STEP 0/1/3/6 のみ実装、STEP 2/4/5 は骨子 placeholder。手動層は STEP 6 に一覧化。
- **方針**: inventory 側は **KEY 名のみ**を持ち、値は持たない。送り出し側と受け取り側の Mac 間で plist/秘密鍵/Cookie は直接コピーしない。
