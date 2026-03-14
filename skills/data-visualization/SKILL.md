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
# X投稿用画像設定
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

ダークテーマ設定詳細:

- 背景: #1a1a2e（深い紺色 — X のダークモードと調和）
- テキスト: #FFFFFF（白）
- グリッド: #2d2d44（薄い紺色、控えめ）
- アクセント: #00d4aa（シアン系、視認性高い）
- 警告色: #ff6b6b（赤）、成功色: #51cf66（緑）

---

## 7. Docker環境セットアップ

```bash
# matplotlib + 日本語フォント環境
docker run --rm -v $(pwd):/work -w /work python:3.11-slim bash -c "
  pip install numpy matplotlib &&
  apt-get update && apt-get install -y fonts-noto-cjk &&
  python your_script.py
"
```

Dockerfile追記例:

```dockerfile
RUN pip install numpy matplotlib
RUN apt-get update && apt-get install -y fonts-noto-cjk && rm -rf /var/lib/apt/lists/*
```

matplotlibrc設定:

```python
import matplotlib
matplotlib.rcParams['font.family'] = 'Noto Sans CJK JP'
matplotlib.rcParams['axes.unicode_minus'] = False
```

---

## 8. チャート別コードテンプレート

### ヒートマップ

```python
import matplotlib.pyplot as plt
import numpy as np

def render_heatmap(spec, data, labels_x, labels_y, output_path):
    """ヒートマップ描画"""
    fig, ax = plt.subplots(figsize=spec.figsize)
    fig.patch.set_facecolor('#1a1a2e')
    ax.set_facecolor('#1a1a2e')

    im = ax.imshow(data, cmap=spec.color.cmap_name, aspect='auto',
                   vmin=spec.color.vmin, vmax=spec.color.vmax)

    ax.set_xticks(range(len(labels_x)))
    ax.set_xticklabels(labels_x, rotation=spec.labels.rotation,
                        color='white', fontsize=spec.labels.font_size)
    ax.set_yticks(range(len(labels_y)))
    ax.set_yticklabels(labels_y, color='white', fontsize=spec.labels.font_size)

    # セル値表示
    if spec.labels.show_values:
        for i in range(len(labels_y)):
            for j in range(len(labels_x)):
                val = data[i][j]
                color = 'white' if abs(val) > (spec.color.vmax - spec.color.vmin) * 0.6 else 'black'
                ax.text(j, i, f'{val:{spec.labels.format_str}}',
                       ha='center', va='center', color=color, fontsize=8)

    cbar = plt.colorbar(im, ax=ax)
    cbar.ax.yaxis.set_tick_params(color='white')
    plt.setp(cbar.ax.yaxis.get_ticklabels(), color='white')

    ax.set_title(spec.title, color='white', fontsize=18, pad=20)
    if spec.subtitle:
        ax.text(0.5, 1.02, spec.subtitle, transform=ax.transAxes,
               ha='center', color='#888888', fontsize=11)

    plt.tight_layout()
    plt.savefig(output_path, dpi=150, facecolor='#1a1a2e', bbox_inches='tight')
    plt.close()
```

### 棒グラフ（正負色分け対応）

```python
def render_bar(spec, values, labels, output_path):
    """棒グラフ描画（正負色分け対応）"""
    fig, ax = plt.subplots(figsize=spec.figsize)
    fig.patch.set_facecolor('#1a1a2e')
    ax.set_facecolor('#1a1a2e')

    colors = ['#51cf66' if v >= 0 else '#ff6b6b' for v in values]
    bars = ax.bar(range(len(values)), values, color=colors, edgecolor='none', width=0.7)

    ax.set_xticks(range(len(labels)))
    ax.set_xticklabels(labels, rotation=spec.labels.rotation,
                        color='white', fontsize=spec.labels.font_size)
    ax.tick_params(axis='y', colors='white')
    ax.spines['bottom'].set_color('#2d2d44')
    ax.spines['left'].set_color('#2d2d44')
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    ax.grid(axis='y', color='#2d2d44', alpha=0.5)

    # 値ラベル
    if spec.labels.show_values:
        for bar, val in zip(bars, values):
            y_pos = bar.get_height() + (max(values) - min(values)) * 0.02
            ax.text(bar.get_x() + bar.get_width()/2, y_pos,
                   f'{val:{spec.labels.format_str}}',
                   ha='center', va='bottom', color='white', fontsize=9)

    # アノテーション
    for ann in spec.annotations:
        ax.annotate(ann.text, xy=(ann.x, ann.y),
                   xytext=(ann.x, ann.y + (max(values)-min(values))*0.1),
                   arrowprops=dict(arrowstyle='->', color=ann.color),
                   color=ann.color, fontsize=ann.fontsize, ha='center')

    ax.set_title(spec.title, color='white', fontsize=18, pad=20)
    plt.tight_layout()
    plt.savefig(output_path, dpi=150, facecolor='#1a1a2e', bbox_inches='tight')
    plt.close()
```

### 折れ線グラフ（トレンドライン・エリア塗りつぶし対応）

```python
def render_line(spec, values, time_labels, output_path, fill_area=False, trend_config=None):
    """折れ線グラフ描画"""
    fig, ax = plt.subplots(figsize=spec.figsize)
    fig.patch.set_facecolor('#1a1a2e')
    ax.set_facecolor('#1a1a2e')

    x = range(len(values))
    ax.plot(x, values, color='#00d4aa', linewidth=2, marker='o', markersize=4)

    if fill_area:
        ax.fill_between(x, values, alpha=0.15, color='#00d4aa')

    # トレンドライン
    if trend_config and trend_config.get('add_trendline'):
        if trend_config['trendline_type'] == 'moving_avg':
            window = trend_config['window']
            ma = np.convolve(values, np.ones(window)/window, mode='valid')
            ma_x = range(window-1, len(values))
            ax.plot(ma_x, ma, color='#ffd43b', linewidth=1.5,
                   linestyle='--', alpha=0.7, label=f'{window}期移動平均')
            ax.legend(facecolor='#1a1a2e', edgecolor='#2d2d44',
                     labelcolor='white', fontsize=9)

    ax.set_xticks(x)
    ax.set_xticklabels(time_labels, rotation=spec.labels.rotation,
                        color='white', fontsize=spec.labels.font_size)
    ax.tick_params(axis='y', colors='white')
    ax.spines['bottom'].set_color('#2d2d44')
    ax.spines['left'].set_color('#2d2d44')
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    ax.grid(color='#2d2d44', alpha=0.5)

    ax.set_title(spec.title, color='white', fontsize=18, pad=20)
    plt.tight_layout()
    plt.savefig(output_path, dpi=150, facecolor='#1a1a2e', bbox_inches='tight')
    plt.close()
```

### ドーナツチャート

```python
def render_donut(spec, values, labels, output_path):
    """ドーナツチャート描画"""
    fig, ax = plt.subplots(figsize=spec.figsize)
    fig.patch.set_facecolor('#1a1a2e')

    colors = plt.cm.get_cmap('Set2')(np.linspace(0, 1, len(values)))
    wedges, texts, autotexts = ax.pie(
        values, labels=labels, autopct='%1.1f%%',
        colors=colors, pctdistance=0.75,
        wedgeprops=dict(width=0.4, edgecolor='#1a1a2e', linewidth=2)
    )
    for text in texts:
        text.set_color('white')
        text.set_fontsize(10)
    for autotext in autotexts:
        autotext.set_color('white')
        autotext.set_fontsize(9)

    # 中央テキスト
    total = sum(values)
    ax.text(0, 0, f'合計\n{total:,.0f}', ha='center', va='center',
           fontsize=16, color='white', fontweight='bold')

    ax.set_title(spec.title, color='white', fontsize=18, pad=20)
    plt.savefig(output_path, dpi=150, facecolor='#1a1a2e', bbox_inches='tight')
    plt.close()
```

### 散布図（トレンドライン対応）

```python
def render_scatter(spec, x_values, y_values, labels, output_path, trend_config=None):
    """散布図描画"""
    fig, ax = plt.subplots(figsize=spec.figsize)
    fig.patch.set_facecolor('#1a1a2e')
    ax.set_facecolor('#1a1a2e')

    ax.scatter(x_values, y_values, c='#00d4aa', s=60, alpha=0.8, edgecolors='white', linewidths=0.5)

    # トレンドライン
    if trend_config and trend_config.get('add_trendline'):
        z = np.polyfit(x_values, y_values, 1)
        p = np.poly1d(z)
        x_line = np.linspace(min(x_values), max(x_values), 100)
        ax.plot(x_line, p(x_line), color='#ffd43b', linewidth=1.5,
               linestyle='--', alpha=0.7, label=f'R²={np.corrcoef(x_values, y_values)[0,1]**2:.3f}')
        ax.legend(facecolor='#1a1a2e', edgecolor='#2d2d44', labelcolor='white')

    ax.tick_params(axis='both', colors='white')
    ax.spines['bottom'].set_color('#2d2d44')
    ax.spines['left'].set_color('#2d2d44')
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    ax.grid(color='#2d2d44', alpha=0.3)

    ax.set_xlabel(spec.x_axis.label, color='white', fontsize=12)
    ax.set_ylabel(spec.y_axis.label, color='white', fontsize=12)
    ax.set_title(spec.title, color='white', fontsize=18, pad=20)
    plt.tight_layout()
    plt.savefig(output_path, dpi=150, facecolor='#1a1a2e', bbox_inches='tight')
    plt.close()
```

### ウォーターフォールチャート

```python
def render_waterfall(spec, values, labels, output_path):
    """ウォーターフォールチャート描画"""
    fig, ax = plt.subplots(figsize=spec.figsize)
    fig.patch.set_facecolor('#1a1a2e')
    ax.set_facecolor('#1a1a2e')

    cumulative = np.cumsum(values)
    starts = np.concatenate([[0], cumulative[:-1]])

    colors = ['#51cf66' if v >= 0 else '#ff6b6b' for v in values]
    # 最後のバーは合計として特別色
    colors[-1] = '#00d4aa'

    for i, (start, val) in enumerate(zip(starts, values)):
        bottom = start if val >= 0 else start + val
        height = abs(val)
        ax.bar(i, height, bottom=bottom, color=colors[i], edgecolor='none', width=0.6)

        # 値ラベル
        label_y = start + val + (max(cumulative) - min(cumulative)) * 0.02
        ax.text(i, label_y, f'{val:+{spec.labels.format_str}}',
               ha='center', va='bottom', color='white', fontsize=9)

    # コネクタライン
    for i in range(len(values) - 1):
        ax.plot([i + 0.3, i + 0.7], [cumulative[i], cumulative[i]],
               color='#2d2d44', linewidth=1, linestyle='-')

    ax.set_xticks(range(len(labels)))
    ax.set_xticklabels(labels, rotation=spec.labels.rotation, color='white')
    ax.tick_params(axis='y', colors='white')
    ax.spines['bottom'].set_color('#2d2d44')
    ax.spines['left'].set_color('#2d2d44')
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    ax.grid(axis='y', color='#2d2d44', alpha=0.5)

    ax.set_title(spec.title, color='white', fontsize=18, pad=20)
    plt.tight_layout()
    plt.savefig(output_path, dpi=150, facecolor='#1a1a2e', bbox_inches='tight')
    plt.close()
```

---

## 9. スクリプト使用方法

```python
# DataVizPipeline → ChartSpec → matplotlib適用例
from data_viz_optimizer import DataVizPipeline, DataShape

pipeline = DataVizPipeline()

# BTC月間乖離率の例
data = {
    "values": [5.2, -3.1, 8.7, -1.5, 12.3, -6.8, 3.4, -2.1, 15.3, -4.2, 7.6, -0.8],
    "labels": ["1月", "2月", "3月", "4月", "5月", "6月",
               "7月", "8月", "9月", "10月", "11月", "12月"],
    "time_index": ["2024-01", "2024-02", "2024-03", "2024-04", "2024-05", "2024-06",
                   "2024-07", "2024-08", "2024-09", "2024-10", "2024-11", "2024-12"],
}

context = {
    "metric_name": "BTC月間乖離率",
    "period": "2024年1月〜12月",
    "unit": "%",
}

spec = pipeline.run(data, data_shape=DataShape.TIME_SERIES, data_context=context)

# ChartSpecの内容を確認
print(f"チャート型: {spec.chart_type}")
print(f"タイトル: {spec.title}")
print(f"カラーマップ: {spec.color.cmap_name}")
print(f"スケール: {spec.x_axis.scale}")

# matplotlibで描画（上記テンプレートを使用）
# render_bar(spec, data["values"], data["labels"], "output/btc_divergence.png")
```

CLI使用方法:

```bash
# JSON入力 → ChartSpec JSON出力
echo '{"values": [1,2,3], "labels": ["A","B","C"]}' | python scripts/data_viz_optimizer.py

# ファイル入力
python scripts/data_viz_optimizer.py input.json

# コンテキスト付き
python scripts/data_viz_optimizer.py input.json --context '{"metric_name": "売上", "unit": "万円"}'
```

---

## 10. チェックリスト

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

## 11. 関連スキル連携

| スキル | 連携内容 |
|--------|---------|
| `sales-analysis` | 売上分析結果の可視化。Phase 7の最終スコアをヒートマップ・棒グラフで表示 |
| `be-extension-pattern` | グラフ生成APIをエクステンションとして実装する場合のパターン |

`sales-analysis` スキルで分析した結果を可視化する場合:

1. `sales-analysis` で Phase 1-7 を実行し、結果CSVを取得
2. `data-visualization` で結果CSVを読み込み、ChartSpec を生成
3. matplotlib でグラフ描画・保存
