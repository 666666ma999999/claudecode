---
name: collect-reply-posts
description: "AI/Claude Code 界隈で reply（返信・会話）を多くもらっている X 投稿を記事ネタ素材として週1で半手動収集するスキル。/collect-reply-posts で起動。トリガー: reply 収集, 返信が多い投稿, 議論を呼んでいる投稿, reply の多い X, 議論投稿収集, 賛否が割れている投稿, collect-reply-posts"
user-invocable: true
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
  - Agent
  - AskUserQuestion
---

# collect-reply-posts

## 発火・詳細（description から移設 2026-07-03）

AI / Claude Code 界隈で reply（返信・会話）を多くもらっている X 投稿を、記事ネタ素材として週1で半手動収集するスキル。探索=手動（保存済み advanced search クエリ）、reply数確認=目視、意味づけ=LLM1回、保存=/x-stock の4段。grok-collect-twittora（likes基準のバズ収集）の補完で、こちらは『議論を呼んでいる＝reply軸』を拾う。/collect-reply-posts で起動。トリガー: 「reply 収集」「返信が多い投稿」「議論を呼んでいる投稿」「reply の多い X」「議論投稿収集」「賛否が割れている投稿」「collect-reply-posts」を含む依頼。

AI / Claude Code 界隈で **reply（返信・会話）をもらっている X 投稿**を、記事ネタ素材バンク（vault `x-article-stock.md`）に週1で溜める。

## スコープ限定（2026-07-01 確定判断）

本 skill の「手動優先」は **min_replies 付き reply 収集に限定**。一般トピックの X 検索収集には使わない（→ 第一選択は influx Cookie 自動収集）。

**教訓（本 skill 自身が失敗例）**: 最終目的を確認せず 4 段ランブック+自己改善ループまで作り込み、Codex の「9 段は過剰」警告を無視した goal-unconfirmed over-build（mistakes.md 2026-06-19）。作成後の運用実績 0 件。**「効く」と分かるまで Stage を拡張しない。**

## このスキルの設計思想（なぜこの形か）

agent team 設計 → Codex 敵対的レビュー（2026-06-19）の結論：

- **「reply数で正確に自動収集」は構造的に困難**。Grok x_search は reply で絞れず数値も不正確 / X API v2 に `min_replies` 演算子なし（取得後フィルタ＋pay-per-use）/ reply を直接絞れるのは X Web UI `min_replies:N` のみだが非公式・Cookie14日失効・自動アクセスはToS違反リスク / nitter・snscrape は実質死亡。
- よって **「探索は手動・数値確認は目視・意味づけは最後にLLM1回」の4段**に絞る。9段の重厚パイプライン（週次クエリ自動生成 / embeddingクラスタ / Fable5を3回）は「精度より先に運用コストと壊れやすさで死ぬ」として却下。
- **「reply多い＝記事ネタ良い」は偽**。炎上・挨拶回り・内輪揉め・釣りでも reply は増える。最終的に効くのは生reply数でなく **トピック適合 × 議論密度**。主ゲートは reply_count、補助に reply/like 比、判定は人＋LLM。

効くと確認できたら、Stage 1-2 の自動化（既存 influx DOM 経路 or X API v2）を後から足す。**まず最小で回す。**

## ⚠️ 手動実行専用・週1以下

| 項目 | 内容 |
|---|---|
| 実行モード | manual（人間が明示トリガー） |
| 推奨頻度 | 週1回。AI界隈で議論が盛り上がったタイミングで随時 |
| 自動化しない理由 | reply の唯一の絞り込み経路（Web UI DOM）が壊れやすく ToS リスクもあるため、収集の核（拾う/捨てる判断）は人が握る |

## 前提

- Obsidian Vault が `~/Documents/Obsidian Vault/` に存在し、`wiki/x-article-stock.md` がある
- X に**ログイン済みのブラウザ**（advanced search の `min_replies:` はログイン時のみ安定）

## 実行フロー（4段＋記録）

### Stage 1: 探索クエリを生成して開く（手動）

今週分の X advanced search URL を生成する（`since:` は実行日の7日前を自動計算）:

```bash
bash ~/.claude/skills/collect-reply-posts/gen-queries.sh
```

出力された 6〜8 本の URL を**ブラウザで開く**（ログイン済みタブで）。各URLは
`min_replies:N -filter:replies -filter:retweets`（=「reply が N 件以上ついた親投稿のみ・RT除外」）で、AI/Claude Code の論点別・日英別になっている。

- 件数が少なければ `gen-queries.sh` 内の `MIN_REPLIES_*` を下げる、`SINCE_DAYS` を伸ばす。
- 多すぎ・ノイズが多ければ `min_replies` を上げる / `min_faves` 行を有効化する。

### Stage 2: reply の多い親投稿URLを目視で拾う（手動）

各検索結果（`f=live` 最新順）の上から、**reply 数が目視で多い・議論になっていそうな親投稿**を 15〜20 件、URL を拾う。

判断は「reply欄を軽く覗いて、賛否が割れている / 専門的な掘り下げがある / 質問に有益回答が連なっている」もの優先。挨拶・絡み・スパムだけの大量replyは捨てる。

拾ったURL（と分かれば reply 数の概数）をこのセッションに貼る。または箇条書きで渡す。

### Stage 3: 採否＋論点＋見出し案を生成（AIが評価・人間はしない）

**ここが Fable 5 の活用ポイント。投稿の評価（採用/却下・論点・見出し）は AI がやる。ユーザーは評価しない。** ユーザーの仕事は Stage 1-2 で投稿を AI の前に出すこと（URL/テキストを貼る）だけ。

`references/judgment-prompt.md` の rubric に従い、Stage 2 で拾った投稿群を **1回のAI評価**で：

1. 記事ネタとして採用/保留/却下を判定（reply の質＝議論密度で。reply が多くても挨拶・絡みなら却下）
2. 採用分に「何で議論になっているか（論点1行）」を付与
3. x-article-stock 形式の「角度＋見出し案2本＋根拠reply＋出典URL」に整形

**誰が評価するか（モデル方針）**:
- **第一候補 = Fable 5（`claude-fable-5`）**。議論の質判定（賛否の割れ・専門性・皮肉や定型挨拶の見分け）と見出し生成という"編集者的判断"に向く。Agent tool の `model: fable` で評価役を委譲する。採用候補を10件以下に絞った後、質判定＋論点＋見出しを **まとめて1回**（3分割しない）。
- **フォールバック = 現行セッションモデル**。Fable 5 が利用不可（`currently unavailable`）の場合や、軽い量なら現行モデルが同じ rubric で同じ仕事をする。評価の中身は同一で、スロットを差し替えるだけ。
- ユーザーに「何を評価するか」を一切負わせない。判定に迷う投稿も AI が「採用/却下＋理由」を出す。

### Stage 4: x-article-stock に保存（/x-stock）

採用ネタを 1 件ずつ `/x-stock` に渡して append する（採番・source記録は x-stock が担当）:

- title: 見出し案（一番強いもの）
- body: 論点1行 ＋ 根拠reply要約 ＋ 出典URL
- tags: `[x-reply, <論点タグ>]`

複数件は1件ずつ `/x-stock` を呼ぶ。x-stock は**追加専用**なので重複チェックは人が見る。

### Stage 5: フィードバック記録（自己改善ループの ground truth）

**このランの「採用/却下」判定を構造化して記録する。** これがクエリ改善の唯一の正解信号（人間判定＝安定。正規表現や LLM 推定は使わない）。

`~/.claude/state/reply-search-feedback.jsonl` に**1ピックにつき1行** append する（append-only・既存行は変更しない）。Stage 3 の判定をそのまま落とすだけ：

```jsonl
{"run_date":"YYYY-MM-DD","query_label":"<どのクエリ由来か・分かる範囲で>","url":"<投稿URL>","verdict":"adopted","idea_id":"idea_NNN","score":N,"reason":"<採用理由1行>"}
{"run_date":"YYYY-MM-DD","query_label":"<クエリ>","url":"<URL>","verdict":"rejected","reason":"<却下理由・例: 挨拶replyのみ / トピック不適合 / 単発で広げようがない>"}
```

- `query_label` は Stage 1 の `gen-queries.sh` が出すラベル（例: `JA / Claude Code・AIエージェント中心の議論`）。どのクエリから来たか分かる範囲で付ける（不明なら `"unknown"`）。
- `verdict` は `adopted`（x-stock 追加）/ `rejected`（Stage 3 で落とした）の2値。`reason` は短い自由語（後で頻出語を集計するので語彙はなるべく揃える）。
- 書き込みは Edit ツールでファイル末尾に append（ファイルがなければ初回のみ Write ツールで新規作成）。

## 完了報告

- 開いたクエリ数 / 拾った投稿数 / 採用→x-stock 追加した idea 数
- 採用ネタのタイトル一覧（idea_NNN 付き）
- feedback.jsonl に記録した件数（adopted / rejected）

## 自己改善ループ（検索精度の恒久改善）

このスキルは「探索クエリ」を恒久資産として運用で磨く閉ループを持つ（make_article の自己改善ループを流用・ただし ground truth は人間採否に修正）。詳細仕様: `references/refine-loop.md`。

```
[捕捉]  Stage 5 が採用/却下を reply-search-feedback.jsonl に構造化記録（人間判定）
[蓄積]  ~/.claude/state/reply-search-feedback.jsonl（append-only）
[集約]  analyze-feedback.py がクエリ別「採用率」「頻出却下理由」「死にクエリ」を算出（機械集計のみ・判定しない）
[反映]  LLM が gen-queries.sh の改善 diff を提示 → 人間承認 → 適用（CHANGELOG に根拠記録）
[利用]  次ランで更新後の gen-queries.sh を使う
```

**改善を回すタイミング**（数ラン〜月1目安）:

```bash
python3 ~/.claude/skills/collect-reply-posts/analyze-feedback.py
```

→ クエリ別採用率と却下理由を見て、LLM に gen-queries.sh の改善案（低採用クエリの淘汰 / 高採用キーワードの追加 / `min_replies` 閾値の上下）を diff で出させ、**人間が承認したものだけ** `gen-queries.sh` に反映。反映時は `gen-queries.sh` 冒頭の `# CHANGELOG` に「日付・変更・根拠となった採用率」を1行残す。Fable5 を使うならこの改善案生成で1回（スポット）。

## grok-collect-twittora との違い（混同しない）

| | grok-collect-twittora | collect-reply-posts（本スキル） |
|---|---|---|
| 軸 | likes / impression（バズ） | **reply / 会話（議論）** |
| 経路 | Grok x_search（API・自動） | X Web UI advanced search（手動目視） |
| 出口 | `.raw/` jsonl+md プール | `x-article-stock.md`（記事ネタ） |
| 用途 | @twittora_ 素材プール更新 | 議論ネタの記事化候補 |

両者は併存。バズ収集はあちら、議論ネタ収集はこちら。

## 既知の制限・将来の拡張

- `min_replies:` は X の非公式挙動。UI仕様変更で突然効かなくなりうる → その時は `gen-queries.sh` のクエリを都度検証。
- 完全手動なので件数は人の集中力依存。回して「効く」と分かったら Stage 1-2 を influx DOM(`fetch-engagement`) or X API v2 で半自動化する（別タスク）。
- reply 数は目視概数。正確値が要るなら influx の `fetch-engagement`（Cookie/DOM）で後から実測。
- **Fable 5 は 2026-07-04 時点で利用可能**（claude-fable-5 稼働確認済）。Stage 3 の第一候補として使う。再び `currently unavailable` になった場合のみ Stage 3 のフォールバック（現行セッションモデル）に切り替える（rubric・出力形式は不変）。
