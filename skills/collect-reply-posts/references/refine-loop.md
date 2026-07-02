# 自己改善ループ仕様（検索クエリを運用で磨く）

collect-reply-posts の探索クエリ（`gen-queries.sh`）を、**運用の採用/却下判定を ground truth に、人間承認で恒久改善する閉ループ**。make_article の自己改善ループ（`transcript-scanner.py` → `improvement-queue.jsonl` → `ingest-improvements` → Material Bank）の**構造を流用**するが、欠陥は継承しない。

## make_article から流用する点 / 直す点

| | make_article（流用元） | collect-reply-posts（本ループ） |
|---|---|---|
| 捕捉 | Stop hook + 正規表現 scanner | **スキル Stage 5 が構造化記録**（hook不要・人間採否が直接入力） |
| 蓄積 | `~/.claude/state/improvement-queue.jsonl` + status | `~/.claude/state/reply-search-feedback.jsonl`（同型・append-only・flock不要なら Edit append） |
| **ground truth** | **正規表現3本の story_score（不安定検出器）** ❌ | **Stage 3 の人間「採用/却下」** ✅（mistakes.md「不安定検出器のground-truth化」回避） |
| 反映 | 手動 ingest → **1277件滞留・ループ未閉鎖** ❌ | **人間承認ゲートで閉じる**・滞留させない ✅ |
| 利用 | 生成が Material Bank を読む | 次ランが更新後 gen-queries.sh を使う |

**設計原則**: 機械は「数える・並べる」だけ（`analyze-feedback.py`）。「良し悪し」は人間（Stage 3）。「クエリをどう変えるか」は LLM 提案＋人間承認。機械が良し悪しを判定する箇所を作らない。

## 5段の実体

1. **[捕捉]** `collect-reply-posts` 実行の Stage 5 で、各ピックの `{verdict: adopted|rejected, query_label, url, reason}` を1行ずつ `reply-search-feedback.jsonl` に append。
2. **[蓄積]** `~/.claude/state/reply-search-feedback.jsonl`（CWD非依存で常に書ける場所・append-only）。
3. **[集約]** `python3 analyze-feedback.py` がクエリ別採用率・頻出却下理由・採用の出所クエリ・淘汰候補（採用率<10%かつ surfaced≥8）を算出。**集計のみ・判定しない**。
4. **[反映]** 集計を読み、LLM（Fable5 スポット可）が `gen-queries.sh` の改善 diff を提案 → **人間が承認したものだけ**適用 → `gen-queries.sh` 冒頭 `# CHANGELOG` に「日付・変更・根拠採用率」を1行残す（版管理）。
5. **[利用]** 次回 `gen-queries.sh` 実行で更新後クエリが効く。

## 改善 diff の出し方（[反映] 段の LLM への指示）

`analyze-feedback.py` の出力を入力に、以下だけを提案させる（過剰な再設計はしない）:

- **淘汰**: 「⚠️淘汰候補」クエリを削除 or キーワード差し替え。
- **強化**: 採用の出所として多いクエリの方向にキーワードを足す（金脈を太らせる）。
- **ノイズ削減**: 頻出却下理由（例「挨拶replyのみ」が多い→ `min_replies` を上げる / `min_faves` 行を有効化 / 除外語を足す）に対応した閾値・演算子調整。
- **閾値較正**: 採用率が極端に低い言語/カテゴリの `MIN_REPLIES_*` を上げる、件数不足なら下げる。

**やらないこと**: クエリの全面再設計、新カテゴリの乱造、機械が採否を自動適用すること。1回の改善で触るのは1〜3クエリまで（小さく回す）。

## 回す頻度

数ラン溜まってから、または月1。`analyze-feedback.py` は件数が少ないと「数ラン回してから」と促す。サンプルが少ないクエリの率は信用しない（surfaced が一桁のクエリは淘汰判定しない＝`DEAD_MIN_SURFACED=8`）。

## Phase 2（任意・未実装）: 可視化 hook

make_article の `improvement-ingest-check.sh`（SessionStart で「取込待ち N件」を出す）に倣い、feedback が一定ラン溜まり前回 refine から日数が経ったら SessionStart で「/collect-reply-posts のクエリ改善が可能」と促す hook を足せる。`~/.claude/state/` の flag gate で休眠可。**自動発火する挙動なのでユーザー明示 opt-in 後に追加**（settings.json 登録は update-config 経由）。
