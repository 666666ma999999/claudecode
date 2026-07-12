---
description: X検索キーワード群パイプライン（influxプロジェクト）の状態表示・手動更新・再生成
argument-hint: "[show|update|regen|render]"
---

# X検索キーワード群パイプライン操作

設計正本: `~/.claude/docs/x-keywords-plan.md`（フロー全体は §A）
実体: `~/.claude/bin/obs-x-keywords`（wrapper・masa-2固定・hostname ガードあり）
成果物ノート: `02_Ai/influx/influx_x_search_keywords.md`

## 引数の解釈

$ARGUMENTS

- 引数なし または `show` → `bash ~/.claude/bin/obs-x-keywords --show`
    - latest.json の世代(gen/rev)・クラスタ数・直近fetch_runを表示するだけ（書込なし・全Mac許可）
- `update` → `bash ~/.claude/bin/obs-x-keywords --fetch`
    - 実fetch（docker経由）→ worklist → トリガー発火時のみLLM生成+ingest。週次自動と同じ経路
- `regen` → `bash ~/.claude/bin/obs-x-keywords --no-fetch --force --reason "manual regen"`
    - fetchをスキップし、既存rawのまま強制的に次世代を生成（手動確認・observation windowは進めない）
- `render` → `bash ~/.claude/bin/obs-x-keywords --render-only`
    - 台帳から latest.json とノートを再導出するだけ（LLM呼び出しなし）

## 実行後にすること

1. 上記コマンドの実行結果（標準出力・exit code）をそのまま報告する
2. exit code が 0 以外の場合は exit code の意味を `~/.claude/docs/x-keywords-plan.md` §A の状態遷移（UPDATED/NO_CHANGE/DEGRADED/FAILED/REJECTED、または worklist/ingest の abort code）と突き合わせて説明する
3. ノート `~/Documents/Obsidian Vault/02_Ai/influx/influx_x_search_keywords.md` のパスを案内し、内容を確認したい場合は Read する
4. `~/.claude/state/x-keywords.log` に実行履歴が1行追記されていることを案内する
