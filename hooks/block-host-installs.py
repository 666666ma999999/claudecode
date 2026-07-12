#!/usr/bin/env python3
"""PreToolUse hook: Block host-level package installs. Force Docker usage."""
import json
import re
import shlex
import sys


DENY_PATTERNS = [
    r"\bpip3?\s+install\b",
    r"\bpython3?\s+-m\s+pip\s+install\b",
    r"\bpython3?\s+-m\s+venv\b",
    r"\bvirtualenv\b",
    r"\bnpm\s+(install|i|ci)\b",
    r"\byarn\s+(install|add)\b",
    r"\bpnpm\s+(install|add)\b",
    r"\bbun\s+(install|add)\b",
    r"\buv\s+(pip|venv)\b",
    r"\bpoetry\s+(install|add)\b",
    r"\bconda\s+(install|create)\b",
    r"\bsource\s+.*/?activate\b",
    r"\.\s+.*/?activate\b",
    r"\bnpx\s+\S",  # npx によるパッケージ実行（npm exec 経由インストール）
]

DOCKER_PREFIXES = (
    "docker compose exec",
    "docker compose run",
    "docker exec",
    "docker-compose exec",
    "docker-compose run",
    "docker run",
)

# Patterns that are explicitly allowed even if they match DENY_PATTERNS.
# グローバルCLAUDE.mdの適用除外「MCP設定、Claude Codeツール拡張、スキル検索」に対応。
#
# WHOLE_ALLOW_PATTERNS: path 依存で whole-command 全体を見ないと判定不可なもの限定。
# (例: `cd ~/.claude/mcp-servers && npm install` の場合 npm 単独では path が見えない)
# ⚠️ ここに登録した pattern は pipe injection 経由でも先頭 match で全体許可されるため、
#    新規追加は path 制約が無いと不安全 (2026-05-27 改修)。
WHOLE_ALLOW_PATTERNS = [
    # Claude Code 自身の upgrade (末尾 \s*$ で `... | npm install evil` 防止)
    r"\bnpm\s+(install|i|update|up)\s+(-g\s+)?@anthropic-ai/claude-code(@[\w.\-]+)?(\s+--force)?\s*$",
    # ~/.claude/mcp-servers/ 配下での MCP サーバーfork用 npm 操作 (path 制約あり)
    r"\.claude/mcp-servers\b.*\bnpm\s+(install|i|ci|run)\b",
    r"\bnpm\s+(install|i|ci|run)\b.*\.claude/mcp-servers\b",
]

# ALLOW_PATTERNS: 候補別ループでのみ照合。pipe injection で && / ; / | 結合された
# 各 candidate を独立に評価するので、`X && Y` の片方が allow でも他方が deny なら全体 deny。
ALLOW_PATTERNS = [
    r"\bnpm\s+(install|i)\s+(-g\s+)?@openai/codex\b",
    # kepano/obsidian-skills の defuddle skill が使う CLI
    r"\bnpm\s+(install|i)\s+(-g\s+)?defuddle\b",
    # npx skills 全 verb を AI 自律実行可に拡張 (2026-05-27 ユーザー指示・最大リスク受容)
    # 含む: find / add / install / update / check / list 等の全 sub-command
    # ⚠️ RCE リスク受容: `npx skills add` の postinstall は任意コード実行可能。
    #    Prompt Injection 経由で `npx skills add @evil/pkg` を踏むと
    #    SSH 鍵 / ~/.mcp.json (APIキー) / ~/.zshrc が外部送信されうる。
    #    流出は reversible でない (鍵入れ替え + 全 secrets ローテーション必須)。
    # 緩和策:
    #   1. 候補別ループでのみ照合 → pipe injection (`X && npx skills add evil`) は X 単独 deny
    #   2. `\S` 要求で `npx skills` 単体 (verb なし) は許可しない
    #   3. AI が install する owner/repo は Bash 実行前にユーザーが見るので review 機会あり
    r"\bnpx\s+skills\s+\S",
]


# --- 誤検知修正 (2026-07-10) -------------------------------------------------
# 旧実装は heredoc 本文・引数のクォート内文字列も deny 照合していたため、
# `grep "npm install"` や python heredoc 内の文書テキストで誤 deny が発生した。
# deny パターン自体は緩めず、「実行されないテキスト」だけを照合対象から外す。

# python heredoc (`python3 - <<'EOF' ... EOF`) の本文は python コードであり
# シェルで実行されないため除外する（既存の `python -c` 除外と同等の扱い）。
# ⚠️ bash/sh/zsh の heredoc は本文がそのまま実行されるため除去しない。
_PY_HEREDOC_RE = re.compile(
    r"(python3?[^\n<;|&]*<<-?\s*'?(\w+)'?[^\n]*\n)(.*?)(^\2\s*$)",
    re.DOTALL | re.MULTILINE,
)

# 引数文字列を実行しない読み取り専用テキスト検索コマンド。
# これらのクォート内リテラルは deny 照合前に除去する。
# ⚠️ echo/printf は `echo "pip install x" | sh` でリテラルが実行に化けるため含めない。
_QUOTE_SAFE_CMDS = ("grep", "egrep", "fgrep", "rg", "ag", "ack", "git", "find")

_QUOTED_RE = re.compile(r"'[^']*'|\"[^\"]*\"")


def strip_python_heredoc_bodies(cmd: str) -> str:
    """python heredoc の本文を deny 照合対象から除去する。"""
    return _PY_HEREDOC_RE.sub(lambda m: m.group(1) + m.group(4), cmd)


def strip_quoted_literals_if_safe(candidate: str) -> str:
    """先頭コマンドが読み取り専用検索系のときだけクォート内を除去した文字列を返す。"""
    stripped = candidate.strip()
    if not stripped:
        return candidate
    first = stripped.split()[0].rsplit("/", 1)[-1]
    if first in _QUOTE_SAFE_CMDS:
        return _QUOTED_RE.sub("", candidate)
    return candidate
# -----------------------------------------------------------------------------


def deny(reason: str):
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        }
    }))
    sys.exit(0)


def extract_inner_command(cmd: str) -> str:
    """bash -lc '...' 等のラッパーから内部コマンドを抽出"""
    try:
        parts = shlex.split(cmd)
    except ValueError:
        return cmd
    if len(parts) >= 3 and parts[0] in ("bash", "zsh", "sh") and parts[1] in ("-c", "-lc"):
        return parts[2]
    return cmd


def main():
    try:
        data = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        sys.exit(2)  # fail-closed: パース失敗はブロック扱い
    tool_name = data.get("tool_name", "")

    if tool_name != "Bash":
        return

    cmd = (data.get("tool_input") or {}).get("command", "")
    if not cmd:
        return

    # Docker経由なら許可
    normalized = " ".join(cmd.strip().split())
    for prefix in DOCKER_PREFIXES:
        if normalized.startswith(prefix):
            return

    # python -c "..." 内のコードはシェルコマンドではないためスキップ
    # （文字列リテラル内の "pip install" 等を誤検知しないため）
    if re.match(r"^\s*python3?\s+-c\b", cmd.strip()):
        return

    # python heredoc 本文（シェルで実行されないテキスト）を照合対象から除去
    # (2026-07-10 誤検知修正。[;&|] 分割前に行うこと — 本文中の | 等で断片化するため)
    cmd_scan = strip_python_heredoc_bodies(cmd)

    # 内部コマンドも検査（bash -c "pip install ..." 対策）
    inner = extract_inner_command(cmd_scan)
    candidates = {cmd_scan.strip(), inner.strip()}

    # && や ; で繋がれた複数コマンドも検査
    for candidate in list(candidates):
        for part in re.split(r"[;&|]+", candidate):
            candidates.add(part.strip())

    # Whole-command allow check: `cd <allowed-dir> && npm install` のような
    # path 依存コマンドは全体を見ないと許可判定できないため、WHOLE_ALLOW_PATTERNS のみ照合。
    # ⚠️ ALLOW_PATTERNS をここで使うと pipe injection (`X && Y` の X が allow なら全体許可)
    #    でバイパスされるため、path 制約あり pattern のみに限定 (2026-05-27 改修)。
    for allow_pat in WHOLE_ALLOW_PATTERNS:
        if re.search(allow_pat, cmd) or re.search(allow_pat, inner):
            return

    for candidate in candidates:
        # Check allow-list first: if ANY candidate matches an allow pattern, skip deny
        allowed = False
        for allow_pat in ALLOW_PATTERNS:
            if re.search(allow_pat, candidate):
                allowed = True
                break
        if allowed:
            continue

        # 読み取り専用検索コマンドのクォート内リテラルは実行されないため除去して照合
        scan_target = strip_quoted_literals_if_safe(candidate)

        for pattern in DENY_PATTERNS:
            if re.search(pattern, scan_target):
                deny(
                    "ホスト環境でのパッケージインストール/venv作成は禁止されています。\n"
                    "Docker経由で実行してください:\n"
                    "  docker compose exec dev pip install ...\n"
                    "  docker compose exec dev npm install ...\n"
                    "  docker compose run --rm dev python -m venv .venv\n"
                    "\n"
                    "※ `npx skills <verb>` は全 verb AI 自律実行可 (2026-05-27 緩和・ユーザー判断)。\n"
                    "   Claude Code upgrade は引き続き AI 実行不可 (Docker-Only 原則)。\n"
                    "   ユーザーが `!` プレフィックスでセッションシェル直接実行してください:\n"
                    "     ! npm install -g @anthropic-ai/claude-code@latest\n"
                    "   詳細: CLAUDE.md §Docker-Only 開発 / rules/10-git-and-execution-guard.md"
                )


if __name__ == "__main__":
    main()
