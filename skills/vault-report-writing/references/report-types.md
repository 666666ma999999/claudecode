# レポート種別 → 表現マッピング + コピペテンプレ

「読み手と目的」で種別を選び、冒頭ブロック・本文構造・図・索引・折りたたみ方針を決める。

## Decision Table

| 種別 | 主読者 | 先頭に置く | 使う Obsidian 表現 | 向いた見せ方 |
|---|---|---|---|---|
| **経営層サマリ / 1-pager** | 意思決定者 | 結論・数字3つ・次アクション | `[!success]` BLUF + 1枚表 + `[!abstract]-` foldable | 1-pager |
| **技術詳細 / 仕様** | 実装者 | 前提・再現手順・差分 | H2/H3・code block・脚注・section link | deep dive |
| **分析レポート / findings** | 分析者・事業責任者 | 仮説・比較表・解釈 | 意味別 callout・表(Tufte)・Mermaid ツリー | evidence-first |
| **進捗 / MOC / ダッシュボード** | PM・チーム | 今の変化・blocker・次 | frontmatter + Dataview/Bases・embed・折りたたみ | status / dashboard |
| **インシデント / ポストモーテム** | 運用・監査 | 事実→影響→暫定対応 | `[!danger]`・timeline・decision log | incident writeup |
| **セキュリティ / リスク監査** | 決裁者+実装者 | 深刻度サマリ | 深刻度マトリクス・`[!bug]` finding・付録 foldable | findings-first |

### 補助ルール（順序）
- 数字で判断する文書: **結論 callout → 比較表 → 補足**
- 監査/障害: **事実 → 影響 → 判断 → 未確定事項**
- 詳細が長い: 本文に埋めず **別ノート embed か section link** に逃がす
- 1 ファイルに種別を混ぜない（Diátaxis: how-to / reference / explanation / tutorial）

---

## データの型 → 推奨図 マッピング（更新対象・vault cheatsheet [[レポート種別チートシート]] と同期）

> セクションが何を報告しているかを「データの型」で判定 → 下表で図を選ぶ。新しい型が出たら 1 行追記。

| データの型 | 推奨図 | Mermaid / 記法 | 使う場面・例 |
|---|---|---|---|
| 構成比（全体の内訳） | 円グラフ | `pie` | 〜のうち○%・チャネル内訳・予算配分 |
| ランキング比較（項目間の大小） | 表 + █ バー | Markdown 表 + コードブロック内 █ 文字 | 商品別 平均金額・CP別 CV |
| 量の比較（現状↔目標・前後・A/B） | 2 列表 / 表 + █ バー | Markdown 表（before/after 列） | 現状CV vs 目標CV・before/after |
| 時系列の伸び（推移・トレンド） | 表 + █ バー | Markdown 表 + コードブロック内 █ 文字 | 会員数の伸び・段階別CV/予算推移 |
| 手順・分岐・連鎖（プロセス） | フローチャート | `flowchart TD`（縦長既定）/ `LR` は明示指定時のみ | ロードマップ・判定フロー・attack narrative |
| 期間・工程（スケジュール） | ガント / タイムライン | `gantt` / `timeline` | Phase 表・障害タイムライン |
| 状態の一覧（増減・常に最新） | 動的表 | `dataview` / `base` | 候補の検証状態・施策進捗索引 |
| 進捗状態（done/todo/doing） | callout / カンバン | `[!success]`/`[!todo]` / kanban | やり残し・ワークフロー |
| 関係の俯瞰（自由配置・概念） | キャンバス / 手描き | `.canvas` / `![[x.excalidraw]]` | アーキ図・概念マップ・KPIツリー |
| 深刻度・優先度（2軸評価） | マトリクス表 + 色 | 表 + 🔴🟠🟡🟢 | finding 深刻度(可能性×影響) |
| 前提・結論・注意（テキスト強調） | callout | `[!info]`/`[!warning]`/`[!success]` | 前提・要訂正・BLUF結論 |

> [!warning] Mermaid の落とし穴
> ラベル付きエッジの連結 `A -->|x| B -->|y| C` はパースエラーで非表示 → エッジは 1 本ずつ改行する。**`xychart-beta` は Obsidian で棒が描画されない**（タイトル・軸目盛は出るが棒が空白）ため使用禁止。棒・量の比較は表 + コードブロックの █ バーで代替する（例: `` `███████▋········` 32% ``）。`flowchart`/`pie`/`gantt`/`timeline` は正式機能なので可。

## テンプレ（コピペ可）

### 経営層サマリ / 1-pager

```markdown
> [!success] 結論
> **誰に**: <執行層> / **何が**: <1 行結論> / **影響**: <KPI 3 つ> / **次**: <1 アクション>

## 主要数字
| 指標 | 現状 | 目標 | 推移 |
| :-- | --: | --: | :-- |

## なぜ（3 柱）
- 柱1 …
- 柱2 …
- 柱3 …

> [!abstract]- 根拠・詳細（開く）
> <統計・前提・脱落理由。技術詳細へは [[#技術詳細]] リンク>
```

### 分析レポート / findings

```markdown
> [!success] 結論（BLUF）
> <答え 1-2 行 + 取るべき判断>

## 背景（SCQA）
状況 → 複雑化 → 問い → 答え。

## 発見
> [!success] 確定: …
> [!warning] 留保（データ不足）: …
> [!question] 未解決: …

## 比較（Tufte 表・右揃え・グレー基調・1 色強調）
| 項目 | before | after | 差分 |
| :-- | --: | --: | :-- |

> [!abstract]- 統計根拠（SQL / cohort 定義）
> …
```

### インシデント / ポストモーテム（blameless 9 節）

```markdown
> [!important] BLUF
> 何が起きたか / 影響 / 暫定対応 を 3 行。

## 1. Summary  ## 2. Impact  ## 3. Root Cause  ## 4. Trigger
## 5. Detection  ## 6. Resolution  ## 7. Action Items
- [ ] <owner> 〆<期日> …
## 8. Lessons
> [!success] うまくいった: …
> [!warning] まずかった: …
> [!info] 運が良かった: …
## 9. Timeline
| 時刻 | 事象 |
```
> 人を役割で書き**仕組みに帰す**（個人を責めない）。

### finding（セキュリティ / レビュー）

```markdown
> [!bug] F-01: <種別> in <箇所> → <影響>
> **深刻度**: 🔴Critical（可能性 高 × 影響 大）
>
> **影響**: …
> **再現**: 1. … 2. …（URL/パラメータ/ロール明示）
> **推奨**: <patch X を where から>

## 深刻度サマリ
| ID | finding | 可能性 | 影響 | 深刻度 |
| :-- | :-- | :-: | :-: | :-: |

> [!example]- 付録: raw ツール出力
> …
```

### 進捗 / MOC / ダッシュボード（drift なし）

```markdown
---
project: <p>
type: dashboard
status: active
last_updated: 2026-05-30
---

> [!tip] 今週の変化
> …（blocker / 次週）

## 索引（動的・手書きしない）
​```dataview
TABLE status, last_updated FROM #report
WHERE status != "done"
SORT last_updated DESC
​```

## 各セクション（embed で集約・実体コピー禁止）
![[施策A#結論]]
![[施策B#結論]]
```
