#!/usr/bin/env python3
"""Aggregate ~/.claude/state/hook-profiling.jsonl into a per-hook latency report.

Usage:
  python3 ~/.claude/hooks/_profile-analyze.py              # all data
  python3 ~/.claude/hooks/_profile-analyze.py --days 7     # last 7 days only
  python3 ~/.claude/hooks/_profile-analyze.py --top 10     # top 10 by p95
"""
import argparse
import json
from collections import defaultdict
from datetime import datetime, timezone, timedelta
from pathlib import Path
from statistics import median


def percentile(sorted_values, pct):
    if not sorted_values:
        return 0
    k = (len(sorted_values) - 1) * (pct / 100)
    f = int(k)
    c = min(f + 1, len(sorted_values) - 1)
    if f == c:
        return sorted_values[f]
    return sorted_values[f] + (sorted_values[c] - sorted_values[f]) * (k - f)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--days", type=int, default=0, help="filter to last N days (0=all)")
    ap.add_argument("--top", type=int, default=0, help="show top N rows by p95 (0=all)")
    ap.add_argument("--log", default=str(Path.home() / ".claude/state/hook-profiling.jsonl"))
    args = ap.parse_args()

    log_path = Path(args.log)
    if not log_path.exists():
        print(f"No log file at {log_path}")
        return

    cutoff = None
    if args.days > 0:
        cutoff = datetime.now(timezone.utc) - timedelta(days=args.days)

    by_hook = defaultdict(list)
    fails_by_hook = defaultdict(int)
    total_records = 0

    with log_path.open() as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except json.JSONDecodeError:
                continue
            if cutoff:
                try:
                    ts = datetime.strptime(rec["ts"], "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
                    if ts < cutoff:
                        continue
                except (KeyError, ValueError):
                    continue
            total_records += 1
            by_hook[rec["hook"]].append(rec["duration_ms"])
            if rec.get("exit_code", 0) != 0:
                fails_by_hook[rec["hook"]] += 1

    if not by_hook:
        print(f"No records found{' in last ' + str(args.days) + ' days' if cutoff else ''}.")
        return

    rows = []
    for hook, durations in by_hook.items():
        durations_sorted = sorted(durations)
        rows.append({
            "hook": hook,
            "n": len(durations),
            "p50": int(median(durations_sorted)),
            "p95": int(percentile(durations_sorted, 95)),
            "p99": int(percentile(durations_sorted, 99)),
            "max": max(durations_sorted),
            "total_s": sum(durations) / 1000,
            "non_zero_exits": fails_by_hook[hook],
        })
    rows.sort(key=lambda r: r["p95"], reverse=True)
    if args.top:
        rows = rows[:args.top]

    print(f"# Hook profiling report  (records: {total_records}, hooks: {len(by_hook)}"
          + (f", last {args.days}d" if cutoff else "") + ")")
    print(f"# Log: {log_path}")
    print()
    header = f"{'hook':<40} {'n':>6} {'p50ms':>7} {'p95ms':>7} {'p99ms':>7} {'maxms':>7} {'total_s':>9} {'fails':>6}"
    print(header)
    print("-" * len(header))
    for r in rows:
        print(f"{r['hook']:<40} {r['n']:>6} {r['p50']:>7} {r['p95']:>7} "
              f"{r['p99']:>7} {r['max']:>7} {r['total_s']:>9.1f} {r['non_zero_exits']:>6}")
    print()
    print(f"# Total wall time spent in measured hooks: "
          f"{sum(r['total_s'] for r in rows):.1f}s")


if __name__ == "__main__":
    main()
