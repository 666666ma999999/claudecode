#!/usr/bin/env bash
# codex-switch.sh — Codex auth.json プロファイル切替
#   Plan: ~/.claude/plans/federated-frolicking-papert.md
#
# Usage:
#   codex-switch.sh status           # 現モード表示
#   codex-switch.sh chatgpt          # ChatGPT Pro モードへ切替
#   codex-switch.sh api              # API Key モードへ切替
#   codex-switch.sh --help

set -euo pipefail

CODEX_DIR="${HOME}/.codex"
AUTH_FILE="${CODEX_DIR}/auth.json"
PROFILES_DIR="${CODEX_DIR}/profiles"
VALID_MODES=(chatgpt api)

usage() {
    cat <<'EOF'
codex-switch.sh — Codex auth.json プロファイル切替

Usage:
  codex-switch.sh status       現在のモードを表示
  codex-switch.sh chatgpt      ChatGPT Pro (OAuth tokens) へ切替
  codex-switch.sh api          API Key モードへ切替
  codex-switch.sh --help       このメッセージ

Profile files:
  ~/.codex/profiles/chatgpt.json
  ~/.codex/profiles/api.json

切替後は Claude Code の再起動が必要です。
EOF
}

die() {
    echo "error: $*" >&2
    exit 1
}

current_mode() {
    [[ -L "${AUTH_FILE}" ]] || { echo "unknown"; return; }
    local target
    target="$(readlink "${AUTH_FILE}")"
    case "${target}" in
        profiles/chatgpt.json|"${PROFILES_DIR}/chatgpt.json") echo "chatgpt" ;;
        profiles/api.json|"${PROFILES_DIR}/api.json")         echo "api" ;;
        *)                                                    echo "unknown" ;;
    esac
}

cmd_status() {
    local mode target auth_mode last_refresh
    mode="$(current_mode)"
    echo "current: ${mode}"

    if [[ -L "${AUTH_FILE}" ]]; then
        target="$(readlink "${AUTH_FILE}")"
        echo "symlink: ${AUTH_FILE} -> ${target}"
    else
        echo "warning: ${AUTH_FILE} は symlink ではありません"
    fi

    if [[ -r "${AUTH_FILE}" ]] && command -v jq >/dev/null 2>&1; then
        auth_mode="$(jq -r '.auth_mode // "-"' "${AUTH_FILE}" 2>/dev/null || echo "-")"
        last_refresh="$(jq -r '.last_refresh // "-"' "${AUTH_FILE}" 2>/dev/null || echo "-")"
        echo "auth_mode (in file): ${auth_mode}"
        echo "last_refresh:        ${last_refresh}"
    fi

    echo ""
    echo "available profiles:"
    for m in "${VALID_MODES[@]}"; do
        local pf="${PROFILES_DIR}/${m}.json"
        if [[ -f "${pf}" ]]; then
            echo "  [x] ${m}  (${pf})"
        else
            echo "  [ ] ${m}  (missing: ${pf})"
        fi
    done
}

cmd_switch() {
    local mode="$1"
    local target_rel="profiles/${mode}.json"
    local target_abs="${PROFILES_DIR}/${mode}.json"

    [[ -f "${target_abs}" ]] || die "profile not found: ${target_abs}"

    local cur
    cur="$(current_mode)"
    if [[ "${cur}" == "${mode}" ]]; then
        echo "already on ${mode} (no change)"
        return 0
    fi

    ( cd "${CODEX_DIR}" && ln -sf "${target_rel}" auth.json )

    local new_cur
    new_cur="$(current_mode)"
    if [[ "${new_cur}" != "${mode}" ]]; then
        die "switch failed: current mode is ${new_cur}, expected ${mode}"
    fi

    echo "switched: ${cur} -> ${mode}"
    echo ""
    echo "NOTE: Claude Code を再起動してください（MCP サーバーの再接続が必要）。"
}

main() {
    if [[ $# -lt 1 ]]; then
        usage
        exit 1
    fi

    case "$1" in
        -h|--help|help) usage ;;
        status)         cmd_status ;;
        chatgpt|api)    cmd_switch "$1" ;;
        *)              echo "unknown subcommand: $1" >&2; usage; exit 1 ;;
    esac
}

main "$@"
