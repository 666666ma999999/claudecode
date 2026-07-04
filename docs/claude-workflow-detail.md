# CLAUDE.md 手順詳細（SSoT 委譲先）

> **CLAUDE.md（常時ロード）から移設した手順の全文**。CLAUDE.md 側は索引・原則のみ（2026-07-03 Phase 2 スリム化・`rules/30→docs/routing-table` と同型の分離）。
> ここは必要時 Read。**本文は CLAUDE.md 当時の全文を無編集で保持**（要約による情報喪失なし）。

---

## vault 書き分け + Claude × Obsidian 連携 2 セット運用

- **Obsidian vault は claude-obsidian 方式**（2026-04-24 以降）: 詳細は `rules/40-obsidian.md`
- **vault 書き分け (Phase E 2026-05-23〜)**: アーキ判断→`wiki/meta/decisions.md` (append-only), ミス・教訓→`wiki/meta/mistakes.md` (de-dup 上書き型、2 回目以降は既存 entry 統合), 実行追跡→`<repo>/tasks/*.md`, 設計 SSoT→`<repo>/plan.md`, プロジェクト概念→`wiki/{concepts,entities}/`。3 hook (recall/capture/dormant) が自動参照・促し・dormant 検出。詳細 `rules/40-obsidian.md`
- **Claude × Obsidian 連携 2 セット運用 (2026-05-24〜)**:
  - **Set 1 (グローバル抽象・全 project 共通)**: Recall (decisions/mistakes 注入) / Capture (`/save decision` `/save mistake` → vault) / Overwrite (mistakes de-dup, hot.md/_index.md 完全上書き) / **Ingest (外部情報の `.raw/` 自動取得 + `wiki/sources/` 昇格・更新)** の **4 ルール**。詳細は vault `wiki/concepts/Claude-Obsidian feedback loop.md`、実装規約は `rules/40-obsidian.md`、ルール本体は [[vault-rules-global]] / [[vault-rules-project]]
  - **Set 2 (プロジェクト実装・各 project 固有)**: 各 `<project>/CLAUDE.md` に `## Vault Integration` セクションを置き、Set 1 の 4 ルールを **当 project でどう投影するか** を記述。テンプレ: `~/.claude/templates/vault-rules-project.md` (例: AIads → impl-notes ノート + AIads_ope.md MOC / prime_crm → findings ノート + finding-sync skill / make_article → x-article-stock + Material Bank + article_bridge.py)
  - **両者の対応**: 同じ 4 ルール構造を 2 レイヤーで持つことで drift 検出可能。各 project の Vault Integration セクションは Claude Code 標準動作で自動 load される (グローバルから「読ませる」hook 不要)
- **ファイル配置 67 種 (2026-05-25〜・Phase 2 連動)**: 詳細 `rules/42-file-type-placement.md` (Active)。`~/.claude/state/vault-cc-enabled` flag gate で完全休眠可。**(2026-06-14 改訂) MOC への `## 🔁 最新更新ログ` 自動 append は廃止** — ロボット生成ログは git log + `decisions.md`(注入)の劣化コピー(rules/20 Dual-Path 違反)で人間も読み返さない。AI の最近の活動把握は本物 SSoT(decisions.md / git log / claude-mem)に委ねる。MOC は人間向け司令塔セクションのみ・自動フィード(Open Issues 等)は最下段の自動生成ゾーンへ(規約 `rules/41 §④`)

## 実装中検証ループ（バッチ検証・全文）

実装は**バッチ単位**(最大 3 タスク or 3 編集の早い方)。バッチ検証未完了で次バッチ Write/Edit 禁止(hook 強制)。最低検証: BE=再起動+ヘルスチェック+API 1 本 / FE=リロード+コンソールエラー 0+操作 1 回 / テストあり=PASSED 確認。検証コマンド実行で自動リセット、手動は `rm ~/.claude/state/verify-step.pending`。implementation-checklist は最終ゲートで中間検証の代替ではない。

## 標準ワークフロー（全文・0.5/1.5 含む）

0. **plan.md/task.md 確認** → plan.md → 該当 task.md の Session Handoff/Stuck Context
0.5. **新プロジェクト着手時のみ**: `/init-project`（環境基盤）+ `/methodology`（作業の型 = 0層+①〜⑥+メタ層を配置）→ 各ステップの「問い」に当 project のデータ・ツールで答える。概念=[[作業メソドロジー]] / 雛形=`templates/methodology-5step.md`
1. **スキル確認**（Plan 前必須）: `30-routing.md` → なければ `find-skills`
1.5. **曖昧点洗い出し**（3 ファイル以上）: エッジケース・エラー・統合ポイント列挙、不明点は `AskUserQuestion`
2. **Plan モード**: 必須セクション Goal/Architecture/Tasks/Verification/成功基準。アーキ判断は `plan-adversarial-review` 検討
3. **実装**: ExitPlanMode 後、規模に応じ SubAgent 活用
4. **セキュリティ監査**: 認証/認可・外部入力受付・秘密情報・新規外部 API 連携時のみ `security-twin-audit`
5. **完了チェック**: `implementation-checklist` STEP 1-4。動作証明まで完了マーク禁止
6. **Session Handoff 更新**: task.md 最新化。詳細: `task-progress` スキル

## Execution Strategy 補足

成功基準例: 「テスト全部通れば OK」「API レスポンスがこの形式なら OK」「ブラウザで○○表示なら OK」。Delivery は `opusplan` 推奨・Prototype は捨てる前提。

## 実装完了チェック（全文）

最終完了報告前に `implementation-checklist` 必ず実行:
- Write/Edit で実行コード (Python/JS/HTML/CSS) 変更しユーザー報告時
- 設定変更で挙動変わる変更 (.mcp.json, config.py 等) 完了報告時

**免除**: 中間報告 / 中間確認依頼 / ドキュメント・コメントのみ変更
「ブラウザで確認してください」は checklist 完了後限定。AI 側可能な検証 (curl 疎通・ログ確認・Playwright MCP) を先に全完了。
完了前自問: 「スタッフエンジニアはこれを承認するか？」

## 指示・修正の永続化（全文・2026-06-16 ユーザー要望）

ユーザーの指示・修正・好みを受けたら、**「今回だけ？ 今後も守る？」を毎回見極める**。**来週もこの指示を守ってほしいなら**、地の文で一度だけ確認（例:「これ今回だけ？ 今後も守るなら記憶に保存します」）→ **`/save` で既存の記憶へ振り分け保存**する。**新ファイル・新仕組み・新スクリプトは作らない**（reuse 徹底・clutter 厳禁）。振り分け:
- やり方の好み・「今後はこうして」 → **feedback memory** (`memory/feedback_*.md` + MEMORY.md 索引)
- 失敗・教訓・「繰り返すな」 → **`/save mistake`** (`wiki/meta/mistakes.md`・自動注入)
- 方針・「X に決めた」 → **`/save decision`** (`wiki/meta/decisions.md`・自動注入)
- プロジェクト固有の定石・閾値 → **`/save playbook`** (`02_Ai/<group>/<sub>-playbook.md`)
- 「今回だけ」 → **保存しない**。

## プロンプト運用（全文・2026-06-26 新モデル・詳細 [[decisions]]）

各 project は **`prompts/<project>_INBOX.md` 1 枚で完結**＝上「🔵 やってほしいこと」に投函→AI 処理→下「📒 記録」へ【全文＋いつ＋なぜ＋結果】で**移す（消さない・要約しない）**。**`spot/` 別ファイル・`spot/done/`・`_README` は作らない**（1 回きりプロンプトも記録に全文を残すだけ）。定期実行プロンプトのみ `prompts/scheduled/`＋launchd（不変）。連続実行は対話で順次。学習（今後も守る指示）は上記 `/save` 経路。**AIads 先行実装・他 project は順次移行**（旧 `spot/` を見ても再生産しない）。
