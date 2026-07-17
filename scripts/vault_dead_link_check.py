#!/usr/bin/env python3
"""vault dead link 双方向検知 (weekly-vault-audit.sh 検証20 の実体・2026-07-17)

実事故: 2026-07-17 レポート統合/凍結で repo↔vault の file:// リンクが断線
(旧 audit は wikilink ambiguity のみで検知不能だった)。

(a) AI_adscrm 現役文書の [[wikilink]] → basename 実在照合 (aliases はリンクを解決しない)
(b) vault→repo の file:// 実在 (自ユーザーのパスのみ・別Mac ユーザー名は除外)
(c) repo→vault の file:// 逆参照 実在 (project-registry の root から repo を発見)

除外: _archive/(歴史・切れ許容) / _INBOX(原文保存) / AGENTS・CLAUDE(自動生成) /
      *-result.md(runner 上書き出力) / symlink / code fence 内 / inline code 内
出力: 1行1違反 (weekly-vault-audit.sh が violations に計上)
"""
import os
import re
import urllib.parse
from pathlib import Path

HOME = Path.home()
VAULT = HOME / "Documents/Obsidian Vault"
SCOPE = VAULT / "02_Ai/AI_adscrm"

WIKILINK = re.compile(r'!?\[\[([^\]|#]+)')
FILEURI = re.compile(r'file://(/Users/[^)\s>"\'（」・]+)')
INLINE_CODE = re.compile(r'`[^`]*`')
ATTACH_EXT = re.compile(r'\.(png|jpe?g|gif|pdf|csv|svg|base|canvas|webp)$', re.I)


def lines_outside_fence(p: Path):
    try:
        text = p.read_text(encoding="utf-8", errors="ignore")
    except Exception:
        return []
    out, fence = [], False
    for ln in text.splitlines():
        if ln.strip().startswith("```"):
            fence = not fence
            continue
        if not fence:
            out.append(INLINE_CODE.sub("", ln))  # inline code 内の [[例]] を除外
    return out


def scope_files():
    for p in SCOPE.rglob("*.md"):
        if p.is_symlink():
            continue
        if "_archive" in p.parts or "prompts" in p.parts:
            continue
        if p.name.endswith("_INBOX.md") or p.name in ("AGENTS.md", "CLAUDE.md"):
            continue
        if p.name.endswith("-result.md"):  # runner 上書き出力 (自動生成)
            continue
        yield p


def main():
    basenames = set()
    for p in VAULT.rglob("*.md"):
        if ".trash" in p.parts:
            continue
        basenames.add(p.stem)

    # (a) dead wikilink + (b) vault→repo file://
    for p in scope_files():
        rel = p.relative_to(VAULT)
        for ln in lines_outside_fence(p):
            for m in WIKILINK.finditer(ln):
                t = m.group(1).strip().rstrip("\\")  # 表セル内 \| エスケープの \ を除去
                if not t or t.startswith("#"):
                    continue
                if ATTACH_EXT.search(t):
                    continue
                base = t.split("/")[-1]
                if base.endswith(".md"):
                    base = base[:-3]
                if base not in basenames:
                    print(f"dead-wikilink: {rel} → [[{t}]] の実体なし (aliases はリンクを解決しない・rules/41 §④ 張替え必須)")
            for m in FILEURI.finditer(ln):
                path = urllib.parse.unquote(m.group(1)).rstrip("/").rstrip("`")
                if not path.startswith(str(HOME) + "/"):
                    continue
                if not os.path.exists(path):
                    print(f"dead-filelink(vault→repo): {rel} → {path} 不在")

    # (c) repo→vault 逆参照
    reg = VAULT / "wiki/meta/project-registry.md"
    roots = []
    if reg.exists():
        for m in re.finditer(r'\*\*root\*\*: `([^`]+)`', reg.read_text(encoding="utf-8", errors="ignore")):
            r = m.group(1)
            if r.startswith("~"):
                r = str(HOME) + r[1:]
            if os.path.isdir(r):
                roots.append(r)
    seen = set()
    for r in roots:
        for p in Path(r).rglob("*.md"):
            if ".git" in p.parts or "node_modules" in p.parts or "archive" in p.parts:
                continue
            try:
                text = p.read_text(encoding="utf-8", errors="ignore")
            except Exception:
                continue
            if "Obsidian" not in text:
                continue
            for m in FILEURI.finditer(text):
                path = urllib.parse.unquote(m.group(1)).rstrip("/")
                if "Obsidian Vault" not in path or not path.startswith(str(HOME) + "/"):
                    continue
                key = (str(p), path)
                if key in seen:
                    continue
                seen.add(key)
                if not os.path.exists(path):
                    print(f"dead-filelink(repo→vault): {p} → {path} 不在")


if __name__ == "__main__":
    main()
