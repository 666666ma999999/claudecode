---
name: codify-config
description: |
  1 台目で試行錯誤した設定変更を、再実行可能なシェルスクリプトに codify し、`~/.claude/scripts/` に置いて git 同期で 2 台目以降へ配布するためのスキル。
  MCP 設定の新設・変更、`~/.codex/` の構成変更、`~/.zshrc` への export 追加 等を実施した直後に呼ぶ。
  login / install / OAuth 等「各機で 1 回手動が必要」なものはスクリプト化しない（手動残りとして明記する）。
  キーワード: 2 台目, 手順書, runbook, 再現, codify, codex-switch, mcp 追加, zshrc export
  NOT for: 新規 Mac 一発初期化（→ machine-bootstrap）、シークレット値そのものの管理（→ secret-management）、設定配置判断（→ config-placement-guide）
triggers:
  - MCP 設定 追加
  - MCP 設定 変更
  - ~/.codex/ 変更
  - ~/.zshrc export 追加
  - 2 台目で同じ設定を再現
  - runbook スクリプト化
  - codify config
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash]
---

# codify-config — 設定変更を再実行可能なスクリプトにする

## 1. コア原則

1 台目で詰まった設定は、**2 台目が試行錯誤ゼロで再現できる形**に固定する。形式はシェルスクリプト（`~/.claude/scripts/*.sh`）。
git 同期に乗せれば配布は自動。2 台目は `bash ~/.claude/scripts/<name>.sh <cmd>` で終わる。

参考実装: `~/.claude/scripts/codex-switch.sh`（Codex `auth.json` の symlink 差し替えを `status`/`chatgpt`/`api` 3 コマンドで固定化）。

## 2. 発動タイミング

次のいずれかを実施した直後に本スキルを呼ぶ:

- `~/.claude/.mcp.json` / `.claude/.mcp.json` に新規 MCP サーバーを追加、または既存サーバー設定を変更した
- `~/.codex/` 配下のファイル・ディレクトリ構成を変更した（profile 分離、config.toml 調整、symlink 組み替え 等）
- `~/.zshrc` に新しい `export` を追加した（API キーは `secret-management` 側と併用）
- 「あ、この手順 2 台目でもやるのか」と気づいた瞬間

## 3. スクリプト化する / しないの判定

| 対象 | 判定 | 理由 |
|---|---|---|
| 設定ファイル編集（JSON/TOML/YAML） | **する** | 冪等に書ける |
| symlink 差し替え / ディレクトリ作成 | **する** | 冪等に書ける |
| 環境変数 `export` の追加 | **する** | `~/.zshrc` への追記は冪等化可能（既存行チェック付き） |
| `brew install` / `npm install -g` | **しない**（machine-bootstrap に任せる） | 重複管理。Brewfile / npm-globals.json 側が SSoT |
| OAuth ログイン / ブラウザ認証 | **しない** | 各機で 1 回手動必須。手順書 README に「手動」と書く |
| API キー値そのものの配布 | **しない** | secret-management の `~/.zshrc` 方式に従う。値の持ち出しは別経路 |
| GUI アプリのクリック操作 | **しない** | 自動化 ROI が合わない |

**迷ったら「スクリプト化しない」側に倒す。** 手動残りは冒頭コメントに列挙。

## 4. 生成規約（~/.claude/scripts/<name>.sh）

### 4.1 ファイル名

- ケバブケース: `codex-switch.sh`, `mcp-add-context7.sh`, `zshrc-export-guard.sh`
- 目的が名前から分かること（何を codify したか）

### 4.2 必須要素

| 要素 | 理由 |
|---|---|
| `#!/usr/bin/env bash` + `set -euo pipefail` | bash 厳格モード。エラーで必ず止まる |
| 冒頭コメント: **何を codify したか / 手動残り** | 2 台目が 5 行読むだけで判る |
| `usage()` 関数 + `--help` | 引数忘れでも自爆しない |
| 冪等性（再実行しても壊れない） | 2 台目で誤って 2 回叩いても安全 |
| サブコマンド形式: `status` / `apply` / `revert`（可能なら） | 現状確認 → 変更 → 戻す、の 3 動作が揃う |

### 4.3 スケルトン

```bash
#!/usr/bin/env bash
# <name>.sh — <何を codify したか 1 行>
#   原典: <1 台目で書いた plan.md / session のパス or 日付>
#
# 手動残り:
#   - <例: 初回の OAuth ログイン>
#   - <例: 最初の ~/.zshrc への値書き込み>
#
# Usage:
#   <name>.sh status    現状表示
#   <name>.sh apply     設定適用
#   <name>.sh revert    戻す

set -euo pipefail

usage() { cat <<'EOF'
<name>.sh — <1 行要約>

Usage:
  <name>.sh status
  <name>.sh apply
  <name>.sh revert
EOF
}

die() { echo "error: $*" >&2; exit 1; }

cmd_status()  { : ; }
cmd_apply()   { : ; }
cmd_revert()  { : ; }

main() {
    [[ $# -ge 1 ]] || { usage; exit 1; }
    case "$1" in
        -h|--help|help) usage ;;
        status)         cmd_status ;;
        apply)          cmd_apply ;;
        revert)         cmd_revert ;;
        *)              echo "unknown: $1" >&2; usage; exit 1 ;;
    esac
}

main "$@"
```

### 4.4 冪等性の書き方

| 操作 | 冪等パターン |
|---|---|
| symlink 差し替え | 既存リンクの target を確認 → 同じなら no-op |
| ディレクトリ作成 | `mkdir -p` |
| `~/.zshrc` 追記 | `grep -qxF "export FOO=..." ~/.zshrc \|\| echo "export FOO=..." >> ~/.zshrc` |
| JSON / TOML 編集 | `jq` で in-place（バックアップ付き）、または `python3 -c` |
| ファイル上書き | `diff -q` で差分確認 → 変更ない場合は no-op |

## 5. 生成後フロー

1. スクリプトを `~/.claude/scripts/<name>.sh` に作成
2. `chmod +x ~/.claude/scripts/<name>.sh`
3. **1 台目で実行確認**: `./~/.claude/scripts/<name>.sh status` → `./<name>.sh apply` → 期待挙動を確認
4. `cd ~/.claude && git add scripts/<name>.sh && git commit -m "feat(scripts): codify <何を> via <name>.sh"`
5. 2 台目で `git pull` → 動作確認
6. （必要なら）README に 1 行追記: `~/.claude/scripts/README.md` を使う運用なら `<name>.sh — <1 行要約>` を追加

## 6. 他スキルとの関係（クロスリファレンス）

| スキル | 関係 |
|---|---|
| `machine-bootstrap` | 新規 Mac 初期化時の文脈で呼ばれる。Brewfile / npm-globals.json / MCP 構造配置は machine-bootstrap 側が SSoT。codify-config は **継続運用**（稼働中 Mac での設定変更を 2 台目へ配る）を担う |
| `secret-management` | `${VAR}` プレースホルダー + `~/.zshrc` export 方式は secret-management の方針を踏襲。codify-config は「export 追加の手順」をスクリプト化するが、**値は書き込まない**（値は各機で `~/.zshrc` に手書き or 1Password 経由） |
| `config-placement-guide` | 「その設定を `~/.claude/` に置くかプロジェクト配下に置くか」の判断は config-placement-guide。codify-config は置き場所が決まった後の「再現スクリプト作成」を担う |
| `skill-creator` | 本スキル自体が skill-creator で作られた。スキル化 vs スクリプト化の判断は skill-lifecycle-reference |

## 7. 判断フロー（要点サマリ）

```
設定を 1 台目で変更した
  │
  ├─ login / install / OAuth？
  │   └─ YES → スクリプト化しない。2 台目で手動と明記
  │
  ├─ 設定ファイル編集 / symlink / export 追加？
  │   └─ YES → ~/.claude/scripts/<name>.sh 作成
  │            ├─ 冪等性を確保（§4.4）
  │            ├─ status/apply/revert 3 コマンド
  │            ├─ 冒頭コメントに「手動残り」を列挙
  │            └─ git commit で 2 台目へ配布
  │
  └─ brew / npm 等のインストール？
      └─ machine-bootstrap の SSoT（Brewfile/npm-globals.json）を更新
```

## 8. Red Flags（これを見たら本スキル発動）

- 「2 台目でも同じ設定やった方がいい気がする」と思った瞬間
- `~/.codex/` や `~/.claude/.mcp.json` を `vim` / `code` で手編集した
- `~/.zshrc` に新しい `export` を追加した
- 「この手順、次やるとき思い出せるかな」と感じた
- 1 台目で 10 分以上悩んで解決した設定変更

## 9. Anti-Patterns

- ❌ スクリプトに API キー値を直書き（secret-management 違反）
- ❌ `brew install` を codify-config のスクリプトに含める（machine-bootstrap の Brewfile と重複）
- ❌ 1 回しか使わない 1 行の操作までスクリプト化（過剰）
- ❌ `rm -rf` / 破壊的操作を `revert` 無しで入れる
- ❌ `set -euo pipefail` なし（エラーが無視されて 2 台目で壊れる）

## 10. チェックリスト（スクリプト作成後）

- [ ] `chmod +x` 済み
- [ ] `./<name>.sh --help` で usage が出る
- [ ] `./<name>.sh status` が読み取り専用で安全に実行できる
- [ ] `./<name>.sh apply` を 2 回叩いても同じ結果になる（冪等）
- [ ] 冒頭コメントに「手動残り」が書かれている
- [ ] `~/.claude/` 配下に配置され git でトラックされている
- [ ] 2 台目で `git pull` → 実行して動作確認済み
