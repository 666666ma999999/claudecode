---
name: vault-research-ledger
description: |
  vault 側 research/ ディレクトリの型と「1枚台帳（_summary.md）」の運用ルール。調査ノートの配置・命名・重複統合・repo との分担を定める。
  repo 側の隔離（worktree/使い捨てスクリプト/中間データ）は research-isolation が担当し、本 skill は vault 側だけを扱う兄弟 skill。
  トリガー語: research 台帳, 調査まとめ, 調査の1枚サマリー, research ディレクトリ運用, 調査ノート統合, 調査どこだっけ, research ledger,
  調査ログ整理, _summary.md, 調査ファイル増えすぎ, 研究ノート配置。
  NOT for: repo 側の探索隔離・使い捨てスクリプト管理（→ research-isolation）/ レポート・司令塔の設計（→ vault-report-writing）/
  確定知見の repo 台帳更新（→ finding-sync）/ wiki 知識化（→ wiki-ingest, /save）
---

# vault-research-ledger — 調査の1枚台帳と research/ の型

## When to use

- project の vault `research/` に調査ノートを置く・探す・統合するとき
- 「この project で何を調査したか」を1枚で把握したいとき
- 調査ファイルが増えて命名・現役/退役が判別できなくなったとき

## 役割分担（vault ↔ repo・Anti-drift）

| 置く場所 | 中身 |
|---|---|
| **vault `research/`** | 台帳 `_summary.md` 1 枚のみ（カテゴリ別詳細を内蔵・＋依頼受付 `_requests/` 任意） |
| **repo** | 生データ・スクリプト・中間生成物・プロンプト全文・実験ログ（隔離の型 = `research-isolation` skill、具体 = 各 project の `docs/research-workflow.md`） |

目安: **50KB を超える生表・ドリルダウンは repo 側**。vault はサマリーと知見だけ（正本: rules/41「vault=索引+サマリー / SSoT は repo」）。

## research/ の型（vault は台帳 1 枚・全文は repo）

```
vault research/                      repo <project>/reports/
├── _summary.md ← 台帳（唯一の入口・     ├── research-notes/    ← 現役ノート全文（台帳カテゴリ節の出典）
│     カテゴリ別詳細を内蔵）             ├── research-archive/raw/           ← ドリルダウン生表
└── _requests/  ← 依頼票の受付（任意）   ├── research-archive/archive/       ← 退役ノート（削除しない）
                                      └── research-archive/requests-done/ ← 完了済み依頼票
```

vault に置くのは**台帳 `_summary.md` 1 枚（＋依頼受付）だけ**。調査の詳細は台帳内の **📁 カテゴリ節**（LTV 調査／流入経路 等・各 10〜20 行の要点＋repo 全文住所）に集約し、ノート全文・生表・退役・完了票はすべて repo へ（2026-07-10 ユーザー裁定「細かい research は obsidian 側に置かない」）。vault に `_raw/`・`_archive/` や個別ノートを**残さない**。`_requests/` は依頼運用を採用した project のみ（自動作成しない）。

**opt-in**: research/ の新設は decisions 2026-05-27 の 4 条件＋ユーザー✅が必要（自動展開禁止）。リファレンス実装 = `02_Ai/AI_adscrm/AIcrm/research/`。

## 台帳 `_summary.md`（この skill の核）

- **固定名 `_summary.md`**・research/ 直下・雛形の正本 = vault `templates/research-summary.md`
- **書式は report ルール（`vault-report-writing`）を世襲**（Write/Edit 前に同 skill を起動）: 冒頭 `[!todo]` 🎯ゴール&やること → `[!success]` 確定知見 BLUF → 長表の前に読み方ガイド 1 行 → 詳細（_archive/_requests）は `[!abstract]-` 折りたたみ隔離 → callout 語彙固定（`[!tip]` 等の語彙外 callout 禁止）
- **リンクは path-qualified 必須**: 固定名は複数 project 展開で basename が重複するため、MOC 等からは `[[<path>/research/_summary|research 台帳]]` 形式でリンクする。bare `[[_summary]]` は曖昧リンク化するため禁止
- 構成: 冒頭に **✅確定知見サマリー**（BLUF・各行 =「（観測日付）気づき → `[[#カテゴリ見出し]]`」＝同一ファイル内ジャンプ）→ **📁 調査詳細（カテゴリ別）** → **🆕 新着 Bases 窓** → 🗂 repo 細部資料表・supersede 折りたたみ・_requests 表
- **カテゴリは 2 階層・`##` 直置き**（ユーザー指定フォーマット 2026-07-10・「📁 調査詳細」のような傘見出しを挟まない）: `##` カテゴリ = **意思決定の問い**（例: `## LTV調査`/`## 流入経路`。誰に売るか/次に何を売るか/どの客が儲かるか…・5〜9 個まで、超えたら統合）／ `###` サブ切り口 = **分析の軸**（例: `### 悩み別`/`### 購入日別`。共通語彙: 悩み別/時間窓別/チャネル別/顧客層別/商品別/時期別・結論が 5 行を超えるカテゴリだけ切る・**カテゴリと同名にしない**＝`[[#見出し]]` リンクの衝突防止）。新カテゴリは既存に収まらない調査が出たときに `##` を足し BLUF に知見行を足す
- **カテゴリ窓（ユーザー指定サマリーフォーマット・2026-07-10）**: 各 `##` カテゴリの末尾（📄 行の直前）に base 窓を置き、vault `reports/` のうち frontmatter `research_category: <カテゴリ名>` が一致する md を自動一覧する（窓の書式はユーザー指定形: inFolder＋research_category の 2 フィルタ・table・limit 8・mtime DESC。空＝新着なしが正常）。**新規の調査レポートを reports/ に置くときは `research_category` を必ず付ける**＝該当カテゴリ窓に自動掲載される
- **🆕 新着 Bases 窓**: 手動索引の腐敗対策として、project の `reports/` 新着 md を自動一覧する base ブロックを台帳に置く（正本形 = vault `templates/cockpit-report.md` の 🆕窓・パスは小文字の実パスをハードコード。`this.file.folder` は research/ から sibling の reports/ に届かない）。✅待ち施策だけの窓（type: proposal）は司令塔ボード側の管轄 — 台帳は調査視点の新着のみ
- **気づき行の合格基準（3 秒テスト）**: 読んで 3 秒で「何がわかった・何に効く（so-what）」が取れること。**「〜を実施/確立/分析した」という活動報告だけの行は禁止**（知見に言い換える）。内部記号・コード名（author 名・セグメント記号等）は callout 冒頭の用語行か初出で 1 語 gloss する（正本: vault-report-writing「初出用語 gloss」）
- **昇格ゲート（Collector's Fallacy 対策）**: 台帳に日付＋1行が載らない調査ファイルは作らない。「収集＝理解」ではない — 台帳に載らないものは存在しないものとして扱う
- **temporal documentation**: 知見・数値には必ず観測日付を付ける（日付付きの古い記述は「その時点の事実」として嘘にならない）
- rules/41 §④「分析サマリは MOC 内サブセクション」の**明示的例外**が本台帳（research/ 配下に限る）。MOC 側は入口（主要ノートの1行導線）、台帳は全量＋status＋知見と役割分担し、同じ知見の本文を両方に書かない

## 命名（開かずに内容がわかる）

- N-1 準拠: `<project>-{research|raw|archive}-<topic>.md`（正本: docs/file-placement-detail.md §N）
- `<topic>` は**内容が読める記述的 slug**（例: `hvs-acquisition-channel` ○ / `analysis-2` ×）
- **日付だけ・連番だけの命名禁止**（`2026-07-09.md` / `research-42.md`）。日付は台帳と frontmatter `last_updated` が持つ
- 新規ノートの frontmatter は rules/41 6 項目。**通常の research ノート**は type `analysis`（読むだけの調査）を推奨 — ただし project 側の窓（Bases 等）が既存 type に依存する場合は project 慣行を優先し、既存ノートの type を一括変更しない。**台帳 `_summary.md` は索引・台帳なので雛形どおり `type: concept`**（analysis に寄せない）

## 重複統合（dedup — ファイル増殖の禁止）

新しい調査を始める前に、必ずこの順で判定する:

1. **検索**: 台帳（と `research/` 直下）を見て類似テーマの既存ノートを探す
2. **あれば追記**: 台帳の該当カテゴリ節に日付付きで要点を追記し、repo `research-notes/` の該当ノート全文にも `## Updates` を追記（**新規ファイル作成は最後の手段**）
3. **結論を覆すとき**: 上書きしない。repo `research-notes/` に新ノートを作り、旧ノートに supersede 注記を書いて `research-archive/archive/` へ移す。台帳のカテゴリ節と supersede 対応表を更新
4. **本当に新規のときだけ**: repo `research-notes/` に N-1 命名で作成し、**同時に**台帳の BLUF＋カテゴリ節へ日付＋要点を追記（台帳に載らない調査ファイルは作らない）
5. セッション単位・調査日単位でファイルを切らない — テーマ単位で切り、2 回目以降は追記で育てる

## references（設計根拠・Web/X 実践）

- Simon Willison — TIL: <https://github.com/simonw/til>（記述的 slug・索引は自動生成）/ research repo: <https://github.com/simonw/research>（1調査=1置き場・正本はサマリー・詳細は PR/commit 側）
- Andy Matuschak — concept-oriented notes: <https://notes.andymatuschak.org/Evergreen_notes_should_be_concept-oriented>（検索→既存にマージ→なければ新規）
- ADR: <https://adr.github.io/>（supersede リンクで増殖制御・確定記録は上書きしない）
- Steph Ango (kepano) — file over app: <https://stephango.com/file-over-app>（frontmatter で台帳列・蒸留フロー）
- Jerry Liu (X): <https://x.com/jerryjliu0/status/2039834316013031909>（調査出力を MD に固定し次セッションの context 入口に）
- アンチパターン: Collector's Fallacy（台帳ゲートなしの収集は墓場化）/ 日付なし追記 / セッション単位のファイル分割 / 詳細とサマリの同居 / 手動索引の放置腐敗

## 境界（既存 skill との分担）

- `research-isolation` = repo 側（worktree 隔離・再生成データ・使い捨てプレフィックス・昇格）。**本 skill は vault 側**。同じ Why を両方に書かない
- `vault-report-writing` = レポート・司令塔の設計。台帳の書式原則（BLUF・ゴール先頭）はそちらの原則を継承
- `finding-sync` = repo 側の確定知見台帳（prime_crm）。vault 台帳と二重記載しない
