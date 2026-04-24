#!/bin/bash
# ~/.claude/hooks/obsidian-now-done-guard.sh
# PostToolUse hook: Obsidian Vault MDファイルのDONEエントリが refs/分離方式を守っているか検証する
#
# ルール（CLAUDE.md Obsidian連携）:
#   NOW→DONE移動時、元プロンプト全文は refs/YYYY-MM-DD_slug.md に退避する。
#   メインMDのDONEエントリは軽量フォーマット（要約+refsリンク+結果）。
#   見出しは h5（#####）固定。
#
# 新形式 (NEW) — 2026-04改定後:
#   ##### タスク名 (YYYY-MM-DD)
#   **プロンプト要約:** 1-3行
#   **元プロンプト:** [[refs/YYYY-MM-DD_slug]]
#
#   **結果:** サマリー
#
# 旧形式 (LEGACY) — grandfather 扱い:
#   ##### タスク名 (YYYY-MM-DD)
#   （元プロンプト全文を本体にインライン記録）
#
#   **結果:** サマリー
#
# 判別ロジック:
#   エントリ内に **プロンプト要約:** または **元プロンプト:** が1つでもあれば NEW 形式として厳格検証。
#   なければ LEGACY として **結果:** + 本文2行以上のみ検証（grandfather）。
#
# 許容リスト:
#   各MDと同じディレクトリに .obsidian-done-legacy-<basename> があれば、
#   記載された見出し行（完全一致）は全検証対象外。元プロンプト不可逆喪失済エントリ用。

input=$(cat 2>/dev/null || true)

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

if [ -z "$file_path" ]; then
  exit 0
fi

case "$file_path" in
  */Obsidian\ Vault/*.md) ;;
  *) exit 0 ;;
esac

# refs/ 配下のファイル自体への編集は監査対象外（refsは Write でのみ新規作成想定）
case "$file_path" in
  */refs/*) exit 0 ;;
esac

if [ ! -f "$file_path" ]; then
  exit 0
fi

if ! grep -q '^## DONE' "$file_path"; then
  exit 0
fi

done_section=$(awk '
  /^## DONE/ { in_done=1; next }
  /^## / && in_done { exit }
  in_done { print }
' "$file_path")

if [ -z "$done_section" ]; then
  exit 0
fi

dir_path=$(dirname "$file_path")
base_name=$(basename "$file_path" .md)
legacy_file="${dir_path}/.obsidian-done-legacy-${base_name}"

# エントリをパース: 見出し\x01理由\x01refs_link\x01形式(NEW/LEGACY)
entries=$(echo "$done_section" | awk '
  BEGIN { current=""; has_result=0; has_summary=0; has_refs_marker=0; refs_link=""; body_lines=0 }
  function flush() {
    if (current == "") return
    reasons = ""
    is_new = (has_summary || has_refs_marker)
    if (is_new) {
      if (!has_result) reasons = reasons "NO_RESULT,"
      if (!has_summary) reasons = reasons "NO_SUMMARY_MARKER,"
      if (!has_refs_marker) reasons = reasons "NO_REFS_MARKER,"
      else if (refs_link == "") reasons = reasons "NO_REFS_LINK,"
    } else {
      if (!has_result || body_lines < 2) reasons = reasons "LEGACY_INCOMPLETE,"
    }
    form = is_new ? "NEW" : "LEGACY"
    printf "%s\x01%s\x01%s\x01%s\n", current, reasons, refs_link, form
    current=""; has_result=0; has_summary=0; has_refs_marker=0; refs_link=""; body_lines=0
  }
  /^##### / {
    flush()
    current=$0
    next
  }
  /\*\*結果:\*\*/ { has_result=1 }
  /\*\*プロンプト要約:\*\*/ { has_summary=1 }
  /\*\*元プロンプト:\*\*/ {
    has_refs_marker=1
    if (match($0, /\[\[[^]]+\]\]/)) {
      raw = substr($0, RSTART+2, RLENGTH-4)
      # パイプ以降（表示名）を除去
      idx = index(raw, "|")
      if (idx > 0) raw = substr(raw, 1, idx-1)
      refs_link = raw
    }
  }
  /^./ && !/^##### / { body_lines++ }
  END { flush() }
')

violations=""
while IFS=$'\x01' read -r heading reasons refs_link form; do
  [ -z "$heading" ] && continue

  # 許容リスト（legacy-grandfather明示指定）
  if [ -f "$legacy_file" ] && grep -Fxq "$heading" "$legacy_file"; then
    continue
  fi

  # 構文違反あり
  if [ -n "$reasons" ]; then
    violations+="$heading [$form] | ${reasons%,}"$'\n'
    continue
  fi

  # NEW形式のみ refs ファイル実在・非空検証
  if [ "$form" = "NEW" ]; then
    refs_clean=$(echo "$refs_link" | sed 's|\.md$||' | sed 's|^/||')
    refs_path="${dir_path}/${refs_clean}.md"
    if [ ! -f "$refs_path" ]; then
      violations+="$heading [NEW] | REFS_FILE_NOT_FOUND: ${refs_path}"$'\n'
      continue
    fi
    refs_size=$(wc -c < "$refs_path" 2>/dev/null || echo 0)
    if [ "$refs_size" -lt 50 ]; then
      violations+="$heading [NEW] | REFS_FILE_TOO_SMALL: ${refs_path} (${refs_size} bytes)"$'\n'
    fi
  fi
done <<< "$entries"

if [ -n "$violations" ]; then
  cat >&2 <<EOF
[OBSIDIAN NOW→DONE FORMAT VIOLATION]
File: $file_path

以下のDONEエントリが規定フォーマット違反です。
（~/.claude/CLAUDE.md「Obsidian連携」参照）

違反エントリ:
$violations

── NEW形式（refs/分離方式 — 推奨） ──
  ##### タスク名 (YYYY-MM-DD)
  **プロンプト要約:** 1-3行
  **元プロンプト:** [[refs/YYYY-MM-DD_slug]]

  **結果:** サマリー

  ＋ 同ディレクトリの refs/YYYY-MM-DD_slug.md に元プロンプト全文を保存
  ＋ refs ファイルの先頭:
       # タスク名 (YYYY-MM-DD)
       参照元: [[../<元ファイル名>]]

       ---

       （NOWの元プロンプト全文）

── LEGACY形式（grandfather — 既存エントリのみ） ──
  ##### タスク名 (YYYY-MM-DD)
  （元プロンプト全文をインライン）

  **結果:** サマリー

チェック項目:
  NEW判定（**プロンプト要約:** または **元プロンプト:** を含む）→ 3マーカー全部 + refs実在 + refs非空
  LEGACY判定（上記マーカーなし）→ **結果:** + 本文2行以上
EOF
  exit 2
fi

exit 0
