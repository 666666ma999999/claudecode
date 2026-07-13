<claude-mem-context>
# Memory Context

# [.claude] recent context, 2026-07-13 2:36pm GMT+9

Legend: 🎯session 🔴bugfix 🟣feature 🔄refactor ✅change 🔵discovery ⚖️decision 🚨security_alert 🔐security_note
Format: ID TIME TYPE TITLE
Fetch details: get_observations([IDs]) | Search: mem-search skill

Stats: 50 obs (19,979t read) | 988,832t work | 98% savings

### Jul 11, 2026
5872 9:48p 🟣 LLM Prompt正本 for X Keyword Extraction Created
### Jul 12, 2026
5893 8:26a ⚖️ Global Skill Candidacy: Cross-Project Web Page Search
5896 9:46a 🔵 bookmarks_viewer.html — Previously Built X Bookmarks Web Viewer Found
5897 " 🟣 X Keywords Ledger — Gen1 Baseline with 8 Active Search Clusters Ingested
5898 " 🔵 B5 Wiring Task State: Item 1 Done, Items 2–6 Not Yet Started After API Disconnect
5901 1:37p 🔴 bookmarks_keyword_worklist Tests: 43/44 Pass, 1 Stale Golden Value Failure
5902 " 🔵 test_real_bookmarks_jsonl Failure Confirmed Pre-existing Data Drift, Not Regression
5905 1:38p 🔴 B5 Item 2 Complete: obs-x-keywords wrapper script created at ~/.claude/bin/obs-x-keywords
5907 " 🔴 obs-x-keywords host-guard corruption persists after re-write; locale confirmed ja_JP.UTF-8; exact corrupt reference is on echo line 56 (${ALLOWED_HOST} expansion)
5908 " 🔴 ALLOWED_HOST corruption confirmed after third Write: Write tool systematically introduces U+FFFD on every serialization of the Japanese echo string on line 56
5906 1:42p 🔴 obs-x-keywords host-guard has Unicode corruption on ALLOWED_HOST variable reference (line 56)
5916 1:59p 🔴 ALLOWED_HOST encoding bug FIXED via Edit tool: host guard now emits explicit ERROR message with exit 2
5918 " 🔴 precedent-check skill created: 4-path search before creating any new artifact (mem-search / FS / routing / vault MOC)
5930 2:13p 🔵 X Bookmark Fetcher — Dual-Source Scroll+GraphQL Architecture
5931 4:01p 🔵 X Keyword Pipeline — Security & Freshness Hardening (B7a/B7b Batch)
5939 4:11p 🟣 influx ingest テストスイートに秘密スキャン回避ケースとworklist鮮度検証クラスを追加
5944 4:26p 🔴 x-keywords pipeline: P0×5 + P1×6 security/correctness fixes all completed
5948 " 🟣 fetch_bookmarks.py + wrapper: 5-case fetch status classification with observed_url_count
5945 4:29p 🔵 Test suite: 72/102 tests ERROR due to sandbox tempdir restriction in Claude Code execution context
5946 " 🔵 fetch_bookmarks.py _write_status_json lacks observed_url_count field
5961 4:34p 🔵 influx P0 fix セッション継続 — リトライfetch結果待ち
5965 4:46p 🔴 リトライfetchで observed_url_count=286 の基準値が台帳に記録 — Codex Condition 1 達成
5966 4:56p ✅ x-keywords パイプライン実装完了 — task.md/plan.md を最終状態に更新
5970 4:58p ✅ x-keywords パイプライン — グローバルルーティング・スキルドキュメント・プロジェクトメモリを一括更新
5976 5:31p 🔵 ~/.claude repo behind origin/main by 7 commits with local modifications
5977 " 🔵 ~/.claude origin/main contains 7 new commits with hooks, skills, and env automation
5978 7:45p 🟣 x-keywords pipeline and precedent-check skill staged for commit
5979 " 🟣 Committed x-keywords pipeline + precedent-check skill (1ccec58e)
5980 " 🔵 Merge conflict on pull: 3 files conflicted between local and origin/main
5981 " 🔵 settings.json model conflict: local "claude-fable-5[1m]" vs origin "sonnet"
5982 7:46p 🔵 Bookmark JSONL conflicts have 0 conflict markers and 0 lines on both sides
5983 " 🔵 Bookmark JSONL "conflicts" are symlinks with diverged target paths (65 vs 56 bytes)
5984 " 🔵 Symlink conflict root cause: different macOS usernames across machines (masaaki vs masaaki_nagasawa)
5985 " 🔵 git checkout --ours failed silently for symlink conflicts ("Updated 0 paths")
5986 7:47p ✅ config-placement-guide updated: ~/.claude/settings.local.json for machine-specific settings
5987 7:57p 🔴 ~/.claude multi-machine git sync: model key and symlinks separated from tracked files
S2453 ~/.claude git sync conflict fix between two Macs — user asked "よく分かりません" (I don't understand) about what to do next (Jul 12 at 8:00 PM)
S2454 「AIで作業してください」— 新セッション開始、作業内容未定 (Jul 12 at 8:44 PM)
5988 8:45p 🔵 hook-development-guide SKILL.md — Claude Code hook設計ガイドの内容確認
5989 " 🔵 ~/.claude SessionStart hooks 完全一覧（settings.json実測）
S2455 GitHub pull request — confirmed ~/.claude repo is already up to date with remote (Jul 12 at 8:50 PM)
5992 8:50p 🟣 machine-local-bootstrap.sh — マシン固有設定の SessionStart 自動生成 hook 新設
5993 8:51p ✅ User initiated GitHub pull on secondary Mac
S2484 prime_suite AIが「言うことを聞かなくなった」原因調査と復旧 (Jul 12 at 9:00 PM)
### Jul 13, 2026
6122 1:21p ⚖️ x-keywords v2 AI検索代行ダイジェスト 設計レビュー依頼（軽量敵対的・P0/P1のみ）
6125 1:28p 🔵 prime_suite project location confirmed
6126 " 🔵 prime_suite monorepo structure: CLAUDE.md/AGENTS.md layout
6128 " 🔵 prime_suite uses claude-fable-5[1m] model; Fable5 sunset hook already triggered
6130 1:29p 🔵 Fable5 sunset hook fired on 2026-07-09 but settings.json was subsequently reverted to claude-fable-5[1m]
6127 " 🔵 Global ~/.claude instruction file size baseline measured
S2490 prime_suite AI品質低下の根本原因調査と修復 — fable5-sunset hook による opus 自動切替が主因と特定・Fable5復帰済み。ユーザー要求「解決方法をfable5で敵対的レビューをcodexでやって」に対応中 (Jul 13 at 1:29 PM)
6134 " ⚖️ prime_suite AI品質低下の解決策レビュー方針: Fable5+Codex敵対的レビュー採用
6129 1:30p 🔵 Stop hook blocked response for missing observation evidence
S2491 prime_suite AI品質低下の根本原因調査と修復 — fable5-sunset hook による opus 自動切替が主因と特定・Fable5復帰済み。ユーザー要求「解決方法をfable5で敵対的レビューをcodexでやって」に対応中 (Jul 13 at 1:30 PM)
6131 " 🔵 AGENTS.md injects claude-mem context header; settings.json model change is uncommitted
S2492 prime_suite AI品質低下の根本原因調査・Fable5モデル復帰・Codex敵対的レビュー実施 — 解決計画に対して P0/P1 の重要な修正要件が発見された (Jul 13 at 2:19 PM)
S2493 Fable5自動切替hook空振り格下げの復旧作業 — Codex敵対的レビューのP0/P1全修正 + メモリ更新 + commit/push完了 (Jul 13 at 2:20 PM)
6146 2:22p 🔵 outputStyle: Fable5-like + Fable 5 model の二重指定が品質低下の原因と判明
S2495 Memory observer session: recording durable observations from primary session's Fable5 sunset hook retirement, Codex P0/P1 fixes, double-edit pattern in memory files, git merge with masa-2 asa-board changes, and final push confirmation (Jul 13 at 2:22 PM)
S2496 Fable5 sunset recovery: model audit across prime_suite sessions to verify recovery status and diagnose ongoing quality issues (Jul 13 at 2:34 PM)
**Investigated**: - git log -S 'Fable5-like' to pinpoint when outputStyle entered and was removed from settings.json
    - settings.json.bak-fable5switch (pre-hook backup, 7/8 22:27) contents: confirms outputStyle was NOT present before the hook
    - settings.local.json mtime and model key placement
    - prime_suite session JSONL files: model usage counts across last 4 sessions (7/9, 7/10, 7/13 morning, 7/13 afternoon)
    - Current session's system prompt: direct observation of Output Style: Fable5-like still active in open sessions

**Learned**: - **outputStyle: Fable5-like entered settings.json via the 7/9 19:58 merge conflict resolution commit** (47eaf772), NOT from the original autoswitch hook. The backup (7/8 22:27) confirms outputStyle was absent pre-hook.
    - **The "4 days of opus downgrade" premise was partially wrong**: opus downgrade lasted only ~hours on 7/9 (hook fired 02:12, Fable 5 restored by 19:58). The real 4-day issue was **Fable 5 + Fable5-like double-specification** running simultaneously from 7/9 19:58 through 7/13 14:23.
    - **7/10 session (5b9bde25): 1,463× claude-fable-5, 15× sonnet, 3× opus** — nearly pure Fable 5, but with double-spec active the entire time
    - **7/9 evening session (2841d3c2): 324× claude-fable-5, 37× claude-sonnet-5, 4× opus** — Fable 5 dominant, double-spec active
    - **7/13 morning session (d0027049): 293× claude-opus-4-8, 182× claude-fable-5** — unexpected opus dominance; cause unconfirmed (possible Fable 5 rate-limit fallback or API outage). status.claude.com reported Opus/Sonnet errors today.
    - **7/13 afternoon session (e3bf66b2): 475× claude-fable-5, 1× opus-4-8** — recovery confirmed for new sessions started after 14:23 fix
    - Settings changes take effect only at session start; all currently-open sessions still carry the old double-spec state

**Completed**: - settings.json: model key + outputStyle + fable5-sunset SessionStart hook registration removed (grep 0 confirmed, JSON parse OK)
    - fable5-sunset-autoswitch.sh retired to hooks/_retired/ via git mv
    - fable5-sunset-runbook.md top section replaced (not appended) with correct conclusions
    - Memory files updated (double-edit pattern: two rounds each for project_fable5-sunset-prep.md and MEMORY.md)
    - commit 66013a04 pushed; merged masa-2 asa-board commits (ort strategy); origin/main = 60e30ad9 confirmed
    - Root cause timeline established: hook fire (7/9 02:12) → short opus period → merge added outputStyle (7/9 19:58) → 4-day double-spec → fix (7/13 14:23)

**Next Steps**: No further implementation tasks. User action required:
    1. Close all open Claude sessions and reopen — settings changes (outputStyle removal) only take effect in new sessions
    2. On masa-2: run `cd ~/.claude && git pull` BEFORE launching Claude (old hook may still fire without pull)
    The 7/13 morning opus dominance (293 turns) is unresolved — monitor in future sessions; likely Fable 5 API fallback during an outage


Access 989k tokens of past work via get_observations([IDs]) or mem-search skill.
</claude-mem-context>