## 事前準備（現行 Mac 側で1回だけ）

### 1. inventory スナップショット更新

新しい Mac へ渡す前に、**送り出し側の最新スナップショット**を取る。

```bash
# brew bundle（VSCode extensions は STEP 5 が所有するため除外）
brew bundle dump --file=~/.claude/skills/machine-bootstrap/inventory/Brewfile --force --no-vscode

# npm globals
npm ls -g --depth=0 --parseable --json \
  | jq -r '.dependencies | keys[]' \
  > ~/.claude/skills/machine-bootstrap/inventory/npm-globals.txt

# MCP テンプレート（値は ${VAR} 化済のグローバル .mcp.json を雛形に）
cp ~/.claude/.mcp.json \
   ~/.claude/skills/machine-bootstrap/inventory/mcp-template.json

# MCP が必要とする環境変数名（${VAR} 参照を抽出 → 新 Mac で export すべきキー一覧）
jq -r '
  [.mcpServers[] |
    ((.env // {}) | to_entries[] | .value),
    (.args[]? | select(type=="string"))
  ]
  | map(scan("\\$\\{([A-Z_][A-Z0-9_]*)\\}"))
  | flatten
  | map(select(. != "HOME"))
  | unique
  | .[]
' ~/.claude/skills/machine-bootstrap/inventory/mcp-template.json \
  > ~/.claude/skills/machine-bootstrap/inventory/mcp-required-env-keys.txt

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

> **注**: Brewfile は `--no-vscode` で生成済のため formulae + casks のみ。VSCode extensions は STEP 5 で別途入れる（責務分離）。

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

グローバル MCP 設定（`~/.claude/.mcp.json`）を **構造だけコピー**し、値は空の `${VAR}` のままにする。現環境では 3 サーバー（codex / context7 / memory）をこのファイルで管理しており、プロジェクトごとに `.mcp.json` を置かない運用。

```bash
cp ~/.claude/skills/machine-bootstrap/inventory/mcp-template.json \
   ~/.claude/.mcp.json
```

### シークレット注入（手動）

`~/.zshrc.local`（`~/.zshrc` 末尾で source 済）に必要な export を追加する:

```bash
# ~/.zshrc.local 末尾に追加する雛形（値は手で埋める）
export OPENAI_API_KEY=sk-...                  # codex MCP 用（mcp-template.json の ${OPENAI_API_KEY}）
export CODEX_PATH=/path/to/codex              # codex MCP 用（mcp-template.json の ${CODEX_PATH}・`command -v codex` の出力）
# Claude Code の API 認証は OAuth フロー（STEP 4）で行うため .zshrc への直 export は不要
```

### 参照すべき inventory ファイル

| ファイル | 内容 | 新 Mac での用途 |
|---|---|---|
| `mcp-required-env-keys.txt` | `mcp-template.json` から抽出した `${VAR}` 名の正規リスト | **新 Mac で必ず export すべき KEY 名**（上記雛形の根拠） |
| `zshrc-export-keys.txt` | 送り出し側 `~/.zshrc` の export 実績（値なし） | 現行マシンで何が PATH 系に流れていたかの参考情報 |

> 現環境では API キーは `~/.zshrc` 本体ではなく `~/.zshrc.local` 経由で export されている（`~/.zshrc` が `[ -f ~/.zshrc.local ] && source ~/.zshrc.local` で読み込み）。新 Mac でも同じ分離方針に従うなら `~/.zshrc.local` に書く。

### 起動確認

```bash
# Claude Code をターミナルから起動（Launchpad 経由だと .zshrc が読まれない）
cd ~/Desktop/biz/make_article
claude
```

Claude Code 内で `/mcp` を叩いて、mcp-template.json の 3 サーバーが authenticated で揃うこと。

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
| カテゴリ | 項目 | 理由 / 支援スクリプト |
|---|---|---|
| 認証 | SSH 鍵生成 + GitHub 登録 | 秘密鍵は移植しない方針 |
| 認証 | Claude Code / Codex OAuth | ブラウザ必須 |
| 認証 | gh / gcloud OAuth | 同上 |
| 認証 | MCP 各サーバーの API key | `~/.zshrc.local` に手書き |
| 認証 | X Cookie（influx 用） | `x_profiles/` は手動コピー（`refresh-x-cookies` skill 参照） |
| OS 権限 | **claude.exe を Full Disk Access に追加** | Claude Code 2.1.x は Bun-compiled native Mach-O (`com.anthropic.claude-code`) で TCC は新規アプリ扱い。親 (iTerm2) の grant 不継承。GUI 操作のみで付与可能。**支援: `~/.claude/scripts/grant-fda-claude.sh apply`** → System Settings 起動 + path 自動コピー。完了後 `verify` で `ls ~/Desktop` / `python3 <<EOF` / Stop hook smoke を一括チェック |
| セキュリティ | GPG 署名設定 | 現状ゼロ件運用。必要ならここで鍵生成 |

### 現環境では未使用だが考慮しておく
| 項目 | 状態 | 備考 |
|---|---|---|
| direnv | 未導入 | 現在は `~/.zshrc.local` を zshrc source で代用 |
| mise / asdf / pyenv | 未導入 | Python は brew `python@3.13`、Node は nvm |
| starship / p10k | 未導入 | oh-my-zsh のデフォルトテーマ運用 |

---

