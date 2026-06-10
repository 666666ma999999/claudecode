# 実例: 広告候補レポート v2 の構造分解 + 4 スタイル実験

モデルケース: `02_Ai/AI_adscrm/AIads-launch-candidates-v2-2026-05-28.md`（占いサブスク広告候補・約 123 行）。
同じ分析が「読み手」で別物の資料になることを示す実験台。

## 元ノートの構造分解（どこが強く・どこが重いか）

| 区画 | 評価 | コメント |
|---|---|---|
| 冒頭メタ（前版/全文/手順/教訓） | ✅ → `[!info]` 化で改善 | 4 行の bold 羅列だったが callout で 1 箱に集約 |
| 「なぜ作り直したか」+ 32% 表 | ✅ 強い | BLUF 的・`[!warning]` + ==highlight== が効く核 |
| 段階1 の 6-CP 表 | 🔴 **致命的**（修正済） | **ヘッダー行欠落で列の意味不明** → 9 列ヘッダー復活が最大改善 |
| CP 別 5/4/6 商品表 | ◎ | データは良い・補足を `[!note]` 化で本文をスキャン可能に |
| 段階2/3 + 鶏卵 | ◎ | `[!question]` で前提を分離 |
| 見込み表 + ¥4,500 ライン | ✅ | `[!danger]` で赤字ラインを強調 |
| やり残し | ✅ | `[!success]`(済) / `[!todo]`(残) に二分 |

→ **学び**: 「綺麗にする」前に**壊れた表（ヘッダー欠落）を直す**のが最大の可読性改善。装飾より構造。

## 4 スタイル実験（別ファイル比較）

配置: `02_Ai/AI_adscrm/_report-experiments/`（experiment 隔離・採用版は元 v2 のまま）。

| スタイル | best_for | 核テクニック |
|---|---|---|
| **executive** (BLUF 1-pager) | 週次 Gate・執行層が 30 秒で判断 | 結論 callout / 二層化 foldable / Tufte 1 色 / embed |
| **analyst** (Dataview ダッシュボード) | 候補が増減し続ける運用・常に最新 | frontmatter / Dataview・Bases 動的索引 / DataCards / Mermaid 判定フロー |
| **hacker-finding** (深刻度マトリクス) | v1 の欠陥を漏れなく優先順位付きで棚卸し | finding 固定テンプレ / 深刻度マトリクス / 強いタイトル / 付録 foldable |
| **postmortem** (blameless) | 教訓を仕組みに（mistakes.md 連携） | 9 節構造 / Lessons 3 callout / attack narrative Mermaid / Action Items |

## 比較観点（「綺麗」でなく伝達効率で評価）

1. **30 秒で要点が拾えるか**（executive が最強）
2. **根拠へ潜れるか**（analyst / hacker-finding）
3. **callout 過多でうるさくないか**（memo 系が軽い）
4. **更新で壊れにくいか**（analyst の動的索引が最強）

→ 結論: **単一の「正解レイアウト」はない。読み手 × 目的で選ぶ**。だから skill は decision_table を持つ。
