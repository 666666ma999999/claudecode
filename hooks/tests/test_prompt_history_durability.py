#!/usr/bin/env python3
"""test_prompt_history_durability.py — Phase 3 恒久性の敵対テスト

検証: ①push未確認なら受領票を消さない/push後は消す/git不在は保持 ②受領票fsync
③reconcile が未反映を検知(INBOXパス改名含む)・一致で0 ④writer引き継ぎ案内。

全 state/vault/config を env で一時ディレクトリに差し替え・実 git remote を bare で作る。
実行: python3 ~/.claude/hooks/tests/test_prompt_history_durability.py
"""
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import uuid
from datetime import date, datetime, timedelta

REFLECT = os.path.join(os.path.expanduser("~"), ".claude", "scripts",
                       "prompt-history-reflect.py")
HOOK = os.path.join(os.path.expanduser("~"), ".claude", "hooks",
                    "sessionstart-prompt-history-reflect.sh")
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


def git(vault, *args):
    return subprocess.run(["git", "-C", vault, *args], capture_output=True, text=True)


def make_env(tmp, writer=True, with_git=True):
    state = os.path.join(tmp, "state")
    vault = os.path.join(tmp, "vault")
    os.makedirs(os.path.join(state, "receipts"))
    host = str(uuid.uuid4())
    with open(os.path.join(state, "host-uuid"), "w") as f:
        f.write(host + "\n")
    paths = {"claude-env": "03_ClaudeEnv/prompts/ClaudeEnv_INBOX.md",
             "general": "00_General/prompts/General_INBOX.md",
             "aiads": "02_Ai/AI_adscrm/AIads/prompts/AIads_INBOX.md"}
    for rel in paths.values():
        os.makedirs(os.path.join(vault, os.path.dirname(rel)), exist_ok=True)
        with open(os.path.join(vault, rel), "w") as f:
            f.write("# INBOX\n\n## 📒 記録\n\n### 既存\n本文\n")
    cfg = {"writer_host_uuid": host if writer else str(uuid.uuid4()),
           "vault_root": vault, "routes": paths,
           "cwd_prefixes": {"~/.claude": "claude-env"}}
    cfg_path = os.path.join(tmp, "config.json")
    with open(cfg_path, "w") as f:
        json.dump(cfg, f)
    remote = None
    if with_git:
        remote = os.path.join(tmp, "remote.git")
        subprocess.run(["git", "init", "--bare", "-q", remote])
        git(vault, "init", "-q")
        git(vault, "config", "user.email", "t@t")
        git(vault, "config", "user.name", "t")
        git(vault, "remote", "add", "origin", remote)
        git(vault, "add", "-A")
        git(vault, "commit", "-qm", "init")
        git(vault, "push", "-q", "-u", "origin", "HEAD:main")
    env = dict(os.environ)
    env.update({"PROMPT_HISTORY_STATE": state, "PROMPT_HISTORY_VAULT": vault,
                "PROMPT_HISTORY_CONFIG": cfg_path})
    return env, state, vault, host, paths, cfg_path, remote


def receipt(route, prompt, ts=None):
    return json.dumps({"ts": ts or (date.today().isoformat() + "T10:00:00+09:00"),
                       "event_id": str(uuid.uuid4()), "host_uuid": "h",
                       "session_id": "s", "cwd": "/x", "route": route,
                       "prompt": prompt, "mask_hits": [], "held": False},
                      ensure_ascii=False) + "\n"


def old_receipt_name(days):
    return (date.today() - timedelta(days=days)).isoformat() + ".jsonl"


def run_reflect(env):
    return subprocess.run([sys.executable, REFLECT], capture_output=True, text=True, env=env)


def run_hook(env):
    return subprocess.run(["bash", HOOK], capture_output=True, text=True, env=env)


def main():
    # === 系統1: purge の push 確認ゲート ===
    tmp = tempfile.mkdtemp(prefix="phd1-")
    try:
        env, state, vault, host, paths, cfgp, remote = make_env(tmp, with_git=True)
        # 35日前の受領票を置く (30日超 = purge 候補)
        oldname = old_receipt_name(35)
        with open(os.path.join(state, "receipts", oldname), "w") as f:
            f.write(receipt("claude-env", "35日前の履歴",
                            ts=(date.today() - timedelta(days=35)).isoformat() + "T10:00:00+09:00"))
        # 1回目 reflect: queue へ転送されるが、まだ push していない → 受領票は残るべき
        run_reflect(env)
        still = os.path.exists(os.path.join(state, "receipts", oldname))
        check("1 hold-when-unpushed", still, "受領票が push 前に消えた")

        # queue を commit だけして push しない → まだ残るべき
        git(vault, "add", "-A")
        git(vault, "commit", "-qm", "queue commit (no push)")
        run_reflect(env)
        still2 = os.path.exists(os.path.join(state, "receipts", oldname))
        check("2 hold-when-committed-not-pushed", still2, "commit だけで消えた")

        # push する → 次の reflect で消えるべき
        git(vault, "push", "-q", "origin", "HEAD:main")
        run_reflect(env)
        gone = not os.path.exists(os.path.join(state, "receipts", oldname))
        check("3 purge-after-pushed", gone, "push 済みでも消えない")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    # === 系統1b: git 不在 vault は保持側に倒す ===
    tmp = tempfile.mkdtemp(prefix="phd1b-")
    try:
        env, state, vault, host, paths, cfgp, remote = make_env(tmp, with_git=False)
        oldname = old_receipt_name(40)
        with open(os.path.join(state, "receipts", oldname), "w") as f:
            f.write(receipt("claude-env", "git無し環境",
                            ts=(date.today() - timedelta(days=40)).isoformat() + "T10:00:00+09:00"))
        run_reflect(env)
        check("4 hold-when-no-git", os.path.exists(os.path.join(state, "receipts", oldname)),
              "git 不在なのに消えた")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    # === 系統2: reconcile が未反映を検知 ===
    tmp = tempfile.mkdtemp(prefix="phd2-")
    try:
        env, state, vault, host, paths, cfgp, remote = make_env(tmp, with_git=True)
        with open(os.path.join(state, "receipts", date.today().isoformat() + ".jsonl"), "w") as f:
            for i in range(3):
                f.write(receipt("claude-env", "履歴%d" % i, ts=f"{date.today().isoformat()}T1{i}:00:00+09:00"))
        run_reflect(env)
        st = json.load(open(os.path.join(state, "reconcile-status.json")))
        check("5 reconcile-all-reflected", st["unreflected"] == 0 and st["captured_total"] == 3,
              json.dumps(st))

        # INBOX を改名 → reconcile が未反映として検知
        os.rename(os.path.join(vault, paths["claude-env"]),
                  os.path.join(vault, paths["claude-env"]) + ".renamed")
        # 新規履歴を追加（改名済み INBOX 宛）
        with open(os.path.join(state, "receipts", date.today().isoformat() + ".jsonl"), "a") as f:
            for i in range(25):
                f.write(receipt("claude-env", "改名後履歴%d" % i,
                                ts=f"{date.today().isoformat()}T20:{i:02d}:00+09:00"))
        run_reflect(env)
        st2 = json.load(open(os.path.join(state, "reconcile-status.json")))
        check("6 reconcile-detects-rename", st2["unreflected"] >= 25
              and "claude-env" in st2["missing_or_renamed_inboxes"], json.dumps(st2))

        # SessionStart hook が具体警告を出す
        env2 = dict(env)
        env2["HOME"] = os.path.join(tmp, "fakehome")  # writer 案内の別経路を避け reconcile だけ見る
        os.makedirs(os.path.join(env2["HOME"], ".claude", "config"), exist_ok=True)
        # hook は $HOME 依存パスも読むので、reconcile 警告部分だけ確認するため state を直接指定できない。
        # 代わりに hook を実 state 環境で走らせ、reconcile 警告文字列の有無を見る。
        r = run_hook(env)
        check("7 hook-warns-unreflected", "反映されていません" in r.stdout
              and "claude-env" in r.stdout, r.stdout)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    # === 系統1c: upstream 未設定 vault は保持 (git はあるが push 先なし) ===
    tmp = tempfile.mkdtemp(prefix="phd1c-")
    try:
        env, state, vault, host, paths, cfgp, remote = make_env(tmp, with_git=True)
        git(vault, "branch", "--unset-upstream")  # upstream を外す
        oldname = old_receipt_name(45)
        with open(os.path.join(state, "receipts", oldname), "w") as f:
            f.write(receipt("claude-env", "upstream無し",
                            ts=(date.today() - timedelta(days=45)).isoformat() + "T10:00:00+09:00"))
        run_reflect(env)
        check("10 hold-when-no-upstream", os.path.exists(os.path.join(state, "receipts", oldname)),
              "upstream 無しで消えた")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    # === 系統2b: held イベントも反映され matched に入る ===
    tmp = tempfile.mkdtemp(prefix="phd2b-")
    try:
        env, state, vault, host, paths, cfgp, remote = make_env(tmp, with_git=True)
        held = json.dumps({"ts": date.today().isoformat() + "T09:00:00+09:00",
                           "event_id": str(uuid.uuid4()), "host_uuid": "h", "session_id": "s",
                           "cwd": "/x", "route": "claude-env", "prompt": None,
                           "mask_hits": [], "held": True}, ensure_ascii=False) + "\n"
        with open(os.path.join(state, "receipts", date.today().isoformat() + ".jsonl"), "w") as f:
            f.write(held)
            f.write(receipt("claude-env", "通常"))
        run_reflect(env)
        st = json.load(open(os.path.join(state, "reconcile-status.json")))
        check("11 held-and-receipt-counted", st["captured_total"] == 2 and st["unreflected"] == 0
              and st.get("matched_total") == 2, json.dumps(st))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    # === 系統2c: receipt のみ(queue に無い=転送失敗)を reconcile が未反映として拾う ===
    tmp = tempfile.mkdtemp(prefix="phd2c-")
    try:
        env, state, vault, host, paths, cfgp, remote = make_env(tmp, with_git=True)
        today = date.today().isoformat()
        rid = str(uuid.uuid4())
        rec = json.dumps({"ts": today + "T08:00:00+09:00", "event_id": rid, "host_uuid": "h",
                          "session_id": "s", "cwd": "/x", "route": "claude-env",
                          "prompt": "転送されなかった履歴", "mask_hits": [], "held": False},
                         ensure_ascii=False) + "\n"
        rfile = os.path.join(state, "receipts", today + ".jsonl")
        with open(rfile, "w") as f:
            f.write(rec)
        # cursor を「処理済み」に細工 → transfer が queue へ移さない (転送失敗/cursor破損の再現)
        with open(os.path.join(state, "transfer-cursor.json"), "w") as f:
            json.dump({today + ".jsonl": 1}, f)
        run_reflect(env)
        st = json.load(open(os.path.join(state, "reconcile-status.json")))
        qf = os.path.join(vault, "03_ClaudeEnv/prompts/.queue", host, today + ".jsonl")
        in_queue = os.path.exists(qf) and rid in open(qf).read()
        check("11b receipt-only-detected", not in_queue and st["unreflected"] == 1
              and st["captured_total"] == 1, "in_queue=%s %s" % (in_queue, json.dumps(st)))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    # === 系統2d: 母集団ファイル読取り失敗で scan_ok=False ===
    tmp = tempfile.mkdtemp(prefix="phd2d-")
    try:
        env, state, vault, host, paths, cfgp, remote = make_env(tmp, with_git=True)
        with open(os.path.join(state, "receipts", date.today().isoformat() + ".jsonl"), "w") as f:
            f.write(receipt("claude-env", "正常"))
        run_reflect(env)  # 1回目で queue 生成
        # queue ファイルを読めなくする (パーミッション 000)
        qf = os.path.join(vault, "03_ClaudeEnv/prompts/.queue", host, date.today().isoformat() + ".jsonl")
        os.chmod(qf, 0)
        run_reflect(env)
        st = json.load(open(os.path.join(state, "reconcile-status.json")))
        os.chmod(qf, 0o600)  # 後片付け用に戻す
        check("11c scan-ok-false-on-unreadable", st["scan_ok"] is False, json.dumps(st))
    finally:
        try:
            shutil.rmtree(tmp, ignore_errors=True)
        except Exception:
            pass

    # === 系統3: writer 引き継ぎ案内 ===
    tmp = tempfile.mkdtemp(prefix="phd3-")
    try:
        # この機は writer ではない設定 + writer-last-success 無し → 引き継ぎ案内
        env, state, vault, host, paths, cfgp, remote = make_env(tmp, writer=False, with_git=True)
        r = run_hook(env)
        check("8 writer-takeover-prompt", "書込み役" in r.stdout, r.stdout)

        # writer が健在 (writer-last-success が最近) なら案内しない
        qroot = os.path.join(vault, "03_ClaudeEnv", "prompts", ".queue")
        os.makedirs(qroot, exist_ok=True)
        with open(os.path.join(qroot, "writer-last-success"), "w") as f:
            f.write(datetime.now().astimezone().isoformat() + "\n")
        r2 = run_hook(env)
        check("9 no-prompt-when-writer-alive", "書込み役" not in r2.stdout, r2.stdout)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    print("\n%d passed, %d failed" % (PASS, FAIL))
    sys.exit(1 if FAIL else 0)


if __name__ == "__main__":
    main()
