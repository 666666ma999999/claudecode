#!/usr/bin/env bash
# mcp-grok-setup.sh — grok-search MCP を ~/.claude/.mcp.json に冪等登録
#   codify: 2026-04-24
#   対応 MCP: grok-search-mcp (npx -y grok-search-mcp)
#
# 手動残り（スクリプト化しない）:
#   - XAI_API_KEY の値を ~/.zshrc に export する（secret-management スキル参照）
#       例) echo 'export XAI_API_KEY=xai-xxxx...' >> ~/.zshrc
#   - 追記後、ターミナル再起動 or `source ~/.zshrc`
#   - Claude Code をターミナルから再起動（Launchpad/Dock 起動は zshrc を読まない）
#
# Usage:
#   mcp-grok-setup.sh status    .mcp.json / XAI_API_KEY / npx 到達性を確認
#   mcp-grok-setup.sh apply     .mcp.json に grok-search ブロックを追加（既存なら no-op）
#   mcp-grok-setup.sh revert    .mcp.json から grok-search ブロックを削除
#   mcp-grok-setup.sh --help

set -euo pipefail

MCP_FILE="${HOME}/.claude/.mcp.json"
SERVER_KEY="grok-search"

usage() {
    cat <<'EOF'
mcp-grok-setup.sh — grok-search MCP を ~/.claude/.mcp.json に冪等登録

Usage:
  mcp-grok-setup.sh status     現状表示
  mcp-grok-setup.sh apply      grok-search ブロックを追加（冪等）
  mcp-grok-setup.sh revert     grok-search ブロックを削除
  mcp-grok-setup.sh --help     このメッセージ

Manual steps (別途必要):
  1. ~/.zshrc に `export XAI_API_KEY=xai-...` を追記
  2. ターミナル再起動 or `source ~/.zshrc`
  3. Claude Code をターミナルから再起動
EOF
}

die() { echo "error: $*" >&2; exit 1; }

require_jq() {
    command -v jq >/dev/null 2>&1 || die "jq が未インストールです。brew install jq"
}

has_block() {
    [[ -f "${MCP_FILE}" ]] || { echo "false"; return; }
    if jq -e ".mcpServers.\"${SERVER_KEY}\"" "${MCP_FILE}" >/dev/null 2>&1; then
        echo "true"
    else
        echo "false"
    fi
}

cmd_status() {
    require_jq

    echo "mcp file:   ${MCP_FILE}"
    if [[ -f "${MCP_FILE}" ]]; then
        echo "  exists:   yes"
    else
        echo "  exists:   no (apply で新規作成)"
    fi

    local present
    present="$(has_block)"
    echo "  ${SERVER_KEY}: ${present}"

    if [[ "${present}" == "true" ]]; then
        echo ""
        echo "current block:"
        jq ".mcpServers.\"${SERVER_KEY}\"" "${MCP_FILE}" | sed 's/^/  /'
    fi

    echo ""
    if [[ -n "${XAI_API_KEY:-}" ]]; then
        echo "XAI_API_KEY: set (len=${#XAI_API_KEY})"
    else
        echo "XAI_API_KEY: NOT set — ~/.zshrc に export が必要"
    fi

    echo ""
    if command -v npx >/dev/null 2>&1; then
        echo "npx:         $(command -v npx)"
    else
        echo "npx:         NOT found — Node.js を machine-bootstrap で入れてください"
    fi
}

cmd_apply() {
    require_jq

    if [[ ! -f "${MCP_FILE}" ]]; then
        echo '{"mcpServers":{}}' > "${MCP_FILE}"
        echo "created: ${MCP_FILE}"
    fi

    if [[ "$(has_block)" == "true" ]]; then
        echo "already present: ${SERVER_KEY} (no change)"
    else
        local tmp
        tmp="$(mktemp)"
        jq --arg key "${SERVER_KEY}" '
            .mcpServers[$key] = {
                "command": "npx",
                "args": ["-y", "grok-search-mcp"],
                "env": {"GROK_API_KEY": "${XAI_API_KEY}"}
            }
        ' "${MCP_FILE}" > "${tmp}"
        mv "${tmp}" "${MCP_FILE}"
        echo "added: ${SERVER_KEY} -> ${MCP_FILE}"
    fi

    echo ""
    echo "next steps:"
    if [[ -z "${XAI_API_KEY:-}" ]]; then
        echo "  1. ~/.zshrc に 'export XAI_API_KEY=xai-...' を追記"
        echo "  2. source ~/.zshrc"
    fi
    echo "  3. Claude Code をターミナルから再起動"
    echo "  4. Claude Code で /mcp を叩いて grok-search が起動することを確認"
}

cmd_revert() {
    require_jq
    [[ -f "${MCP_FILE}" ]] || die "not found: ${MCP_FILE}"

    if [[ "$(has_block)" == "false" ]]; then
        echo "already absent: ${SERVER_KEY} (no change)"
        return 0
    fi

    local tmp
    tmp="$(mktemp)"
    jq --arg key "${SERVER_KEY}" 'del(.mcpServers[$key])' "${MCP_FILE}" > "${tmp}"
    mv "${tmp}" "${MCP_FILE}"
    echo "removed: ${SERVER_KEY} from ${MCP_FILE}"
}

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
