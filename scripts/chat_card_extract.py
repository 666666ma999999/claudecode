#!/usr/bin/env python3
"""chat_card_extract.py — Google Chat の増分メッセージを収集（承認カードの入力・決定論パート）

- gog CLI で全スペースの最新メッセージを取得し、last_run 以降 & 本人以外の発言だけを抽出
- スレッド文脈（同スレッドの直近数件）も添える
- ~/.claude/state/chat-cards/worklist.json に書き出す（runner プロンプトが Read する）
本人許可: 2026-07-16 業務Chatの常設AI処理を本人（事業責任者）権限で許容済み。ローカル処理・社外共有なし。
"""
import json, os, subprocess, sys
from datetime import datetime, timedelta, timezone

HOME = os.path.expanduser("~")
STATE_DIR = os.path.join(HOME, ".claude/state/chat-cards")
LAST_RUN_F = os.path.join(STATE_DIR, "last_run.txt")
CANDIDATE_F = os.path.join(STATE_DIR, "last_run_candidate.txt")  # apply 成功時のみ昇格（commit-on-success）
OUT = os.path.join(STATE_DIR, "worklist.json")
SELF_ID = "users/102884527284642128717"  # MASA（2026-07-13 実測同定: 90スペース・最多発言）
MAX_PER_SPACE = 50  # 夜間バックログ(21→8時)でも1スペース50件あれば取りこぼさない

def gog(args):
    r = subprocess.run(["gog"] + args, capture_output=True, text=True, timeout=120)
    if r.returncode != 0:
        raise RuntimeError(f"gog {' '.join(args)}: {r.stderr[:200]}")
    return r.stdout

def get_last_run():
    if os.path.exists(LAST_RUN_F):
        return datetime.fromisoformat(open(LAST_RUN_F).read().strip())
    return datetime.now(timezone.utc) - timedelta(hours=48)  # 初回=48時間

def main():
    os.makedirs(STATE_DIR, exist_ok=True)
    last_run = get_last_run()
    started = datetime.now(timezone.utc)

    spaces = []
    for line in gog(["chat", "spaces", "list", "--plain"]).splitlines()[1:]:
        parts = line.split("\t")
        if parts and parts[0].startswith("spaces/"):
            spaces.append({"id": parts[0], "name": parts[1] if len(parts) > 1 else "", "type": parts[2] if len(parts) > 2 else ""})

    items = []
    for sp in spaces:
        try:
            data = json.loads(gog(["chat", "messages", "list", sp["id"], "--json", "--max", str(MAX_PER_SPACE), "--order", "createTime desc"]))
        except Exception as e:
            print(f"[warn] {sp['id']}: {e}", file=sys.stderr)
            continue
        msgs = data.get("messages", [])
        # createTime 昇順とは限らないため全件見る
        fresh = []
        for m in msgs:
            ct = m.get("createTime", "")
            try:
                t = datetime.fromisoformat(ct.replace("Z", "+00:00"))
            except Exception:
                continue
            if t > last_run and m.get("sender") != SELF_ID and (m.get("text") or "").strip():
                fresh.append(m)
        if not fresh:
            continue
        # スレッド文脈: 同スペースの直近メッセージ（送信者匿名の下6桁）を添付
        ctx = [{"sender": (m.get("sender") or "")[-6:], "text": (m.get("text") or "")[:200], "t": m.get("createTime", "")}
               for m in list(reversed(msgs))[-6:]]
        for m in fresh:
            items.append({
                "space": sp["name"] or sp["id"],
                "space_type": sp["type"],
                "sender_tail": (m.get("sender") or "")[-6:],
                "text": (m.get("text") or "")[:1500],
                "time": m.get("createTime", ""),
                "thread": m.get("thread", ""),
                "context": ctx,
            })

    payload = {
        "generated_at": started.astimezone().isoformat(timespec="seconds"),
        "window_from": last_run.astimezone().isoformat(timespec="seconds"),
        "self_id_tail": SELF_ID[-6:],
        "items": items,
    }
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=1)
    # last_run はここでは前進させない。apply 成功後に candidate を昇格する
    # （runner/apply が落ちた批を次回再抽出できるように。重複カードは見える事故・欠落は見えない事故）
    open(CANDIDATE_F, "w").write(started.isoformat())
    print(f"[ok] spaces={len(spaces)} new_items={len(items)} window_from={last_run.isoformat()} -> {OUT}")

if __name__ == "__main__":
    main()
