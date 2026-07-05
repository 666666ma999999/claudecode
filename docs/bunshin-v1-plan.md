> **Status: ✅ Phase 0-3準備 実装完了 (2026-07-02・commit未実施=ユーザー確認待ち)**
> 生成経路: 5面検証 workflow → 敵対反証2本 → 3アーキテクト独立立案 → 審査統合 → Codex 敵対レビュー2周 (REJECT→APPROVE-WITH-CHANGES→全反映)。
> 検証の一次データ: 本セッション workflow w0roar5in / w74fhf9be (transcripts は14日で消えるため要点は本ファイルに内蔵済み)。
> **2026-07-02 深掘り反映(workflow wh6qz3ghx)**: claude-mem SQLite `user_prompts` テーブルに**原文プロンプト verbatim 5,516件(2026-04-26〜07-02・6/15以前4,427件・887セッション)が現存**と実測確認。「原文は6/15以降881件のみ」は誤りだったため本ファイル内の該当前提を訂正済み。アクセスは稼働中DBへ直接クエリせず read-only コピー経由(claude-mem 書き戻し事故回避)。
> **分析正本**: 分類 v2(工程P0-P5×機能11サブタイプ)・創造プレイブック14手・人間専権12スロット・3類型論・全プロダクト台帳・別Mac保全手順 = `docs/bunshin-taxonomy-v2.md`(2026-07-02)。ラベル済み生データ = `~/.claude/archives/bunshin-corpus/`(25MB・gitignored・退避済み)。
> **2026-07-05 教材源泉 v3 追補(末尾節・Codex 2R反映)**: ユーザー再設計指示により vault 人筆レイヤー④を源泉に追加・AI筆除外規則を明文化・MASA claude-mem デルタ手順を確定。実測ログ = taxonomy-v2 §12。

# 分身 (bunshin) v1 — 統合実行プラン「投入まで届くレール + 素材保全」

**土台**: プランC(実行ループ) / **移植**: プランAの実装メカニクス(awk注入窓修理・正確な検証コマンド・cleanupPeriodDays・dormant hook削除・claude-mem実測) + プランBのコーパス前処理仕様(Phase 4の固定仕様として)
**改訂**: Codex 敵対レビュー Round 1 = REJECT(16 findings)を全反映(末尾の対応表)。cleanupPeriodDays は公式設定と一次ソース確認済み(https://code.claude.com/docs/en/settings・2026-07-02 取得: "Session files older than this period are deleted at startup"・default 30日・min 1)= **CC 本体も 30 日で消すため 365 への引き上げは保険でなく必須の第二防壁**。

**配置先(一次ソース検証済み)**:
- plan.md(設計SSoT): `~/.claude/docs/bunshin-v1-plan.md` — 理由: `~/.claude/plan.md` は vault-control-center 用に既存占有。`~/.claude/plans/` は data-retention.sh L130 で14日削除。**`~/.claude/tasks/` は .gitignore 対象と実測確認(git check-ignore で ignored)= 2台Mac同期に乗らないため設計SSoTは置けない**。docs/ は git 追跡・既存の docs/routing-table.md 等と同型。scope-prefix 命名(rules/41 §②)準拠
- task.md(実行追跡): `~/.claude/tasks/p-bunshin-v1.md` — 既存 `p-*.md` 慣行に追従。data-retention の cleanup_dirs はディレクトリのみ削除(実測: 5/16 の p-passvault-*.md が生存)でファイルは安全。ローカル限定だが実行追跡はマシン単位で可

---

## 🟢 ふつうの言葉で30秒

あなたの分身 v1 は「新しいロボット」ではなく、**今ある定期実行への配線変更**で作ります。やることは4つだけ。①今日: AIとのやりとり全体(あなたの文+AIの応答+作業記録)が14日で消える穴を塞ぐ(4/7〜6/26 分は別の場所に4,140件退避済み、さらに**あなたの打った文章そのものは claude-mem に 4/26 から 5,516 件無事に残存**と確認済み。無防備なのは 6/27 以降のフル記録)。②7/13(次の隔週月曜)まで: 完成済みの「広告CPを続ける/直す/止める判定ルール」を隔週レポートに配線し、失敗したらMacに通知が来るようにする。③来週: AIが言うことを聞かない問題は「ルール注入の壊れた窓の修理+ルール2行」だけ(10個の新ガードは作らない)。④7/13と7/27: レポートに「✅承認/❌差し戻し」欄が付き、あなたが一言返せば記帳・検証はAIが運ぶ。**あなたの手番は「読んで一言返す」だけ**になります。

## Goal

prime_ad(AIads) 1本で、「現況データを読む→本人の判定ルールで裁く→施策を起案する→承認欄付きで提示→人間の承認一言→記帳・投入検証はAIが運ぶ→次サイクルで機械確認」の**閉ループを人間の関与1点(承認)まで圧縮して定常運転させる**。同時に、分身の将来の学習素材の恒久保全を今日確立する(原文=claude-mem user_prompts を主軸、transcripts は 6/27 以降のフル文脈=AI応答側の補完として保全)。

本人SSoT(AIads-playbook 2026-06-22)「発案に凝った装置を作らない。律速は発案でなく実行(1年で実投入1件・提案30件超未投入)」に従い、分身v1の目標関数は**文体模倣・起案量産ではなく「提案が投入まで届くレールの敷設」**に置く。

**分身の一般パターン(v1 が最初に実証する型・project 非依存)**: 『AIが現況データを読む → 本人の判定ルールで裁く → 施策を起案する → 人間は承認一言 → 記帳・検証はAIが運ぶ』。v1 はこの型を AIads で 1 本閉じる。型は汎用で、v1.1 以降は scheduled プロンプト md 1枚コピーで AIcrm/pokeca 等へ複製する(=広告運用自動化への矮小化ではなく分身の型の初回実証・Codex F16 回答)。v1 が配線するこのループは分類 v2 の **P5(運用・裁定期)** に正確に対応し、承認欄はあなたの最大の入力成分 RULING(短文裁定・全期間の11-41%)を最小摩擦化する装置である。

**運用原則=蓄積/実行の分離(2026-07-03 正式決定・Codex 敵対レビュー APPROVE-WITH-CHANGES 反映・decisions.md 起票済)**: 分身の作業は session-goal 冒頭ラベル `[実行]`/`[蓄積]`/`[混合: 実行後に還流]` で分類。`[実行]` 中は新hook・新skill・新台帳を作らない(改善案は既存経路へ1行退避)。蓄積→実行の**参照**は常時可・実行→蓄積の**更新**は原則実行完了後(重大例外のみ即時)。実行モードでも公開・送信・課金・外部書込の出口ゲートは省略不可。台帳は操作で分ける(事実の追記=実行の一部/方針・優先順位の変更=還流)。

**分身の第二の型(2026-07-02 環境genesis分析で追加・v1では定義のみ)**: 事業ループに加え、**環境自己改善ループ**『違和感検知 → 制度起案 → 敵対レビュー → 承認 → 強制配線(deny>hook>ルールの強度階段) → 1行スモーク検証』。全プロンプトの25%を占める最大単一活動で、2-strike 規範(同じ失敗の2回目で恒久対策へ格上げ)が発火規則。実装は Phase 4 ゲート通過後。

**非ゴール(v1)**: 文体模倣コーパスの全面構築 / ゼロイチ起案・会議レイヤー再現 / Messenger・LINE自動返信 / 管理画面への自動書込 / 4プロジェクト横展開 / NOW.mdスコア重み較正 / persona-core等の新ノート作成。

## Architecture

新規スクリプト0本・新規hook 0本。変更は**既存7ファイルの編集**(data-retention.sh / settings.json / scheduled prompt / vault-prompt-runner.sh / recurring-mistakes.md / implementation-checklist SKILL.md / AIads-playbook.md)+**管理用 md 2枚のみ新規**(plan/task・rules/05 義務・Codex F6/F7 回答として正直に申告)。

```
[Phase 0: 保全(即日)]                    [Phase 1: 委譲の配線(7/13前・v1主軸)]
~/.claude/hooks/data-retention.sh §7      vault …/AIads/prompts/scheduled/adscrm-biweekly-ads-pdca.md
  jsonl の rm -f → mv -n 退避               ├ 一次ソース節に biweekly-cp-decision-algorithm.md 1行
    └→ ~/.claude/archives/jsonl/<projdir>/  ├ §4 に「アルゴリズム準拠裁定・節番号出典」1行
       (claude-mem の既存退避先を reuse・     └ 新節§8 に「✅承認/❌差し戻し+投入指示書」欄
        .gitignore L85 済・4,140件実在確認)  ~/.claude/scripts/vault-prompt-runner.sh L112 失敗分岐
~/.claude/settings.json                      └ osascript 通知1行 (idle-notify.sh と同型 reuse)
  + "cleanupPeriodDays": 365 (必須第二防壁・公式default30日)
                                          [Phase 3: 試運転 7/13・7/27]
[Phase 2: 是正の最小修理 3+1]              AI提案+承認欄 → 人間が一言 → AIが interventions.csv
settings.json L464: head -20|tail -15      記帳+NOW.md更新+verify_cp_changes.py → 次回§6 G2 で
  → awk セクション抽出 (恒久修理)          機械確認 = ループ閉鎖 (playbook Must Remember に1行)
state/recurring-mistakes.md +2行・40行cap
skills/implementation-checklist +1項      [Phase 4: 条件付き拡張 (8月〜・定義のみ)]
hooks/pretooluse-askuserquestion-guard.sh  M1-M4ゲート通過後: runner_tools Write 解禁判断・
  削除 (settings参照0件=dormant 実測)      コーパス抽出v0 (Bの前処理仕様固定)・Gmail draft-only
```

**是正(fix_first)の機構決定 — 反証 must_address への回答**:
- **注入窓の物理制約**: settings.json L464 の `head -20 | tail -15`(6〜20行目固定窓)を実測。現ルールは L9-18 で残余ちょうど2行 = 2行追加は今日は入るが3行目から無言で圏外に落ちる。**窓を `awk '/^## Active Rules/{f=1;next} /^## メタルール/{f=0} f'` のセクション抽出へ差し替え**(プランA採用・行数増減に恒久追従・メタルール節の混入なし)。C案の `head -30|tail -25` は固定窓のままで却下、B案の `tail -n +6` はメタルール節が混入するため却下。ファイル側キャップは 30→40 行へ改定
- **既存hookとの重複**: wiki-recall-on-prompt.sh のキーワード改修は**やらない** — userprompt-routing-inject.sh が既に recurring-mistakes.md からの trigger 注入を実装済み(reuse違反になる)。将来のキーワード発火は同hookへの数行追記が受け皿
- **10項目は過剰**: 採用は「①注入機構修理(root cause) ②obs-before-claim + plain-language-bluf の2行 ③runner失敗通知 ④implementation-checklist への決定事項照合1項」のみ。**新hook 0本**。残り7項は却下(下記Cut)し、Phase 4 の月次計測(M4是正シグナル率)で再発が数字で続いたものだけ rules/10 の優先順位(deny第一選択→hookは最後)で翌月1件ずつ判断するデータ駆動の後追い
- **dormant hook**: pretooluse-askuserquestion-guard.sh は settings.json 参照0件(実測)。二択のうち**削除**を採用(A案) — 対象バグは recurring-mistakes L9 の行動ルールで運用済み・5週間 dormant で実害なし・clutter厳禁。再発時は git 履歴から復元+登録1行で復帰可能
- **A群論拠の用途限定**: A群(是正・窓により12-21%・問い詰め型は A/D 複合判定・「よくわかりません」は全期間226件)は Phase 4 コーパス抽出時の負例分離フィルタとしてのみ使用。ライブ環境の是正完了の根拠には使わない(是正と素材保全・配線は全て並行)
- **優先度0**: transcript保全を全Phaseの先頭に配置(下記 Phase 0)

**分身v1のスコープ判断: prime_ad 1本に限定(採用・根拠を2026-07-02深掘りで更新)**。根拠: ①判定アルゴリズム正本(37KB・Codex敵対レビュー+実データ較正済・2026-07-01正式採用)が存在するのは prime_ad だけ ②実行ループ部品(interventions.csv・verify_cp_changes.py・NOW.mdゲート・scheduled 2枚)が prime_ad にのみ完備 ③runner は runner_project 対応済みのため、v1 が1本閉じてから他projectは「プロンプトmd 1枚コピー」で増設できる(AIcrm が v1.1 第一候補)。※旧根拠「起案4段の実例は AIads 6/16 の1例のみ」は**削除** — 原文5,516件の検証で起案の型は全project共通(初出 prm 4/30・フル形の先行例 prime_suite 5/18・5/27)と確定し、6/15以降だけを見た標本切断による誤認だった。Phase 4 コーパスは「**起案テンプレ=全project共通部品 / prime_ad=ドメイン知識供給源**」の分離設計とする。

## Tasks

粒度2-5分・原則1ファイル・バッチ3タスクごとに fast_verify(rules/10準拠)。

### Phase 0 — 素材保全(Priority-0・即日)

**Batch 1 [T1-T3]**

| # | 対象ファイル | 変更概要 | 検証コマンド |
|---|---|---|---|
| T1 | `~/.claude/hooks/data-retention.sh` §7 (L88-97) | jsonl の `rm -f`(L94) を退避へ変更: `mkdir -p "$dest" && mv -n "$file" "$dest/" || true; [ -e "$file" ] && [ -e "$dest/$(basename "$file")" ] && rm -f "$file"`(衝突時は **projects 側のみ**削除・archives 側は絶対に消さない=Codex F4)。関数冒頭に `chmod 700 "${CLAUDE_DIR}/archives" "${CLAUDE_DIR}/archives/jsonl" 2>/dev/null`(F5)。UUID セッションdir(L100-107・subagents/tool-results)は従来どおり削除(人間プロンプトは親jsonlに集約・容量抑制)。log文言 deleted→archived | `bash -n ~/.claude/hooks/data-retention.sh` |
| T2 | `~/.claude/settings.json` | top-level に `"cleanupPeriodDays": 365` 追加。**公式設定と確認済み**(default 30日・startup時にセッションファイル削除=放置すると CC 本体が 30 日で消すため必須)。編集は python3 の json load/dump で構造編集(手書きエスケープで settings.json を壊さない=F10) | `python3 -c "import json;print(json.load(open('/Users/masaaki_nagasawa/.claude/settings.json'))['cleanupPeriodDays'])"` → 365 |
| T3 | (調査のみ・変更なし) | ①claude-mem アーカイブが 6/26 で停止した原因(plugin 12.4.x 更新等)をSubAgent 30分で特定・復旧可否判定 ②【2026-07-02 実施済み・task.md 作成時に転記】素材②の主役は observations(AI要約・二次)でなく **user_prompts(原文・一次)**: 総数5,516・期間4/26〜7/2・project分布(prime_suite 2114/.claude 1373/pokeca 703/autopost 513/make_article 404…)・機械混入率12-18%(1プロンプトセッション663件=AI委譲文ほか)。アクセス手順=稼働中DBに触れず read-only コピーを scratchpad へ | `sqlite3 <コピー>.db "SELECT COUNT(*),MIN(created_at) FROM user_prompts;"` → 5516・2026-04-26 |

**fast_verify(Batch 1)**: `bash ~/.claude/hooks/data-retention.sh 2>&1 | tail -5 && find ~/.claude/projects -maxdepth 2 -name '*.jsonl' -mtime +14 | wc -l`(→0)`&& find ~/.claude/archives/jsonl -name '*.jsonl' -newermt 2026-06-27 | wc -l`(→1以上=6/27以降分の退避開始)
※**必須ゲート(F5・順序固定)**: **T1 の初回実行(既存 jsonl の退避開始)より前に** Open Q1(トークン rotate 済みか)を判定する。未 rotate の場合は ①rotate 手順の提示 ②該当トークンを含む jsonl への Phase 4 マスク regex の先行適用、の両方が完了するまで T1 の適用・退避開始を行わない(保全と秘密保持の衝突を fail-close で解消)。**別Mac エクスポートにも同型の fail-close を適用** — export ディレクトリ chmod 700・転送は AirDrop のみ(git/クラウド禁止)・分析投入前に Phase 4 マスク regex を先行適用

**T3.5(2026-07-02 追加): 別Mac(MASA.local) 保全** — 別Mac でも data-retention.sh が transcripts を14日で削除し続けており totty/ai_dashboard/rohan 進化分が毎日失われている。手順: ①このMacの T1/T2 を commit+push(T1 は hooks/ と extensions/data-retention/hooks/ の**2箇所**修正) ②別Mac で `git -C ~/.claude pull`(auto-pull なし=手動必須・dirty なら止まって報告) ③別Mac で claude-mem DB を VACUUM INTO で安全コピー→AirDrop でこのMacへ。**コピペプロンプト完成済み**(taxonomy-v2 §7)・人間の手番=別Macで1回貼る+AirDrop 1回
**T3.6(実施済み 2026-07-02)**: ラベル済みコーパス(全5,516件の二次元ラベル・遷移表・founding dumps)を `~/.claude/archives/bunshin-corpus/`(25MB・chmod 700・gitignored 実測確認)へ退避完了
**T3.7(位置づけ確定 2026-07-03)**: `~/.claude/archives/index.db`(SQLite FTS5・1.35GB・326,816 msgs・projects+archives/jsonl 全量を 2026-07-03 差分ingest済み)を**分身の採掘用全文検索DB**として保持。用途=次回コーパス採掘時の発話抽出高速化(例:「role=user かつ『もっとシンプル』を含む」を一発クエリ)。再生成は `python3 ~/.claude/scripts/ingest-jsonl-to-sqlite.py`(idempotent・数分・原本jsonlから何度でも再構築可)。**常設自動更新はしない**(decision 2026-07-03「蓄積/実行分離・実行中の仕組み化禁止」準拠。週次launchdジョブは同日撤去→`launchd/_archive/com.masa.claude-history-ingest.plist`)。採掘直前に手動1コマンド更新で足りる。claude-mem DB への外部書込は禁じ手(mistakes: live-process-state-clobbered)のため、claude-mem との関係は read-only 参照のみ

### Phase 1 — 委譲の配線(v1主軸・7/13 の第2月曜前に必須)

**Batch 2 [T4-T6]**

| # | 対象ファイル | 変更概要 | 検証コマンド |
|---|---|---|---|
| T4 | `~/Documents/Obsidian Vault/02_Ai/AI_adscrm/AIads/prompts/scheduled/adscrm-biweekly-ads-pdca.md` | ①「## 読むべき一次ソース」節(L43-60)に `docs/biweekly-cp-decision-algorithm.md — 継続/修正/抑制/縮小 裁定の正本(2026-07-01採用)` 1行。**repo 相対パス=runner_workdir(prime_ad)からの相対。vault 側に正本を作らない**(Codex F1。既存の vault 内参照 2件 AIads-cp-review.md:59 / AIads_ope.md:94 も repo 正本を指しており、正本一本を維持=F2。「参照0件」は scheduled プロンプト内に限った実測) ②§4(L75-86)冒頭に「既存CP裁定は docs/biweekly-cp-decision-algorithm.md の判定手順に従い、該当CPの判定に使う節のみ読み、適用節番号を出典明記」1行(§5 公式照合との重複を避け §4 に限定=F9) ③承認欄は §7 に詰めず**新節 `### 8. 承認欄`** として追加(起案0-2件それぞれに ✅承認/❌差し戻し 記入欄+投入指示書・押すボタン1つまで還元) ④frontmatter last_updated 更新 | `grep -c 'biweekly-cp-decision-algorithm' <同ファイル>`(≥2=一次ソース節+§4。§8 に「§4 裁定に対する承認」と書けば3)+ `grep -c '承認' <同ファイル>`(≥1) |
| T5 | `~/.claude/scripts/vault-prompt-runner.sh` L112-115 失敗分岐 | `osascript -e "display notification \"vault-prompt-runner FAILED rc=$RC ($SLUG)\" with title \"Claude 定期実行\"" 2>/dev/null || true` 1行追加(idle-notify.sh と同型reuse・6/22 rc=127 silent失敗の再発防止) | `bash -n` + scratchpad に `runner_model: "no-such-model"` の失敗用プロンプトで1回実行→Mac通知目視+log FAILED行 |
| T6 | (検証のみ・結果は task.md へ) | headless hook probe: `claude -p` に scratch Write をさせ hook 副作用(state/edit-history.jsonl 行数増・verify-step pending 生成)の有無で発火を判定(Phase 4 ゲート M3 の前提を先行測定) | `wc -l ~/.claude/state/edit-history.jsonl` の before/after 差分を task.md に記録 |

**fast_verify(Batch 2)**: runner を手動で biweekly モード起動(dry-run・7/13を待たない)→ `reports/adscrm-biweekly-ads-pdca-result.md` に (a)アルゴリズム節番号の出典引用 (b)§1-8 全出力 (c)承認欄、を確認。context圧迫(37KB)で§7が崩れたら「該当節のみ読む」指示を調整して再実行(3-Fix Limit)。検証: `grep -E '§[0-9]|規則' <result md>` + `tail -3 ~/.claude/state/vault-prompt-runner.log`

### Phase 2 — 是正の最小修理(fix_first 3+1)

**Batch 3 [T7-T9]**

| # | 対象ファイル | 変更概要 | 検証コマンド |
|---|---|---|---|
| T7 | `~/.claude/settings.json` L464 | 注入コマンドを `[ -f ~/.claude/state/recurring-mistakes.md ] && echo '=== ⚠️ Recurring Mistakes (実行時注入ルール) ===' && awk '/^## Active Rules/{f=1;next} /^## メタルール/{f=0} f' ~/.claude/state/recurring-mistakes.md \|\| true` へ差し替え(固定窓の恒久解消)。**編集は python3 json load/dump で構造的に行う**(awk のクォート/パイプを手書きエスケープすると settings.json 全体を壊すリスク=F10)。適用後 `claude doctor` 相当の JSON 妥当性確認 | 差し替え後コマンドを単体実行し全 Active Rules(10+新2=12行)が stdout に出る |
| T8 | `~/.claude/state/recurring-mistakes.md` | ①`- **obs-before-claim** \| 「完了/投入済み/push済み/反映済み」等の状態宣言は同じ応答内に観測出力(コマンド結果・実読引用)を伴う。無ければ「未確認」と書く(git push はremote実照合後) \| UserPromptSubmit injection` ②`- **plain-language-bluf** \| 非エンジニア向け報告は BLUF先頭+専門用語1行注釈+使い心地の言葉。「よくわかりません」は一段平易に言い直す合図 \| UserPromptSubmit injection` ③L9 enforcement 表記を `LLM behavior` へ修正(T10と整合) ④L25 キャップ 30→40行 ⑤Last updated 更新 | `grep -c '^- \*\*' ~/.claude/state/recurring-mistakes.md` → 12、`wc -l` ≤40 |
| T9 | `~/.claude/skills/implementation-checklist/SKILL.md` STEP 4 | 「完了報告前に、同セッションでユーザーが決定・訂正した事項を列挙し、成果物への反映を1件ずつ照合した表を報告に含める」1項追記(surface-compliance 26回超への act-time 対策・新hookなし) | `grep -n '決定事項' <同ファイル>` |

**fast_verify(Batch 3)**: T7 コマンド単体実行(12ルール出力)+ `git -C ~/.claude diff --stat`(変更が意図3ファイルのみ)

**Batch 4 [T10]**(1タスク)

| # | 対象ファイル | 変更概要 | 検証コマンド |
|---|---|---|---|
| T10 | `~/.claude/hooks/pretooluse-askuserquestion-guard.sh` | 削除(settings.json 参照0件=dormant 実測・git履歴に残る・復帰=restore+登録1行)。Codex は hooks/dormant/ 移動を代替提示(F11)したが、git 履歴+task.md への削除理由記録で監査性は担保されるため削除を維持(clutter厳禁優先)。あわせて hooks/ vs settings.json の一度きり突合棚卸しを行い、他の dormant があれば task.md に列挙のみ(自動化しない) | `ls ~/.claude/hooks/pretooluse-askuserquestion-guard.sh`(not found)+ 突合結果が task.md に記載 |

### Phase 3 — 分身v1試運転(7/13・7/27 の2サイクル)

**Batch 5 [T11-T12]**

| # | 対象ファイル | 変更概要 | 検証コマンド |
|---|---|---|---|
| T11 | `~/Documents/Obsidian Vault/02_Ai/AI_adscrm/AIads/AIads-playbook.md` Must Remember | 1行追記:「ユーザーが承認と言ったら AI が同セッションで interventions.csv 追記+NOW.md 該当行更新+verify_cp_changes.py 実行まで運ぶ」(記帳代行の定石化・新仕組みなし・対話運用) | `grep -c 'interventions.csv 追記' <同ファイル>` ≥1 |
| T12 | (計測のみ・task.md へ) | ゲート指標 M1-M4 の baseline 記録: M1=runner 直近成功率(log) / M2=承認差し戻し率(初期値なし) / M3=T6 probe 結果 / M4=是正シグナル週次件数(grep 辞書「よくわかりません/何回言ったら/反映されていない/進んでますか/ファクトチェックして」を projects/+archives/jsonl の直近35日 user 発話に適用・baseline≈16件/週。加えて claude-mem user_prompts(read-onlyコピー)にも同辞書を適用し9週間baseline(「よくわかりません」全期間226件の週次推移)を取得) | task.md に数値4つ+判定式が記載 |

**Phase 3 の観測イベント(タスク外・Verification に含む)**: 7/13 10:30 の自動実行(毎週月曜 10:30 の launchd が日付帯 8-14/22-28 で biweekly を選ぶ方式=厳密な隔週ではない・F12)後、result md の生成時刻・アルゴリズム出典・承認欄を確認(7/14 に1分の人間チェック・Macスリープ時の launchd スキップ検出を兼ねる)。承認1件目で「csv 追記行+verify 出力」まで到達=ループ閉鎖1件(S4)。未達なら止まった1点(承認が返らない/記帳漏れ)だけ直す。

### Phase 4 — 条件付き拡張(8月〜・v1では定義のみ・実装しない)

- **無人解禁ゲート(観測指標・恣意的開閉の防止)**: M1=runner 直近4回連続 FAILED 0 / M2=承認差し戻し率<25%(2サイクル) / M3=headless hook probe PASS(T6 で測定済) / M4=是正シグナル 2週連続 baseline比50%以下。**全通過後の最初のタスク(唯一の直列点)**: runner frontmatter `runner_tools` への Write 付与をコード変更なしで個別判断。管理画面投入・メッセージ送信は v2 でも人間承認を維持(fail-close)
- **コーパス抽出 v0(Q2 回答後)**: 源泉は **三本+補助**【2026-07-05 改訂: ④vault人筆レイヤーを追加。源泉一覧・除外規則は末尾「教材源泉 v3」節が正】 — ①claude-mem `user_prompts` このMac(4/26〜・5,516件・ラベル済み退避済み) ②transcripts アーカイブ(6/27〜のフル文脈=AI応答側) ③別Mac claude-mem エクスポート(T3.5・totty genesis/ai_dashboard/rohan 校正群) +補助: git log(pre-window の間接復元)。**環境構築プロンプト(約1,440件=25%)は『仕組み化ループ・サブコーパス』として第一級の正例に昇格**(9サブタイプ+12ループ実例+2-strike+強度階段・taxonomy-v2 §5)。まず claude-mem knowledge-agent/mem-search で30分試行→不足時のみ最小スクリプト1本。前処理仕様は以下で**固定**(2026-07-02 原文検証で更新): ①dedupe+訂正二連投は最終版採用(訂正癖・誤綴り指紋 valut/teamnde はメタ特徴として保持) ②マスク fail-close: `EAA[A-Za-z0-9]{20,}`/32-hex/`Bearer \S+`/`sk-|ghp_|xox[bp]-`/高エントロピー連続40字 `[A-Za-z0-9+/=_-]{40,}` は `[MASKED]`・出力先は gitignore 済みパスのみ・**user_prompts にも適用必須**(6/22 prompt#72 に LINE トークン生値の実在を確認済) ③A群(是正・窓により12-21%・問い詰め型は A/D 複合判定)は負例分離・収録しない ④**AI起草混入(全体の12-18%)の除外**: 1プロンプトセッション663件(SubAgent委譲文)・「あなたは〜」役割付与型185件・[Nh check]定期文・runner frontmatter・obsidian-git Conflicts定型・paste-relay ⑤音声正規化辞書(valutMD→vault MD/コーデックス→codex)は解釈時適用・原文不改変。**B正例は6/15以前4,427件まで遡及可**(ラベル構造140件中94件が5月=型密度最高)。**ノイズ実分離は 2026-07-02 実行済**(`~/.claude/archives/bunshin-corpus/clean/`・正例プール clean_B 2072+keep_A_standard 98=2170件・separate.py で冪等再現)。生成器は clean 正例プール+§11.5「正確な癖テンプレ」を教師にする(汚い§1でなく§11が正)。残: keep_A_standard の27件が AI起草prose逆流=人手1パス要。**生成器仕様は v2 3段パイプへ差し替え**: 第1段=工程認識(P0-P5 判定・週次指紋プロキシ or NOW.md/phase-tracker 読取)→第2段=11サブタイプ別テンプレ充填(必須スロット+実測遷移表 ideate→verify→RULING→dispatch)→第3段=ミクロ品質層(必須要素12項)。詳細 taxonomy-v2 §1-2。**データ分類思考モデル(taxonomy-v2 §10・第一原理15+判定フローQ-1〜Q9+器21行)を生成器の第0層(データ設計)として搭載** — 検証 needs-fixes(的中73%)のため §10.6 の修正リスト適用を Phase 4 の先頭タスクに置く
- v1.1 候補: AIcrm 横展開(プロンプトmd 1枚)・Gmail draft-only 返信支援(MCP に send 系なし=構造的 fail-safe)・persona-core の要否判断(コーパス実物を見てから)

## Verification

- 各バッチの fast_verify を実行してから次バッチへ(verify-step hook 準拠・Batch 4 は高リスク1タスク)
- 静的+実行時の両方: shell 変更は `bash -n`、settings.json は python json load、Phase 1 は故意失敗テスト+dry-run 実実行まで
- **Phase 0 実効**: 2026-07-17 に `find ~/.claude/archives/jsonl -name '*.jsonl' -newermt 2026-07-02 | wc -l` > 0(7/2以降分が退避されている=出血停止の直接証明)
- **Phase 1 実効**: 7/13 自動実行で result md にアルゴリズム節番号出典の判定表+承認欄。故意失敗テストで Mac 通知1回実測済み
- **Phase 2 実効**: 新セッション注入に Active Rules 全12行(T7 コマンド単体実行でも機械確認可)
- **Phase 3 実効**: 7月中にループ閉鎖1件(interventions.csv 新規行+verify_cp_changes.py 出力+次回§6 G2 通過)
- 最終完了報告前に implementation-checklist STEP 1-4(T9 で強化した決定事項照合込み)

## 成功基準

| # | 基準 | 観測方法 |
|---|---|---|
| S1 | 素材が二度と消えない | retention 実行後 projects/ の mtime+14 jsonl=0 かつ archives/jsonl に 6/27 以降分が増え続ける(コマンド1本) |
| S2 | 是正ルールが実際に注入される | T7 コマンド単体実行で全12ルール出力+dormant hook 0件 |
| S3 | 7/13 の無人実行が本人の判定ルールで裁く | result md に (a)アルゴリズム節番号出典 (b)§7起案0-2件+承認欄 (c)人手ゼロ生成。失敗時は Mac 通知が届く(故意失敗で実測済) |
| S4 | ループ閉鎖1件以上(7月中) | AI提案→人間承認一言→AI記帳(interventions.csv 新規行)→verify_cp_changes.py→次回§6 G2 通過 |
| S5 | 使い心地 | ユーザーの手番=「月曜にレポートを読み、承認/差し戻しを一言返す」だけ。読めないレポート・silent失敗・消える履歴の3つが無い |

## その他4項目の扱い

| 項目 | v1 判断 | 理由 |
|---|---|---|
| チャット/Messenger返信 | **やらない**(Gmail draft-only のみ Phase 4 候補) | 検証実績ゼロ・BAN/誤送信リスク・宛先allowlist不在。Gmail は MCP に send 系ツールなし=draft までが構造的ガードで今日でも可能(新設不要) |
| PDCAを回す | **v1 の主軸そのもの**(Phase 1+3) | Plan/Check は自走済み。Do の承認ゲート化+承認後の記帳代行が本丸。管理画面への実書込のみ人間(意図的設計を維持) |
| 定期実行の自動実行 | **既に稼働・v1 は配線修理のみ**(T4/T5) | launchd 3本+runner の型が確立済み。増設は scheduled/ md 1枚+plist 1枚の既存型コピー。再発明禁止 |
| /loop を作る仕組み | **やらない** | loop skill 実利用ゼロ(実測)・セッション内限定で無人化に寄与しない・律速はループ数でなく投入。必要時に commands/ 23枚の模倣で足りる |

## Cut(却下リスト・要約)

①fix_first 残り7項(Stop hook XML検知/PostToolUse diff検査/preflight表/レポートskill警告hook/SessionStart credential注入/echo-the-axis/branch併記)= rules/10「denyが第一選択・hookは最後」+clutter厳禁に抵触。M4計測で再発が数字で続いたものだけ翌月1件ずつ ②wiki-recall改修=userprompt-routing-inject.sh と機能重複(reuse違反) ③persona-core 新ノート=判断正本は playbook/algorithm に既在・authorship 未確認のまま作ればAIの癖の自己模倣。コーパス実物確認後に要否判断 ④NOW.md スコア重み較正=優先順位の最終裁定は人間のまま(Q回答不要・明示的に外す) ⑤decisions.md タグ再編=append-only 1,890行の改変は Anti-Bloat 違反。抽出時の選別引用で代替 ⑥4project 横展開=素材が AIads 偏在。1本閉じてから md コピー ⑦INBOX 蓄積待ち=新規蓄積ほぼゼロ実測。素材源泉は user_prompts(原文・主軸)+保全 transcripts(フル文脈補完)に置く

## 反証 must_address 対応表(16項)

data 1-8: ①Phase 0 先頭配置 ②prime_ad 限定を根拠4点で採用 ③Open Q2+INBOX非依存設計 ④Open Q3+回答まで文体教師に載せない ⑤タグ再編却下+抽出時選別で代替(v1 は decisions.md を教師に使わない) ⑥01_Biz 棚卸しは Q2/Q3 と同時にユーザー可否確認後 read-only 調査(T12 に併記) ⑦T3 で実測記録 ⑧較正を外すと明示。
approach 1-8: ①Phase 0 新設 ②T7 で窓修理してから T8 追加 ③wiki-recall 却下+dormant は削除に裁定 ④3+1 に削減・新hook 0 ⑤Phase 1 を主軸に格上げ・7/13 期限 ⑥M1-M4 数値ゲート定義 ⑦21% は負例フィルタ限定 ⑧headless 検証(T6)を Phase 4 の必須前提として直列維持。

## Open Questions(実装前に要回答)

- **Q1(Phase 0 と同時)**: 平文貼付された鍵の rotate 状況(アーカイブ保全は平文の保持を恒久化するため)。対象=6/24-25 の LINE/Meta トークン+深掘りで新規検出した4クラスタ: (a)5/13 OAuth client_secret JSONパス+client_id入りURL 2件 (b)6/8 別 client_secret JSONパス1件 (c)6/21 92字高エントロピー文字列5連投(.claude) (d)6/22 prime_suite prompt#72 の LINEチャネルアクセストークン+シークレット生値。※biz系8project 全2,272件は実鍵ヒット0件(スキャン済)。**(e・2026-07-02 分類検証で新規検出・最優先)** vault `00_Inbox/key_api.md` に sk-ant- 系4件+AIza 系2件が平文保存・**git 追跡済みで GitHub リモートに 2026-03-25 から push 済み**(履歴にも残存)。rotate(全6鍵の再発行)→ファイル撤去(または passvault 移設)が必須。未 rotate なら手順提示+先行マスク完了まで T1 適用禁止
- **Q2(Phase 4 前・v1 は非依存)**: INBOX 投函がほぼ止まっているのは「対話で直接頼む方が速い」からですか？→ 素材源泉を **user_prompts(4/26〜の原文・一次)+transcripts アーカイブ(6/27〜のフル文脈)の二本立て**に置く本設計で良いか確認
- **Q3 クローズ(2026-07-02)**: 起案の型(4段+11サブタイプ)は原文で本人の型と実証済み。「取る的/捨てる的」等のレポート様式のみ Phase 4 で軽く確認
- **Q6(Phase 4 前・新規)**: P0 昇格判定則(同種の単発依頼2回目→「プロジェクト化しますか？」を分身が提案)を持たせますか？ 実史では昇格は全て人間判断で自律発火実績ゼロ=テンプレは書けるが未実証
- **Q7(Phase 4 前・新規)**: 人間専権12スロット(相場観の閾値・採算構造・投資thesis・会議決定 等= taxonomy-v2 §3)を、分身が起案時に**先出しの質問チェックリスト**としてあなたに聞くインタビュー型設計で良いですか？(生成器の核)
- **Q4(7/13 前)**: レポート承認欄への返し方は (a)対話で一言 (b)INBOX 📒 に記入 (c)NOW.md 1行 — どれが一番ラクですか？(v1 の摩擦設計の核心)
- **Q5(plan 承認時)**: transcript は無期限ローカル保持(gitignore 済・増加 ~300-600MB/月・抽出時マスク方式)+無人解禁は M1-M4 全通過まで凍結、で良いですか？

## Codex 敵対レビュー対応表(Round 1: REJECT 16 findings → Round 2: APPROVE-WITH-CHANGES 4点 → 全反映)

| # | 指摘 | 対応 |
|---|---|---|
| F1 | アルゴリズム参照は vault でなく repo 正本 | T4 を repo 相対 `docs/` パスに明記・vault 正本は作らない |
| F2 | 「参照0件」は誤り(vault に2件) | 「scheduled プロンプト内0件」に限定し既存2参照と整合 |
| F3 | cleanupPeriodDays 実効性不明 | 公式docs で確認済み(default 30日=必須の第二防壁に格上げ) |
| F4 | mv 衝突 fallback がアーカイブを消しうる | fallback は projects 側のみ削除の安全形に固定 |
| F5 | 平文トークン恒久保持リスク | Q1 を必須ゲート化+未rotate時は先行マスク+chmod 700 |
| F6/F7 | 変更範囲の過小申告 | 「既存7ファイル+新規md 2枚」に正直化 |
| F8 | osascript の変数展開/エスケープ | $RC/$SLUG 実在確認済み(L58/L109)・二重引用符形+bash -n 必須 |
| F9 | T4 編集位置が雑 | §4 限定+承認欄は新節 §8 に分離 |
| F10 | settings.json 手書き編集の破壊リスク | python3 json load/dump 構造編集に固定 |
| F11 | dormant hook 削除は監査性低下 | git履歴+task.md記録を根拠に削除維持(理由明記) |
| F12 | 「隔週」表現不正確 | 「日付帯 8-14/22-28 分岐」に修正 |
| F13/F14 | 行番号・配置判断は正しい | 変更なし |
| F15 | cleanupPeriodDays 未確認(重複) | F3 で解消 |
| F16 | 広告運用への矮小化懸念 | Goal に「分身の一般パターンの初回実証・md 1枚コピーで複製」を明文化 |

**Round 2 残存4点の反映**: ①Architecture 図を §4+新節§8/必須第二防壁 表記に同期 ②Q1 rotate 判定を「T1 初回実行前」に順序固定 ③T4 grep 閾値を ≥2 に修正 ④公式URL+取得日(2026-07-02)を明記。


## 分身プロンプト生成器の必須要素(2026-07-02・原文5,516件から抽出・Phase 4 で実装)

分身があなたの代わりに実装プロンプトを書くとき、初回プロンプトに必ず入れる要素(全て原文の実績から逆算):

1. **現状確認の強制句を冒頭に**(「現運用CP/最新データ/NOW.md をまず確認してから」— 是正226+107件の未然防止)
2. **観測可能な数値ファクト基準を1行**(「2週間で10枚以上売買成立ならファクトとする」級)
3. **成果物の置き場所を絶対パスで先頭指定**(読み物=vault MD・コード=repo)
4. **角括弧ラベル節の骨格**([goal]/[ask]/[env/memo]/[置き場所] — 4/30 prm 初出の本人の不変骨格)
5. **委譲と着手の分離**(「codex , agent teamで考えて」→敵対レビュー→承認・着手は別発話)
6. **非エンジニア語彙の強制**(専門用語は定義併記+BLUF — 「よくわかりません」226件の未然消火)
7. **自己検証句の常置**(「実画面で反映を確認してから完了報告」— 「反映されてますか」142件を1往復に圧縮)
8. **長時間ジョブ・worktree の監視/復帰定型**([Nh check]テンプレ+worktree ヘッダで Session Handoff を先に読ませる)
9. **終了儀式の自動提案**(push→/save decision・mistake→引き継ぎ書)
10. **エスカレーション規則**(2回修正失敗→個別修正をやめ根本原因へ切替)
11. **(学習側規定・2026-07-02 クリーン再抽出で訂正)負例と正例の切り分け**: 負例=**純傷跡のみ**(罵倒・回数勘定・AI忘却への再入力=全体1.0%/56件)。AI起草混入(委譲文259+役割付与185+英語AIプロンプト等=500件/9.1%)は文体から**除外**。⚠️**是正の形をした「本物の品質基準」(ファクトチェック/現運用確認/SSoT/完了定義/恒久化/平易化/構成図/既存資産棚卸し=毎週12.1%安定)は負例でなく正例=第3層**(§11.3)。dispatch は AI 起草が88%なので長文委譲 prose を模写せず「委託を発火」だけを継承(taxonomy §11.2)
12. **仕組み化ループの発火規則(2-strike・2026-07-02追加)**: 同一の失敗・違和感が2回目に観測されたら個別修正をやめ、制度化(rules/10 優先順位: deny第一→hook→ルール)を起案→敵対レビュー→/save 振り分けまで運ぶ。ただしリスク受容・DO NOTHING 裁定・「人間が読むか」による制度廃止・面倒くささ却下の4点は人間専権(1問エスカレーション)

※この12項は v2 生成器 3段パイプの**第3段(ミクロ品質層)**に位置づく(#2→goal/collect スロットへ、#4→require サブタイプへ、#5→遷移規則へ吸収 — 対応は taxonomy-v2 §1)。工程認識とテンプレ選択は第1-2段が担う。

## 2026-07-02 claude-mem 深掘りによる前回検証への主な訂正

- 「原文は6/15以降881件のみ」→ **誤り**。user_prompts に9週間+2日・5,516件が現存
- 「起案4段のクリーン実例は AIads 1例のみ」→ **棄却**(標本切断による誤認・型は全project共通)
- 「A是正21.1%」→ 窓依存(11.9〜21%)。A+D合算32-34%は全期間で整合
- 「よくわかりません」41回 → 全期間**226件**(最長寿・現役の負例パターン)
- user_prompts=人間の声、は不成立: **12-18%がAI起草混入**(除外クラスXとして前処理必須)
- 秘密貼付は 6/24-25 以外に**4クラスタ追加検出**(Q1 の対象リスト拡大済み)
- 是正→ガード導入→クラスタ消滅の対応ペアが原文で**5組実証**(hook乱造でなく計測後追い方針の裏付け)
- fix_first 3+1・Phase 1/3 の配線・成功基準 S1-S5 は**変更不要**(現役の是正パターン全てに直撃弾が対応済みと確認)


## 関連ファイルへの追記提案(プラン外・承認後に実施)

- `~/.claude/templates/methodology-5step.md`: 新ファイルは作らず3点追記 — (a)0層に P0 昇格判定則 (b)①に P1 外部情報運搬プロトコル(「これですか？」照合・DL手順MD化・push前秘密確認) (c)実装節に P3 分社/統合判定の定型プロンプト


## 2026-07-05 教材源泉 v3 — vault 人筆レイヤーの追加 + MASA claude-mem の確定（[蓄積]・ユーザー再設計指示への回答）

> **位置づけ**: decision 2026-07-03 の分類で **[蓄積]**。Phase 1-3 の実行ループ・M1-M4 ゲート・生成器 v2 仕様には一切触れない（教材の供給源定義と保全手順だけを追加）。新hook・新launchd・常設自動化なし。
> **指示原文**: vault `00_Inbox/memo.md` L19-27(7/5)「自分の分身プロジェクトに obsidian を読み込ませるのを忘れていました。また、このPCの claude mem も参考になるかもしれません。ただ、ここには AI が作ったファイルもあるので、それを除外して、私の行動原理を読み込む足しにして、再度設計してください」
> **生成経路**: MASA.local で実測2本（vault 全457md の人筆/AI筆判別・45件実読サンプル / claude-mem read-only VACUUM コピー実測）→ 設計 → Codex 敵対レビュー Round 1 **REJECT**(12 findings) → 7 must-address 全反映 → Round 2 **APPROVE-WITH-CHANGES**(残7点) → 全反映（対応表 = 本節末尾）。実測ログ = taxonomy-v2 §12。

### 源泉一覧 v3（Phase 4「コーパス抽出 v0」の源泉に ④ を追加。①②③⑤は不変）

| # | 源泉 | 規模 | 教材上の役割 |
|---|---|---|---|
| ① | masa-2 user_prompts（ラベル済 5,516・正例 2,170） | 済 | 実行指示の文法（P1-P5） |
| ② | transcripts アーカイブ（6/27〜） | 稼働 | AI応答側フル文脈 |
| ③ | MASA claude-mem export（10,954件 2/2〜7/3・7/4検収済） | 済 + デルタ手順(下記) | pre-window 2〜4月の唯一の原文・rohan 6,566件 |
| ④ | **vault 人筆レイヤー（本節で新設）** | 初回サンプル調査の推定 約140-155ファイル・45-55万字（**実装時に ledger で確定**） | **P0候補の追加探索源**（プロンプト以前の草稿・価値観・起案の癖が残る候補地。「P0 gap が直接埋まる」とは主張しない — 実際に何件採れたかは S8b で観測し、0 なら本役割文と taxonomy §12 サマリーの両方を下方修正） |
| ⑤ | git log | — | 補助 |

### 除外規則（指示の核 =「AIが作ったもの」を教材から外す。**除外は層0(文体教師)からのみ**）

1. claude-mem **observations(MASA 32,568件)・session_summaries(7,207件)** = AI生成要約 → 層0/層1教材から除外。許可用途は (a)セッションの日付・所属特定 (b)読むべき raw transcript の索引、の2つだけ。**要約テキストが教材・価値観抽出へ入る経路は禁止**（AI要約の逆流 = §11.2 dispatch 過大計上事故と同型）
2. MASA user_prompts の**機械行 41.2%**（`<task-notification>` 30.9% + `Implement the following plan` 貼り戻し 10.3%・11,227件全件grep実測）→ 除外クラスXに MASA 固有2パターンを追加（masa-2 の X=9.1% と混入プロファイルが別物）。ただし捨てるのは層0からだけ — Monitor 運用文・plan 貼り戻し承認は「運用文法サブコーパス」として保持し、承認発行 vs churn の裁定は §8 既存 Open 事項と同軸で Phase 4 で行う
3. vault の AI筆 約300ファイル（MOC/_ope・reports/・wiki 知識ノート・impl-notes・templates・NOWミラー等）→ provenance ledger で除外。**例外**: decisions.md / mistakes.md は「判断=本人・文=AI」→ 層1（判断基準）入力には使い、層0（文体）には使わない

### vault provenance ledger（**chunk 単位**・主指標 = 抽出物の AI筆混入率）

- 判定3段: **L1 パス** → **L2 frontmatter**（rules/41 6フィールド + **wiki 別スキーマ `type: concept|entity|meta|source` 判定を必須追加**＝素朴実装だと wiki 41件が人筆側へ誤流入する実測済みの穴）→ **L3 文体指紋**（`valut`(12hit)・`コーデックス`(8)・`エージェントチーム`(12)・`goal)`・`[issue]` 等。**指紋は「人筆が存在する印」でありファイル全体の証明ではない**）。globs/regex 詳細 = taxonomy §12.2
- ledger 行 = path / chunk範囲(見出し or 行range) / 判定(H|A|MIX) / 判定手段(L1|L2|L3|人手) / 抽出可否 / 備考。純 HUMAN は file=1 chunk 可。MIXED（INBOX 📒🔵・decisions 引用・Daily・セッションlog型 — 初回推定 25-35件・**確定は ledger 構築時**）は見出し・引用ブロック・コードフェンス・貼付プロンプト境界で切る
- **段階採掘**: Wave1 = 人筆TOP20（taxonomy §12.3・パス参照）を全件人手確認して即教材化 → Wave2 = 自動確定 HUMAN 残り(~120)を抜き取り検査 → Wave3 = MIXED セクション抽出を**全件人手検収**。初回推定精度 91-93% は設計根拠にしない（45件実読サンプルの推定・Wave2 で再測定）
- 成果物と器: masa-2 `~/.claude/archives/bunshin-corpus/` 配下に vault-provenance.csv + pair ledger + 抽出スクリプト（**separate.py 系列・git非追跡・入力/出力/再実行1コマンドを同ディレクトリ README に1行ずつ記録・常設自動化しない**）。vault は read-only 不改変。glob は case-insensitive（実ディレクトリは小文字 `02_ai`）

### 秘密/PII ゲート（fail-close・成功基準に組込み）

パイプ順序固定: 抽出 → secrets スキャン（既存 Phase 4 マスク regex + `AIza[A-Za-z0-9_-]{20,}` + メールアドレス）→ 隔離 dir(chmod700) → マスク → 検収 → コーパス化。**顧客名・社名・個人名は project 固有辞書がある場合のみ機械スキャン、無い場合は Wave1/Wave3 人手検収の必須チェック項目**（検出不能なものを検出可能とは扱わない）。key_api.md は入口除外。`.raw/` 収集ログ・rohan/pokeca 顧客系集計値は教材除外（rules/42 M-1）。スキャンヒット>0 のままコーパス化する経路を作らない。

### dedupe = pair ledger（正規化ハッシュ単独は廃止）

INBOX 📒・refs/・prompt-original は user_prompts と重複しうる。**どちらも削除しない**。pair ledger（vault_path×chunk / prompt_id / 類似度 / 先行側(mtime・created_at) / diff種別[同一|草稿→清書|別物] / 層0採用側）で対応付ける。**層0正本の決定は「先行性 + provenance 判定 + diff 種別」の合議 — AI/MIX 判定の側は先行でも層0正本にしない**（先行がAI生成MOC・後続が本人裁定という逆汚染ケースを塞ぐ）。統計は pair 単位1カウント（S8 の二重計上防止）。

### MASA デルタ手順（手動1コマンド・常設自動化しない = decision 2026-07-03 準拠）

7/4 export の正確な切断時刻が不明（総数差 273 vs cutoff 7/3EOD比 131）→ cutoff は **2026-07-02T23:59:59 の安全側**・重複は user_prompts.id で dedupe:

```bash
TMP=/tmp/bunshin-delta-tmp.db; FINAL=~/Desktop/bunshin-delta-$(date +%Y%m%d).db
sqlite3 "file:$HOME/.claude-mem/claude-mem.db?mode=ro" "
ATTACH DATABASE '$TMP' AS d;
CREATE TABLE d.sdk_sessions AS SELECT * FROM sdk_sessions WHERE content_session_id IN (SELECT content_session_id FROM user_prompts WHERE created_at > '2026-07-02T23:59:59');
CREATE TABLE d.user_prompts AS SELECT * FROM user_prompts WHERE created_at > '2026-07-02T23:59:59';
" && sqlite3 "$TMP" "VACUUM INTO '$FINAL'" && chmod 700 "$FINAL" && rm -f "$TMP"
```

転送は AirDrop のみ・分析投入前に Phase 4 マスク regex 適用（§7 と同型 fail-close）。observations/summaries はデルタに**含めない**（除外規則1）。実測: 7/4以降 131件（.claude 52 / rohan 46 / influx 14 / totty2 9 / chacha_bot 7 / masaaki 3）＝次回採掘直前にまとめて実行で足りる。

### 成功基準（S1-S5 に追加）

| # | 基準 | 観測方法 |
|---|---|---|
| S6 | ledger が vault 全 md をカバーし chunk 行+判定手段列を持つ | csv 行数・列検算 vs `find` 実測数 |
| S7 | 抽出済みコーパスの AI筆混入: Wave1/Wave3 = 人手全件検収で 0 / Wave2 = **max(50 chunk, 自動HUMAN chunk の10%)** 抜き取りで混入 ≤1。**1件でも発見したらその判定ルール由来の全 chunk を再分類**（2-strike） | 抜き取り記録 |
| S7b | マスク後の抽出物への secrets/PII スキャンヒット 0 | スキャナ出力 |
| S8 | pair ledger による正味追加件数・字数（二重計上なし） | 抽出スクリプト出力 |
| S8b | P0/P1 タグ付き人筆引用の実件数を報告。0 なら「④の役割文(本節)」と「taxonomy §12 サマリー」の**両方**を下方修正 | ledger タグ集計 |

### 実行場所と残手番

- 採掘・ledger 構築 = **masa-2**（vault は obsidian_work git 同期済み・データ転送不要）。**着手前チェック3点**: ① `git -C ~/.claude pull` 済みで本節が読める ② vault 側 pull 済み+conflict なし ③ `02_ai` の大文字小文字差分を glob が吸収している
- MASA 側の残手番 = デルタ export 1コマンド + AirDrop のみ
- **衛生（要ユーザー判断・原則即削除推奨）**: MASA `~/Desktop/bunshin-export/` に 7/4 原本 442MB が残置（iCloud Desktop 同期無効は確認済み）。masa-2 検収済み（司令塔 T3.5）を根拠に `rm -rf ~/Desktop/bunshin-export`（実行は人間）。保持例外は「再検収が必要な場合のみ」・最長 2026-08 末・理由を司令塔に1行記録

### 非ゴール（変わらないこと）

persona-core 新ノートは作らない（Cut③維持）/ vault の改変・移動なし / 生成器 v2 3段パイプ・M1-M4 ゲート不変 / 新hook・新launchd・常設自動化なし

### Codex 敵対レビュー対応表（Round 1 REJECT 12 findings → 7 must-address 反映 → Round 2 APPROVE-WITH-CHANGES 残7 → 全反映）

| R2-# | 指摘 | 反映 |
|---|---|---|
| 1 | 使い捨てスクリプトの器を縛れ | archives/bunshin-corpus/ 固定・git非追跡・README 1行記録・常設自動化なし |
| 2 | 「顧客名系列」の機械スキャンは空文化する | 辞書がある場合のみ機械・無い場合は Wave1/3 人手検収の必須チェックへ変更 |
| 3 | 抜き取り 50 chunk は過少 | max(50, 10%) + 発見時は当該ルール由来の全 chunk 再分類 |
| 4 | 時刻先行だけの層0正本化は逆汚染 | 先行性+provenance判定+diff種別の合議・AI/MIX 側は正本化しない |
| 5 | §12 の肥大化ゲート | §12 は要約のみ・詳細は archives・TOP20 はパス参照 |
| 6 | Desktop 残骸の期限が甘い | 原則即削除推奨・保持例外は再検収時のみ+理由を司令塔に記録 |
| 7 | S8b の下方修正先が不明 | ④役割文 + §12 サマリーの両方と明記 |
