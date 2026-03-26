---
name: data-visualization
description: |
  データ可視化スキル。データの統計特性を自動分析し、最適なチャート型・スケール・色・ラベルを選択。
  金融データ（BTC乖離率、騰落率等）に特化した決定木を持ち、X(Twitter)投稿用の
  インパクト最大化（タイトル・アノテーション・色強度）を自動適用する。
  3レイヤーパイプライン: 統計分析 → チャート型選択 → インパクト最適化。
allowed-tools: "Bash(python:*) Read Write Edit Glob Grep"
compatibility: "requires: Python 3.x, numpy, matplotlib"
license: proprietary
metadata:
  author: masaaki-nagasawa
  version: 1.0.0
  category: data-processing
  tags: [visualization, chart, graph, financial, twitter, impact]
---

# データ可視化スキル

## Read This First

このファイルには判定テーブル・決定木・チェックリストを記載。
描画コードが必要なときのみ references/ を参照。

- チャート別描画コード・使用例 → `references/chart-templates.md`

## 1. 概要

3レイヤーパイプラインでデータの統計特性を分析し、最適なグラフ仕様(ChartSpec)を自動生成する。

```
[入力データ] → Layer 1: 統計分析・自動最適化
             → Layer 2: KPI検出・チャート型選択
             → Layer 3: インパクト最適化
             → [ChartSpec] → matplotlib描画
```

DataVizPipeline がデータの統計特性を分析し、最適なグラフ仕様(ChartSpec)を自動生成するスキル。生成されたChartSpecをmatplotlibに適用してグラフ画像を出力する。

---

## 2. 発動条件

以下のいずれかに該当する場合にこのスキルを使用する:

- グラフ・チャート・可視化の作成依頼
- データからの画像生成
- X(Twitter)投稿用グラフ作成
- ヒートマップ・棒グラフ・折れ線グラフ等の具体的チャート型指定
- 「インプレッション最大化」「見栄えの良いグラフ」等の要求

---

## 3. Layer 1: 統計分析・自動最適化

### スケール判定表

| 条件 | ScaleType | 用途 |
|------|-----------|------|
| CV > 3.0 かつ min > 0 | LOG | 桁違いの値が混在 |
| 負値あり かつ 歪度 < 1.0 | DIVERGING | ゼロ中心の正負分布 |
| CV > 2.0 かつ 負値あり | SYMLOG | 負値含む広範囲 |
| その他 | LINEAR | 標準 |

### カラーマップ選択表

| 条件 | カラーマップ | 用途 |
|------|------------|------|
| DIVERGING スケール | RdBu_r | 正負の対比（中心=白） |
| ヒートマップ | YlOrRd | 強度の段階表示 |
| 負値比率 > 40% | RdYlGn | 良い/悪いの直感的表現 |
| 金融 bullish | カスタム緑基調 | 上昇トレンド強調 |
| 金融 bearish | カスタム赤基調 | 下落トレンド強調 |
| デフォルト | viridis | 色覚多様性対応 |

### 外れ値処理

| 外れ値比率 | 戦略 | 処理 |
|-----------|------|------|
| > 10% | log変換 | スケール変更で対応 |
| 2-10% | クリッピング | Q1-1.5*IQR 〜 Q3+1.5*IQR |
| < 2% | なし | そのまま表示 |

### ラベル密度表

| データ数 | 表示 | rotation | font_size |
|---------|------|----------|-----------|
| < 10 | 全表示 | 0 | 11 |
| 10-20 | 全表示 | 45 | 10 |
| 20-50 | 1つおき | 45 | 9 |
| 50+ | 5つおき | 90 | 8 |

---

## 4. Layer 2: チャート型選択

### 金融データ決定木

```
is_financial?
├── TIME_SERIES → LINE（単一系列はエリア塗りつぶし付き）
├── MATRIX → HEATMAP（月×年 等のクロス集計）
├── is_percentage + has_negative → HORIZONTAL_BAR（乖離率の正負表示）
│   └── is_growth_rate → WATERFALL（変化の積み上げ）
└── CATEGORICAL + is_growth_rate → BAR（前年比等の比較）
```

### 汎用データ決定木

```
data_shape?
├── PART_OF_WHOLE
│   ├── categories ≤ 7 → DONUT
│   └── categories > 7 → TREEMAP
├── CATEGORICAL
│   ├── categories ≤ 15 → BAR
│   └── categories > 15 → HORIZONTAL_BAR
├── TIME_SERIES
│   ├── 1 series → LINE
│   ├── 2-5 series → LINE（マルチ）
│   └── 6+ series → HEATMAP
├── MATRIX → HEATMAP
├── 2 numeric series → SCATTER
└── デフォルト → BAR
```

### KPI → チャート型マッピング表

| KPI種別 | 主なチャート型 | 条件 |
|---------|--------------|------|
| 価格推移 | LINE / AREA | 時系列データ |
| 乖離率 | HORIZONTAL_BAR | 正負の比較 |
| 騰落率 | WATERFALL | 累積変化 |
| 構成比 | DONUT / TREEMAP | カテゴリ数による |
| 相関 | SCATTER | 2変数 |
| クロス集計 | HEATMAP | マトリクス型 |

---

## 5. Layer 3: インパクト最適化（X投稿向け）

### インパクト検出

- 極値検出: |直近値 - 平均| > 2σ → 「急騰」「急落」フラグ
- トレンド検出: N期連続上昇/下降 → 「連続上昇」フラグ
- トーキングポイント自動生成: 最大値、最小値、前期比、平均との乖離

### タイトル自動生成ルール

| 状況 | タイトルパターン | 例 |
|------|----------------|-----|
| 急騰検出 | 🔥 {metric}が{value}に急騰 | 🔥 BTC月間乖離率が+15.3%に急騰 |
| 急落検出 | ⚠️ {metric}が{value}に急落 | ⚠️ 日経平均騰落率が-8.2%に急落 |
| 連続トレンド | 📈 {metric} {N}ヶ月連続上昇 | 📈 S&P500 6ヶ月連続上昇 |
| 通常 | {metric}の推移（{period}） | BTC月間乖離率の推移（2024年） |

サブタイトル: 「平均: X | 最大: Y | 直近: Z」形式

### アノテーション配置

- 必須: 最大値、最小値、直近値（時系列の場合）
- 外れ値が3個以下ならアノテーション追加
- 重なり回避: シンプルなオフセットアルゴリズム

### 色強度調整

- 極値検出時: intensity 1.0 → 1.3
- 金融bearish: 赤を強調
- 金融bullish: 緑を強調

---

## 6. X投稿仕様

```python
X_POST_CONFIG = {
    "figsize": (12, 7),           # 1200x700px目標（X推奨1200x675）
    "dpi": 150,                    # 高解像度
    "dark_theme": True,            # ダーク背景（#1a1a2e）
    "bg_color": "#1a1a2e",         # 背景色
    "text_color": "#FFFFFF",       # テキスト色
    "grid_color": "#2d2d44",       # グリッド色
    "font_family": "Noto Sans CJK JP",  # 日本語フォント
    "title_fontsize": 18,          # タイトルサイズ
    "subtitle_fontsize": 12,       # サブタイトルサイズ
    "format": "png",               # PNG形式
    "transparent": False,          # 不透明背景
    "tight_layout": True,          # 余白最適化
    "watermark": "@your_handle",   # ウォーターマーク（任意）
}
```

ダークテーマカラー: 背景 #1a1a2e / テキスト #FFFFFF / グリッド #2d2d44 / アクセント #00d4aa / 警告 #ff6b6b / 成功 #51cf66

---

## 7. Docker環境セットアップ

```bash
docker run --rm -v $(pwd):/work -w /work python:3.11-slim bash -c "
  pip install numpy matplotlib &&
  apt-get update && apt-get install -y fonts-noto-cjk &&
  python your_script.py
"
```

```python
import matplotlib
matplotlib.rcParams['font.family'] = 'Noto Sans CJK JP'
matplotlib.rcParams['axes.unicode_minus'] = False
```

---

## 8. チェックリスト

実装完了時に確認:

- [ ] Layer 1: StatisticalProfile の全フィールドが計算されているか
- [ ] Layer 1: スケール判定が判定表どおりか（CV > 3.0 → LOG 等）
- [ ] Layer 1: カラーマップが条件に応じて正しく選択されるか
- [ ] Layer 1: 外れ値処理が適用されているか
- [ ] Layer 2: 金融キーワード検出が機能するか
- [ ] Layer 2: チャート型が決定木どおりに選択されるか
- [ ] Layer 3: タイトルにインパクト表現が含まれるか（極値時）
- [ ] Layer 3: アノテーションが最大値・最小値に配置されるか
- [ ] X仕様: figsize (12,7), dpi 150, ダークテーマ適用
- [ ] X仕様: 日本語フォント設定済み
- [ ] ダークテーマ: 背景 #1a1a2e, テキスト白, グリッド控えめ
- [ ] エッジケース: 空データ、1点のみ、全ゼロ、全同値で落ちないか
- [ ] Docker: numpy + matplotlib + fonts-noto-cjk がインストール済み

---

## 9. 関連スキル連携

| スキル | 連携内容 |
|--------|---------|
| `sales-analysis` | 売上分析結果の可視化。Phase 7の最終スコアをヒートマップ・棒グラフで表示 |
| `be-extension-pattern` | グラフ生成APIをエクステンションとして実装する場合のパターン |

`sales-analysis` スキルで分析した結果を可視化する場合:

1. `sales-analysis` で Phase 1-7 を実行し、結果CSVを取得
2. `data-visualization` で結果CSVを読み込み、ChartSpec を生成
3. matplotlib でグラフ描画・保存
