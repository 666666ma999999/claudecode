#!/usr/bin/env bash
# Weekly Spec Pulse: 過去 7 日の .raw/news/*.jsonl から spec_pulse 系を集約し
# vault/02_Ai/AI_adscrm/reports/weekly-update-YYYY-MM-DD.md を生成する。
# (2026-06-13: 出力先を project wiki/ → reports/ へ移設。rules/42 K-3 project 内 wiki/ 廃止)
#
# launchd: ~/Library/LaunchAgents/com.masa.weekly-spec-pulse.plist (月曜 09:30 JST)
# 起案: ~/Desktop/prm/prime_suite/prime_ad/tasks/spec-pulse-plan.md
# マッピング: ~/.claude/data/spec-pulse-mapping.yaml
#
# 出力:
#   - vault/02_Ai/AI_adscrm/reports/weekly-update-YYYY-MM-DD.md  (人間用 + SessionStart 注入)
#   - ~/.claude/state/weekly-spec-pulse.last_run             (mtime 死活監視)
#   - ~/.claude/state/weekly-spec-pulse.log                  (ログ)

set -uo pipefail

PY=/usr/bin/python3
HOME_DIR="$HOME"
RAW_DIR="$HOME_DIR/Documents/Obsidian Vault/.raw/news"
OUT_DIR="$HOME_DIR/Documents/Obsidian Vault/02_Ai/AI_adscrm/reports"
MAPPING="$HOME_DIR/.claude/data/spec-pulse-mapping.yaml"
HEALTH="$HOME_DIR/.claude/state/news_health.json"
STATE_DIR="$HOME_DIR/.claude/state"
LAST_RUN="$STATE_DIR/weekly-spec-pulse.last_run"
LOG="$STATE_DIR/weekly-spec-pulse.log"

mkdir -p "$OUT_DIR" "$STATE_DIR"
TODAY=$(date +%Y-%m-%d)
TS=$(date -Iseconds)
OUT_MD="$OUT_DIR/weekly-update-$TODAY.md"

{
  echo "=== [$TS] weekly_spec_pulse start ==="

  "$PY" - <<PYEOF
import json
import re
from datetime import date, timedelta
from pathlib import Path

RAW_DIR = Path("$RAW_DIR")
OUT_MD = Path("$OUT_MD")
MAPPING_FILE = Path("$MAPPING")
HEALTH = Path("$HEALTH")
TODAY = date.fromisoformat("$TODAY")

def load_mapping():
    """Parse mappings: key: [M1, M2] from spec-pulse-mapping.yaml."""
    mappings = {}
    if not MAPPING_FILE.exists():
        return mappings
    in_mappings = False
    for raw in MAPPING_FILE.read_text(encoding="utf-8").splitlines():
        line = raw.rstrip()
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if line.startswith("mappings:"):
            in_mappings = True
            continue
        if line.startswith(("deleted_measures:", "sources:", "trace:")):
            in_mappings = False
            continue
        if not in_mappings:
            continue
        m = re.match(r"^\s+(\w+):\s*\[(.*?)\]\s*$", line)
        if m:
            key = m.group(1)
            vals = [v.strip() for v in m.group(2).split(",") if v.strip()]
            mappings[key] = vals
    return mappings

def lookup_measures(tags, mapping):
    """tags の各要素を mapping で引き、ユニークな M番号 list を返す。"""
    out = []
    seen = set()
    for tag in tags or []:
        for m in mapping.get(tag, []):
            if m not in seen:
                out.append(m)
                seen.add(m)
    return out

# 過去 7 日 (今日含む) の jsonl を読み込み
items = []
for n in range(7):
    d = TODAY - timedelta(days=n)
    p = RAW_DIR / f"{d.isoformat()}.jsonl"
    if not p.exists():
        continue
    for line in p.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue
        # spec_pulse タグのみ採用
        if "spec_pulse" not in (obj.get("tags") or []):
            continue
        items.append(obj)

mapping = load_mapping()

# url_hash で重複排除 (同じ URL が複数日 jsonl にある可能性)
seen_hashes = set()
deduped = []
for it in items:
    h = it.get("url_hash") or it.get("url")
    if h in seen_hashes:
        continue
    seen_hashes.add(h)
    deduped.append(it)

# priority 別に分類
p0 = [x for x in deduped if "p0" in (x.get("tags") or [])]
p1 = [x for x in deduped if "p1" in (x.get("tags") or [])]

# stale source 検出 (consecutive_failures >= 3)
stale = []
if HEALTH.exists():
    try:
        h = json.loads(HEALTH.read_text())
        for name, entry in h.items():
            if entry.get("consecutive_failures", 0) >= 3:
                stale.append((name, entry.get("consecutive_failures")))
    except Exception:
        pass

coverage_start = (TODAY - timedelta(days=6)).isoformat()

def render_item(it, idx):
    title = it.get("title", "(no title)").strip()[:200]
    url = it.get("url", "")
    pub = it.get("published_at", "")
    src = it.get("source", "")
    summary = (it.get("summary") or "").strip()[:300]
    candidates = lookup_measures(it.get("tags"), mapping)
    cand_str = " / ".join(candidates) if candidates else "(マッピング辞書に該当なし・人間判断)"
    return f"""### {idx}. [{src}] {title}
- url: {url}
- published: {pub}
- summary: {summary}
- **関連施策候補** (自動推定): {cand_str}
- [ ] 確認済
"""

lines = []
lines.append("---")
lines.append("project: prime_ad")
lines.append("type: weekly-spec-pulse")
lines.append('folder: "02_Ai/AI_adscrm/reports/"')
lines.append("categories:")
lines.append('  - "[[AIads_ope]]"')
lines.append(f"generated_at: {TODAY.isoformat()}")
lines.append(f'coverage: "{coverage_start} 〜 {TODAY.isoformat()}"')
lines.append(f"total_p0: {len(p0)}")
lines.append(f"total_p1: {len(p1)}")
lines.append(f"stale_sources: {len(stale)}")
lines.append(f"last_updated: {TODAY.isoformat()}")
lines.append("tags:")
lines.append("  - project/prime_ad")
lines.append("  - type/spec-pulse")
lines.append("---")
lines.append("")
lines.append(f"# Weekly Spec Pulse — {TODAY.isoformat()}")
lines.append("")
lines.append(f"> Coverage: {coverage_start} 〜 {TODAY.isoformat()}")
lines.append(f"> P0: {len(p0)} 件 / P1: {len(p1)} 件 / stale source: {len(stale)} 件")
lines.append("")
lines.append("## P0 (要確認)")
lines.append("")
if not p0:
    lines.append("(該当なし)")
    lines.append("")
else:
    for i, it in enumerate(p0, 1):
        lines.append(render_item(it, i))
lines.append("## P1 (参考)")
lines.append("")
if not p1:
    lines.append("(該当なし)")
    lines.append("")
else:
    for i, it in enumerate(p1, 1):
        lines.append(render_item(it, i))
lines.append("## stale source 警告")
lines.append("")
if not stale:
    lines.append("(すべて健全)")
else:
    for name, n in stale:
        lines.append(f"- consecutive_failures={n}: {name}")
lines.append("")
lines.append("## 関連リンク")
lines.append("")
lines.append("- [AIads_ope.md](file:///Users/masaaki_nagasawa/Documents/Obsidian%20Vault/02_Ai/AI_adscrm/AIads_ope.md)")
lines.append("- [AIcrm_ope.md](file:///Users/masaaki_nagasawa/Documents/Obsidian%20Vault/02_Ai/AI_adscrm/AIcrm/AIcrm_ope.md)")
lines.append("- [measures-detail.md](file:///Users/masaaki_nagasawa/Desktop/prm/prime_suite/prime_ad/docs/measures-detail.md)")
lines.append("- [spec-pulse-plan.md](file:///Users/masaaki_nagasawa/Desktop/prm/prime_suite/prime_ad/tasks/spec-pulse-plan.md)")
lines.append("")

OUT_MD.parent.mkdir(parents=True, exist_ok=True)
OUT_MD.write_text("\n".join(lines), encoding="utf-8")
print(f"[weekly_spec_pulse] P0={len(p0)} P1={len(p1)} stale={len(stale)} → {OUT_MD}")
PYEOF

  # mtime 死活監視用
  date -Iseconds > "$LAST_RUN"

  echo "=== [$(date -Iseconds)] weekly_spec_pulse end (exit=0) ==="
  echo ""
} >> "$LOG" 2>&1

exit 0
