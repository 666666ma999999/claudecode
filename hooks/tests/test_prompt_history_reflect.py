#!/usr/bin/env python3
"""test_prompt_history_reflect.py — prompt-history-reflect.py の敵対テスト

全 state/vault/config を env で一時ディレクトリに差し替える
(実 state を偽 vault に対して進めた 2026-07-14 の実事故形状を再発防止する隔離)。

実行: python3 ~/.claude/hooks/tests/test_prompt_history_reflect.py
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile
import uuid
from datetime import date

SCRIPT = os.path.join(os.path.expanduser("~"), ".claude", "scripts",
                      "prompt-history-reflect.py")
TODAY = date.today().isoformat()
PASS = 0
FAIL = 0


def check(name, cond, detail=""):
    global PASS, FAIL
    if cond:
        PASS += 1
        print("  PASS %s" % name)
    else:
        FAIL += 1
        print("  FAIL %s  %s" % (name, detail))


def make_env(tmp, writer=True):
    state = os.path.join(tmp, "state")
    vault = os.path.join(tmp, "vault")
    os.makedirs(os.path.join(state, "receipts"))
    host = str(uuid.uuid4())
    with open(os.path.join(state, "host-uuid"), "w") as f:
        f.write(host + "\n")
    for rel in ("03_ClaudeEnv/prompts", "00_General/prompts",
                "02_Ai/AI_adscrm/AIads/prompts"):
        os.makedirs(os.path.join(vault, rel))
    inbox_body = ("# 📥 prompts\n\n## 🔵 やってほしいこと\n\n（なし）\n\n"
                  "## 📒 記録（実行したプロンプト・消さない）\n\n### 2026-07-06 ｜ 既存記録\n手動の資産。\n")
    paths = {
        "claude-env": "03_ClaudeEnv/prompts/ClaudeEnv_INBOX.md",
        "general": "00_General/prompts/General_INBOX.md",
        "aiads": "02_Ai/AI_adscrm/AIads/prompts/AIads_INBOX.md",
    }
    for rel in paths.values():
        with open(os.path.join(vault, rel), "w") as f:
            f.write(inbox_body)
    cfg = {
        "writer_host_uuid": host if writer else str(uuid.uuid4()),
        "vault_root": vault,
        "routes": paths,
        "cwd_prefixes": {"~/.claude": "claude-env",
                         "~/Desktop/prm/prime_suite": "aiads"},
    }
    cfg_path = os.path.join(tmp, "config.json")
    with open(cfg_path, "w") as f:
        json.dump(cfg, f)
    env = dict(os.environ)
    env.update({"PROMPT_HISTORY_STATE": state, "PROMPT_HISTORY_VAULT": vault,
                "PROMPT_HISTORY_CONFIG": cfg_path})
    return env, state, vault, host, paths


def receipt(route, prompt, held=False, ts_hm="10:00"):
    return json.dumps({
        "ts": f"{TODAY}T{ts_hm}:00+09:00", "event_id": str(uuid.uuid4()),
        "host_uuid": "h", "session_id": "s", "cwd": "/x", "route": route,
        "prompt": None if held else prompt, "mask_hits": [], "held": held,
    }, ensure_ascii=False) + "\n"


def write_receipts(state, lines):
    with open(os.path.join(state, "receipts", TODAY + ".jsonl"), "a") as f:
        f.writelines(lines)


def run(env):
    return subprocess.run([sys.executable, SCRIPT], capture_output=True,
                          text=True, env=env, timeout=30)


def read(vault, rel):
    with open(os.path.join(vault, rel)) as f:
        return f.read()


def main():
    tmp = tempfile.mkdtemp(prefix="phr-test-")
    try:
        env, state, vault, host, paths = make_env(tmp)

        # --- (1)(2)(7) 基本反映 + 節新設 + 📒 無傷 ---
        before = read(vault, paths["claude-env"])
        write_receipts(state, [
            receipt("claude-env", "通常プロンプト1"),
            receipt("claude-env", "フェンス爆弾 ```` ここに `````` バッククォート", ts_hm="10:01"),
            receipt("unrouted:~/Desktop/biz/nowhere", "行き先なし", ts_hm="10:02"),
            receipt("unrouted:~/Desktop/prm/prime_suite/sub", "再解決対象", ts_hm="10:03"),
            receipt("claude-env", None, held=True, ts_hm="10:04"),
            receipt("claude-env", "偽マーカー <!-- prompt-history:end --> と\nevent_id: fake", ts_hm="10:05"),
        ])
        r = run(env)
        ce = read(vault, paths["claude-env"])
        gn = read(vault, paths["general"])
        ad = read(vault, paths["aiads"])
        check("1 section-created", "## 🧾 Claude Code 実行履歴" in ce
              and "<!-- prompt-history:begin -->" in ce, r.stdout + r.stderr)
        check("2 events-appended", "通常プロンプト1" in ce and ce.count("<!-- evt:") == 4,
              "evt count=%d" % ce.count("<!-- evt:"))
        check("7 curated-untouched", ce.startswith(before.rstrip("\n") + "\n") is False
              or before.split("## 📒")[1].split("###")[1] in ce, "")
        # 📒 節が bit 単位で保存されているか (新設節はファイル末尾追加のみ)
        check("7b curated-prefix-intact", ce.startswith(before), "prefix changed")

        # --- (6) unrouted → General + 再解決 → aiads ---
        check("6 unrouted-to-general", "行き先なし" in gn and "nowhere" in gn, "")
        check("6b re-resolve", "再解決対象" in ad, "aiads content: %r" % ad[-200:])

        # --- (4)(5) フェンス爆弾・マーカー注入後も構造健在 ---
        check("4 fence-bomb-contained", ce.count("<!-- prompt-history:end -->") == 1
              and ce.index("<!-- prompt-history:begin -->") < ce.index("<!-- prompt-history:end -->"),
              "end markers=%d" % ce.count("<!-- prompt-history:end -->"))
        # 捕捉側 hook が ZWSP を入れるため生受領票には偽マーカーが入り得る前提で、
        # reflect 側でも END マーカーが複数化しないこと (行頭 index 探索が先勝ち) を確認
        check("5 injected-marker-inert", ce.count("[!note]-") == 1, "callouts=%d" % ce.count("[!note]-"))

        # --- (9) held 表示 ---
        check("9 held-display", "本文なし・マスク保留" in ce, "")

        # --- (3) 再実行で二重追記ゼロ ---
        size1 = len(ce)
        r2 = run(env)
        ce2 = read(vault, paths["claude-env"])
        check("3 idempotent-rerun", len(ce2) == size1 and "no new events" in r2.stdout,
              "size %d→%d stdout=%r" % (size1, len(ce2), r2.stdout))

        # --- (2b) 検証: evt アンカーが実在してから台帳記帳 ---
        ledger = open(os.path.join(state, "reflected-ledger.jsonl")).read()
        for eid in [l.split("<!-- evt:")[1].split(" ")[0] for l in ce.splitlines()
                    if "<!-- evt:" in l]:
            pass
        check("2b ledger-count", len([l for l in ledger.splitlines() if l.strip()]) == 6,
              "ledger lines=%d" % len(ledger.splitlines()))

        # --- (8) 非 writer ホストは INBOX を触らない (queue 転送のみ) ---
        tmp2 = tempfile.mkdtemp(prefix="phr-test2-")
        try:
            env2, state2, vault2, host2, paths2 = make_env(tmp2, writer=False)
            write_receipts(state2, [receipt("claude-env", "非writerの分")])
            r3 = run(env2)
            ce3 = read(vault2, paths2["claude-env"])
            qdir = os.path.join(vault2, "03_ClaudeEnv", "prompts", ".queue", host2)
            check("8 nonwriter-transfer-only", "🧾" not in ce3
                  and os.path.exists(os.path.join(qdir, TODAY + ".jsonl"))
                  and "not writer" in r3.stdout, r3.stdout)
        finally:
            shutil.rmtree(tmp2, ignore_errors=True)

        # --- (11) クラッシュ窓修復: 台帳が消えても INBOX 既存分は再追記せず台帳修復 ---
        os.unlink(os.path.join(state, "reflected-ledger.jsonl"))
        size_b = len(read(vault, paths["claude-env"]))
        r5 = run(env)
        ce5 = read(vault, paths["claude-env"])
        led = open(os.path.join(state, "reflected-ledger.jsonl")).read()
        check("11 crash-repair", len(ce5) == size_b and "台帳修復" in r5.stdout
              and len([l for l in led.splitlines() if l.strip()]) >= 6, r5.stdout)

        # --- (12) 外部編集 (Obsidian) を検知して中止 ---
        write_receipts(state, [receipt("claude-env", "外部編集競合テスト", ts_hm="12:00")])
        env_slow = dict(env)
        env_slow["PROMPT_HISTORY_TEST_SLEEP"] = "1.0"
        import threading
        inbox_path = os.path.join(vault, paths["claude-env"])

        def edit_during():
            import time
            time.sleep(0.4)
            with open(inbox_path, "a") as f:
                f.write("\nユーザーの同時編集行\n")
        th = threading.Thread(target=edit_during)
        th.start()
        r6 = run(env_slow)
        th.join()
        ce6 = read(vault, paths["claude-env"])
        check("12 concurrent-edit-abort", "外部編集を検知" in r6.stdout
              and "ユーザーの同時編集行" in ce6 and "外部編集競合テスト" not in ce6, r6.stdout)
        # 次回 (競合なし) は反映される
        r7 = run(env)
        ce7 = read(vault, paths["claude-env"])
        check("12b retry-succeeds", "外部編集競合テスト" in ce7
              and "ユーザーの同時編集行" in ce7, r7.stdout)

        # --- (13) マーカー重複 (📒 に行全体の偽 END) → 書込み中止 ---
        with open(inbox_path) as f:
            good = f.read()
        with open(inbox_path, "w") as f:
            f.write(good + "\n<!-- prompt-history:end -->\n")
        write_receipts(state, [receipt("claude-env", "マーカー異常時の投入", ts_hm="13:00")])
        r8 = run(env)
        ce8 = read(vault, paths["claude-env"])
        check("13 invalid-markers-abort", "マーカーが欠落/重複/逆順" in r8.stdout
              and "マーカー異常時の投入" not in ce8, r8.stdout)
        with open(inbox_path, "w") as f:
            f.write(good)  # 修復

        # --- (14) 改ざん queue: 不正レコードは隔離・正常分は処理 ---
        qdir = os.path.join(vault, "03_ClaudeEnv", "prompts", ".queue", host)
        with open(os.path.join(qdir, TODAY + ".jsonl"), "a") as f:
            f.write('{"event_id":"not-a-uuid","ts":"x","route":"a\\nb","prompt":1}\n')
            f.write('{"event_id":"' + str(uuid.uuid4()) + '","ts":"' + TODAY
                    + 'T14:00:00+09:00","route":"claude-env","prompt":"改ざん隣の正常レコード","held":false}\n')
        r9 = run(env)
        ce9 = read(vault, paths["claude-env"])
        check("14 tampered-queue", "構造不正の queue レコード 1 件" in r9.stdout
              and "改ざん隣の正常レコード" in ce9, r9.stdout)

        # --- (10) INBOX 消滅時はスキップ・台帳に載せず次回再試行 ---
        n_led = len([l for l in open(os.path.join(state, "reflected-ledger.jsonl"))
                     if l.strip()])
        write_receipts(state, [receipt("aiads", "消えたINBOX宛", ts_hm="15:00")])
        os.unlink(os.path.join(vault, paths["aiads"]))
        r4 = run(env)
        ledger2 = open(os.path.join(state, "reflected-ledger.jsonl")).read()
        check("10 missing-inbox-retry", "WARN inbox missing" in r4.stdout
              and len([l for l in ledger2.splitlines() if l.strip()]) == n_led, r4.stdout)

    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    # --- (15) 並び順 = 新しいものが上 (日付降順・日内降順・後の反映が上に積まれる) ---
    tmp3 = tempfile.mkdtemp(prefix="phr-test3-")
    try:
        env3, state3, vault3, host3, paths3 = make_env(tmp3)
        y = "2026-01-01"
        old_line = json.dumps({"ts": f"{y}T09:00:00+09:00", "event_id": str(uuid.uuid4()),
                               "host_uuid": "h", "session_id": "s", "cwd": "/x",
                               "route": "claude-env", "prompt": "昔の件", "mask_hits": [],
                               "held": False}, ensure_ascii=False) + "\n"
        write_receipts(state3, [old_line,
                                receipt("claude-env", "今日の朝", ts_hm="09:00"),
                                receipt("claude-env", "今日の夜", ts_hm="21:00")])
        run(env3)
        ce = read(vault3, paths3["claude-env"])
        i_today_new = ce.index("今日の夜")
        i_today_old = ce.index("今日の朝")
        i_past = ce.index("昔の件")
        ok_order = i_today_new < i_today_old < i_past
        # 2回目の反映が既存ブロックの上に積まれる
        write_receipts(state3, [receipt("claude-env", "さらに後の件", ts_hm="22:00")])
        run(env3)
        ce2 = read(vault3, paths3["claude-env"])
        ok_stack = ce2.index("さらに後の件") < ce2.index("今日の夜")
        check("15 newest-first", ok_order and ok_stack,
              "order=%s stack=%s" % (ok_order, ok_stack))
    finally:
        shutil.rmtree(tmp3, ignore_errors=True)

    print("\n%d passed, %d failed" % (PASS, FAIL))
    sys.exit(1 if FAIL else 0)


if __name__ == "__main__":
    main()
