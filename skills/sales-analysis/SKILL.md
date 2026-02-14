---
name: sales-analysis
description: |
  売上データの多変数分析スキル。カテゴリ・担当者・商品属性など複数変数が絡む売上データを分析し、各変数の影響度を正確に測定する。
  使用タイミング:
  (1) 売上に影響する要因を特定したい
  (2) 複数変数の影響度を比較したい
  (3) 交絡因子を除去してフェアな評価をしたい
  (4) 商品力・担当者力・カテゴリ効果を分離したい
  キーワード: 売上分析、重回帰、特徴量重要度、交絡因子、係数算出
allowed-tools: "Bash(python:*) Read Write Edit Glob Grep"
compatibility: "requires: Python 3.x (pandas, scikit-learn)"
license: proprietary
metadata:
  author: masaaki-nagasawa
  version: 1.0.0
---

# 売上データ多変数分析スキル

## 概要

複数の変数（カテゴリ、担当者、商品属性など）が絡む売上データを分析し、各変数の影響度を正確に測定するフレームワーク。

## よくある誤り

| 誤り | 正しいアプローチ |
|------|------------------|
| 単純な平均比較で結論 | 機械学習で変数間の影響度を先に測定 |
| サンプルサイズ無視 | 商品数による信頼性評価 |
| 交絡因子の放置 | 影響の大きい変数から順に除去 |
| 外れ値の影響放置 | 中央値/トリム平均/上限設定 |
| 相関を因果と誤認 | 因果関係の検証 |

---

## 分析フレームワーク

### Phase 1: データ理解

```python
import pandas as pd

df = pd.read_csv('data.csv')
print(f"行数: {len(df)}")
print(f"カラム: {df.columns.tolist()}")
print(df.describe())
```

確認事項:
- 目的変数（売上など）
- 説明変数（カテゴリ、担当者など）
- 欠損値、外れ値

### Phase 2: 機械学習で変数重要度を測定【最初に実行】

手動分析の前に、機械学習で各変数の影響度を客観的に測定する。

```python
from sklearn.preprocessing import LabelEncoder
from sklearn.ensemble import RandomForestRegressor
from sklearn.metrics import r2_score

# 目的変数
y = df['売上']

# 説明変数をエンコード
le = LabelEncoder()
X = pd.DataFrame({
    'カテゴリ': le.fit_transform(df['カテゴリ']),
    '担当者': le.fit_transform(df['担当者'])
})

# 各変数単独のR²を測定
def measure_r2(X_subset, y):
    rf = RandomForestRegressor(n_estimators=100, random_state=42)
    rf.fit(X_subset, y)
    return r2_score(y, rf.predict(X_subset))

r2_cat = measure_r2(X[['カテゴリ']], y)
r2_author = measure_r2(X[['担当者']], y)
r2_both = measure_r2(X, y)

print(f"カテゴリ単独: R²={r2_cat:.3f} ({r2_cat*100:.1f}%)")
print(f"担当者単独:   R²={r2_author:.3f} ({r2_author*100:.1f}%)")
print(f"両方:         R²={r2_both:.3f} ({r2_both*100:.1f}%)")
print(f"担当者の純粋な寄与: {r2_both - r2_cat:.3f}")
print(f"残り（商品力等）: {1 - r2_both:.3f}")
```

この結果で変数間の影響度を把握してから手動分析に進む。

### Phase 3: サンプルサイズ確認

各グループの件数を確認し、信頼性を評価。

```python
MIN_SAMPLES = 30  # 最小サンプル数

group_stats = df.groupby('担当者').agg({
    '売上': ['count', 'sum', 'mean']
})
group_stats.columns = ['件数', '総売上', '平均売上']
group_stats['信頼性'] = group_stats['件数'] >= MIN_SAMPLES
group_stats = group_stats.sort_values('件数', ascending=False)

print("【信頼できるグループ】")
print(group_stats[group_stats['信頼性']])

print("\n【信頼できないグループ（係数1.0にフォールバック）】")
print(f"{len(group_stats[~group_stats['信頼性']])}件")
```

### Phase 4: 影響度ランキング

変数間で係数の幅を比較し、どの変数が最も影響があるか判断。

```python
global_avg = df['売上'].mean()

# 各変数の係数幅を計算
def calc_coef_range(df, group_col, target_col, min_samples=30):
    stats = df.groupby(group_col)[target_col].agg(['count', 'mean'])
    reliable = stats[stats['count'] >= min_samples]
    coef = reliable['mean'] / df[target_col].mean()
    return coef.min(), coef.max(), coef.max() / coef.min()

cat_min, cat_max, cat_ratio = calc_coef_range(df, 'カテゴリ', '売上')
author_min, author_max, author_ratio = calc_coef_range(df, '担当者', '売上')

print(f"カテゴリ: 係数{cat_min:.2f}〜{cat_max:.2f} ({cat_ratio:.1f}倍差)")
print(f"担当者:   係数{author_min:.2f}〜{author_max:.2f} ({author_ratio:.1f}倍差)")
```

### Phase 5: 計算式の検証

#### 5.1 方向性の確認

```python
# 正しい方向: 人気担当者の売上を「割り引く」
調整後売上 = 実売上 / 担当者係数

# 誤った方向: 人気担当者の期待を「上げる」
# 期待売上 = カテゴリ平均 × 担当者係数  ← これは逆効果
```

#### 5.2 基準値の選択

| 手法 | 用途 | コード |
|------|------|--------|
| 平均 | 標準的 | `df.groupby(col).mean()` |
| 中央値 | 外れ値が多い場合 | `df.groupby(col).median()` |
| トリム平均 | バランス型 | `scipy.stats.trim_mean(x, 0.1)` |

```python
from scipy import stats

def calc_coefficient(df, group_col, target_col, method='mean'):
    if method == 'mean':
        group_avg = df.groupby(group_col)[target_col].mean()
        global_avg = df[target_col].mean()
    elif method == 'median':
        group_avg = df.groupby(group_col)[target_col].median()
        global_avg = df[target_col].median()
    elif method == 'trim':
        group_avg = df.groupby(group_col)[target_col].apply(
            lambda x: stats.trim_mean(x, 0.1) if len(x) >= 5 else x.mean()
        )
        global_avg = stats.trim_mean(df[target_col], 0.1)

    return group_avg / global_avg
```

#### 5.3 外れ値対策

```python
# 上限設定
df['相対売上'] = df['売上'] / df['カテゴリ'].map(cat_avg)
df['相対売上_cap'] = df['相対売上'].clip(upper=3.0)

# 平方根圧縮
coef_sqrt = np.sqrt(coef_raw)
```

#### 5.4 妥当性チェック

ドメイン知識と照合:
```python
# 例: 「sequencehは1.3〜1.7倍程度の影響」という知見がある場合
expected_range = (1.3, 1.7)
actual_coef = author_coef['sequenceh']

if expected_range[0] <= actual_coef <= expected_range[1]:
    print("妥当な範囲")
else:
    print(f"要調整: {actual_coef:.2f} (期待: {expected_range})")
```

### Phase 6: 交絡因子の除去

影響の大きい変数から順に除去:

```python
# Step 1: カテゴリ効果を除去
cat_avg = df.groupby('カテゴリ')['売上'].mean()
df['カテゴリ内相対売上'] = df['売上'] / df['カテゴリ'].map(cat_avg)

# Step 2: 担当者係数を再計算（カテゴリ効果除去後）
author_coef_adjusted = df.groupby('担当者')['カテゴリ内相対売上'].mean()

# Step 3: 信頼できる担当者のみ係数適用
reliable_authors = group_stats[group_stats['信頼性']].index
final_coef = {
    author: coef for author, coef in author_coef_adjusted.items()
    if author in reliable_authors
}
# 他は1.0にフォールバック
```

### Phase 7: 最終スコア計算

```python
def get_author_coef(author, coef_dict, default=1.0):
    return coef_dict.get(author, default)

df['担当者係数'] = df['担当者'].map(lambda x: get_author_coef(x, final_coef))
df['調整後売上'] = df['売上'] / df['担当者係数']
df['商品力スコア'] = (df['調整後売上'] - df['カテゴリ平均']) / df['カテゴリ平均'] * 100
```

---

## チェックリスト

分析前:
- [ ] 目的変数と説明変数を明確にしたか？
- [ ] 機械学習で変数間の影響度を測定したか？

分析中:
- [ ] 各グループのサンプルサイズを確認したか？
- [ ] 係数の幅を変数間で比較したか？
- [ ] 計算式の方向性は正しいか？
- [ ] 外れ値の影響を確認したか？

分析後:
- [ ] ドメイン知識と照合して妥当性を確認したか？
- [ ] 因果関係と相関関係を区別したか？
- [ ] 機械学習の結果と手動分析の結果が整合しているか？

---

## ケーススタディ: 占いプライム売上分析

### 誤った分析

1. 監修者別平均売上を計算
2. sequenceh: ¥93,259 > 全体平均¥42,264
3. 「監修者効果が大きい！」と結論

### 正しい分析

1. **機械学習で影響度測定**
   - カテゴリ: R²=20.1%
   - 監修者: R²=20.0%（カテゴリ除去後）
   - 商品力: R²=59.9%

2. **サンプルサイズ確認**
   - TOP4のみ100件以上
   - twinflame: 9件 → 信頼性低

3. **カテゴリ効果を除去してから監修者係数を計算**
   - sequenceh: 2.21 → 1.7（カテゴリ効果除去後）

4. **最終結論**
   - カテゴリと監修者は同程度の影響（各20%）
   - 60%は商品力で決まる
   - 監修者で影響があるのはTOP3のみ
