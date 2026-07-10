---
name: machine-bootstrap
description: 新しい Mac（または2台目）を現環境と同じ Claude Code + Codex CLI + MCP 並列開発環境に揃える。brew/npm/MCP/LaunchAgent の「機械的に入れれば済む層」を bulk 実行し、OAuth・SSH・API keys など「手で握る層」を honesty セクションに明示する。実施記録を inventory/diff-YYYY-MM-DD.log に残すことで、何が自動化でき何が手動で残ったかを数値で証明する（記事 Fact-check 素材も兼ねる）。
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
- OAuth ログイン（Claude Code / Codex / gh / gcloud）
- SSH 秘密鍵（新規生成 → GitHub 登録を手動実施）
- GPG 秘密鍵（現状ゼロ件・署名運用なし）
- `~/.zshrc` の export 実値（`~/.zshrc.local` に分離済）
- X / Gmail / Drive の各 Cookie（influx 側 `x_profiles/` は手動コピー）

---

## 全手順 (STEP 0-6)

事前準備・brew/npm bulk install・MCP 配置・OAuth ログイン・VSCode + LaunchAgent の完全手順は `references/full-procedure.md` を参照。

## 検証（STEP 1〜3 終了時に実行）

```bash
# 1. brew + npm
brew bundle check --file=~/.claude/skills/machine-bootstrap/inventory/Brewfile
diff <(npm ls -g --depth=0 --parseable --json | jq -r '.dependencies | keys[]' | sort) \
     <(sort ~/.claude/skills/machine-bootstrap/inventory/npm-globals.txt)

# 2. MCP
claude  # 起動して /mcp で mcp-template.json の 3 サーバー（codex / context7 / memory）が authenticated を確認

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

- `output/drafts/art_013_2pc_fastdev_tools_2026-04-19.md` — 2台並列運用の実運用記事
- `refresh-x-cookies` skill（influx 側） — X Cookie の手動移行手順

## Decision Log

- **2026-04-24**: P1 起草。STEP 0/1/3/6 のみ実装、STEP 2/4/5 は骨子 placeholder。手動層は STEP 6 に一覧化。
- **2026-04-26**: Claude Code 2.1.120 から配布形式が Node script → Bun-compiled native Mach-O (`com.anthropic.claude-code` 署名) に変更。macOS TCC が新規アプリとして default-deny し、`~/Desktop` 配下で `ls` / `python3 <<EOF` / Stop hook が EPERM になる症状を 2台目セットアップで再現。STEP 6 に「FDA 付与」を追加し `~/.claude/scripts/grant-fda-claude.sh` を codify（apply/verify/status/path の 4 サブコマンド）。並行して `~/.claude/hooks/*.sh` の `python3 <<'PYEOF'` を `python3 -I <<'PYEOF'` に置換（cwd を sys.path から外す保険、6 ファイル）。
- **方針**: inventory 側は **KEY 名のみ**を持ち、値は持たない。送り出し側と受け取り側の Mac 間で plist/秘密鍵/Cookie は直接コピーしない。
