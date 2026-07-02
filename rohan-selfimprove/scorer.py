#!/usr/bin/env python3
"""
selfimprove scorer — FROZEN deterministic garble metric (rohan 版 evaluate_bpb).

DO-NOT-MODIFY by the self-improvement loop. This is the immutable scorer (autoresearch
prepare.py 相当)。固定された出力 `structured` に対し純関数で動くので run間 zero-noise。
loop はこのファイルも検出器も corpus も編集できない(別 PR / 人間のみ)。

何を出すか (1 ppv あたり):
- 4-vector 決定論 CGR  [deletion_particle, hiragana_fabrication, identity_swap, other]
- depth proxy         char_count + TTR(語彙多様性)  ← KEEP gate 用 (#3/B3, depth 退化を弾く)
- AI校正 critical      critical_count + 型内訳        ← ユーザーが0にしたい指摘 (noisy・参照)
- RECALL              AI-critical を決定論ユニオンが code 単位でどれだけ捕捉するか
                      (= 純決定論 metric が支配的 garble を見えているかの実測)

実証(2026-06-18): 既存決定論ユニオンは支配的 garble「とても誤挿入」を取りこぼす。
→ 新規 `totemo_nitotte_misuse` 検出器(sudachi POS)を metric 専用に追加(read-only・本番ゲート不触)。

実行は backend コンテナ内 (sudachi/janome 必須):
  docker compose exec -T backend python - 42300650 42300648 42300649 < tools/selfimprove/scorer.py
  docker compose exec -T backend python - --recent 20 < tools/selfimprove/scorer.py
"""
from __future__ import annotations
import json
import glob
import re
import sys
import collections

# --- preflight: sudachi 必須。欠落で silent no-op せず CRASH (B2 fix) ------
try:
    from sudachipy import dictionary as _sudachi_dict
    from sudachipy import tokenizer as _sudachi_tok
except Exception as e:  # pragma: no cover
    sys.stderr.write(f"PREFLIGHT FAILED: sudachipy not importable ({e!r}). "
                     "Run inside the backend container.\n")
    sys.exit(2)

_SUDACHI = _sudachi_dict.Dictionary().create()
_MODE = _sudachi_tok.Tokenizer.SplitMode.C

# 既存検出器 (本番と同一実装を import = 採点と本番ゲートで同じ判定を共有) -------
try:
    from extensions.typo_correction.detectors import DETECTORS
    from extensions.proofread.generation_validator import (
        validate_code, aggregate_reports, high_precision_composite,
    )
    from utils.japanese_quality_gate import detect_garbage_patterns
except Exception as e:  # pragma: no cover
    sys.stderr.write(f"PREFLIGHT FAILED: backend detectors not importable ({e!r}).\n")
    sys.exit(2)

DATA_DIR = "/app/data"
_CONTENT_POS = {"名詞", "動詞", "形容詞", "副詞", "形状詞"}
# 「とても」が正当に係れる後続 (degree adverb の被修飾語)
_TOTEMO_OK_NEXT_POS = {"形容詞", "副詞", "形状詞", "連体詞"}

BUCKETS = ["deletion_particle", "hiragana_fabrication", "identity_swap", "other"]


# --- 新規 metric 専用検出器: とても / にとって hiragana-insertion family --------

_TOTEMO_RE = re.compile(r"にとって|とても")


def _first_token_pos(tail: str):
    """tail 文字列の先頭 content/機能トークンの (POS major, surface) を返す。"""
    try:
        for t in _SUDACHI.tokenize(tail, _MODE):
            if t.surface().strip() == "":
                continue
            return t.part_of_speech()[0], t.surface()
    except Exception:
        return None, None
    return None, None


def detect_totemo_nitotte(structured) -> list[dict]:
    """脱字箇所への「とても」「にとって」誤挿入を検出。
    regex で出現を見つけ(sudachi が garble 文脈で 'とても' を分割しても拾える)、
    直後の語の POS で legit 判定: 後続が 形容詞/副詞/形状詞/連体詞 なら正当(とても良い)。
    それ以外(助詞/動詞/名詞 等)は脱字捏造として flag。bucket=hiragana_fabrication。"""
    issues = []
    for st in structured.get("subtitles", []) or []:
        for c in (st.get("codes") or []):
            body = c.get("body") or ""
            code = c.get("code")
            sub_idx = st.get("order")
            for m in _TOTEMO_RE.finditer(body):
                word = m.group(0)
                tail = body[m.end():m.end() + 14]
                npos, nsurf = _first_token_pos(tail)
                if npos is None:
                    continue  # 文末直前等は判定不能 → 見送り
                why = None
                if word == "とても":
                    if npos in _TOTEMO_OK_NEXT_POS:
                        continue  # とても良い / とてもゆっくり / とても元気(形状詞) = legit
                    why = f"とても+{npos}({nsurf})"
                else:  # にとって
                    # legit「Xにとって(は/も/の/名詞/形状詞)」は正当に幅広く係る。
                    # #62 の garble は「にとって」が動詞直結する misgeneration のみ。
                    if npos != "動詞":
                        continue
                    why = f"にとって+動詞({nsurf})"
                issues.append({
                    "source": "totemo_nitotte", "key": "totemo_nitotte_misuse",
                    "severity": "critical", "bucket": "hiragana_fabrication",
                    "code": code, "subtitle_index": sub_idx,
                    "surface": word, "why": why,
                })
    return issues


# --- 既存3系統 → unified issue 正規化 + 静的 bucket マップ ----------------------

def _bucket_genval_field(field: str, payload: str) -> str:
    if field == "particle_anomalies":
        return "hiragana_fabrication"
    if field == "misconversion_anomalies":
        # totte_misuse=捏造 / ano_jinsei=助詞欠落
        return "hiragana_fabrication" if payload.startswith("totte") else "deletion_particle"
    if field == "solo_partner_violations":
        return "identity_swap"
    if field == "personal_numeric_violations":
        return "other"
    if field in ("grammar_critical", "kuse_glue_anomalies"):
        return "other"
    return "other"


def _bucket_jqg(prefix: str) -> str:
    if prefix in ("ni_totte_break", "ni_taisuru_break", "ni_taishi_family_break",
                  "toshite_break", "demo_break"):
        return "hiragana_fabrication"
    if prefix in ("numeric_drop", "numeric_head_drop"):
        return "deletion_particle"
    if prefix in ("placeholder_bad",):
        return "identity_swap"
    return "other"


def _bucket_detection(detector_id: str, pattern: str) -> str:
    d = detector_id or ""
    if "particle_collision" in d:
        if pattern in ("ni_totte_misuse",) or "taisuru" in d:
            return "hiragana_fabrication"
        return "deletion_particle"   # Pattern A particle clash
    if "broken_placeholder" in d:
        return "identity_swap"
    # noun_chain(meaningless_compound), inflection, ngram, bracket, non_japanese,
    # title_body, forbidden_first_person, tsukeru → other
    return "other"


def run_union(structured) -> list[dict]:
    """3系統 + 新規検出器を走らせ unified issue list を返す(severity 正規化済)。"""
    out: list[dict] = []

    # 1) typo_correction DETECTORS (List[DetectionIssue])
    for det in DETECTORS:
        try:
            for it in det(structured):
                t = getattr(it, "type", None)
                sev = getattr(it, "severity", None)
                ev = getattr(it, "evidence", None) or {}
                did = getattr(it, "detector_id", None)
                pat = ev.get("pattern")
                out.append({
                    "source": "typo_correction", "key": did or t, "type": t,
                    "severity": sev, "bucket": _bucket_detection(did, pat),
                    "code": ev.get("code"), "subtitle_index": ev.get("subtitle_index"),
                    "pattern": pat,
                })
        except Exception:
            continue

    # 2) generation_validator (List[str] fields → severity by field name)
    crit_fields = {"grammar_critical": "critical", "particle_anomalies": "critical",
                   "solo_partner_violations": "critical", "personal_numeric_violations": "critical",
                   "misconversion_anomalies": "gate", "kuse_glue_anomalies": "gate"}
    for st in structured.get("subtitles", []) or []:
        for c in (st.get("codes") or []):
            body = c.get("body") or ""
            if not body:
                continue
            try:
                rep = validate_code(body, subtitle_index=st.get("order") or 0, code=c.get("code"))
            except Exception:
                continue
            for field, sev in crit_fields.items():
                for payload in (getattr(rep, field, None) or []):
                    out.append({
                        "source": "generation_validator", "key": field,
                        "severity": "critical" if sev == "critical" else "gate",
                        "bucket": _bucket_genval_field(field, str(payload)),
                        "code": c.get("code"), "subtitle_index": st.get("order"),
                        "payload": payload,
                    })

    # 3) japanese_quality_gate (str|None, first-match/body)
    site_id = str(structured.get("site_id") or "")
    for st in structured.get("subtitles", []) or []:
        for c in (st.get("codes") or []):
            body = c.get("body") or ""
            if not body:
                continue
            try:
                r = detect_garbage_patterns(body, site_id=site_id) if site_id else detect_garbage_patterns(body)
            except Exception:
                r = None
            if r:
                prefix = r.split(":")[0].strip()
                out.append({
                    "source": "japanese_quality_gate", "key": prefix, "severity": "critical",
                    "bucket": _bucket_jqg(prefix), "code": c.get("code"),
                    "subtitle_index": st.get("order"), "reason": r,
                })

    # 4) 新規 とても/にとって family
    out.extend(detect_totemo_nitotte(structured))
    return out


# --- depth proxy (字数 + TTR) ------------------------------------------------

def depth_proxy(structured) -> dict:
    bodies = [c.get("body") or "" for st in structured.get("subtitles", []) or []
              for c in (st.get("codes") or [])]
    char_count = sum(len(b) for b in bodies)
    types = collections.Counter()
    total = 0
    for b in bodies:  # body 単位で tokenize (sudachi の 49149byte 入力上限を回避)
        if not b:
            continue
        try:
            for t in _SUDACHI.tokenize(b, _MODE):
                if t.part_of_speech()[0] in _CONTENT_POS:
                    types[t.dictionary_form()] += 1
                    total += 1
        except Exception:
            continue
    ttr = round(len(types) / total, 4) if total else 0.0
    return {"char_count": char_count, "content_tokens": total,
            "content_types": len(types), "ttr": ttr}


# --- session 読み込み (コンテナ内 /app/data) --------------------------------

def load_session_by_ppv(ppv: str, data_dir: str = DATA_DIR):
    best, best_ts = None, ""
    for fp in glob.glob(f"{data_dir}/sessions/reg_*.json"):
        try:
            d = json.load(open(fp, encoding="utf-8"))
        except Exception:
            continue
        if str((d.get("ids") or {}).get("ppv_id")) == str(ppv):
            ts = d.get("updated_at") or d.get("created_at") or ""
            if ts >= best_ts:
                best, best_ts = d, ts
    return best


def recent_ppvs(n: int, site=None, data_dir: str = DATA_DIR) -> list[str]:
    import os
    files = sorted(glob.glob(f"{data_dir}/sessions/reg_*.json"),
                   key=os.path.getmtime, reverse=True)
    out = []
    for fp in files:
        try:
            d = json.load(open(fp, encoding="utf-8"))
        except Exception:
            continue
        ids = d.get("ids") or {}
        if site and str(ids.get("site_id")) != str(site):
            continue
        ppv = ids.get("ppv_id")
        if ppv and str(ppv) not in out:
            out.append(str(ppv))
        if len(out) >= n:
            break
    return out


# --- score one ppv ----------------------------------------------------------

def score_ppv(ppv: str, data_dir: str = DATA_DIR) -> dict:
    sess = load_session_by_ppv(ppv, data_dir)
    if not sess:
        return {"ppv": ppv, "error": "session not found"}
    product = sess.get("product") or {}
    structured = product.get("structured_manuscript") or {}
    issues = run_union(structured)

    # 4-vector CGR = bucket 別 garble 件数 (critical + gate + 新規)
    cgr = {b: 0 for b in BUCKETS}
    det_codes = set()
    for it in issues:
        if it.get("severity") in ("critical", "gate"):
            cgr[it["bucket"]] = cgr.get(it["bucket"], 0) + 1
            if it.get("code") is not None:
                det_codes.add(str(it["code"]))

    # AI 校正 critical (参照・recall 分母)
    rep = product.get("proofread_report") or {}
    ai_issues = [i for i in (rep.get("issues") or []) if i.get("severity") == "critical"]
    ai_codes = set(str(i.get("code")) for i in ai_issues if i.get("code") is not None)
    ai_types = collections.Counter(i.get("type") for i in ai_issues)

    # RECALL by code: AI-critical を持つ code を決定論ユニオンも flag したか
    covered = ai_codes & det_codes
    recall = round(len(covered) / len(ai_codes), 3) if ai_codes else None

    depth = depth_proxy(structured)
    totemo_hits = sum(1 for it in issues if it.get("source") == "totemo_nitotte")

    return {
        "ppv": ppv, "site": (sess.get("ids") or {}).get("site_id"),
        "pf_status": product.get("proofread_status"),
        "cgr": cgr, "cgr_total": sum(cgr.values()),
        "det_union_issues": len([i for i in issues if i.get("severity") in ("critical", "gate")]),
        "totemo_hits": totemo_hits,
        "ai_critical": rep.get("critical_count"),
        "ai_types": dict(ai_types),
        "recall_by_code": recall,
        "ai_codes": len(ai_codes), "det_codes": len(det_codes), "covered_codes": len(covered),
        "depth": depth,
        "_issues": [it for it in issues if it.get("severity") in ("critical", "gate")],
    }


def main():
    args = sys.argv[1:]
    if not args:
        sys.stderr.write("usage: scorer.py <ppv...> | --recent N [--site S]\n")
        sys.exit(1)
    site = None
    if "--site" in args:
        i = args.index("--site"); site = args[i + 1]; del args[i:i + 2]
    if args and args[0] == "--recent":
        ppvs = recent_ppvs(int(args[1]), site=site)
    else:
        ppvs = args

    import os
    debug = bool(os.environ.get("SI_DEBUG"))
    rows = []
    for ppv in ppvs:
        r = score_ppv(ppv)
        rows.append(r)
        if "error" in r:
            print(f"ppv={ppv} ERROR {r['error']}")
            continue
        if debug:
            for it in r.get("_issues", []):
                sys.stderr.write(f"  DBG {ppv} bucket={it['bucket']:<20} src={it['source']:<22} "
                                 f"code={it.get('code')} {it.get('why') or it.get('key') or it.get('reason') or it.get('payload')}\n")
        print(f"ppv={r['ppv']} site={r['site']} pf={r['pf_status']:<10} "
              f"CGR{ [r['cgr'][b] for b in BUCKETS] } tot={r['cgr_total']:<3} "
              f"とても={r['totemo_hits']:<3} AIcrit={r['ai_critical']:<3} "
              f"recall_code={r['recall_by_code']} (AIcodes={r['ai_codes']} covered={r['covered_codes']}) "
              f"chars={r['depth']['char_count']} ttr={r['depth']['ttr']} "
              f"AItypes={r['ai_types']}")
    # 集計
    scored = [r for r in rows if "error" not in r]
    if scored:
        tot_ai = sum((r["ai_critical"] or 0) for r in scored)
        tot_cov = sum(r["covered_codes"] for r in scored)
        tot_aicodes = sum(r["ai_codes"] for r in scored)
        agg_recall = round(tot_cov / tot_aicodes, 3) if tot_aicodes else None
        print(f"\n[AGG] n={len(scored)} AIcrit_total={tot_ai} "
              f"recall_by_code(agg)={agg_recall} (covered {tot_cov}/{tot_aicodes} AI-critical codes)")
    # JSONL も stdout 末尾に (パイプ集計用・行頭 @JSON で識別)
    for r in rows:
        r2 = {k: v for k, v in r.items() if k != "_issues"}
        print("@JSON " + json.dumps(r2, ensure_ascii=False))


if __name__ == "__main__":
    main()
