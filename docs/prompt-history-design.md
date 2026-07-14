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
[writer=このMac 1台のみ] 日次ジョブ (Phase 2)
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

## Phase 2（未着手・有効化ゲートあり）

**ゲート**: 受領票を数日ソーク → 伏字出力の人間レビュー合格 + 本設計書の敵対テスト全 PASS が確認されるまで、`.queue` の git 同期と writer を有効化しない（それまで vault `.gitignore` に `.queue` を入れておく）。

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

## レビューで否決した案（再提案しない）

- 全文 JSONL を新たな恒久正本にする（transcript と二重正本になる）
- 単一 writer への他ホスト分転送を ~/.claude git 経由にする（マスク前の秘密が GitHub に載る恐れ）
- 「なぜ」「結果」の自動生成（end_turn≠完了・tool_result 混在で信頼不能）
- 意味による選別・要約・自動ローテーション（要望「すべて残す」に反する）
- 自前の git pull --ff-only トランザクション（vault は自動バックアップ commit が頻発し livelock。実測: バックアップ 13本/6h）
