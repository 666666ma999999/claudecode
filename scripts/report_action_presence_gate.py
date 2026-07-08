#!/usr/bin/env python3
"""report_action_presence_gate.py — 施策レポートの「なぜ＋理由資料」存在検査ゲート。

何を保証するか(正直に): 各アクションに
  (a) 「なぜやらねばならないか」ブロックが存在する
  (b) 実在する deep link ([[note#anchor]] / [[note#^block-id]]) の理由資料がある
  (c) 判断材料の構造語(金額/戻し方/答え合わせ 等)が最低2種ある
ことの **存在検査のみ**。内容の妥当性・深さは保証しない (presence gate)。

背景: 2026-07-08 ユーザー却下「なぜ止血しなければいけないかわからない」。散文指示は
この環境で定着した前例がなく (wiki/meta/mistakes.md)、機械述語化で再発を止める。

使い方:
  report_action_presence_gate.py <file.md>            # 検査のみ: NG なら exit 1 + JSON
  report_action_presence_gate.py --annotate <file.md> # NG なら警告バナー+frontmatterキー追記して exit 1
  report_action_presence_gate.py --scan <files...>    # 一括 lint (常に exit 0・FP率計測用)
  report_action_presence_gate.py --embeds <notes...>  # ![[note#anchor]] の断線検査 (✅1c 2026-07-08)
                                                      #   ボード/ope の📡窓が生成物に解決できるか。断線で exit 1

fail-open: 解析例外は exit 0 だが stdout に {"gate_status":"error"} を必ず返す
(✅1a 2026-07-08: 故障が OK に偽装される fail-silent を廃止。runner 側が ERROR として記録)。
"""
import sys, os, re, json, glob

VAULT = os.path.expanduser("~/Documents/Obsidian Vault")

# 承認導線の節だけを対象にする (汎用語 アクション/打ち手 は非承認文書を踏むため不採用・2026-07-08 在庫scanで較正)
SECTION_RE = re.compile(r"^(#{1,6})\s.*(今週やるべき|承認欄|きょうやること|今週やること|ボード差分パッチ案)", re.M)
ITEM_RE = re.compile(r"^\d+\.\s", re.M)
WHY_MARKER = "なぜやらねばならないか"
DEEPLINK_RE = re.compile(r"\[\[([^\]\|#]+)#(\^?[^\]\|]+)(?:\|[^\]]*)?\]\]")
EMBED_RE = re.compile(r"!\[\[([^\]\|#]+)#(\^?[^\]\|]+)(?:\|[^\]]*)?\]\]")
STRUCT_WORDS = ["¥", "%", "戻", "答え合わせ", "放置", "毎月", "件"]
STRUCT_MIN = 2


def strip_noise(text):
    """frontmatter と fenced code block を除去 (fence 内の例示での誤検知防止)。"""
    if text.startswith("---\n"):
        end = text.find("\n---\n", 4)
        if end != -1:
            text = text[end + 5:]
    out, in_code = [], False
    for line in text.split("\n"):
        if line.strip().startswith("```"):
            in_code = not in_code
            continue
        if not in_code:
            out.append(line)
    return "\n".join(out)


_target_cache = {}

def link_targets(path):
    """note の見出し集合と block-id 集合。"""
    if path in _target_cache:
        return _target_cache[path]
    hs, blocks = set(), set()
    try:
        with open(path, encoding="utf-8") as f:
            for l in f:
                m = re.match(r"#{1,6}\s+(.*)", l)
                if m:
                    hs.add(m.group(1).strip())
                # block id は独立行 (`^id`) と行末付記 (`本文 ^id`) の両記法が正 (Obsidian 仕様)
                m2 = re.search(r"(?:^|\s)\^([A-Za-z0-9-]+)\s*$", l.rstrip())
                if m2:
                    blocks.add(m2.group(1))
    except OSError:
        pass
    _target_cache[path] = (hs, blocks)
    return hs, blocks


def resolve_note(name, near_dir):
    """basename → 実ファイル。近傍(同dir/親/親の親) → vault 全域の順で解決。"""
    fname = name + ".md"
    d = near_dir
    for _ in range(3):
        for cand in (os.path.join(d, fname), *glob.glob(os.path.join(d, "*", fname))):
            if os.path.isfile(cand):
                return cand
        d = os.path.dirname(d)
    hits = glob.glob(os.path.join(VAULT, "**", fname), recursive=True)
    hits = [h for h in hits if os.path.isfile(h) and "/.trash/" not in h]
    return hits[0] if hits else None


def check_file(path):
    """returns (ng:[{item, missing}], warnings:[str]) — 対象節が無ければ ([], [])"""
    raw = open(path, encoding="utf-8").read()
    text = strip_noise(raw)

    items, ng, warnings = [], [], []
    for m in SECTION_RE.finditer(text):
        level = len(m.group(1))
        rest = text[m.start():]
        nxt = re.search(r"^#{1,%d}\s" % level, rest[m.end() - m.start():], re.M)
        section = rest[: (m.end() - m.start()) + (nxt.start() if nxt else len(rest))]
        starts = [mm.start() for mm in ITEM_RE.finditer(section)]
        sec_items = ([section[s:e] for s, e in zip(starts, starts[1:] + [len(section)])]
                     if starts else [section])
        items.extend(sec_items)
        if "今週やるべき" in section.split("\n", 1)[0] and len(starts) > 3:
            warnings.append(f"アクション {len(starts)} 件 > 上限3件")

    near = os.path.dirname(os.path.abspath(path))
    for it in items:
        head = re.sub(r"\W+", " ", it.strip().split("\n", 1)[0])[:50].strip()
        missing = []
        if WHY_MARKER not in it:
            missing.append("『なぜやらねばならないか』ブロック")
        links = DEEPLINK_RE.findall(it)
        if not links:
            missing.append("理由資料 deep link ([[note#anchor]])")
        else:
            for name, anchor in links:
                target = resolve_note(name.strip(), near)
                if target is None:
                    warnings.append(f"{head}: リンク先ノート未解決 [[{name}]]")
                    continue
                hs, blocks = link_targets(target)
                ok = (anchor[1:] in blocks) if anchor.startswith("^") else (anchor.strip() in hs)
                if not ok:
                    missing.append(f"リンク先アンカー不在 [[{name.strip()}#{anchor.strip()[:30]}]]")
        structs = [w for w in STRUCT_WORDS if w in it]
        if len(structs) < STRUCT_MIN:
            missing.append(f"判断材料の構造語不足 ({len(structs)}/{STRUCT_MIN}: 金額・戻し方・答え合わせ日 等)")
        if missing:
            ng.append({"item": head, "missing": missing})
    return ng, warnings


def check_embeds(path):
    """![[note#anchor]] 断線検査: 返り値 = broken リスト (✅1c 📡窓の保護)。"""
    raw = open(path, encoding="utf-8").read()
    text = strip_noise(raw)
    broken = []
    near = os.path.dirname(os.path.abspath(path))
    for name, anchor in EMBED_RE.findall(text):
        target = resolve_note(name.strip(), near)
        if target is None:
            broken.append(f"![[{name.strip()}#…]] ノート未解決")
            continue
        hs, blocks = link_targets(target)
        ok = (anchor[1:] in blocks) if anchor.startswith("^") else (anchor.strip() in hs)
        if not ok:
            broken.append(f"![[{name.strip()}#{anchor.strip()[:40]}]] アンカー不在")
    return broken


# --- CP章の構造検査 (--cp-sections・2026-07-08 金標準の恒久化・Codex GO-WITH-CHANGES 反映) ---
# 対象選抜 (文字列1本依存を避ける・Codex must-fix): ### 節のうち
#   (1) 見出しに 真ROAS or CP を含む、または (2) 節内に ⏱時間軸callout + ①〜④のうち3個以上。
#   denylist (見出しに含む): M3 / Meta / 付録 / 具体的な施策。
# 候補だが構造未満 (📊診断なし等) は candidate_cp_unstructured として別warn。
# presence gate 思想は維持: 存在検査のみ・因果の質は契約とskill checklistが担う。
CP_DENY = ("M3", "Meta", "付録", "具体的な施策")
PART_MARKS = ["①", "②", "③", "④"]
PART_TITLE_RE = re.compile(r"^>\s*\[!(todo|note|abstract)\]([+-]?)\s*(.*)$", re.M)


def check_cp_sections(path):
    """returns (ng:[{section,missing}], warnings:[str])"""
    raw = open(path, encoding="utf-8").read()
    text = strip_noise(raw)
    ng, warnings = [], []

    heads = [(m.start(), m.group(1)) for m in re.finditer(r"^###\s+(.*)$", text, re.M)]
    bounds = [h[0] for h in heads] + [len(text)]
    for i, (start, title) in enumerate(heads):
        sec = text[start:bounds[i + 1]]
        # 次の ## (レベル2) で節が終わる場合も切る (自身の ### 見出し行はスキップして探す)
        nl = sec.find("\n")
        m2 = re.search(r"^##[^#]", sec[nl + 1:], re.M) if nl != -1 else None
        if m2:
            sec = sec[: nl + 1 + m2.start()]
        if any(d in title for d in CP_DENY):
            continue
        has_clock = "⏱" in sec
        marks_in_sec = sum(1 for p in PART_MARKS if p in sec)
        if not (("真ROAS" in title or "CP" in title) or (has_clock and marks_in_sec >= 3)):
            continue
        # 候補確定。構造未満 (診断折りたたみ不在) は別warn
        if "📊" not in sec:
            warnings.append(f"candidate_cp_unstructured: {title[:40]} (📊診断なし・金標準未適用)")
            continue
        missing = []
        if not re.search(r"^>\s*\[!tip\].*⏱", sec, re.M):
            missing.append("⏱時間軸callout")
        if not re.search(r"^\*\*窓\*\*:", sec, re.M):
            missing.append("**窓**行")
        if not (re.search(r"\|\s*\*\*(原因|狙い)\*\*\s*\|", sec) and re.search(r"\|\s*\*\*判定\*\*\s*\|", sec)):
            missing.append("原因(狙い)/判定の2行")
        # ①〜④: callout タイトル行にトークン存在 (「なし」も可・存在のみ)
        part_titles = [m.group(3) for m in PART_TITLE_RE.finditer(sec)]
        main_parts = [t for t in part_titles if re.match(r"[⓪①②③④](?![\-a-z])", t)]
        for p in PART_MARKS:
            if not any(t.startswith(p) for t in main_parts):
                missing.append(f"部品{p}")
        # [!todo] 部品の状態タグ+日付 / やること+なぜ
        for m in PART_TITLE_RE.finditer(sec):
            kind, fold, t = m.group(1), m.group(2), m.group(3)
            if not re.match(r"[⓪①②③④](?![\-a-z])", t):
                continue
            # callout 本文 = タイトル行に続く > 行 (m.end()は行末=先頭要素は空なので捨てる)
            body_lines = []
            for line in sec[m.end():].split("\n")[1:]:
                if not line.startswith(">"):
                    break
                body_lines.append(line)
            body = "\n".join(body_lines)
            if kind == "todo" and not (re.search(r"\*\*状態[:：]", body) and re.search(r"20\d\d-\d\d-\d\d", body)):
                missing.append(f"{t[:14]}…の状態タグ(日付つき)")
            if kind in ("todo", "note") and not ("やること" in body or "確認すること" in body):
                missing.append(f"{t[:14]}…の「やること」")
            if kind in ("todo", "note") and "なぜ" not in body:
                missing.append(f"{t[:14]}…の「なぜ」")
            if kind in ("todo", "note", "abstract") and fold != "-":
                warnings.append(f"{title[:20]}: 折りたたみ`-`なし callout「{t[:20]}」(可視行増)")
        if missing:
            ng.append({"section": title[:50], "missing": missing})

    # P8: 可視行の概算 (>で始まらない非空行) — warn のみ
    visible = sum(1 for l in text.split("\n") if l.strip() and not l.startswith(">"))
    if visible > 320:
        warnings.append(f"可視行の概算 {visible} 行 > 320 (折りたたみ規律の確認を)")
    return ng, warnings


def annotate(path, ng, warnings):
    raw = open(path, encoding="utf-8").read()
    fails = "; ".join(f"{x['item']}→{'/'.join(x['missing'])}" for x in ng)[:500]
    if raw.startswith("---\n"):
        end = raw.find("\n---\n", 4)
        fm, body = raw[4:end], raw[end + 5:]
        fm = re.sub(r"^quality_gate:.*\n?", "", fm, flags=re.M)
        fm = re.sub(r"^quality_gate_failures:.*\n?", "", fm, flags=re.M)
        fm = fm.rstrip("\n") + f'\nquality_gate: warn\nquality_gate_failures: "{fails}"\n'
        raw = "---\n" + fm + "---\n" + body
    banner = ("\n> [!warning] 🚦 品質ゲートNG（存在検査・内容の妥当性は保証しない）\n"
              + "".join(f"> - {x['item']}: {'・'.join(x['missing'])} が欠落\n" for x in ng)
              + "".join(f"> - ⚠️ {w}\n" for w in warnings)
              + "> 対応: 生成契約（prompts/scheduled/）の「なぜやらねばならないか＋📎理由資料」要件を参照。\n")
    lines = raw.split("\n")
    idx = next((i for i, l in enumerate(lines) if l.startswith("> ⚠️ 自動生成")), None)
    if idx is not None:
        lines.insert(idx + 1, banner.rstrip("\n"))
    else:
        h = next((i for i, l in enumerate(lines) if l.startswith("# ")), 0)
        lines.insert(h + 1, banner.rstrip("\n"))
    open(path, "w", encoding="utf-8").write("\n".join(lines))


def main():
    args = sys.argv[1:]
    mode = "check"
    if args and args[0] == "--annotate":
        mode, args = "annotate", args[1:]
    elif args and args[0] == "--scan":
        mode, args = "scan", args[1:]
    elif args and args[0] == "--embeds":
        mode, args = "embeds", args[1:]
    elif args and args[0] == "--cp-sections":
        mode, args = "cp-sections", args[1:]
    if not args:
        print("usage: report_action_presence_gate.py [--annotate|--scan|--embeds|--cp-sections] <file.md>...", file=sys.stderr)
        return 0

    if mode == "cp-sections":
        # CP章の構造検査 (存在検査のみ・書込なし=evergreenボード保護・NGでexit 1)
        any_ng = False
        for path in args:
            try:
                ng, warnings = check_cp_sections(path)
            except Exception as e:  # fail-open だが故障は stdout で可視化
                print(json.dumps({"file": path, "gate_status": "error", "error": str(e)[:200]}, ensure_ascii=False))
                continue
            if ng:
                any_ng = True
            detail = "; ".join(f"{x['section']}→{'/'.join(x['missing'])[:120]}" for x in ng)[:600]
            print(f"[{'NG' if ng else 'OK'}] {path}" + (f" :: {detail}" if ng else ""))
            for w in warnings:
                print(f"  ⚠️ {w}")
        return 1 if any_ng else 0

    if mode == "embeds":
        any_broken = False
        for path in args:
            try:
                broken = check_embeds(path)
            except Exception as e:  # fail-open だが故障は stdout で可視化
                print(json.dumps({"file": path, "gate_status": "error", "error": str(e)[:200]}, ensure_ascii=False))
                continue
            if broken:
                any_broken = True
            print(f"[{'NG' if broken else 'OK'}] {path}" + (" :: " + " / ".join(broken)[:300] if broken else ""))
        return 1 if any_broken else 0

    any_ng = False
    for path in args:
        try:
            ng, warnings = check_file(path)
        except Exception as e:  # fail-open だが故障は stdout で可視化 (fail-silent 廃止)
            print(json.dumps({"file": path, "gate_status": "error", "error": str(e)[:200]}, ensure_ascii=False))
            print(f"gate-error(fail-open) {path}: {e}", file=sys.stderr)
            continue
        status = "NG" if ng else "OK"
        if ng:
            any_ng = True
        if mode == "scan":
            print(f"[{status}] {path}" + (f" :: {json.dumps({'ng': ng, 'warn': warnings}, ensure_ascii=False)[:300]}" if ng or warnings else ""))
        else:
            print(json.dumps({"file": path, "ng": ng, "warnings": warnings}, ensure_ascii=False))
            if ng and mode == "annotate":
                try:
                    annotate(path, ng, warnings)
                except Exception as e:
                    print(f"annotate-error(fail-open) {path}: {e}", file=sys.stderr)
    return 1 if (any_ng and mode != "scan") else 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:  # 最終 fail-open (故障は stdout で可視化)
        print(json.dumps({"gate_status": "error", "error": str(e)[:200]}, ensure_ascii=False))
        print(f"gate-fatal(fail-open): {e}", file=sys.stderr)
        sys.exit(0)
