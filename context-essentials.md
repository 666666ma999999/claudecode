# Context Essentials（compact 後 自動再注入）

このファイルは auto-compact 直後に SessionStart(matcher=compact) フックで cat される。
失われやすい「最重要事項」を 200 字以内で記載する。長くなったら `topics/` に分離してリンクのみ残す。

## いま絶対に忘れてはいけない 5 行

1. **ユーザー名/メール**: masaaki_nagasawa（masaaki@mkb.ne.jp）
2. **記事プロジェクト**: `~/Desktop/biz/make_article/` — 全ドラフトは `output/drafts/art_NNN_*.md`
3. **art_015 進行中**: `art_015_memory_loss_prevention_2026-04-24.md` / fact_verified=false / prompts_verified=false / score=0.00（公開前ゲート未通過）
4. **claude-mem 稼働中**（v12.4.7 / port 37701 / `~/.claude-mem/claude-mem.db`）— DB が増え続けていることを定期確認
5. **2台運用**: `~/.claude` 配下は GitHub 同期、`~/.claude-mem/` は Mac 固有（rsync 禁止：WAL/Lock 競合）

## 行動原則（compact で失いがち）

- **ファイル編集は cwd 配下のみ**（`~/.claude/` 配下は例外）
- **3 ファイル以上の変更で plan.md/task.md 必須**
- **完了報告前に implementation-checklist 実行**
- **AskUserQuestion で曖昧点を確認する**（仮定で進めない）
