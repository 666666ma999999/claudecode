# ship-article — Phase 詳細手順

SKILL.md の Phase 表を実行する手順書。**すべて既存スキルへの delegate**。ship-article 自身は state 更新と gate 判定だけを行う。判断は下記の明示条件で分岐する（裁量語で判断しない）。

## 共通: パスと state ファイル

```bash
MA=~/Desktop/biz/make_article
RES=$MA/output/published/results.jsonl
STOCK="$HOME/Documents/Obsidian Vault/wiki/x-article-stock.md"
STATE_DIR=~/.claude/state/ship-article
```

state ファイル `$STATE_DIR/<slug>.json`（Phase ごとに Write で上書き更新）:

```json
{
  "slug": "obsidian-2pc-sync",
  "stock_entry_id": "idea_20260611_001",
  "art_id": null,
  "source_cwd": "/Users/masaaki_nagasawa/Desktop/biz/make_article",
  "draft_path": null,
  "posted_url": null,
  "phase": "located",
  "updated_at": "2026-07-05T21:00:00+09:00"
}
```

`phase` の値は `located → materialized → drafted → approved → posted → measuring → done` の順に進む。各 Phase 完了時に `phase` と `updated_at` を更新して Write する。`$STATE_DIR` が無ければ Write が自動作成する（mkdir 不要）。

---

## P0 起点判定 → phase: located

**目的**: 「どのネタを出荷するか」を 1 件に確定する。

1. 引数を判定:
   - 引数が `idea_YYYYMMDD_NNN` 形式 → その entry を `$STOCK` から読む。entry は `## <id>` 見出しから次の `---` 区切りまでの可変長ブロック（`**note**` 節を含むと 12 行を超える）なので、固定行数の `grep -A` ではなく `awk '/^## <id>/{f=1} f{print} f&&/^---$/{exit}'` で見出しから次の `---` まで全文取得する。
   - 引数がテーマ/プロダクト名 → `$STOCK` を Read し `state: idea` の entry から title 部分一致で候補を挙げる。
   - 引数なし → `project-recall` を呼び直近の成果を要約させ、記事化候補を 1-3 件提示する。
2. 候補が 2 件以上、または 0 件 → `AskUserQuestion` で 1 件に確定（新規テーマなら stock_entry_id は null のまま進む）。
3. `source_cwd` を決める: 対象プロダクトの作業 cwd。不明なら entry の `source_cwd` を使う。
4. state を Write（`phase: located`, `stock_entry_id`, `source_cwd`, `slug`）。

**失敗分岐**:
- `$STOCK` が存在しない → 停止し「x-article-stock.md が見つからない。/x-stock でネタ蓄積が先」と報告。
- `state: idea` の entry が 0 件かつ引数もテーマ無し → 「出荷対象なし。/x-stock か /capture-improvement で素材を作ってから再実行」と報告して停止。

---

## P1 素材化 → phase: materialized

**目的**: 記事の裏付けとなる Material Bank 素材を最低 1 件用意する（認証性の担保）。

1. 対象プロダクトに定量改善/体験がある → `/capture-improvement <メモ>` を呼び Material Bank に登録させる（global スキル・cwd 非依存）。
2. すでに素材がある（entry の `related_materials` が非空、または Material Bank に該当素材あり）→ P1 をスキップして materialized に進む。
3. `session-to-material`（設計のみ・未実装）には依存しない。自動抽出が要る場合は当面 `/capture-improvement` の手動フローで代替する。

**ゲート**: 素材 0 件のまま P2 に進まない。素材が 1 件も無く capture-improvement も登録ゲート未通過（数値不足）なら、`AskUserQuestion` で「素材なしで一次体験の薄い記事になるが続行するか」を確認。No → 停止。

**失敗分岐**:
- capture-improvement が「情報不足で x-stock に降格推奨」を返した → その時点で素材化は未達。ユーザーに具体数値/体験の追記を促し、得られなければ P1 で停止。

---

## P2 記事生成 → phase: drafted

**目的**: `art_NNN` 長文 + `-short` ペアを生成し、ハウスルールの品質ゲートを通す。

1. **`/generate-x-article` はセッション cwd が make_article でないと自動発火しない**（project-local skill・Bash の `cd` だけではセッションの skill 解決先は切り替わらない）。現在のセッション cwd が make_article でない場合は、`~/Desktop/biz/make_article/.claude/skills/generate-x-article/SKILL.md` を絶対パスで直接 Read し、その手順をこのセッション内でそのまま実行する（slash-command 解決に頼らない・手順書として使う）。cwd が既に make_article なら `/generate-x-article <トピック or 3行メモ>` をそのまま呼んでよい。
2. `/generate-x-article`（または直接実行した同等手順）は内部で下記を順に実行する（ship-article 側で再実装しない・重複起動しない）:
   - STEP 6.3 `fact-check-from-history`（環境ベース裏取り）
   - STEP 6.4 `article-review-team`（決定的チェック + 3 SubAgent 並列 + Codex synthesizer → issue.md）
   - STEP 6.5 `verify-experience`（1 人称の体験/数値の実態確認）
3. 生成物 `output/drafts/art_NNN_*.md`（長文 + `-short`）のパスと `art_id` を state に記録。
4. `results.jsonl` に `draft_created` と、ゲート通過時に `review_passed` の event が追記されていることを確認:
   ```bash
   grep '"event": "draft_created"' "$RES" | grep '<art_id>'
   grep '"event": "review_passed"' "$RES" | grep '<art_id>'
   ```

**失敗分岐**:
- `review_passed` が出ない（issue.md に blocker 残存）→ **P3 に進まない**。issue.md の内容をユーザーに提示し、修正は make_article 側で行う旨案内して停止。ship-article は記事本文を直接編集しない。
- 生成が短文単発で十分な場合（長文不要）→ ship-article の射程外。`/generate-x-post` 直叩きを案内して終了（NOT for に該当）。

---

## P3 承認ゲート → phase: approved

**目的**: 投稿前の人間承認。ここは自動化しない。

1. `review_passed` event の存在を再確認（P2 の grep）。無ければ P2 に戻す。
2. OPSEC 確認: draft を Grep し、実パス・機密ノート名・個人事情の露出をチェック（`grep -nE "/Users/[a-z]+/|Obsidian Vault/[0-9]" <draft>` 等）。ヒットがあれば該当箇所をユーザーに列挙して提示する（マスキング判断は make_article 側で修正）。
3. `AskUserQuestion` で「この draft を autopost に登録してよいか（実投稿は autopost 側で別途）」を **必ず**問う。承認が明示されるまで P4 に進まない。
4. 承認 → state を `approved` に更新。

**失敗分岐**:
- ユーザーが修正指示 → make_article cwd で修正後、P2 の review を再走（`/article-review-team <draft>` を再起動）。承認まで P4 に進まない。

---

## P4 投稿登録 → phase: posted

**目的**: autopost 管理画面に登録し、x-stock entry を消化済みにする。

1. P2 と同じ制約: セッション cwd が make_article なら `/post-article <draft ファイル名>` をそのまま呼ぶ。そうでなければ `~/Desktop/biz/make_article/.claude/skills/post-article/SKILL.md` を絶対パスで直接 Read し、その手順をこのセッション内で実行する（autopost 管理画面へ登録・X 実投稿は autopost 側）。
2. `results.jsonl` に `posted` event と `posted_url` が追記されたことを確認:
   ```bash
   grep '"event": "posted"' "$RES" | grep '<art_id>'
   ```
   posted_url を state に記録。
3. **x-stock entry を consumed 化**（idea→consumed を運ぶのが ship-article の存在意義。x-stock スキルはスコープ外なのでここで行う）:
   - `$STOCK` の該当 entry の yaml ブロック内 `state: idea` を `state: consumed` に Edit。
   - 同 entry の `related_article: null`（または既存値）を `related_article: <art_id>` に Edit。
   - **frontmatter（ファイル先頭 `---` ブロック）と他 entry は変更しない**（x-stock の append-only 制約を尊重）。
   - `stock_entry_id` が null（新規テーマ由来で stock に無い）場合はこの手順を飛ばす。
4. state を `posted` に更新。

**失敗分岐**:
- `/post-article` が `status=posted` 検出で exit 3（既に投稿済み再同期拒否）→ 二重投稿を防いだ正常動作。既存の posted_url を state に記録し、consumed 化だけ行って P5 へ。
- `posted` event が results.jsonl に出ない → 登録失敗。ログを提示し停止。x-stock の consumed 化も**行わない**（未投稿を consumed にしない）。

---

## P5 計測接続 → phase: measuring → done

**目的**: 投稿後 24h の実測を results.jsonl に還流する経路を接続する。

1. `fetch-engagement`（global スキル）で posted_url の実測を取得:
   ```bash
   cd "$MA" && bash scripts/fetch_engagement_via_influx.sh --url <posted_url> --account maaaki
   ```
   Cookie pre-flight（age ≥ 14 日で exit 3）や連続 fail ガードは fetch-engagement 側の責務。ship-article は結果 event を確認するだけ。
2. `metrics_snapshot` event が results.jsonl に追記されたか確認:
   ```bash
   grep '"event": "metrics_snapshot"' "$RES" | grep '<art_id>'
   ```
3. 即時計測が空でも、定期計測（launchd Label: `com.masa.make-article-metrics`。呼び出すスクリプトが `cron_metrics_snapshot.sh` という名前なだけで launchd 上の識別子ではない）が生きていれば「24h 後に自動取得される」で接続済みとみなす:
   ```bash
   launchctl list | grep -i com.masa.make-article-metrics
   ```
   どちらか成立で `done`。fetch が Cookie 失効で失敗した場合のみ `/record-result <posted_url>`（手動フォールバック）を案内。
4. state を `measuring`（即時未取得・定期待ち）または `done`（metrics_snapshot 取得済み）に更新。

**完了報告**: SKILL.md「完了条件」の 3 点 grep がすべて成立したら完了。1 点でも欠ける場合は欠けた Phase 名と再開コマンドを添えて中間報告にとどめる。

---

## delegate 先の実在一覧（2026-07-05 test -e 確認済み）

| delegate | 種別 | 実体パス |
|---|---|---|
| `project-recall` | global skill | `~/.claude/skills/project-recall/SKILL.md` |
| `/capture-improvement` | global command+skill | `~/.claude/commands/capture-improvement.md` |
| `/generate-x-article` | make_article local skill | `~/Desktop/biz/make_article/.claude/skills/generate-x-article/SKILL.md` |
| `fact-check-from-history` `article-review-team` `verify-experience` | make_article local（generate-x-article 内蔵ゲート） | `~/Desktop/biz/make_article/.claude/skills/` |
| `/post-article` | make_article local skill | `~/Desktop/biz/make_article/.claude/skills/post-article/SKILL.md` |
| `fetch-engagement` | global skill | `~/.claude/skills/fetch-engagement/SKILL.md` |
| `/record-result` | make_article local skill（手動フォールバック） | `~/Desktop/biz/make_article/.claude/skills/record-result/SKILL.md` |

**設計 doc から現実優先で変えた点**: ネタ帳は `02_Ai/AI_adscrm/article-stock.md`（不在）ではなく `wiki/x-article-stock.md`。`session-to-material` `/collect-materials` `/article-from-here` は未実装のため P1 は `/capture-improvement` に一本化。P3 のレビューは独自 rg ではなく generate-x-article 内蔵のハウスルール 3 ゲート（fact-check-from-history / article-review-team / verify-experience）を正とする。
