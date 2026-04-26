#!/usr/bin/env bash
# grant-fda-claude.sh — claude.exe を macOS Full Disk Access へ登録する手順支援
#   codify: 2026-04-26
#   発見トリガー: Stop hook で `PermissionError: Operation not permitted` が
#                 各プロジェクトで連発した（cwd=~/Desktop/biz/* 全滅）
#
# 背景:
#   Claude Code 2.1.x は配布形式が変わり、Bun-compiled native Mach-O
#   (Identifier=com.anthropic.claude-code, Hardened Runtime) として install される。
#   旧版（Node script + node 経由起動）と違って TCC は **完全に新規アプリ** 扱いし、
#   親アプリ (iTerm2 等) の Desktop/Documents grant は継承されない。
#   結果、~/Desktop 配下での scandir が EPERM になり以下が壊れる:
#     - ls ~/Desktop / find ~/Desktop（ディレクトリ列挙）
#     - python3 <<EOF（cwd が Desktop 配下のとき、起動直後の sys.path[0]=cwd の scandir）
#     - その他 readdir/getdirentries 系
#   一方、full path 既知の cat / mdfind は通る（非対称な壊れ方）。
#
# 手動残り（スクリプト化できない）:
#   - 「システム設定 → プライバシーとセキュリティ → フルディスクアクセス」での
#     `+` 追加・トグル ON 操作（Touch ID/password 必須、GUI のみ）
#   - 本スクリプトは path 検出・クリップボード投入・System Settings 起動・検証
#     の周辺だけを担う。
#
# Usage:
#   grant-fda-claude.sh status     FDA が必要かどうか現状確認
#   grant-fda-claude.sh apply      path をクリップボードに入れ System Settings を開く
#   grant-fda-claude.sh verify     付与後の動作確認（ls / python / hook smoke）
#   grant-fda-claude.sh path       claude.exe の絶対 path を stdout 出力
#   grant-fda-claude.sh --help

set -euo pipefail

# ---------- path detection ----------
detect_claude_path() {
    # 優先順:
    #   1. npm root -g/@anthropic-ai/claude-code/bin/claude.exe（lib 側 canonical）
    #   2. which claude（npm 側 wrapper bin）
    # 両者は byte-identical の copy で CDHash 同一 → どちらに FDA を当てても両方有効
    if command -v npm >/dev/null 2>&1; then
        local npm_root
        npm_root=$(npm root -g 2>/dev/null) || true
        if [ -n "$npm_root" ] && [ -f "$npm_root/@anthropic-ai/claude-code/bin/claude.exe" ]; then
            echo "$npm_root/@anthropic-ai/claude-code/bin/claude.exe"
            return 0
        fi
    fi
    if command -v claude >/dev/null 2>&1; then
        local p
        p=$(command -v claude)
        if file "$p" 2>/dev/null | grep -q "Mach-O"; then
            echo "$p"
            return 0
        fi
    fi
    return 1
}

check_desktop_access() {
    ls "$HOME/Desktop" >/dev/null 2>&1
}

cmd_status() {
    echo "[claude binary]"
    local p
    if p=$(detect_claude_path); then
        echo "  path:       $p"
        local id
        id=$(codesign -dvvv "$p" 2>&1 | awk -F= '/^Identifier=/{print $2; exit}')
        echo "  identifier: ${id:-unknown}"
        local auth
        auth=$(codesign -dvvv "$p" 2>&1 | grep -m1 "Authority=Developer ID" | sed 's/^Authority=//')
        echo "  signed by:  ${auth:-unsigned}"
    else
        echo "  path: NOT FOUND" >&2
        return 1
    fi
    echo ""
    echo "[Desktop folder access]"
    if check_desktop_access; then
        echo "  ✅ ls ~/Desktop OK — FDA grant 済み（または不要）"
    else
        echo "  ❌ ls ~/Desktop EPERM — FDA grant 必要"
        echo "  → grant-fda-claude.sh apply"
    fi
}

cmd_apply() {
    local p
    p=$(detect_claude_path) || { echo "claude binary が見つかりません" >&2; exit 1; }

    if check_desktop_access; then
        echo "✅ 既に Desktop access 通ってます。grant 不要です。"
        return 0
    fi

    printf '%s' "$p" | pbcopy
    echo "✓ path をクリップボードにコピー:"
    echo "    $p"
    echo ""
    echo "✓ システム設定をフルディスクアクセスペインで開きます..."
    open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
    echo ""
    cat <<'EOF'
[GUI 手順]
  1. 右下の `+` を押す → Touch ID / password で認証
  2. Finder で Cmd+Shift+G → Cmd+V → Return（path はクリップボード済み）
  3. claude.exe を選択 → 「開く」
  4. リストに claude.exe が追加され、左のトグルが ON になっていることを確認
  5. （任意）既存の claude セッションを再起動
       → 実測上 TCC 反映は即時。再起動不要なケースが多い
  6. → grant-fda-claude.sh verify
EOF
}

cmd_verify() {
    local rc=0

    echo "[1] ls ~/Desktop"
    if check_desktop_access; then
        ls "$HOME/Desktop" | head -5 | sed 's/^/    /'
        echo "    ✅ OK"
    else
        echo "    ❌ FAIL — まだ EPERM。GUI 手順を見直してください"
        return 1
    fi
    echo ""

    echo "[2] python3 heredoc from a Desktop subdir（FDA 無いと EPERM）"
    local target=""
    for d in "$HOME/Desktop/biz" "$HOME/Desktop"; do
        [ -d "$d" ] && { target="$d"; break; }
    done
    if [ -z "$target" ]; then
        echo "    SKIP — ~/Desktop も無い"
    else
        local tmp
        tmp=$(mktemp)
        cat > "$tmp" <<'PYEOF'
import os
print("    ✅ OK cwd=" + os.getcwd())
PYEOF
        if (cd "$target" && python3 < "$tmp" 2>&1); then
            :
        else
            echo "    ❌ FAIL — python3 が cwd scandir で EPERM"
            rc=1
        fi
        rm -f "$tmp"
    fi
    echo ""

    echo "[3] stop hook smoke test (~/.claude/hooks/stop-continue-until-green.sh)"
    local hook="$HOME/.claude/hooks/stop-continue-until-green.sh"
    if [ -x "$hook" ] && [ -n "$target" ]; then
        local out
        out=$(cd "$target" && printf '{"transcript_path":"x","cwd":"%s"}' "$target" \
            | bash "$hook" 2>&1) || true
        if echo "$out" | grep -qE "PermissionError|Operation not permitted"; then
            echo "    ❌ FAIL:"
            echo "$out" | sed 's/^/      /'
            rc=1
        else
            echo "    ✅ OK"
        fi
    else
        echo "    SKIP"
    fi
    echo ""

    if [ "$rc" -eq 0 ]; then
        echo "✅ 全部通りました。FDA grant 反映完了。"
    else
        echo "⚠️ 失敗あり。grant-fda-claude.sh status で再確認してください"
    fi
    return "$rc"
}

case "${1:-}" in
    status) cmd_status ;;
    apply)  cmd_apply ;;
    verify) cmd_verify ;;
    path)   detect_claude_path ;;
    -h|--help|"")
        cat <<'EOF'
grant-fda-claude.sh — claude.exe を macOS Full Disk Access へ登録する手順支援

Usage:
  grant-fda-claude.sh status     FDA 必要かどうか現状確認
  grant-fda-claude.sh apply      path クリップボード投入 + System Settings 起動 + 手順
  grant-fda-claude.sh verify     付与後動作確認（ls / python / hook smoke）
  grant-fda-claude.sh path       claude.exe 絶対 path を stdout 出力

背景:
  Claude Code 2.1.x は Bun-compiled native Mach-O (com.anthropic.claude-code 署名)。
  macOS TCC は新規アプリ扱いで Desktop/Documents folder access を default deny。
  親アプリ (iTerm2 等) の grant は継承されない。
  GUI 操作のみで付与可能。本スクリプトはその周辺を支援。

典型運用:
  ./grant-fda-claude.sh status   # 必要かチェック
  ./grant-fda-claude.sh apply    # GUI を開く
  # ←ここで GUI 操作
  ./grant-fda-claude.sh verify   # 動作確認

Codified: 2026-04-26
EOF
        ;;
    *) echo "Unknown subcommand: $1" >&2; exit 2 ;;
esac
