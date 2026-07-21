# prompt-history 設計書 v3（SSoT）

**目的**: Claude Code の全実行プロンプトを「グローバル作業→ClaudeEnv_INBOX / プロジェクト作業→各 project INBOX」へ履歴として残す。
**経緯**: 2026-07-13〜14、Fable5×GPT-5.6 Sol 設計議論（2巡合意）→ 敵対レビュー2体（Fable5 SubAgent 13件 / Codex 14件・P0 4件）→ 改訂 v2 → Codex NO-GO（必須変更8件）→ v3 GO-WITH-CHANGES（微修正5件・全採用）。Codex スレッド `019f5bcc-2ceb-77a0-a1d7-c763a5171dd8`。

## ユーザー決定（変更には再承認が必要）

1. **ローテーションなし**: INBOX の自動履歴は永続追記。月次 archive 移動案は**否決**（2026-07-14）。肥大は閾値到達時にユーザーへ相談する監視のみ。無断のローテ・要約・削除は禁止
2. Phase 1 から実装開始（Phase 2 は伏字レビュー合格が有効化ゲート）

## 全体アーキテクチャ

```
[両Mac] UserPromptSubmit hook (即時・数十ms)
  └→ 多層マスキング → 受領票 state/prompt-history/receipts/YYYY-MM-DD.jsonl (0600・gitignore)
[両Mac] 転送ジョブ (Phase 2)
  └→ vault 内 03_ClaudeEnv/prompts/.queue/<host_uuid>/YYYY-MM-DD.jsonl (ホスト別=衝突ゼロ)
       └→ git 同期は既存 Obsidian Git プラグイン相乗り (自前 pull/push なし)
[writer=2台のうち1台のみ(要固定・どちらかは未確定)] 日次ジョブ (Phase 2)
  └→ 各 INBOX の <!-- prompt-history:begin/end --> マーカー間へ日別ブロック append
       (動的長コードフェンス・日別 callout 折りたたみ・冪等台帳で dedupe)
```

**原文の正本 = ローカル transcript**（`~/.claude/projects/*/…jsonl`・jsonl-archive hook で保全）。受領票・INBOX 側は lossy-safe（過剰伏字を許容）。「なぜ」「結果」欄は**持たない**（自動判定は信頼不能というレビュー結論）。記録項目 = 日時・host・route・session・全文のみ。手動 curated の「📒 記録」とは節を分離し混ぜない。

## Phase 1（実装済み 2026-07-14）

- `hooks/userpromptsubmit-prompt-history.py` — 捕捉+伏字+ルーティング記録。settings.json UserPromptSubmit 4本目（timeout 5）
- 受領票 schema: `{ts, event_id(UUIDv4), host_uuid, session_id, cwd, route, prompt(伏字済), mask_hits[], held}`
- `host_uuid` = 初回生成 `state/prompt-history/host-uuid`（hostname 不使用）
- マスキング3層: ①既知形式（sk-/AKIA/ASIA/ghp_/gho_/ghu_/ghs_/ghr_/github_pat_/xox?-/AIza/ya29./PEM ブロック/JWT/URL埋込認証/Authorization・Cookie ヘッダ）②汎用 credential key=value（日本語「パスワード:」「APIキー:」「認証トークン:」「秘密鍵:」含む）・.env 形式行 ③高エントロピー token（20字以上・英数混在・シャノン>3.7。例外: 40字以下の純hex=git SHA・UUID は残す）
- マーカー無害化: 本文中 `<!-- prompt-history` / 行頭 `event_id:` に U+200B 挿入（Phase 2 writer の行頭マーカー探索を本文が偽装できない）
- マスカー例外 = `held:true`・本文保存なし・`capture-warnings.log` 記録。hook 全体 fail-open（常に exit 0・stdout 無出力）
- 排他: hook-guide ⑥（専用 .lock + fcntl.flock）。日別ファイルなので rotate なし
- ルーティング: `config/prompt-history-routing.json`（repo 管理・`~` 相対で 2台のユーザー名差を吸収）prefix 最長一致 → 外れたら `git rev-parse --git-common-dir` で worktree→主repo 再判定 → `unrouted:<cwd>`。判定不能でも捕捉は必ず行う
- テスト: `hooks/tests/test_prompt_history_capture.py` 17件（実事故形状: c8b2e8fc 同型の日本語平文認証情報・.env 貼付・URL埋込認証を含む。sanitized-fixtures 禁止準拠）

## Phase 2（実装済み 2026-07-14・同日有効化）

**ゲート通過の記録**: 受領票 55 件の機械再スキャン（漏れ 0）＋全件目視 → ユーザー「今すぐ作って」で同日有効化（当初の数日ソークは短縮・ユーザー判断）。

**実装**: `scripts/prompt-history-reflect.py`（Step A 転送 + Step B writer 反映の単一スクリプト）＋ `hooks/sessionstart-prompt-history-reflect.sh`（SessionStart 起動）。テスト = `hooks/tests/test_prompt_history_reflect.py` 13件。

**設計からの実装判断（Decision Log）**:
1. **起動は launchd でなく SessionStart hook の日次スタンプ方式**（20h guard・バックグラウンド実行・ログ `state/prompt-history/reflect.log`）。理由: launchd は vault(~/Documents) への TCC/FDA 未付与で沈黙死する実績。Claude セッションは確実に権限を持ち毎日起動する
2. **ACK 機構の簡素化**: 受領票の削除条件 =「queue への転送完了（vault git の耐久保存）+30日」。queue 自体が同期・耐久のため writer 死亡でもデータ喪失なし（v3 条件2 の意図を単純構造で充足）
3. **unrouted の反映時再解決**: 住所録（cwd_prefixes）への追記が過去の未ルート受領票にも遡及して効く
4. **マーカー無害化は reflect 側でも再実施**（多層防御・hook 修正前の旧受領票や queue 改ざん耐性。テスト 4 が実際にこの穴を検出した）
5. **表示形式 = Fable5 D案**（2026-07-14 敵対レビュー2体→ユーザー承認）: ①並びは 📒 と同じ**新しいものが上**（日付降順・日内降順・新しい反映ブロックは BEGIN 直後へ積む）②callout 見出しに「・自動記録」ラベル・節先頭に「生ログ・清書は 📒 が正・昇格は依頼」の自己説明 ③**🧾→📒 昇格は手動運用**（「これを 📒 に転記して」→ AI が〈いつ/なぜ/結果〉付きで転記。rules/30-routing.md に 1 行追加・新 skill は作らない）。**却下案**: A=📒 風の見た目統一（手書き資産の汚染・順序逆転・モバイル崩れ）／Codex D=索引+月別別ノート（「別ファイル禁止」決定と衝突・再提案には決定の再承認が必要）

Codex GO 条件（v3 必須変更 8 + 微修正 5・全採用）:
1. flock(1) 不使用（macOS に無い）→ Python fcntl【Phase 1 で実装済】
2. 受領票の先行耐久保存 → queue 転写後も、**writer 永続台帳に event_id が反映され、その ACK が送信元 Mac へ同期された後**に削除（30日ではなく ACK 基準）
3. event_id = hook 内 UUIDv4 が正本【実装済】
4. マーカー/event_id の本文エスケープ【実装済】+ writer 探索は行頭の厳密文法のみ
5. 転送は各ホストが自分の受領票を自分の `.queue/<host_uuid>/` へ書く（責任主体明記）。Obsidian Git 停止検知 = 各Mac が定期更新する **同期 heartbeat** の 48h 停止で判定（「相手 queue 最終受信時刻」は無入力時に誤警告するため不採用）
6. dedupe 正本 = writer の永続台帳（INBOX 実文 grep は二次確認）。台帳更新は INBOX 書込→fsync→再読確認**後**に atomic（台帳先行更新は禁止）
7. writer 死活は両Mac から監視（成功スタンプを vault 内=同期される場所に置き、両Mac の SessionStart hook が 48h 超で警告）
8. callout 内コードフェンスは全行 `>` プレフィクス。実 Obsidian で複数行・空行・引用・既存フェンスの表示テスト必須
9. 受領票・queue とも 0600 / umask 077【Phase 1 実装済】

INBOX 側の形（Phase 2 実装時）:
- 各 INBOX 末尾に `## 🧾 Claude Code 実行履歴（自動・秘密値伏字）` + `<!-- prompt-history:begin/end -->` マーカー
- 日別 `> [!note]- YYYY-MM-DD（N件）` callout。各件 = ts+session 短縮 ID の行 + 動的長フェンス（本文中の最長バッククォート連より長い）で全文
- 挿入は end マーカー直前へ append（📒 記録の「新しいものを上」とは独立・見出しリネーム耐性）

## 既知の制限（Codex コードレビュー 3巡 GO の許容条件・2026-07-14）

- **非 UTF-8 stdin**: fail-open で受領票を残さない（安全側。原文は transcript にも残らない可能性があるが、Claude Code の hook 入力は実運用上 UTF-8）
- **cwd ベースの捕捉除外**（`exclude_cwd_prefixes`・claude-mem observer）は厳密な「ユーザー投稿」判定ではない: `~/.claude-mem` 内で人間が打てば除外され、observer が別 cwd で動けば捕捉される。現運用のノイズ除去として許容
- **サイズ上限 200KB（UTF-8 バイト）超**は held:true（本文は transcript のみ）

## Phase 3（実装済み 2026-07-14）— 恒久性の穴を塞ぐ

Fable5×Codex 敵対レビュー（一次＋クロス2巡）で実コード確認された「データ喪失2経路＋監視の穴」に対応。

1. **purge の push 確認ゲート** (`reflect.py` `queue_file_pushed`): 受領票は「vault queue が git remote に push 済み（`git log @{u}` に登場＋`git diff @{u}` クリーン）」を確認してからのみ削除。未push・git不在・確認不能は保持（データ喪失ゼロ）
2. **受領票 fsync** (`userpromptsubmit-prompt-history.py`): 電源断で直近を失わない
3. **reconcile** (`reflect.py` `reconcile`): 毎回 writer が「捕捉した event_id（queue 全ホスト **＋ writer 機のローカル未転送 receipts**）のうち INBOX に載った数（matched）」を照合し `state/prompt-history/reconcile-status.json` へ（`captured_total`/`matched_total`/`unreflected`/route別内訳/INBOX 改名検知）。これで **queue→INBOX の反映失敗・1枚停止・パス改名、および receipt→queue の転送失敗**を可視化。`scan_ok=false` は母集団ファイルの読取り失敗（照合が不完全）を示す。**既知の限界**: capture hook が完全停止して receipt がそもそも生成されない状態は reconcile では検知できない（未来の受領票が無いことは件数照合では見えない）。現行の SessionStart 警告は「writer-last-success 不在時に古い受領票が 48h 滞留」しか見ないため、この完全停止は未カバー（今後の課題として design に明記）。
4. **SessionStart 警告の強化** (`sessionstart-*.sh`): reconcile 未反映 ≥20 件で具体警告／writer 不在・3日更新なしで引き継ぎ案内／stale 警告を二択手順（①writer機で起動 ②Obsidian同期確認）に
5. writer 引き継ぎは半自動（案内＋設定1行差し替え。完全自動選出はスプリットブレイン risk で不採用）
- テスト: `hooks/tests/test_prompt_history_durability.py` 13件（push未確認保持/commit未push保持/push後purge/git不在保持/upstream無し保持/reconcile一致/改名検知/receipt-only検知/held計上/scan_ok=false/警告文/引き継ぎ案内/writer健在時は案内なし）
- **スコープ外（レビューで一段下と裁定）**: queue/ログ肥大の自動ローテ（警告のみ）・TOCTOU 完全排除・cursor ハッシュ化・launchd 併用（両レビュー一致で不要）

## レビューで否決した案（再提案しない）

- 全文 JSONL を新たな恒久正本にする（transcript と二重正本になる）
- 単一 writer への他ホスト分転送を ~/.claude git 経由にする（マスク前の秘密が GitHub に載る恐れ）
- 「なぜ」「結果」の自動生成（end_turn≠完了・tool_result 混在で信頼不能）
- 意味による選別・要約・自動ローテーション（要望「すべて残す」に反する）
- 自前の git pull --ff-only トランザクション（vault は自動バックアップ commit が頻発し livelock。実測: バックアップ 13本/6h）

## MEMO ノート運用（全 project 共通）

`<project>_MEMO.md` はメモ帳。**▶欄** = 実行プロンプト（「メモ見て」で AI が実行 → 結果を INBOX の 📒 記録へ転記・⏳/✅ 状態管理も AI 担当）。**💭欄** = 思いつき（整形・要約しない・原文のまま）。

制作工程への加筆依頼だけは workflow ノート末尾「メモ・変更したいこと」欄、それ以外は MEMO。

出典: aiimg/reading-factory CLAUDE.md の実運用・14 project 展開済み・2026-07-16 global 化。
