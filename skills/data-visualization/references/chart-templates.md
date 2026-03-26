# チャート別コードテンプレート

> 親ファイル: `SKILL.md` — Layer 1/2/3 判定テーブル・チェックリストはそちらを参照

## ヒートマップ

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

## 棒グラフ（正負色分け対応）

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

## 折れ線グラフ（トレンドライン・エリア塗りつぶし対応）

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

## ドーナツチャート

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

## 散布図（トレンドライン対応）

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

## ウォーターフォールチャート

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

## スクリプト使用方法

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
