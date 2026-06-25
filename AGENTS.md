<claude-mem-context>
# Memory Context

# [.claude] recent context, 2026-06-24 9:29am GMT+9

Legend: 🎯session 🔴bugfix 🟣feature 🔄refactor ✅change 🔵discovery ⚖️decision 🚨security_alert 🔐security_note
Format: ID TIME TYPE TITLE
Fetch details: get_observations([IDs]) | Search: mem-search skill

Stats: 50 obs (18,007t read) | 2,200,526t work | 99% savings

### Jun 23, 2026
3468 7:16p 🔵 sync-vault-summary SKILL.md fully confirmed stale — cmd_append is no-op in .py but SKILL.md still describes full prepend workflow
3469 " 🔵 rules/41 基本原則 line still says "vault = 索引 + サマリー / 実体の SSoT は repo" — directly contradicts 2026-06-23 decision
3470 " 🔵 file-placement-detail.md H-1 table (line 151) vs supersede note (line 261) — exact text of both confirmed
3473 7:23p ⚖️ Adversarial review commissioned for Obsidian×Claude file placement rules proposal
3474 " 🔵 sync-vault-summary.py cmd_append confirmed RETIRED/no-op since 2026-06-14
3475 " 🔵 decisions.md L34-46 verbatim-confirmed: "vault=索引のみ" is explicitly the rejected alternative ②
3476 " 🔵 Two real drifts confirmed: detail L98 contradicts index L64 on prime_suite Phase structure
3477 " 🔵 rules/40 L13 confirmed as existing master declaration — "原典の穴" claim in prior draft was factual error
3488 7:29p 🔵 decisions.md §Supersedes は L45 に実在・「別途承認後」の明示保留が Stage 3 の法的根拠
3489 " 🔵 sync-vault-summary の「休眠した罠」: cmd_append は no-op だが CLI/docstring/SKILL手順は生存中
3490 " ⚖️ Codex 敵対レビュー 6手裁定 + 追加指摘（2026-06-23 最終）
3491 " ⚖️ aiads-ope-now-cat.sh cross-reference 監査完了: ~/.claude + ~/Library/LaunchAgents で間接呼出ゼロ確認
3492 " ⚖️ Obsidian vault 構造の全面再設計案をユーザーが提示
3503 8:21p ⚖️ Vault root cleanup workflow: directory structure must be displayed before each move
3505 8:35p ⚖️ Vault Root Cleanup Phase① — User Approved First Batch of File Operations
3510 8:53p ✅ memo_Pmac.md moved from vault root to 00_Inbox/
3511 9:08p ⚖️ Vault Root Ambiguous Files — Agent Team + Codex Adversarial Review Requested
3514 9:10p 🔵 Obsidian vault contains 5 real API keys committed to git history
3515 " ⚖️ Vault scattered-file triage plan finalized after internal adversarial review
3516 " 🔵 AIads/prompts/ confirmed as canonical subproject prompt structure template
3517 10:40p ⚖️ Vault 散乱ファイル仕分け 確定版 — 敵対的レビュー発動
3518 " 🚨 Obsidian vault に OpenAI×2 + Anthropic×3 の実 API キーが git tracked で存在
3519 10:41p 🔵 rules/41 §① の「定期実行プロンプト」配置先テキストに両論解釈が実在することを実読確認
3520 " 🔵 file-placement-detail.md の全争点条項が実在することを行番号で確認 — 内部レビューの「捏造」主張は誤り
3521 " 🔵 adscrm-asks-triage-2026-06-14.md を実読 — adscrm_prompt の行き先は「AIads/prompts/」と確定できず「prompts/」止まり
3522 " 🔵 17 moves 対象ファイル全件の実在位置を確認 — 仕分けプランの現在地記述は全て正確
3523 10:43p 🔵 Codex adversarial review: prompt hierarchy rule is group-level, not subproject-level
3524 " 🔵 Codex: 3 of 6 rule clause citations in sorting plan are misapplied (G-3, 0-7, 0-1)
3525 " 🔵 Codex: adscrm_prompt.md triage document says decompose+archive, NOT move to AIads/prompts/
3526 " 🔵 Codex: analytics_prompt.md destination is AIcrm/research/_requests/ (existing), not AIcrm/prompts/ (new)
3527 " 🔵 Codex 17-move final verdicts: 10 support, 5 require correction, 1 reject, 1 conditional
3528 10:48p 🔵 全17対象ファイルの内容実読完了 — コンテンツと配置ルールの照合により5件の計画誤認を発見
S1551 散在prompt8件の実読完了 — 新名称・移動先の提案表を作成、ユーザー承認待ち (Jun 23 at 10:56 PM)
S1555 Vault散乱ファイル仕分け — 8件promptファイルのN-8命名規約（YYYY-MM-DD_slug）適用・移動先確定・APIキー漏洩revoke待ち (Jun 23 at 10:56 PM)
S1553 vault全体のdone/フォルダとresult命名パターンの実態調査 (Jun 23 at 10:59 PM)
S1552 vault-spot-runner.shの命名ロジックとfile-placement-detail.mdのN群命名規約を確認 (Jun 23 at 10:59 PM)
S1554 Vault散乱ファイル仕分け確定作業 — 8件promptファイルのN-8命名規約適用・移動先確定・API漏洩対応 (Jun 23 at 10:59 PM)
S1556 Vault散乱promptファイル8件の仕分け確定 + ファイル保管・命名ルールのWeb研究agent teamを起動 (Jun 23 at 11:00 PM)
S1557 Vault散乱promptファイル8件の命名・移動確定 + ファイル保管・命名ルール共通化のWebリサーチagent team起動・待機 (Jun 23 at 11:00 PM)
S1558 vault ファイル保管・命名ルール Codex 敵対的レビュー完了 → 8種簡素化ルール確定 + spot vs task 区別の説明 (Jun 23 at 11:09 PM)
3531 11:12p 🔵 File Placement Standardization Framework (rules/42) Already Defined with 67 Types
3532 " 🔵 Prompt Execution Infrastructure: Scheduled vs Spot Prompt Segregation
3533 " 🔵 Naming Pattern Drift Across Projects: Common Files Lack Standardized Naming
3534 " ⚖️ File Organization & Naming Specification (Draft): 12-Type Taxonomy with Lifecycle Rules
3538 " 🔵 ユーザーが spot プロンプトと claude-task の区別を質問
### Jun 24, 2026
3535 7:31a ⚖️ Adversarial Review Commissioned for Vault File Storage/Naming Rule (Codex共通化版)
3536 " 🔴 敵対的レビュー用参照ファイル群の一斉実読完了 — 条項番号・実体の照合結果
3537 " 🔴 H-4引用の構造的問題: ルール定義行 vs 適用順序メモの混同
S1559 vault 散らばりプロンプト7件の確定移動先と命名を決定 + tasks/archive/ 完了慣行の実ファイル確認 (Jun 24 at 8:57 AM)
3539 8:57a 🔵 タスク管理手法の比較調査リクエスト: NOW/DONE 1枚 MD vs 現行 tasks/ マルチファイル方式
S1560 NOW/DONE 1枚MD方式 vs フォルダ移動方式のグローバル主流比較 — エージェントチームで Web 調査 + 内部敵対レビュー (Jun 24 at 9:03 AM)
3540 9:10a 🔵 prime_suite 週次ゴールが2目的混在し可読性低下
3541 9:11a 🔵 prime_suite に新旧フォーマット混在で目標が2つ見える根本原因を特定
3542 " 🔵 prime_suite 関連リポジトリが ~/Desktop/ 直下に8分割で存在
3543 " 🔵 Meta Ads Playbook Stage 0 は6/23に既完了・AGENTS.md に詳細履歴確認
3544 9:12a 🔵 AIads-playbook.md の実在場所を特定: Obsidian Vault 内 AI_adscrm/AIads/ 配下
3545 9:14a 🔵 Explore agent 完了: Meta Playbook Stage 0 は 6/23 に完了済み・4キーワードはすでに実装済み構造に対応
3553 9:22a 🔵 session-goal conflict root cause clarified — terminal title is LINE Push, not Meta Playbook
3555 " 🔵 prime_suite has 9 worktrees — "LINEプッシュ" terminal likely maps to prime_suite-line-push or prime_suite-line24, not main prime_suite worktree
3554 9:25a 🔵 session-goal state inspection: prime_suite has 3 goal files — old worktree-key + 2 new session-scoped files all showing Meta Playbook goal

Access 2201k tokens of past work via get_observations([IDs]) or mem-search skill.
</claude-mem-context>