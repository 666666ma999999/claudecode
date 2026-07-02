#!/usr/bin/env python3
"""
regen.py — headless STEP1 再生成エンジン (offline_screen の核心)。

捕捉済み ppv の入力を使い、**候補プロンプトを適用して原稿を1本 headless 再生成**し、
(structured_manuscript, proofread_critical, 実USD) を JSON で返す。ブラウザ/CMS は走らない。

★ backend コンテナ内で実行 (import main が必須)。host では動かない。
★ 安全隔離: ROHAN_DATA_DIR=/tmp/... で本番 sessions/usage/PPVカウンタを汚さない・本番PPV番号を消費しない。
★ 候補プロンプトは prompt_loader を in-process 差替 (ファイル不触)。
★ REGENERATE_ON_CRITICAL=false で first-pass garble を安く測定。

入力 (stdin JSON):
  {"capture": <_corpus/<ppv>.json の中身>, "candidate_prompt": "<差替える AiUranaiManuscriptPrompt 全文 or null>"}
  candidate_prompt=null なら baseline (現行プロンプト) で再生成。

出力 (stdout JSON, 行頭 @RESULT):
  {"ppv","reg_id","ok","proofread_critical","char_count","usd","error"}

呼び出し例 (loop.py offline_screen から):
  cat job.json | docker compose exec -T backend python - < tools/selfimprove/regen.py
"""
import os
import sys
import json
import glob

# --- env は import main より前に設定 (隔離・first-pass・実験タグ) ---------
ISO_DATA = os.environ.get("ROHAN_SELFIMPROVE_ISO_DATA", "/tmp/selfimprove_iso_data")
os.environ["ROHAN_DATA_DIR"] = ISO_DATA            # sessions/usage/PPVカウンタを隔離
os.environ.setdefault("REGENERATE_ON_CRITICAL", "false")  # first-pass 測定 (regen 課金なし)
os.environ.setdefault("ROHAN_USAGE_TAG", "experiment")    # 本番 usage 集計から除外可能に
os.makedirs(ISO_DATA, exist_ok=True)
os.makedirs(os.path.join(ISO_DATA, "sessions"), exist_ok=True)


def _read_usd(reg_id: str) -> float:
    tot = 0.0
    for fn in ("gpt_usage.jsonl", "gemini_usage.jsonl"):
        p = os.path.join(ISO_DATA, fn)
        if not os.path.exists(p):
            continue
        with open(p, encoding="utf-8") as f:
            for line in f:
                try:
                    r = json.loads(line)
                    if str(r.get("reg")) == str(reg_id):
                        tot += float(r.get("est_usd") or r.get("usd") or 0)
                except Exception:
                    pass
    return round(tot, 4)


async def _run(capture: dict, candidate_prompt):
    import main  # noqa: F401  gemini_api.init / genai.configure / set_data_dir を実行 (必須)
    from core.manuscript import prompt_loader
    import utils.helpers as helpers

    # 1) 候補プロンプトを in-process 差替 (AiUranaiManuscriptPrompt のみ・他は素通し)
    _orig = prompt_loader.load_prompt_file
    if candidate_prompt:
        def _patched(prompt_path, task_name=""):
            if str(prompt_path).endswith("AiUranaiManuscriptPrompt.md"):
                return candidate_prompt
            return _orig(prompt_path, task_name)
        prompt_loader.load_prompt_file = _patched
        helpers.load_prompt_file = _patched
        prompt_loader.clear_cache()

    try:
        # 2) fresh session (idempotency no-op 回避)
        from routers.registration_session import CreateSessionRequest, create_session, get_session
        ids = capture.get("ids") or {}
        inp = capture.get("input") or {}
        cfg = inp.get("config") or {}
        site_id = ids.get("site_id")
        sess = await create_session(request=CreateSessionRequest(site_id=site_id))
        session_id = sess["record"]["session_id"]

        # 3) 捕捉入力から input_a / input_b を再構成 (csv_batch_runner の builder を再利用)
        from services.csv_batch_runner import build_input_a, build_input_b
        title = inp.get("title") or ""
        # subtitles は構造化出力から (順序保持)
        sm = (capture.get("output") or {}).get("structured_manuscript") or {}
        subtitles = [st.get("title") for st in (sm.get("subtitles") or []) if st.get("title")]
        theme = inp.get("csv_row_text") or cfg.get("theme") or ""
        logic_name = cfg.get("logic_name") or ""
        char_count = cfg.get("char_count") or 0
        input_a = build_input_a_safe(build_input_a, title, subtitles)
        input_b = build_input_b_safe(build_input_b, theme, site_id, logic_name, char_count, title, subtitles)

        # 4) headless STEP1
        from extensions.step1_generation.pipeline import Step1Pipeline
        res = await Step1Pipeline().execute(
            session_id=session_id, input_a=input_a, input_b=input_b,
            mode="manual", site_id=site_id,
            title=title,
            generate_opening=bool(cfg.get("generate_opening", True)),
            generate_closing=bool(cfg.get("generate_closing", True)),
            price=cfg.get("price", 0) or 0,
            mid_id=str(ids.get("mid_id") or cfg.get("mid_id") or ""),
            category_num=str(cfg.get("category_num") or ""),
            wait_for_background=True,
        )
        reg_id = res.record_id or session_id
        rec = get_session(reg_id)
        product = getattr(rec, "product", None)
        structured = getattr(product, "structured_manuscript", None) or {}
        rep = getattr(product, "proofread_report", None) or {}
        bodies = [c.get("body") or "" for st in (structured.get("subtitles") or [])
                  for c in (st.get("codes") or [])]
        return {
            "ppv": capture.get("ppv_id"), "reg_id": reg_id,
            "ok": bool(getattr(res, "success", False)),
            "proofread_critical": int(rep.get("critical_count") or 0),
            "char_count": sum(len(b) for b in bodies),
            "structured": structured,
            "usd": _read_usd(reg_id),
            "error": getattr(res, "error", None) or getattr(res, "fatal_error", None),
        }
    finally:
        if candidate_prompt:
            prompt_loader.load_prompt_file = _orig
            helpers.load_prompt_file = _orig
            prompt_loader.clear_cache()


def build_input_a_safe(fn, title, subtitles):
    """build_input_a は product-like を要求する場合があるため shim 経由で呼ぶ。"""
    try:
        return fn(title, subtitles)
    except TypeError:
        # product オブジェクト型シグネチャの場合
        class _P:  # minimal product surrogate
            pass
        p = _P(); p.title = title; p.subtitles = subtitles
        return fn(p)


def build_input_b_safe(fn, theme, site_id, logic_name, char_count, title, subtitles):
    try:
        return fn(theme, site_id, logic_name, char_count, title, subtitles)
    except TypeError:
        return fn(theme=theme, site_id=site_id, logic_name=logic_name,
                  char_count=char_count, title=title, subtitles=subtitles)


def main_entry():
    raw = sys.stdin.read()
    job = json.loads(raw)
    capture = job["capture"]
    candidate_prompt = job.get("candidate_prompt")
    import asyncio
    try:
        out = asyncio.run(_run(capture, candidate_prompt))
    except Exception as e:
        import traceback
        out = {"ppv": (capture or {}).get("ppv_id"), "ok": False,
               "error": f"{type(e).__name__}: {e}", "trace": traceback.format_exc()[-800:]}
    print("@RESULT " + json.dumps(out, ensure_ascii=False))


if __name__ == "__main__":
    main_entry()
