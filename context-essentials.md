# Context Essentials（compact 後 自動再注入）

このファイルは auto-compact 直後に SessionStart(matcher=compact) フックで cat される。
**腐る事実（進行中の作業・バージョン・スコア等）はここに書かない** — 生きた正本への
ポインタだけを置く（2026-07-04 化石注入の再発防止。旧版は 2 ヶ月前の作業を「進行中」と注入していた）。

## いま絶対に忘れてはいけないこと

1. **ユーザー**: masaaki_nagasawa（masaaki@mkb.ne.jp）・非エンジニア = BLUF + 平易な言葉で
2. **作業状態の正本**: 直前の状態はこの下に自動注入される `state/compact-restore.md`、継続作業は `<repo>/tasks/*.md` の Session Handoff を読む
3. **プロジェクト入口**: 記事 = `~/Desktop/biz/make_article/`（playbook は vault `02_Ai/x-buzz/make_article/`）／環境 = `~/.claude/`（GitHub 同期・2台運用。`~/.claude-mem/` は Mac 固有・rsync 禁止）

## 行動原則（compact で失いがち）

- **ファイル編集は cwd 配下のみ**（`~/.claude/` 配下は例外）
- **3 ファイル以上の変更で plan.md/task.md 必須**
- **完了報告前に implementation-checklist 実行・状態宣言には観測（コマンド出力）を添える**
- **曖昧は AskUserQuestion**（仮定で進めない）
