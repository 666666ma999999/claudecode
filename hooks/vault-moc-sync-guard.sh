#!/bin/bash
# vault-moc-sync-guard.sh
#
# 目的: repo 側の司令塔系ファイル (plan.md / tasks/phase-tracker.md / docs/measures-detail.md)
#       を更新したのに vault MOC (02_Ai/<group>/<project>_ope.md) を同期更新しない drift を防ぐ。
#       rules/41 §「drift 防止の同期義務」を機械的に思い出させる reminder hook。
#       ※ vault を自動で書き換えはしない (prime_suite/CLAUDE.md「手動更新」方針に整合)。
#
# 登録: PostToolUse(Write|Edit) と Stop の両方 (hook_event_name で分岐)。
# gate: ~/.claude/state/vault-cc-enabled が無ければ完全休眠。
# state:
#   ~/.claude/state/vault-moc-sync.pending      … 同期義務が残っている印 (中身=更新した repo ファイル)
#   ~/.claude/state/vault-moc-sync.blocked-once … Stop で1度ブロック済みの印 (無限ループ防止)

[ -f "$HOME/.claude/state/vault-cc-enabled" ] || exit 0

PENDING="$HOME/.claude/state/vault-moc-sync.pending"
BLOCKED="$HOME/.claude/state/vault-moc-sync.blocked-once"

input=$(cat 2>/dev/null)
[ -n "$input" ] || exit 0

event=$(printf '%s' "$input" | python3 -c 'import sys,json
try: print(json.load(sys.stdin).get("hook_event_name",""))
except Exception: print("")' 2>/dev/null)

case "$event" in
  PostToolUse)
    fp=$(printf '%s' "$input" | python3 -c 'import sys,json
try:
    d=json.load(sys.stdin); ti=d.get("tool_input",{}) or {}
    print(ti.get("file_path") or d.get("file_path") or "")
except Exception: print("")' 2>/dev/null)
    [ -n "$fp" ] || exit 0
    case "$fp" in
      */prime_suite/*/plan.md|*/prime_suite/*/tasks/phase-tracker.md|*/prime_suite/*/docs/measures-detail.md)
        # repo 司令塔ファイルを更新 → 同期義務を立てる
        if [ ! -f "$PENDING" ]; then
          printf '%s\n' "$fp" > "$PENDING"
          rm -f "$BLOCKED"
        fi
        ;;
      */02_Ai/*/*_ope.md)
        # vault MOC を更新 → 同期完了とみなし解除
        rm -f "$PENDING" "$BLOCKED"
        ;;
    esac
    exit 0
    ;;
  Stop)
    [ -f "$PENDING" ] || exit 0
    src=$(head -1 "$PENDING" 2>/dev/null)
    msg="vault MOC 未同期です。repo 司令塔ファイル ($src) を更新しましたが、対応する vault MOC (02_Ai/<group>/<sub>_ope.md・例: AIads_ope.md / AIcrm_ope.md / make_article_ope.md / x-operation_ope.md 等) のサマリーと frontmatter last_updated を同期更新していません (rules/41 §drift 防止の同期義務)。vault MOC を同期更新するか、同期不要なら 'rm ~/.claude/state/vault-moc-sync.pending' を実行し理由を述べてください。"
    if [ ! -f "$BLOCKED" ]; then
      # 初回 Stop: ブロックして Claude に同期を促す (escape hatch あり)
      touch "$BLOCKED"
      printf '%s' "$msg" | python3 -c 'import sys,json; print(json.dumps({"decision":"block","reason":sys.stdin.read()}))'
    else
      # 2 回目以降: 無限ループ防止のため警告のみ (ブロックしない)
      echo "⚠️ $msg"
    fi
    exit 0
    ;;
  *)
    exit 0
    ;;
esac
