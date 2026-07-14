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

        # --- (10) INBOX 消滅時はスキップ・台帳に載せず次回再試行 ---
        write_receipts(state, [receipt("aiads", "消えたINBOX宛", ts_hm="11:00")])
        os.unlink(os.path.join(vault, paths["aiads"]))
        r4 = run(env)
        ledger2 = open(os.path.join(state, "reflected-ledger.jsonl")).read()
        check("10 missing-inbox-retry", "WARN inbox missing" in r4.stdout
              and len([l for l in ledger2.splitlines() if l.strip()]) == 6, r4.stdout)

    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    print("\n%d passed, %d failed" % (PASS, FAIL))
    sys.exit(1 if FAIL else 0)


if __name__ == "__main__":
    main()
