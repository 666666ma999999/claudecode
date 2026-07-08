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

---

## 司令塔（command-center）モデルケース：AIads-cp-review.md

live ノート: `02_Ai/AI_adscrm/reports/AIads-cp-review.md`（`type: progress`・固定名上書き・約 580 行）。上の launch-candidates-v2（候補棚卸しの分析 findings 系・123 行）とは**別物**——**cp-review 系＝毎日見る運用司令塔(full)** ／ **launch-candidates＝候補棚卸しの分析 findings**。

司令塔 skeleton（**vault** `templates/cockpit-report.md`（正本））の `{{スロット}}` に広告ドメインを当てはめた実例として読む（**数値は live ノートが正本・ここにコピーしない**＝コピーすると drift 防止に自己矛盾）。

## skeleton スロットへの広告ドメイン当てはめ（＝普遍層へ昇格させない要素）

- **{{単位}}** = CP（キャンペーン）。**{{主要指標}}** = 真ROAS（GA4 purchases 売上 ÷ cost）。管理画面 ROAS は約 3.1 倍（CP 別 1.45〜6.2 倍）に盛れるので headline に使わず盛り倍率を注記。
- **{{部品}}** = ①KW（検索語＝振り分け）②広告文（RSA・有効上限 3 本・ETA 編集不可）③掲載商品（着地＝LTV 源）④入札。**かぶせ NG は①KW のみ**（学習分散回避・②③は重複 OK）。PMax/DGen は KW を持たないので「なし」。
- **6 軸現状表** = cost / 真CV / CPC / 真CVR / KW構成 / 入札・着地。**真CPA = CPC ÷ 真CVR** で原因を分解。
- **{{判定軸}}の具体** = スマート入札の学習リセット制約（KW/広告/着地を一度に大入替すると 14〜30 日 CPA 1.5〜2 倍 → 1 本ずつ追加・勝ち CP は触らない）／ tROAS 段階緩和 ±20%/ステップ ／ 増分真ROAS（追加 1 円の追加売上で拡大可否・窓重複+売上ラグで下振れ注意）／ 掲載スコア = 初回獲得数 × cohort 生涯 LTV。

→ これらは「ルール」でなく **AIads 版の適用例**。CRM 等の新ドメイン司令塔では skeleton を再利用し、`model-case-<domain>.md` を別に足してそのドメインの当てはめを書く（**普遍 skeleton は不変**）。

## CP章skeleton の広告ドメイン当てはめ（2026-07-08 金標準恒久化・正本はこの節）

汎用skeleton（vault `templates/cockpit-report.md` §2）を広告運用に当てはめる時の対応表:

| skeletonスロット | 広告での実体 |
|---|---|
| 軸表 | 6軸: cost／真CV／CPC／真CVR／KW構成／入札・広告/着地（算出不能は `—（未算出）`） |
| 部品①〜④ | ①KW ②広告文(RSA・有効上限3本) ③掲載商品(着地) ④入札(tROAS ±20%/ステップ) |
| 盛り係数 | 管理画面CV÷GA4真CV・**CP別**（出会い3.1／連絡6.2／Max1.45／DGen2.6）・同窓で導出し使い回さない |
| なぜ最小の中身 | 学習リセット回避（一度に大きく変えると14-30日 CPA1.5-2倍）／交絡回避（着地ABの切り分け）／赤字のままスケールしない |
| 実行順の型 | KW停止を先行 → 1〜2週後に tROAS（同時打ちは before/after が濁る） |
| 全リスト表の3分割 | (1-A)止める（母数を壊さない小口）／(1-B)止めず④で締める（量の柱）／(2)除外（固有名詞のみ・自社CP有はNG） |
| ⛔禁止の定番 | 「無料」含む語の一括除外禁止（優良語を殺す）／自社CP有の固有名詞除外NG／勝ちCPは触らない |

金標準の実例 = AIads-cp-review「占いプラス-検索-出会い」節。機械検査 = `report_action_presence_gate.py --cp-sections`（存在検査）・因果の質 = 原因の品質6点（観測事実→除外した原因→残る仮説→次に確認するデータ→機序→撤退条件・隔週契約 §4）。
