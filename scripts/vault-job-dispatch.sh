#!/bin/bash
# vault-job-dispatch.sh — VaultJobs.app（TCCラッパー）から呼ばれるジョブ振り分け
#
# なぜ: launchd の bash 直実行は Documents(vault) を TCC に無音拒否される（2026-07-17 実障害）。
#       app bundle 経由なら許可ダイアログ1クリックで済む。複数ジョブを1アプリに束ねると
#       許可も1回で済むため、ジョブ本体はここで CLAUDE_JOB（plist の EnvironmentVariables）で分岐する。
# ⚠️ VaultJobs.app を再ビルドすると TCC 許可が無効化される（再生成は build-vaultjobs-app.sh）。
set -uo pipefail

case "${CLAUDE_JOB:-}" in
  wiki)
    "$HOME/.claude/scripts/vault-prompt-runner.sh" "$HOME/Documents/Obsidian Vault/00_General/prompts/scheduled/wiki-daily-ingest.md" \
      && /usr/bin/python3 "$HOME/.claude/scripts/wiki_ingest_apply.py" "$HOME/Documents/Obsidian Vault/wiki/meta/wiki-daily-ingest-result.md"
    ;;
  eng)
    /usr/bin/python3 "$HOME/.claude/scripts/eng_vocab_extract.py" \
      && "$HOME/.claude/scripts/vault-prompt-runner.sh" "$HOME/Documents/Obsidian Vault/00_General/prompts/scheduled/eng-vocab-weekly.md" \
      && /usr/bin/python3 "$HOME/.claude/scripts/eng_vocab_apply.py" "$HOME/Documents/Obsidian Vault/00_Inbox/eng-reports/eng-vocab-weekly-result.md"
    ;;
  *)
    # 許可ダイアログを出すためだけの起動（open -a VaultJobs）ではここに来る。正常系。
    echo "[vault-job-dispatch] CLAUDE_JOB 未指定（許可トリガー起動）" >&2
    exit 0
    ;;
esac
