#!/usr/bin/env python3
"""
selfimprove capture — 受動・READ-ONLY・pure-stdlib。

完了済み product 登録(ppv)から「入力 / 生成出力 / 校正結果 / 実コスト」を
忠実に1レコードへ凍結する。**生成パイプラインには一切触れない**(read-only)。
今週の ~20 件課金登録(hayatomo423 / karinsp504 / beppu275)を追加コスト$0 で
種コーパス化するのが目的。

設計根拠 (file:line は 2026-06-18 の調査で確認):
- live data = /Users/masaaki/Desktop/prm/rohan/data (Docker が ./data:/app/data で mount)。
  ROHAN_DATA_DIR=.../rohan-data は frozen な red herring なので使わない。
- session = data/sessions/reg_<ts>_<hex>.json (record_id 命名・flat)。ppv は ids.ppv_id で突合。
- cost = gpt_usage.jsonl / gemini_usage.jsonl、各行 reg=record_id タグ(06-11以降)で正確按分。
- 入力(新 CSV-batch 登録)= batch_runs/batch_<id>.json products[] + csv_path。
  prompt_history.json は 2026-05-19 凍結なので新登録には使わない。

使い方:
  python3 capture.py --baseline                 # usage jsonl の現在行数を snapshot ($0 証明用)
  python3 capture.py --ppv 42300650             # 1 件キャプチャ
  python3 capture.py --recent 5                 # 最新 5 セッションをキャプチャ
  python3 capture.py --ppv 42300650 --print     # stdout に要約だけ出す(ファイル書かない)

出力: <out>/<ppv>.json  (既定 out = このファイルから ../../tasks/p-2026-06-18-self-improve-loop/_corpus/)
"""
from __future__ import annotations
import argparse
import glob
import json
import os
import sys
import time
from pathlib import Path

# --- live runtime data dir (read-only) -------------------------------------
DEFAULT_DATA = "/Users/masaaki/Desktop/prm/rohan/data"


def resolve_data_dir(arg: str | None) -> Path:
    cand = arg or os.environ.get("ROHAN_SELFIMPROVE_DATA") or DEFAULT_DATA
    p = Path(cand)
    return p


def preflight(data: Path) -> None:
    """B12 fix: live runtime dir / usage jsonl が実在しないと '$0' が vacuous pass するので落とす。"""
    problems = []
    if not data.is_dir():
        problems.append(f"data dir not found: {data}")
    for name in ("sessions", "gpt_usage.jsonl", "gemini_usage.jsonl"):
        if not (data / name).exists():
            problems.append(f"missing live artifact: {data / name}")
    if problems:
        sys.stderr.write("PREFLIGHT FAILED (live runtime data not reachable):\n  " + "\n  ".join(problems) + "\n")
        sys.stderr.write("This capture reads the LIVE Docker-mounted data dir. Pass --data or set ROHAN_SELFIMPROVE_DATA.\n")
        sys.exit(2)


# --- low level readers ------------------------------------------------------

def _load_json(p: Path):
    with open(p, encoding="utf-8") as f:
        return json.load(f)


def _iter_jsonl(p: Path):
    if not p.exists():
        return
    with open(p, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                yield json.loads(line)
            except json.JSONDecodeError:
                continue


def find_session_by_ppv(data: Path, ppv_id: str) -> Path | None:
    """ids.ppv_id == ppv の最新セッションファイルを返す。"""
    best = None
    best_ts = ""
    for fp in glob.glob(str(data / "sessions" / "reg_*.json")):
        try:
            d = _load_json(Path(fp))
        except Exception:
            continue
        if str((d.get("ids") or {}).get("ppv_id")) == str(ppv_id):
            ts = d.get("updated_at") or d.get("created_at") or ""
            if ts >= best_ts:
                best, best_ts = Path(fp), ts
    return best


def find_batch_row(data: Path, ppv_id: str):
    """batch_runs/*.json から ppv に対応する products[] 行 + run config + csv_path を引く。"""
    for fp in sorted(glob.glob(str(data / "batch_runs" / "*.json")), reverse=True):
        try:
            d = _load_json(Path(fp))
        except Exception:
            continue
        # batch_runs は dict{products,config,csv_path} 形式と、古い bare list[product] 形式が混在
        if isinstance(d, dict):
            products, config, csv_path = (d.get("products") or []), d.get("config"), d.get("csv_path")
        elif isinstance(d, list):
            products, config, csv_path = d, None, None
        else:
            continue
        for prod in products:
            if isinstance(prod, dict) and str(prod.get("ppv_id")) == str(ppv_id):
                return {"batch_file": Path(fp).name,
                        "product_row": prod,
                        "config": config or prod.get("config"),
                        "csv_path": csv_path or prod.get("csv_path")}
    return None


def read_csv_row(data: Path, csv_path: str | None, row_idx) -> str | None:
    """csv_path(コンテナ側 /app/data/...)を host 側に読み替えて該当行テキストを返す(best-effort)。"""
    if not csv_path or row_idx is None:
        return None
    p = Path(csv_path)
    if str(p).startswith("/app/data/"):
        p = data / str(p)[len("/app/data/"):]
    if not p.exists():
        # site_info 配下を basename で探す fallback
        cands = glob.glob(str(data / "site_info" / p.name))
        if not cands:
            return None
        p = Path(cands[0])
    try:
        import csv as _csv
        with open(p, encoding="utf-8-sig", newline="") as f:
            rows = list(_csv.reader(f))
        if isinstance(row_idx, int) and 0 <= row_idx < len(rows):
            return " | ".join(rows[row_idx])
    except Exception:
        return None
    return None


# --- derived metrics --------------------------------------------------------

def extract_bodies(structured: dict) -> list[str]:
    bodies = []
    for st in (structured.get("subtitles") or []):
        for c in (st.get("codes") or []):
            b = c.get("body")
            if isinstance(b, str) and b:
                bodies.append(b)
    for key in ("opening", "closing"):
        oc = structured.get(key)
        if isinstance(oc, dict) and isinstance(oc.get("body"), str):
            bodies.append(oc["body"])
    return bodies


def char_count(bodies: list[str]) -> int:
    return sum(len(b) for b in bodies)


def cost_for_reg(data: Path, record_id: str) -> dict:
    """reg==record_id の usage 行を集計。est_usd が None の行は flagged(コスト過少防止)。"""
    out = {"gpt_usd": 0.0, "gemini_usd": 0.0, "rows": 0, "null_usd_rows": 0,
           "by_phase": {}, "by_provider_model": {}}
    for provider, fn in (("gpt", "gpt_usage.jsonl"), ("gemini", "gemini_usage.jsonl")):
        for r in _iter_jsonl(data / fn):
            if str(r.get("reg")) != str(record_id):
                continue
            out["rows"] += 1
            usd = r.get("est_usd")
            phase = r.get("phase") or "first-pass"
            model = f"{provider}:{r.get('model')}"
            if usd is None:
                out["null_usd_rows"] += 1
            else:
                out[f"{provider}_usd"] += float(usd)
                out["by_phase"][phase] = round(out["by_phase"].get(phase, 0.0) + float(usd), 6)
                out["by_provider_model"][model] = round(out["by_provider_model"].get(model, 0.0) + float(usd), 6)
    out["gpt_usd"] = round(out["gpt_usd"], 6)
    out["gemini_usd"] = round(out["gemini_usd"], 6)
    out["total_usd"] = round(out["gpt_usd"] + out["gemini_usd"], 6)
    return out


# --- capture one ppv --------------------------------------------------------

def capture_ppv(data: Path, ppv_id: str) -> dict:
    sess_fp = find_session_by_ppv(data, ppv_id)
    if not sess_fp:
        raise SystemExit(f"no session found for ppv {ppv_id} under {data}/sessions")
    rec = _load_json(sess_fp)
    product = rec.get("product") or {}
    ids = rec.get("ids") or {}
    record_id = rec.get("record_id")
    structured = product.get("structured_manuscript") or {}
    bodies = extract_bodies(structured)
    rep = product.get("proofread_report") or {}
    crit_types = [i.get("type") for i in (rep.get("issues") or []) if i.get("severity") == "critical"]
    batch = find_batch_row(data, ppv_id)
    csv_text = None
    if batch:
        csv_text = read_csv_row(data, batch.get("csv_path"),
                                (batch.get("product_row") or {}).get("csv_title_row"))

    return {
        "schema": "selfimprove-capture-v1",
        "captured_at": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "ppv_id": str(ppv_id),
        "record_id": record_id,
        "session_file": sess_fp.name,
        "ids": {"site_id": ids.get("site_id"), "site_namecode": ids.get("site_namecode"),
                "mid_id": ids.get("mid_id"), "menu_id": ids.get("menu_id")},
        "input": {
            "batch_file": (batch or {}).get("batch_file"),
            "config": (batch or {}).get("config"),
            "csv_path": (batch or {}).get("csv_path"),
            "csv_row_text": csv_text,
            "product_row": (batch or {}).get("product_row"),
            "title": product.get("title"),
        },
        "output": {
            "n_subtitles": len(structured.get("subtitles") or []),
            "n_code_bodies": len(bodies),
            "char_count": char_count(bodies),
            "manuscript": product.get("manuscript"),       # full text (CUT 適用済) ※ scorer/TTR 用
            "structured_manuscript": structured,           # 検出器を走らせる正本
            "generation_provider_usage": product.get("generation_provider_usage"),  # gal-patch: 実出力 provider
            "keywords_sha256": product.get("keywords_sha256"),
        },
        "proofread": {
            "status": product.get("proofread_status"),
            "critical_count": rep.get("critical_count"),
            "warning_count": rep.get("warning_count"),
            "type_breakdown_critical": rep.get("type_breakdown_critical"),
            "critical_types": crit_types,
            "model": rep.get("model"),
            "truncated": rep.get("truncated"),
        },
        "cost": cost_for_reg(data, record_id),
    }


def snapshot_baseline(data: Path) -> dict:
    def _count(fn):
        p = data / fn
        if not p.exists():
            return 0
        with open(p, encoding="utf-8") as f:
            return sum(1 for _ in f)
    return {
        "schema": "selfimprove-usage-baseline-v1",
        "snapped_at": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "data_dir": str(data),
        "gpt_usage_lines": _count("gpt_usage.jsonl"),
        "gemini_usage_lines": _count("gemini_usage.jsonl"),
    }


def recent_ppvs(data: Path, n: int) -> list[str]:
    files = sorted(glob.glob(str(data / "sessions" / "reg_*.json")),
                   key=lambda f: os.path.getmtime(f), reverse=True)[:n]
    out = []
    for fp in files:
        try:
            d = _load_json(Path(fp))
            ppv = (d.get("ids") or {}).get("ppv_id")
            if ppv:
                out.append(str(ppv))
        except Exception:
            continue
    return out


def main():
    ap = argparse.ArgumentParser(description="selfimprove passive capture (read-only)")
    ap.add_argument("--data", help=f"runtime data dir (default {DEFAULT_DATA})")
    ap.add_argument("--ppv", help="single ppv_id to capture")
    ap.add_argument("--recent", type=int, help="capture N newest sessions")
    ap.add_argument("--baseline", action="store_true", help="snapshot usage jsonl line counts")
    ap.add_argument("--out", help="output dir for records")
    ap.add_argument("--print", dest="do_print", action="store_true", help="print summary, do not write file")
    args = ap.parse_args()

    data = resolve_data_dir(args.data)
    preflight(data)

    here = Path(__file__).resolve().parent
    out_dir = Path(args.out) if args.out else (here / ".." / ".." / "tasks" / "p-2026-06-18-self-improve-loop" / "_corpus").resolve()

    if args.baseline:
        base = snapshot_baseline(data)
        if args.do_print:
            print(json.dumps(base, ensure_ascii=False, indent=2))
        else:
            out_dir.mkdir(parents=True, exist_ok=True)
            (out_dir / "_baseline.json").write_text(json.dumps(base, ensure_ascii=False, indent=2), encoding="utf-8")
            print(f"baseline -> {out_dir/'_baseline.json'}: {base['gpt_usage_lines']} gpt / {base['gemini_usage_lines']} gemini lines")
        return

    ppvs = []
    if args.ppv:
        ppvs = [args.ppv]
    elif args.recent:
        ppvs = recent_ppvs(data, args.recent)
    else:
        ap.error("one of --ppv / --recent / --baseline required")

    if not args.do_print:
        out_dir.mkdir(parents=True, exist_ok=True)
    for ppv in ppvs:
        rec = capture_ppv(data, ppv)
        summary = (f"ppv={rec['ppv_id']} site={rec['ids']['site_id']} "
                   f"chars={rec['output']['char_count']} codes={rec['output']['n_code_bodies']} "
                   f"pf_status={rec['proofread']['status']} pf_crit={rec['proofread']['critical_count']} "
                   f"crit_types={rec['proofread']['critical_types']} "
                   f"usd={rec['cost']['total_usd']} (rows={rec['cost']['rows']}, null_usd={rec['cost']['null_usd_rows']})")
        if args.do_print:
            print(summary)
        else:
            fp = out_dir / f"{ppv}.json"
            fp.write_text(json.dumps(rec, ensure_ascii=False, indent=1), encoding="utf-8")
            print(f"[capt] {summary} -> {fp.name}")


if __name__ == "__main__":
    main()
