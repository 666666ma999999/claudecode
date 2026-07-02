#!/usr/bin/env python3
"""
watch_activate.py — 20件完了を自動検知 → 自動キャプチャ + baseline + 通知。

「あなたは20件登録するだけ」を実現する見張り役。launchd で hourly 実行。
host・READ-ONLY (生成パイプライン不触)。検知前は毎回ほぼ no-op (安全)。

フロー:
  --install : いまの完了済み登録を「既存」として記録し、ここから新規をカウント開始 (登録前に1回)
  --check   : 新規完了が TARGET(既定20) 件に達したら → capture → baseline scoring(best-effort) →
              macOS 通知 + _activation_ready.json を立てる → activated 化 (idempotent)
  --status  : 現在の検知状況

注意: エンジン本体(再生成)の仕上げは検知後に Claude が実データで行う。本 watcher は「検知+取り込み+通知」まで。
"""
import os
import sys
import json
import glob
import time
import subprocess
import importlib.util as _ilu
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
DATA = Path(os.environ.get("ROHAN_SELFIMPROVE_DATA", "/Users/masaaki/Desktop/prm/rohan/data"))
REPO_FOR_DOCKER = os.environ.get("ROHAN_SELFIMPROVE_REPO", "/Users/masaaki/Desktop/prm/rohan")
TASKDIR = ROOT / "tasks" / "p-2026-06-18-self-improve-loop"
CORPUS = HERE / "_corpus"  # relocated: corpus は deployed script の隣 (worktree 非依存)
MARKER = CORPUS / "_activation_marker.json"
READY = CORPUS / "_activation_ready.json"
BASELINE = CORPUS / "_baseline_scored.json"
SITES = set(s.strip() for s in os.environ.get("ROHAN_SELFIMPROVE_SITES", "423,504,275").split(",") if s.strip())
TARGET = int(os.environ.get("ROHAN_SELFIMPROVE_TARGET", "20"))

# capture.py を正本のままパス読込 (静的 import 検証と非干渉)
_spec = _ilu.spec_from_file_location("si_capture", str(HERE / "capture.py"))
_cap = _ilu.module_from_spec(_spec)
_spec.loader.exec_module(_cap)


def log(msg):
    print(f"[watch {time.strftime('%H:%M:%S')}] {msg}", flush=True)


def completed_sessions() -> dict:
    """target site の生成完了(proofread_status set)セッションの {ppv: updated_at}。"""
    out = {}
    for fp in glob.glob(str(DATA / "sessions" / "reg_*.json")):
        try:
            d = json.load(open(fp, encoding="utf-8"))
        except Exception:
            continue
        ids = d.get("ids") or {}
        site = str(ids.get("site_id"))
        ppv = ids.get("ppv_id")
        if site not in SITES or not ppv:
            continue
        st = (d.get("product") or {}).get("proofread_status")
        if st in ("passed", "unresolved", "skipped"):   # 生成は完了している
            out[str(ppv)] = d.get("updated_at") or ""
    return out


def load_marker():
    if MARKER.exists():
        try:
            return json.load(open(MARKER, encoding="utf-8"))
        except Exception:
            return None
    return None


def notify(msg):
    try:
        subprocess.run(["osascript", "-e",
                        f'display notification "{msg}" with title "rohan 自己改善ループ"'],
                       timeout=10)
    except Exception:
        pass


def cmd_install():
    CORPUS.mkdir(parents=True, exist_ok=True)
    pre = completed_sessions()
    m = {"installed_at": time.strftime("%Y-%m-%dT%H:%M:%S"),
         "preexisting": sorted(pre.keys()), "activated": False,
         "target": TARGET, "sites": sorted(SITES)}
    json.dump(m, open(MARKER, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    log(f"installed. 既存完了={len(pre)} 件を基準化 → 以降の新規 +{TARGET} 件で発火 (sites={sorted(SITES)})")


def cmd_status():
    m = load_marker()
    if not m:
        log("未 install (--install を先に)。")
        return
    if m.get("activated"):
        log(f"activated 済 ({READY})。エンジン仕上げ待ち。")
        return
    pre = set(m.get("preexisting", []))
    new = [p for p in completed_sessions() if p not in pre]
    log(f"新規完了 {len(new)}/{m['target']} 件 (sites={m['sites']})。発火まで残り {max(0, m['target']-len(new))} 件。")


def _score_baseline(ppvs):
    """Docker 内 scorer で baseline 4-vector を算出 (best-effort)。"""
    scorer = HERE / "scorer.py"
    try:
        with open(scorer, encoding="utf-8") as sf:
            r = subprocess.run(
                ["docker", "compose", "exec", "-T", "backend", "python", "-"] + list(ppvs),
                stdin=sf, cwd=REPO_FOR_DOCKER, capture_output=True, text=True, timeout=1800)
        rows = [json.loads(l[6:]) for l in r.stdout.splitlines() if l.startswith("@JSON ")]
        if rows:
            json.dump({"scored_at": time.strftime("%Y-%m-%dT%H:%M:%S"), "n": len(rows), "rows": rows},
                      open(BASELINE, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
            return True
    except Exception as e:
        log(f"baseline scoring 後回し: {e}")
    return False


def cmd_check():
    m = load_marker()
    if not m:
        log("未 install。")
        return
    if m.get("activated"):
        return
    pre = set(m.get("preexisting", []))
    new = [p for p in completed_sessions() if p not in pre]
    if len(new) < m["target"]:
        log(f"新規 {len(new)}/{m['target']} → 待機")
        return
    # ★発火: capture → baseline → 通知 → activate
    log(f"発火: 新規 {len(new)} 件検知 → 取り込み開始")
    CORPUS.mkdir(parents=True, exist_ok=True)
    captured = []
    for ppv in new:
        try:
            rec = _cap.capture_ppv(DATA, ppv)
            (CORPUS / f"{ppv}.json").write_text(json.dumps(rec, ensure_ascii=False, indent=1), encoding="utf-8")
            captured.append(ppv)
        except Exception as e:
            log(f"capture 失敗 {ppv}: {e}")
    baseline_ok = _score_baseline(captured)
    json.dump({"ready_at": time.strftime("%Y-%m-%dT%H:%M:%S"), "captured": captured,
               "baseline_scored": baseline_ok}, open(READY, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    m["activated"] = True
    json.dump(m, open(MARKER, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    notify(f"{len(captured)}件 検知・取り込み完了。エンジン仕上げ待ち。")
    log(f"ACTIVATED: captured={len(captured)} baseline_scored={baseline_ok} → {READY}")


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "--status"
    if cmd == "--install":
        cmd_install()
    elif cmd == "--check":
        cmd_check()
    else:
        cmd_status()


if __name__ == "__main__":
    main()
