#!/usr/bin/env python3
"""collect-reply-posts 自己改善ループ [集約] 段。

reply-search-feedback.jsonl（Stage 5 が書く人間採否ログ）を集計し、
クエリ別の採用率・頻出却下理由・死にクエリを出す。**集計のみ・採否判定はしない**
（ground truth は人間。ここで機械が良し悪しを決めない＝不安定検出器の ground-truth 化を避ける）。

出力を見て、LLM が gen-queries.sh の改善 diff を提案 → 人間承認 → 適用、が次段。

使い方: python3 ~/.claude/skills/collect-reply-posts/analyze-feedback.py [--recent N]
  --recent N  直近 N ラン(run_date のユニーク日)だけを対象（既定: 全件）
"""
import json
import os
import sys
from collections import defaultdict, Counter

FEEDBACK = os.path.expanduser("~/.claude/state/reply-search-feedback.jsonl")
# 採用率がこれ未満かつ十分な surfaced があるクエリは「淘汰候補」
DEAD_RATE = 0.10
DEAD_MIN_SURFACED = 8


def load(path):
    rows = []
    if not os.path.exists(path):
        return rows
    with open(path, encoding="utf-8") as f:
        for ln, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            try:
                rows.append(json.loads(line))
            except json.JSONDecodeError:
                print(f"  ! 行 {ln} がJSONとして壊れている（スキップ）", file=sys.stderr)
    return rows


def main():
    recent = None
    if "--recent" in sys.argv:
        i = sys.argv.index("--recent")
        try:
            recent = int(sys.argv[i + 1])
        except (IndexError, ValueError):
            print("--recent には整数を渡す", file=sys.stderr)
            sys.exit(2)

    rows = load(FEEDBACK)
    if not rows:
        print(f"フィードバックなし: {FEEDBACK} が空 or 未作成。")
        print("collect-reply-posts を数ラン回してから再実行する。")
        return

    if recent:
        dates = sorted({r.get("run_date", "") for r in rows}, reverse=True)[:recent]
        rows = [r for r in rows if r.get("run_date", "") in dates]

    run_dates = sorted({r.get("run_date", "") for r in rows})
    total = len(rows)
    adopted = sum(1 for r in rows if r.get("verdict") == "adopted")
    rejected = sum(1 for r in rows if r.get("verdict") == "rejected")

    print(f"==== collect-reply-posts feedback 集計 ====")
    print(f"対象ラン: {len(run_dates)}日分 ({run_dates[0]}〜{run_dates[-1]})" if run_dates else "")
    print(f"総ピック: {total}  採用: {adopted}  却下: {rejected}  "
          f"全体採用率: {adopted/total:.0%}\n")

    # --- クエリ別 採用率 ---
    by_q = defaultdict(lambda: {"adopted": 0, "rejected": 0})
    for r in rows:
        q = r.get("query_label", "unknown")
        v = r.get("verdict")
        if v in ("adopted", "rejected"):
            by_q[q][v] += 1

    print("---- クエリ別 採用率（採用/総ピック）----")
    stats = []
    for q, c in by_q.items():
        surf = c["adopted"] + c["rejected"]
        rate = c["adopted"] / surf if surf else 0.0
        stats.append((rate, surf, c["adopted"], q))
    for rate, surf, ad, q in sorted(stats, reverse=True):
        flag = "  ⚠️淘汰候補" if (rate < DEAD_RATE and surf >= DEAD_MIN_SURFACED) else ""
        print(f"  {rate:5.0%}  ({ad}/{surf})  {q}{flag}")

    # --- 頻出却下理由（全体）---
    reasons = Counter(
        (r.get("reason", "") or "").strip()
        for r in rows if r.get("verdict") == "rejected" and r.get("reason")
    )
    if reasons:
        print("\n---- 頻出 却下理由 TOP10（クエリを絞るヒント）----")
        for reason, n in reasons.most_common(10):
            print(f"  {n:3}  {reason}")

    # --- 採用された投稿の query_label 分布（どのクエリが金脈か）---
    gold = Counter(
        r.get("query_label", "unknown")
        for r in rows if r.get("verdict") == "adopted"
    )
    if gold:
        print("\n---- 採用の出所クエリ（金脈の所在）----")
        for q, n in gold.most_common():
            print(f"  {n:3}  {q}")

    print("\n次段: この集計を読み、LLM に gen-queries.sh の改善 diff を出させる")
    print("      （低採用クエリ淘汰 / 高採用キーワード追加 / min_replies 上下）")
    print("      → 人間が承認したものだけ適用し、gen-queries.sh の # CHANGELOG に1行残す。")


if __name__ == "__main__":
    main()
