#!/usr/bin/env python3
"""
売上データ多変数分析スクリプト
Phase 1-7を自動実行し、各変数の影響度と係数を算出する
"""

import pandas as pd
import numpy as np
from sklearn.preprocessing import LabelEncoder
from sklearn.ensemble import RandomForestRegressor
from sklearn.metrics import r2_score
from scipy import stats
import argparse
import warnings
warnings.filterwarnings('ignore')


def load_data(filepath, encoding='utf-8-sig'):
    """データ読み込み"""
    return pd.read_csv(filepath, encoding=encoding)


def measure_variable_importance(df, target_col, feature_cols):
    """
    Phase 2: 機械学習で変数重要度を測定
    """
    print("=" * 70)
    print("【Phase 2: 機械学習による変数重要度分析】")
    print("=" * 70)

    y = df[target_col]

    # エンコード
    X = pd.DataFrame()
    encoders = {}
    for col in feature_cols:
        le = LabelEncoder()
        X[col] = le.fit_transform(df[col].astype(str))
        encoders[col] = le

    # 各変数単独のR²
    results = {}
    for col in feature_cols:
        rf = RandomForestRegressor(n_estimators=100, random_state=42, n_jobs=-1)
        rf.fit(X[[col]], y)
        r2 = r2_score(y, rf.predict(X[[col]]))
        results[col] = r2
        print(f"{col}: R²={r2:.3f} ({r2*100:.1f}%の売上変動を説明)")

    # 全変数
    rf_all = RandomForestRegressor(n_estimators=100, random_state=42, n_jobs=-1)
    rf_all.fit(X, y)
    r2_all = r2_score(y, rf_all.predict(X))
    results['全変数'] = r2_all
    results['残り（商品力等）'] = 1 - r2_all

    print(f"\n全変数: R²={r2_all:.3f} ({r2_all*100:.1f}%)")
    print(f"残り（商品力等）: {(1-r2_all)*100:.1f}%")

    return results


def check_sample_size(df, group_col, target_col, min_samples=30):
    """
    Phase 3: サンプルサイズ確認
    """
    print("\n" + "=" * 70)
    print(f"【Phase 3: サンプルサイズ確認】最小サンプル数={min_samples}")
    print("=" * 70)

    group_stats = df.groupby(group_col).agg({
        target_col: ['count', 'sum', 'mean']
    })
    group_stats.columns = ['件数', '総売上', '平均売上']
    group_stats['信頼性'] = group_stats['件数'] >= min_samples
    group_stats = group_stats.sort_values('件数', ascending=False)

    reliable = group_stats[group_stats['信頼性']]
    unreliable = group_stats[~group_stats['信頼性']]

    print(f"\n信頼できるグループ: {len(reliable)}件")
    print(reliable.head(20).to_string())

    print(f"\n信頼できないグループ: {len(unreliable)}件 → 係数1.0にフォールバック")

    return group_stats


def calc_coefficient_range(df, group_col, target_col, min_samples=30):
    """
    Phase 4: 影響度ランキング
    """
    stats_df = df.groupby(group_col)[target_col].agg(['count', 'mean'])
    reliable = stats_df[stats_df['count'] >= min_samples]

    global_avg = df[target_col].mean()
    coef = reliable['mean'] / global_avg

    return {
        'min': coef.min(),
        'max': coef.max(),
        'ratio': coef.max() / coef.min() if coef.min() > 0 else np.inf,
        'coefficients': coef
    }


def remove_confounding(df, primary_col, secondary_col, target_col, min_samples=30):
    """
    Phase 6: 交絡因子の除去
    """
    print("\n" + "=" * 70)
    print(f"【Phase 6: 交絡因子の除去】{primary_col}効果を除去後の{secondary_col}係数")
    print("=" * 70)

    # 主要変数の平均
    primary_avg = df.groupby(primary_col)[target_col].mean()

    # 相対売上（主要変数の効果を除去）
    df['相対売上'] = df.apply(
        lambda row: row[target_col] / primary_avg[row[primary_col]], axis=1
    )

    # 二次変数の係数を再計算
    secondary_coef = df.groupby(secondary_col)['相対売上'].agg(['mean', 'count'])
    secondary_coef.columns = ['係数', '件数']
    secondary_coef['信頼性'] = secondary_coef['件数'] >= min_samples
    secondary_coef = secondary_coef.sort_values('係数', ascending=False)

    print("\n【信頼できる係数】")
    reliable = secondary_coef[secondary_coef['信頼性']]
    for name, row in reliable.head(20).iterrows():
        print(f"{name:<20} 係数:{row['係数']:.2f} 件数:{int(row['件数'])}")

    return secondary_coef


def calculate_final_score(df, target_col, category_col, author_col, author_coef_dict):
    """
    Phase 7: 最終スコア計算
    """
    print("\n" + "=" * 70)
    print("【Phase 7: 最終スコア計算】")
    print("=" * 70)

    # カテゴリ平均
    cat_avg = df.groupby(category_col)[target_col].mean()

    # 係数適用
    df['担当者係数'] = df[author_col].map(lambda x: author_coef_dict.get(x, 1.0))
    df['調整後売上'] = (df[target_col] / df['担当者係数']).round(0).astype(int)
    df['カテゴリ平均'] = df[category_col].map(cat_avg).round(0).astype(int)
    df['商品力スコア'] = ((df['調整後売上'] - df['カテゴリ平均']) / df['カテゴリ平均'] * 100).round(1)

    print(f"適用した係数: {author_coef_dict}")
    print(f"\n【商品力スコア TOP10】")
    top10 = df.nlargest(10, '商品力スコア')[[category_col, author_col, target_col, '調整後売上', '商品力スコア']]
    print(top10.to_string())

    return df


def main():
    parser = argparse.ArgumentParser(description='売上データ多変数分析')
    parser.add_argument('filepath', help='CSVファイルパス')
    parser.add_argument('--target', default='税抜金額', help='目的変数カラム名')
    parser.add_argument('--category', default='カテゴリ', help='カテゴリカラム名')
    parser.add_argument('--author', default='監修者', help='担当者カラム名')
    parser.add_argument('--min-samples', type=int, default=30, help='最小サンプル数')
    parser.add_argument('--output', help='出力CSVファイルパス')

    args = parser.parse_args()

    # Phase 1: データ読み込み
    print("=" * 70)
    print("【Phase 1: データ理解】")
    print("=" * 70)
    df = load_data(args.filepath)
    print(f"行数: {len(df)}")
    print(f"カラム: {df.columns.tolist()}")
    print(f"\n目的変数: {args.target}")
    print(f"説明変数: {args.category}, {args.author}")

    # Phase 2: 機械学習で変数重要度測定
    importance = measure_variable_importance(
        df, args.target, [args.category, args.author]
    )

    # Phase 3: サンプルサイズ確認
    author_stats = check_sample_size(df, args.author, args.target, args.min_samples)

    # Phase 4: 影響度ランキング
    print("\n" + "=" * 70)
    print("【Phase 4: 影響度ランキング】")
    print("=" * 70)

    cat_range = calc_coefficient_range(df, args.category, args.target, args.min_samples)
    author_range = calc_coefficient_range(df, args.author, args.target, args.min_samples)

    print(f"{args.category}: 係数{cat_range['min']:.2f}〜{cat_range['max']:.2f} ({cat_range['ratio']:.1f}倍差)")
    print(f"{args.author}: 係数{author_range['min']:.2f}〜{author_range['max']:.2f} ({author_range['ratio']:.1f}倍差)")

    # Phase 6: 交絡因子の除去
    author_coef = remove_confounding(
        df, args.category, args.author, args.target, args.min_samples
    )

    # 信頼できる係数のみ抽出
    reliable_coef = author_coef[author_coef['信頼性']]['係数'].to_dict()

    # Phase 7: 最終スコア計算
    df = calculate_final_score(df, args.target, args.category, args.author, reliable_coef)

    # 出力
    if args.output:
        df.to_csv(args.output, index=False, encoding='utf-8-sig')
        print(f"\n保存完了: {args.output}")

    print("\n" + "=" * 70)
    print("【分析完了】")
    print("=" * 70)


if __name__ == '__main__':
    main()
