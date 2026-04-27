# Obsidian Vault + MCP 再現手順書（別Mac向け・自己完結版）

まっさらな別Mac で、現環境と同じ Claude Code + Obsidian vault + MCP（mcpvault 含む）構成を
**この 1 ファイルだけで** 構築する手順書。Phase 0 で OS 前提から立ち上げ、STEP 1-8 で vault と MCP を再現する。

## 構成サマリ（現環境 = 1台目）

| 要素 | 値 |
|---|---|
| Vault パス | `~/Documents/Obsidian Vault` |
| Vault Git remote | `git@github.com:666666ma999999/obsidian_work.git` (SSH) |
| Vault ブランチ | `main` |
| Vault pull/push 担い手 | Obsidian プラグイン **obsidian-git**（定期 `vault backup: <ts>` コミット & pull/push） |
| MCP 設定 | `~/.claude/.mcp.json`（10 サーバー、うち vault 連携は **mcpvault**） |
| mcpvault パッケージ | `@bitbonsai/mcpvault@latest` |
| mcpvault 環境変数 | `MCPVAULT_PATH=${HOME}/Documents/Obsidian Vault` |
| シークレット | `~/.zshrc` で `export`（`OPENAI_API_KEY`, `XAI_API_KEY`, `DB_CONNECTION_STRING`, `CODEX_PATH`） |

---

## Phase 0. OS / CLI ベース整備（machine-bootstrap 相当）

別Mac がまっさらな状態を想定。上から順に実行する。**鶏卵問題回避のため SSH 鍵は最初に作る**。

### 0-1. Xcode Command Line Tools

```bash
xcode-select --install      # ダイアログが出たら "Install"。完了まで数分
```

### 0-2. SSH 鍵生成 & GitHub 登録（最優先：以降の clone で必須）

```bash
# 鍵生成
ls ~/.ssh/id_ed25519.pub 2>/dev/null || ssh-keygen -t ed25519 -C "100ameros@gmail.com" -f ~/.ssh/id_ed25519 -N ""

# 公開鍵を表示 → GitHub Web UI (https://github.com/settings/keys) で New SSH key に貼る
cat ~/.ssh/id_ed25519.pub

# 接続確認
ssh -T git@github.com       # "Hi 666666ma999999!" が出ればOK（fingerprint確認 yes）
```

> `gh` 未インストール段階なので Web UI で登録。`gh` 導入後に `gh ssh-key add` でも可。

### 0-3. Homebrew

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Apple Silicon の場合、PATH を ~/.zshrc に追記
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
source ~/.zshrc

brew --version              # 動作確認
```

### 0-4. Node.js（nvm 経由）+ Git + gh CLI + Obsidian + Docker

```bash
# nvm
brew install nvm
mkdir -p ~/.nvm
cat <<'EOF' >> ~/.zshrc
export NVM_DIR="$HOME/.nvm"
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && . "/opt/homebrew/opt/nvm/nvm.sh"
EOF
source ~/.zshrc

# Node.js 22（現環境踏襲）
nvm install 22
nvm alias default 22
node --version              # v22.x
npx --version

# Git は brew 版に揃える（Xcode 同梱版より新しい）
brew install git gh

# Obsidian.app
brew install --cask obsidian

# Docker Desktop（Firecrawl 用、不要なら省略可）
brew install --cask docker
open -a Docker              # 初回起動して常駐させる
```

### 0-5. `~/.claude/` をクローン（dotfiles 同期）

```bash
# 鍵が登録済みなのでこの時点で SSH clone できる
git clone git@github.com:666666ma999999/claudecode.git ~/.claude

# 確認
ls ~/.claude/.mcp.json ~/.claude/CLAUDE.md ~/.claude/rules/40-obsidian.md
```

> `~/.claude/.mcp.json` `rules/` `skills/` `hooks/` `scripts/` が一式入る。STEP 4 はこの clone で済むのでスキップしてよい。

### 0-6. Claude Code CLI インストール + 初回ログイン

```bash
npm install -g @anthropic-ai/claude-code
claude --version

# 初回 OAuth（ブラウザが開く → 100ameros@gmail.com でログイン → 認可）
claude
# プロンプトが立ち上がったら /quit で抜ける
```

### 0-7. Codex CLI インストール + 初回ログイン（codex MCP 用）

```bash
npm install -g @openai/codex
which codex                 # → ~/.nvm/versions/node/v22.x/bin/codex （CODEX_PATH 候補）

codex login                 # ブラウザが開く → ChatGPT アカウントで認可
```

### 0-8. OS パーミッション（Full Disk Access 等）

```bash
# 既存のヘルパースクリプトがあればそれを使う
bash ~/.claude/scripts/grant-fda-claude.sh 2>/dev/null || true
```

実行後、**System Settings → Privacy & Security → Full Disk Access** で `claude` / `Terminal` / `iTerm` 等にチェックが入っているか手動確認。

### 0-9. Firecrawl ローカル起動（任意：firecrawl MCP を使う場合）

```bash
docker run -d --name firecrawl -p 3002:3002 --restart unless-stopped ghcr.io/mendableai/firecrawl:latest
curl http://localhost:3002/health   # 200 が返ればOK
```

> 不要なら本ステップ省略 + `.mcp.json` から `firecrawl` ブロックを外しても良い。

### Phase 0 完了チェック

- [ ] `ssh -T git@github.com` が "Hi 666666ma999999!" を返す
- [ ] `brew --version` `node --version`（v22.x）`git --version` `gh --version` 全て動く
- [ ] `~/.claude/.mcp.json` が存在
- [ ] `claude --version` が動く、初回 OAuth 済み
- [ ] `which codex` がパスを返す、`codex login` 済み
- [ ] Obsidian.app が `/Applications/` に存在
- [ ] （Firecrawl 使うなら）`curl localhost:3002/health` が 200

> **重要**: 以降のすべての作業は **ターミナル（zsh）から `claude` を起動**すること。Launchpad / Spotlight 起動だと `~/.zshrc` の `export` が読まれず MCP が動かない。

---

## STEP 1. GitHub 認証 & SSH 鍵（手動：1回だけ）

> Phase 0-2 で完了済み。スキップ可。`gh` で再登録したい場合のみ以下:

vault repo は SSH (`git@github.com:...`) のため SSH 鍵が必要。

```bash
# SSH 鍵生成（既存があればスキップ）
ls ~/.ssh/id_ed25519.pub 2>/dev/null || ssh-keygen -t ed25519 -C "<your-email>"

# 公開鍵を GitHub に登録（gh CLI 経由 / 手動どちらか）
gh auth login            # まだなら
gh ssh-key add ~/.ssh/id_ed25519.pub --title "$(hostname)"

# 接続確認
ssh -T git@github.com    # "Hi 666666ma999999! ..." が出ればOK
```

> 失敗時は `~/.ssh/config` に `Host github.com / IdentityFile ~/.ssh/id_ed25519` を追記。

---

## STEP 2. Vault を clone（手動：1回だけ）

```bash
mkdir -p ~/Documents
cd ~/Documents
git clone git@github.com:666666ma999999/obsidian_work.git "Obsidian Vault"

# 確認
cd ~/Documents/"Obsidian Vault"
git remote -v          # origin = git@github.com:666666ma999999/obsidian_work.git
git branch --show-current   # main
ls .obsidian/plugins/  # obsidian-git 等が入っていることを確認
```

> 注: vault ディレクトリ名のスペースは正しく `"Obsidian Vault"` とクオートする。
> 注: `~/.claude/rules/40-obsidian.md` で「vault 直下既存ノートは無変更」「`.raw/` `<project>/refs/` は append-only」が不変ルール。

---

## STEP 3. Obsidian.app で vault を開く + obsidian-git 設定（手動：1回だけ）

1. Obsidian.app 起動 → "Open folder as vault" → `~/Documents/Obsidian Vault` を選択
2. プラグインは `.obsidian/plugins/` ごと clone してきているので**自動ロードされる**
3. Settings → Community plugins → **Trust author and enable plugins**（初回のみ確認ダイアログ）
4. **obsidian-git 設定確認**（Settings → obsidian-git）
   - Vault backup interval (minutes): 既存設定（`vault backup: <ts>` のペースに合う値、現環境はおおむね 60 分）
   - Auto pull interval: 起動時 pull が有効になっていること
   - Commit message: `vault backup: {{date}}`（現環境踏襲）
   - Author identity: `git config user.email` / `user.name` が GitHub と整合

> 別Macでも obsidian-git が pull/push を担うため、launchd / cron は**不要**。
> 1台目で同時編集しないこと（コンフリクト回避）。Obsidian は片側ずつ閉じる運用が安全。

---

## STEP 4. `~/.claude/.mcp.json` 確認（Phase 0-5 で配置済み）

Phase 0-5 で `~/.claude/` を clone 済みのため、`.mcp.json` は既に以下の状態のはず:

```json
{
  "mcpServers": {
    "context7":   { "command": "npx", "args": ["-y", "@upstash/context7-mcp@latest"] },
    "sentry":     { "type": "http", "url": "https://mcp.sentry.dev/mcp" },
    "firecrawl":  { "command": "npx", "args": ["-y", "firecrawl-mcp"], "env": { "FIRECRAWL_API_URL": "http://localhost:3002" } },
    "memory":     { "command": "npx", "args": ["-y", "@modelcontextprotocol/server-memory"], "env": { "MEMORY_FILE_PATH": "${HOME}/.claude/memory/memory.jsonl" } },
    "postgresql": { "command": "npx", "args": ["-y", "@henkey/postgres-mcp-server", "--connection-string", "${DB_CONNECTION_STRING}"] },
    "repomix":    { "command": "npx", "args": ["-y", "repomix", "--mcp"] },
    "codex":      { "type": "stdio", "command": "${CODEX_PATH}", "args": ["mcp-server"], "env": { "OPENAI_API_KEY": "${OPENAI_API_KEY}" } },
    "chrome-devtools": { "type": "stdio", "command": "npx", "args": ["chrome-devtools-mcp@latest", "--autoConnect"] },
    "grok-search":     { "command": "npx", "args": ["-y", "grok-search-mcp"], "env": { "GROK_API_KEY": "${XAI_API_KEY}" } },
    "mcpvault":   { "command": "npx", "args": ["-y", "@bitbonsai/mcpvault@latest"], "env": { "MCPVAULT_PATH": "${HOME}/Documents/Obsidian Vault" } }
  }
}
```

確認コマンド:

```bash
diff <(jq -S . ~/.claude/.mcp.json) <(ssh masaaki@<1台目-host> 'jq -S . ~/.claude/.mcp.json')
# 差分ゼロが理想
```

> `.mcp.json` にシークレット直書き禁止。すべて `${VAR}` プレースホルダー。詳細は `secret-management` スキル。

---

## STEP 5. シークレット投入（手動：1回だけ）

`~/.zshrc` に以下を `export` する。値は **1台目の `~/.zshrc`** または **1Password** から手動コピー（git に乗せない）。

**1台目から値を吸い出す参考コマンド**（1台目で実行）:

```bash
grep -E '^export (OPENAI_API_KEY|XAI_API_KEY|DB_CONNECTION_STRING|CODEX_PATH)=' ~/.zshrc
```

**別Mac側 `~/.zshrc` に追記**:

```bash
# ~/.zshrc に追記
export OPENAI_API_KEY="sk-..."           # codex MCP
export XAI_API_KEY="xai-..."             # grok-search MCP
export DB_CONNECTION_STRING="postgres://..." # postgresql MCP（使わなければ空でも可）
export CODEX_PATH="$(which codex)"       # codex MCP
# firecrawl はローカル起動 (http://localhost:3002) — Docker/プロセス側で別途起動
```

反映 & 確認:

```bash
source ~/.zshrc
echo "$OPENAI_API_KEY" | head -c 8       # 先頭だけ出して値が入っていることを確認
echo "$CODEX_PATH"                        # codex バイナリのパス
```

> **Claude Code は必ずターミナルから起動**すること（Launchpad 起動だと `~/.zshrc` の export が空になり MCP 起動失敗）。

---

## STEP 6. mcpvault 動作確認

```bash
# 別Macで Claude Code を起動した後、新セッションで:
#   /mcp  または  ToolSearch で mcp__mcpvault__* が見えること

# CLI 単体テスト（任意）
MCPVAULT_PATH="$HOME/Documents/Obsidian Vault" npx -y @bitbonsai/mcpvault@latest --help
```

期待: `mcp__mcpvault__read_note`, `mcp__mcpvault__write_note`, `mcp__mcpvault__search_notes` 等のツールが利用可能。

---

## STEP 7. hooks の動作確認（vault 限定 guard）

`~/.claude/settings.json` の以下が動くことを確認:

| Event | 動作 | 確認方法 |
|---|---|---|
| SessionStart | `wiki/hot.md` を `cat`（vault 内のみ） | vault 内ディレクトリで `claude` 起動 → 起動メッセージに hot.md 内容が出る |
| SessionStart | DONE 形式違反警告（obsidian-now-done） | vault 内で `## DONE` を含む MD があるディレクトリで起動 |
| PostToolUse(Write\|Edit) | `wiki/` `.raw/` を auto-commit | vault 内で `wiki/test.md` を 1 行編集 → `git log` に commit が出る |
| Stop | `hot.md` 更新プロンプト注入 | wiki/ 配下を編集して終了 → 次回起動時にプロンプト出る |

> 全 hook は `[ -d wiki ] && [ -d .git ]` または vault path ガード付き → vault 外プロジェクトでは no-op。

---

## STEP 8. Vault の pull 運用（日常同期）

別Macで vault の最新を取り込む方法。日常運用は **方法A だけで完結**する。

### 方法A: Obsidian.app の obsidian-git プラグイン（推奨・自動）

Obsidian を起動するだけで自動 pull/push が走る。設定:

1. Obsidian → Settings → **obsidian-git**
2. 以下を有効化:
   - **Pull updates on startup**: ON（起動時 pull）
   - **Pull every X minutes**: 任意（例: 30）
   - **Vault backup interval (minutes)**: 60（commit + push の間隔、現環境踏襲）
   - **Sync method**: `merge` ではなく **`rebase`** 推奨（履歴がきれいに残る）
   - **Auto-push**: ON（離脱時に commit + push）

→ 以降は Obsidian を起動/前面化するだけで pull が走る。

### 方法B: 手動 pull（Obsidian を開かず CLI で最新化したい時）

```bash
cd ~/Documents/"Obsidian Vault"
git fetch origin
git status                   # 念のため現状確認
git pull --rebase origin main
```

alias 化しておくと楽:

```bash
# ~/.zshrc に追記
alias vaultpull='cd ~/Documents/"Obsidian Vault" && git pull --rebase origin main && cd -'
```

### 方法C: コンフリクト発生時のリカバリ

両Macで同時編集してしまった場合:

```bash
cd ~/Documents/"Obsidian Vault"
git pull --rebase origin main
# ↓ コンフリクトが出たら
git status                          # コンフリクトファイル一覧
# 該当ファイルを Obsidian / エディタで開いて <<<<<<< マーカーを手動解消
git add <解消したファイル>
git rebase --continue
git push origin main
```

> `.raw/` `<project>/refs/` は append-only ルール（`rules/40-obsidian.md`）。
> コンフリクト時もこれらは**両方残す**マージを選ぶ。既存 142 ノートも同じく無変更尊重。

### 運用の鉄則（コンフリクト予防）

1. **Mac を切り替える前に、離れる側の Obsidian を完全に閉じる**（バックグラウンド残留に注意 → `cmd+Q`）
2. 作業開始は必ず `vaultpull`（方法B）→ Obsidian 起動 の順、または Obsidian 起動だけで方法A に任せる
3. obsidian-git の auto-push を ON にしておく（離脱時に commit+push が走る）
4. Claude Code 側 PostToolUse の auto-commit と obsidian-git 側 commit が二重に走る可能性あり → どちらも push まで含む設定なら片方の push を OFF にして競合回避してもよい

---

## チェックリスト（別Mac側で順番にチェック）

**Phase 0（OS / CLI ベース整備）**:
- [ ] Xcode CLT インストール完了
- [ ] SSH 鍵生成 + GitHub 登録、`ssh -T git@github.com` 成功
- [ ] Homebrew インストール、PATH 通った
- [ ] Node.js v22.x、git、gh、Obsidian.app、Docker（任意）インストール
- [ ] `~/.claude/` クローン完了
- [ ] `claude` CLI 初回 OAuth 完了
- [ ] `codex` CLI 初回 login 完了
- [ ] FDA 等 OS パーミッション付与済み
- [ ] （任意）Firecrawl ローカル起動 `curl localhost:3002/health` = 200

**STEP 1-8（vault + MCP 再現）**:
- [ ] `ssh -T git@github.com` 成功
- [ ] `~/Documents/Obsidian Vault/.git` が存在
- [ ] Obsidian.app で vault を開ける、obsidian-git プラグイン enabled
- [ ] `vault backup: <ts>` コミットが定期的に出る
- [ ] `~/.claude/.mcp.json` が 1 台目と一致（`diff` で差分ゼロ）
- [ ] `echo $OPENAI_API_KEY $XAI_API_KEY $CODEX_PATH` が空でない
- [ ] Claude Code をターミナルから起動 → `mcp__mcpvault__*` ツールが見える
- [ ] vault 内で起動 → `wiki/hot.md` が SessionStart で表示される
- [ ] vault 内で `wiki/` 配下を編集 → auto-commit が走る
- [ ] vault 外プロジェクトで編集 → vault に余計なコミットが入らない（hook guard が効いている）

---

## 手動残り（codify 不可・各機で 1 回）

機械的にスクリプト化できず、別Macで毎回手で済ませるしかない項目:

| 項目 | 理由 |
|---|---|
| GitHub SSH 鍵生成 & Web UI 登録 | 鍵は機密、機械的に配布しない（鶏卵問題回避のため最初に実行） |
| Xcode Command Line Tools インストール | OS ダイアログ操作必須 |
| `claude` 初回 OAuth | ブラウザ手動認可 |
| `codex login` | ChatGPT アカウントでブラウザ手動認可 |
| `~/.zshrc` のシークレット `export` | 値は 1台目 / 1Password から手動転記 |
| Obsidian.app の community plugins 信頼ダイアログ | OS UI 操作 |
| obsidian-git の Author identity / 同期方式設定 | プラグイン GUI 操作 |
| FDA（Full Disk Access）付与 | System Settings の Privacy 画面で手動チェック |
| Docker Desktop 初回起動 + サインイン（任意） | OS GUI 操作 |
| Firecrawl コンテナ起動（任意） | Docker 常駐前提、使わなければスキップ |

---

## 参照

- `~/.claude/rules/40-obsidian.md` — vault 不変ルール、hook 仕様
- `~/.claude/CLAUDE.md` §Obsidian 連携 — 併用方針（claude-obsidian / obsidian-now-done）
- `secret-management` スキル — `${VAR}` プレースホルダー方式
- `machine-bootstrap` スキル — 新Mac 一発初期化（本手順の上位）
- `codify-config` スキル — 設定変更を再現スクリプト化
- vault repo: <https://github.com/666666ma999999/obsidian_work>
