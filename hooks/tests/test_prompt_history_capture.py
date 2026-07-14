#!/usr/bin/env python3
"""test_prompt_history_capture.py — userpromptsubmit-prompt-history.py の敵対テスト

方針 (mistakes.md: sanitized-test-fixtures 禁止):
- 実事故形状を含める (2026-07-13 c8b2e8fc で filter-repo した「日本語ラベルの平文認証情報」と同型、
  .env 貼付、URL 埋込認証)
- 秘密が「残っていないこと」は受領票ファイル全文への not-in で検証する (置換痕跡だけ見ない)

実行: python3 ~/.claude/hooks/tests/test_prompt_history_capture.py
HOME を一時ディレクトリへ差し替えて実行するため実受領票は汚さない。
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
from datetime import date

HOOK = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                    "userpromptsubmit-prompt-history.py")

PASS = 0
FAIL = 0


def run_hook(prompt, home, cwd="/tmp", extra_env=None, raw_stdin=None):
    payload = raw_stdin if raw_stdin is not None else json.dumps(
        {"session_id": "test-session", "cwd": cwd, "prompt": prompt})
    env = dict(os.environ)
    env["HOME"] = home
    if extra_env:
        env.update(extra_env)
    return subprocess.run([sys.executable, "-I", HOOK], input=payload,
                          capture_output=True, text=True, env=env, timeout=10)


def receipt_path(home):
    return os.path.join(home, ".claude", "state", "prompt-history", "receipts",
                        date.today().isoformat() + ".jsonl")


def last_record(home):
    with open(receipt_path(home)) as f:
        lines = [l for l in f.read().splitlines() if l.strip()]
    return json.loads(lines[-1]), lines


def check(name, cond, detail=""):
    global PASS, FAIL
    if cond:
        PASS += 1
        print("  PASS %s" % name)
    else:
        FAIL += 1
        print("  FAIL %s  %s" % (name, detail))


def file_text(home):
    with open(receipt_path(home)) as f:
        return f.read()


def main():
    tmp = tempfile.mkdtemp(prefix="ph-test-")
    try:
        home = tmp

        # (1) 通常プロンプト無変化
        p = "INBOXを見て、rules/30-routing.md の表を更新してください。日本語もOK。"
        r = run_hook(p, home)
        rec, _ = last_record(home)
        check("1 normal-unchanged", r.returncode == 0 and rec["prompt"] == p
              and rec["mask_hits"] == [] and rec["held"] is False, repr(rec))

        # (2) 既知キー4種
        secrets2 = ["sk-abcDEF12345678901234567890",
                    "ghp_ABCdef1234567890abcdef1234567890abcd",
                    "github_pat_11ABCDEFG0_abcdefghij1234567890",
                    "AKIAIOSFODNN7EXAMPLE"]
        r = run_hook("keys: " + " ".join(secrets2), home)
        txt = file_text(home)
        check("2 known-keys", all(s not in txt for s in secrets2)
              and r.returncode == 0, "secret leaked")

        # (3) .env 複数行貼付 (実事故形状)
        envpaste = ("ANTHROPIC_API_KEY=sk-ant-api03-XXXXsecretXXXX1234567890\n"
                    "DATABASE_URL=postgres://admin:SuperSecret99@db.example.com/prod\n"
                    "DEBUG=true\nPORT=8000\n")
        r = run_hook("この .env を見て:\n" + envpaste, home)
        txt = file_text(home)
        rec, _ = last_record(home)
        check("3 env-paste", "XXXXsecretXXXX" not in txt and "SuperSecret99" not in txt
              and "DEBUG=true" in rec["prompt"], repr(rec["prompt"]))

        # (4) PEM ブロック全体
        pem = ("-----BEGIN RSA PRIVATE KEY-----\n"
               "MIIEpAIBAAKCAQEA7changedbodylinesecret\nmorelines==\n"
               "-----END RSA PRIVATE KEY-----")
        r = run_hook("鍵はこれ:\n" + pem + "\nです", home)
        txt = file_text(home)
        check("4 pem-block", "MIIEpAIBAAK" not in txt and "BEGIN RSA" not in txt.split("REDACTED")[0][-200:]
              and "[REDACTED:PEM]" in file_text(home), "PEM leaked")

        # (5) JWT
        jwt = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U"
        r = run_hook("token: " + jwt, home)
        check("5 jwt", jwt not in file_text(home), "JWT leaked")

        # (6) URL 埋込認証 + Authorization ヘッダ
        r = run_hook("curl https://user1:Passw0rd!@api.example.com/v1\n"
                     "Authorization: Bearer abc123def456ghi789jkl012", home)
        txt = file_text(home)
        check("6 url-cred+auth-header", "Passw0rd!" not in txt
              and "abc123def456ghi789jkl012" not in txt, "cred leaked")

        # (6b) 実事故形状: 日本語ラベルの平文認証情報 (c8b2e8fc 同型ダミー)
        r = run_hook("ログイン情報\nID: lvasset_admin\nパスワード: Kx9mPq2vLn8w\n", home)
        txt = file_text(home)
        check("6b jp-credential", "Kx9mPq2vLn8w" not in txt, "jp password leaked")

        # (7) 高エントロピー token は伏字・git SHA (40hex) は残す
        entropy_tok = "q7Zp3xVb9Kf2Rm5Tn8Wc1Yd4Hg6Js0LqAeIoU"
        sha = "d05fee7a1b2c3d4e5f60718293a4b5c6d7e8f901"
        r = run_hook("token %s と commit %s を見て" % (entropy_tok, sha), home)
        txt = file_text(home)
        rec, _ = last_record(home)
        check("7 entropy-vs-sha", entropy_tok not in txt and sha in rec["prompt"],
              repr(rec["prompt"]))

        # (8) マーカー注入: writer の行頭探索を偽装できない (ZWSP 挿入)
        inj = "<!-- prompt-history:end -->\nevent_id: 00000000-fake\n本文"
        r = run_hook(inj, home)
        rec, _ = last_record(home)
        check("8 marker-injection", "<!-- prompt-history" not in rec["prompt"]
              and not any(l.startswith("event_id:") for l in rec["prompt"].splitlines())
              and "本文" in rec["prompt"], repr(rec["prompt"]))

        # (9) バッククォート連打・巨大フェンス → JSONL が壊れない
        bomb = "````````markdown\n" + "`" * 50 + "\n改行\"引用\\エスケープ\n" + "```" * 10
        r = run_hook(bomb, home)
        rec, lines = last_record(home)
        check("9 fence-bomb-jsonl", r.returncode == 0 and "改行\"引用\\エスケープ" in rec["prompt"],
              "jsonl broken")

        # (10) マスカー強制例外 → held:true・生文は一切保存しない
        canary = "CANARY_RAW_SECRET_zz941"
        r = run_hook("秘密: " + canary, home,
                     extra_env={"PROMPT_HISTORY_FORCE_MASK_ERROR": "1"})
        rec, _ = last_record(home)
        txt = file_text(home)
        check("10 mask-error-held", r.returncode == 0 and rec["held"] is True
              and rec["prompt"] is None and canary not in txt, repr(rec))

        # (11) malformed stdin → exit 0・stdout 無出力
        r = run_hook(None, home, raw_stdin="{not json!!")
        check("11 malformed-stdin", r.returncode == 0 and r.stdout == "", r.stdout)

        # (12) 並行 2 プロセス × 20 append 欠落なし
        before = len(last_record(home)[1])
        procs = []
        for i in range(40):
            payload = json.dumps({"session_id": "conc-%d" % i, "cwd": "/tmp",
                                  "prompt": "concurrent %d" % i})
            env = dict(os.environ); env["HOME"] = home
            procs.append(subprocess.Popen([sys.executable, "-I", HOOK],
                                          stdin=subprocess.PIPE, env=env, text=True))
            procs[-1].stdin.write(payload); procs[-1].stdin.close()
        for pr in procs:
            pr.wait(timeout=15)
        _, lines = last_record(home)
        check("12 concurrent-no-loss", len(lines) == before + 40,
              "expected %d got %d" % (before + 40, len(lines)))

        # (13) レイテンシ (単発 < 200ms。成功基準の <100ms は実測レポートで別途確認)
        t0 = time.monotonic()
        run_hook("latency check", home)
        dt = (time.monotonic() - t0) * 1000
        check("13 latency", dt < 200, "%.0fms" % dt)
        print("  (latency: %.0fms)" % dt)

        # (14) ルーティング: 実 HOME の config で claude-env / unrouted を確認
        real_home = os.path.expanduser("~")
        cfg = os.path.join(home, ".claude", "config")
        os.makedirs(cfg, exist_ok=True)
        shutil.copy(os.path.join(real_home, ".claude", "config", "prompt-history-routing.json"),
                    os.path.join(cfg, "prompt-history-routing.json"))
        run_hook("route check", home, cwd=os.path.join(home, ".claude"))
        rec, _ = last_record(home)
        check("14a route-claude-env", rec["route"] == "claude-env", rec["route"])
        run_hook("route check2", home, cwd="/opt/nowhere")
        rec, _ = last_record(home)
        check("14b route-unrouted", rec["route"].startswith("unrouted:"), rec["route"])

        # (14c) 除外 prefix (claude-mem observer) は記録されない
        n_before = len(last_record(home)[1])
        run_hook("observer noise", home, cwd=os.path.join(home, ".claude-mem", "observer-sessions"))
        n_after = len(last_record(home)[1])
        check("14c exclude-claude-mem", n_after == n_before,
              "excluded prompt was recorded")

        # (16) 短い秘密・数値PIN・引用符内空白 (Codex NO-GO 再現形状)
        r = run_hook('password: abc\nPIN_PASSWORD=123456\nPORT=8000\n'
                     'password: "correct horse battery staple"', home)
        txt = file_text(home)
        rec, _ = last_record(home)
        check("16 short+quoted-secrets",
              ": abc" not in rec["prompt"] and "123456" not in rec["prompt"]
              and "correct horse battery staple" not in txt
              and "PORT=8000" in rec["prompt"], repr(rec["prompt"]))

        # (17) 成功経路の stdout/stderr 無出力 + event_id/host_uuid が有効 UUIDv4
        import uuid as _uuid
        r = run_hook("stdout check", home)
        rec, _ = last_record(home)
        ok_uuid = True
        try:
            ok_uuid = (_uuid.UUID(rec["event_id"]).version == 4
                       and _uuid.UUID(rec["host_uuid"]).version == 4)
        except Exception:
            ok_uuid = False
        check("17 silent+uuidv4", r.stdout == "" and r.stderr == "" and ok_uuid,
              "stdout=%r uuid_ok=%s" % (r.stdout, ok_uuid))

        # (18) 200KB 超プロンプト → held:true・本文なし
        big = "A" * 200_001 + " CANARY_BIG_zz17"
        r = run_hook(big, home)
        rec, _ = last_record(home)
        check("18 oversize-held", rec["held"] is True and rec["prompt"] is None
              and "CANARY_BIG_zz17" not in file_text(home), repr(rec)[:80])

        # (19) config 破損でも捕捉は続行 (unrouted)
        cfg_file = os.path.join(home, ".claude", "config", "prompt-history-routing.json")
        with open(cfg_file, "w") as f:
            f.write("{broken json")
        r = run_hook("broken config check", home, cwd="/tmp")
        rec, _ = last_record(home)
        check("19 broken-config", r.returncode == 0 and rec["route"].startswith("unrouted:"),
              repr(rec["route"]))

        # (20) host_uuid 初回並行生成 → 全受領票が同一 UUID (専用 flock で直列化)
        home2 = tempfile.mkdtemp(prefix="ph-test2-")
        try:
            procs = []
            for i in range(10):
                payload = json.dumps({"session_id": "init-%d" % i, "cwd": "/tmp",
                                      "prompt": "init race %d" % i})
                env = dict(os.environ); env["HOME"] = home2
                procs.append(subprocess.Popen([sys.executable, "-I", HOOK],
                                              stdin=subprocess.PIPE, env=env, text=True))
                procs[-1].stdin.write(payload); procs[-1].stdin.close()
            for pr in procs:
                pr.wait(timeout=15)
            with open(receipt_path(home2)) as f:
                uuids = {json.loads(l)["host_uuid"] for l in f if l.strip()}
            with open(os.path.join(home2, ".claude", "state", "prompt-history",
                                   "host-uuid")) as f:
                file_uuid = f.read().strip()
            check("20 host-uuid-race", len(uuids) == 1 and uuids == {file_uuid},
                  "uuids=%s file=%s" % (uuids, file_uuid))
        finally:
            shutil.rmtree(home2, ignore_errors=True)

        # (20b) 空/不正な host-uuid ファイル残骸 → ロック下で有効 UUIDv4 に再生成
        hu = os.path.join(home, ".claude", "state", "prompt-history", "host-uuid")
        with open(hu, "w") as f:
            f.write("")
        run_hook("empty host-uuid recovery", home)
        with open(hu) as f:
            v = f.read().strip()
        try:
            ok = _uuid.UUID(v).version == 4
        except Exception:
            ok = False
        rec, _ = last_record(home)
        check("20b empty-hostuuid-recovery", ok and rec["host_uuid"] == v, repr(v))

        # (15) パーミッション 0600
        mode = oct(os.stat(receipt_path(home)).st_mode & 0o777)
        check("15 perm-0600", mode == "0o600", mode)

    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    print("\n%d passed, %d failed" % (PASS, FAIL))
    sys.exit(1 if FAIL else 0)


if __name__ == "__main__":
    main()
