<claude-mem-context>
# Memory Context

# [.claude] recent context, 2026-07-03 11:58am GMT+9

Legend: 🎯session 🔴bugfix 🟣feature 🔄refactor ✅change 🔵discovery ⚖️decision 🚨security_alert 🔐security_note
Format: ID TIME TYPE TITLE
Fetch details: get_observations([IDs]) | Search: mem-search skill

Stats: 50 obs (12,935t read) | 1,753,782t work | 99% savings

### Jul 2, 2026
4537 3:23p 🔵 AIads-NOW.md は symlink で repo NOW.md を直参照（スクリプト同期なし）
4538 " 🔵 Obsidian 00_Inbox/key_api.md に API キー平文保存（セキュリティリスク確認）
4539 " 🔵 prime_ad には reports/ ディレクトリ不在・metrics/ が GA4 レポート置き場として機能
4544 3:41p ✅ bunshin v1 Phase 0: T1-T12 全完了分を ~/.claude リポジトリへ commit+push
4543 3:47p 🔵 T6 Hook Probe File Write Test
4545 4:12p 🔵 Bunshin corpus 5-bucket separation: pure scar rate confirmed at 0.33–1.0%
4546 " 🔵 Capability amnesia identified as primary driver of June scar spike (8.5x)
4547 " ⚖️ Discrimination rule: 是正発話を「情緒の殻」と「核の要求」に分解して傷跡vs基準を峻別
4548 " ✅ taxonomy-v2.md §1「12-21%」は誇大値と判明・訂正待ち状態
4549 4:55p 🔵 Bunshin Corpus: Quality Standards Misclassified as Negative Examples in v2 Taxonomy
4550 " 🟣 Taxonomy v2 §11 Added: Clean Re-Derivation with Correct Scar/Standard Separation
4551 " ⚖️ User Requests Global Claude Environment Update: standard-not-noise Rule Enforcement
4552 5:50p 🔵 Stop hook architecture: 8 hooks wired, all as command-type with no matcher
4553 " 🔵 ユーザー最大ストレス: Top5違反パターンへの毎度チェック要望
4554 6:03p 🟣 Stop hook「根拠フッター強制」実装・発動確認
4555 6:07p 🔵 次点BEST10候補の実カウント採掘完了（クリーンコーパス2170件）
4556 " 🔵 claude-mem DBスキーマとクリーンコーパス採掘用TSV生成の手順確立
4557 7:21p 🔵 次点BEST10の確定頻度ランキング（Python正規表現・クリーンコーパス2170件・15候補全実測）
4558 " 🔵 次点10基準の現ガード実ファイル確認結果：act-time hookで本当に止まるのは#18/#20/#17の3つのみ
4560 7:24p 🔵 次点10基準の現ガード実ファイル確認結果：act-time hookで本当に止まるのは#18/#20/#17の3つのみ
4562 7:40p 🔵 worktree複数リポジトリ棚卸し：pokeca-investはmainでなくpsa10-fact-check-pinにHEADが乗っており、prime_suite-ad/line24はgitなし（linked worktree）
4563 " 🔵 worktree複数リポジトリ棚卸し：pokeca-investはmainでなくpsa10-fact-check-pinにHEADが乗っており、prime_suite-ad/line24はgitなし（linked worktree）
4564 " ⚖️ 二重記載排除・SSoT一元化（#15）の必須hook化要求：注入のみでは不十分とユーザーが確定判断
4565 9:12p 🟣 bunshin act-time hooks committed and pushed to origin/main
4566 9:13p 🔵 state/recurring-mistakes.md はgitignored — 別Mac伝播は git push では不可
4567 " 🟣 act-time ガード3本 commit 0e3b7f8f — origin/main に push 完了
4568 9:14p ✅ commit 0e3b7f8f を origin/main へ push 完了 — 3本の act-time hook が別Macから git pull で取得可能に
4581 10:28p 🔴 stop-evidence-footer.sh の誤検知修正（質問前置きターンを免除）
S2008 別Mac(MASA.local)の設定不動作の原因診断 → 切り分け診断プロンプトを別Macで実行するよう案内 (Jul 2 at 11:04 PM)
S2002 「2」選択 → 別Mac(MASA)への履歴保全確認 — origin/main に data-retention 修正が載っているかを検証 (Jul 2 at 11:04 PM)
S2003 別Mac(MASA.local)への履歴保全手順の確定 — origin/main の data-retention.sh 検証完了・別Mac 実行コマンドの案内 (Jul 2 at 11:04 PM)
### Jul 3, 2026
S2027 make_articleプロジェクトのリテイク多発診断・既存設定棚卸し・autopost統合判断 — 3並列workflow起動済み (Jul 3 at 9:34 AM)
4599 10:32a 🔵 X投稿記事作成プロジェクトのリテイク多発問題 — 調査開始
4602 10:39a 🔵 X投稿プロジェクト分散構造の統合検討 — make_article と autopost の2プロジェクト体制が判明
S2030 make_article リテイク多発診断完了＋新フロー実践デモ（AI分身プロジェクト記事の一次体験先確定） (Jul 3 at 10:39 AM)
4603 10:43a 🔵 make_article リテイク多発の根本原因 TOP6 を特定
4604 " 🔵 既存設定の採用/不採用仕分け完了
4605 " ⚖️ autopost / tier3_posting の統合判断: 統合しない
4609 " 🔵 make_article リテイク多発の根本原因 TOP6 確定（404プロンプト実測分析）
4610 " 🔵 make_article 既存資産の採用/不採用仕分け完了（adopt 8・drop 8・gap 6）
4611 " ⚖️ autopost/tier3_posting の統合判断: 統合しない（独立 group 維持）
4612 " 🔵 正規パイプラインと実運用の乖離を実測確認（art_022 以降 SKILL.md バイパス）
4613 " 🔵 make_article 診断レポートがユーザーに「よくわかりません」と返された
4616 " ⚖️ make_article診断フェーズ完了・実践フェーズへ移行
4606 10:51a 🔵 make_article 正規パイプラインと実運用の乖離を実ファイルで確認
4607 " 🔵 make_article 採用/不採用の詳細仕分けと6つのギャップが確定
4608 " 🔵 autopost独立化は2026-05-26 decisionでload-bearing化済み・統合判断に確定的根拠
4618 10:57a 🔵 make_article 次テーマ：AI分身プロジェクト記事の骨格と未カバー指摘
S2033 AI分身プロジェクト記事の新フロー実践デモ（一次体験先確定→執筆）＋診断内容の平易版説明 (Jul 3 at 11:05 AM)
4620 11:17a 🔵 art_029 に「分身を作るメリット」が欠落していることをユーザーが指摘
S2036 art_029「分身を作るメリット（ライフハック価値）」セクション追記 — ユーザー指摘「何がライフハックできるか書かれていない」への対応 (Jul 3 at 11:17 AM)
4625 11:22a 🔵 art_029「分身メリット」セクションへのユーザー事実確認
S2039 art_029「分身メリットセクション」のファクトチェック — ユーザーの「これ本当？」を受けて実ファイルで各メリットを裏取り・盛りを摘出・正直版に差し替え提案 (Jul 3 at 11:24 AM)
S2040 「見える化もAIが自律でやったわけじゃない」という追加指摘 — 分身メリットの正直な現在地の再評価と記事方針の選択 (Jul 3 at 11:41 AM)
4626 11:46a 🔵 分身メリット6項目の実態ファクトチェック完了 — 全項目に誇張・誤りあり
S2045 「貯めるもの」vs「即実行するもの」の分離設計提案 — グローバルロード環境の過負荷構造を実ファイルで確認 (Jul 3 at 11:47 AM)
4627 11:49a 🔵 グローバルロード注入量の実測 — 毎プロンプト約467トークン、起動時約776トークン
4628 " 🔵 make_article playbookに「Must Remember」節が存在しSessionStart hookで自動注入される設計
4629 11:50a 🔵 Stop hookが事実断定を含む応答に「根拠フッター」未記載でブロック発動
4630 " 🔵 make_article Must Remember節の実内容 — 完了境界・投入ゲート・Xアルゴ正本の運用定石を確認

Access 1754k tokens of past work via get_observations([IDs]) or mem-search skill.
</claude-mem-context>