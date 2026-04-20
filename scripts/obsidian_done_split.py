#!/usr/bin/env python3
"""
~/.claude/scripts/obsidian_done_split.py

Obsidian MD の `## DONE` セクション全体を別ファイル `<basename>-archive.md` へ切り出す。
本体にはポインタ1行だけ残し、NOW/SPEC など現役セクションを軽量化する。

使い方:
    python3 obsidian_done_split.py --dry-run <md_file>
    python3 obsidian_done_split.py --apply   <md_file>

処理:
    1. 本体MDから `## DONE` 行以降〜次の `## ` 見出し or EOF までを抽出
    2. `<basename>-archive.md` を作成（参照元リンク付き）
    3. 本体から DONE セクションを削除し、`## DONE` + ポインタ1行に置換
    4. legacy list `.obsidian-done-legacy-<basename>` が存在する場合、
       `<basename>-archive` 用にもコピー（archive側のhook検証互換性確保）

セーフティ:
    - dry-run デフォルト、--apply で実適用
    - 適用前に <md>.bak-done-split バックアップ
    - archive.md が既存の場合は pre-flight abort（上書き事故防止）
"""
from __future__ import annotations

import argparse
import re
import shutil
import sys
from pathlib import Path


DATE_IN_HEADING_RE = re.compile(r"\((\d{4}-\d{2}-\d{2})\)")


def find_done_section(lines: list[str]) -> tuple[int, int] | None:
    """## DONE セクションの (start_idx, end_idx) を返す。end は exclusive。"""
    done_start = None
    for i, line in enumerate(lines):
        if line.startswith("## DONE"):
            done_start = i
            break
    if done_start is None:
        return None

    done_end = len(lines)
    for i in range(done_start + 1, len(lines)):
        if lines[i].startswith("## ") and not lines[i].startswith("## DONE"):
            done_end = i
            break
    return (done_start, done_end)


def count_done_entries(lines: list[str], start: int, end: int) -> int:
    return sum(1 for i in range(start, end) if lines[i].startswith("##### "))


def build_archive_content(md_path: Path, done_lines: list[str]) -> str:
    """archive.md の内容を構築。"""
    parent_stem = md_path.stem
    header = [
        f"# {parent_stem} — DONE Archive",
        f"参照元: [[{parent_stem}]]",
        "",
        "---",
        "",
    ]
    return "\n".join(header) + "\n".join(done_lines).rstrip() + "\n"


def build_pointer_block(archive_stem: str) -> list[str]:
    """本体MDに残すポインタブロック。"""
    return [
        "## DONE",
        "",
        f"過去の完了タスクは [[{archive_stem}]] を参照。",
        "",
    ]


def plan_split(md_path: Path) -> dict:
    content = md_path.read_text(encoding="utf-8")
    lines = content.splitlines()
    section = find_done_section(lines)
    archive_stem = f"{md_path.stem}-archive"
    archive_path = md_path.parent / f"{archive_stem}.md"

    plan: dict = {
        "md_path": str(md_path),
        "archive_path": str(archive_path),
        "archive_stem": archive_stem,
        "status": "",
        "reason": "",
        "done_start": -1,
        "done_end": -1,
        "entry_count": 0,
        "total_lines": len(lines),
        "done_lines_count": 0,
        "archive_exists": archive_path.exists(),
    }

    if section is None:
        plan["status"] = "SKIP"
        plan["reason"] = "## DONE セクションが見つからない"
        return plan

    start, end = section
    plan["done_start"] = start
    plan["done_end"] = end
    plan["done_lines_count"] = end - start
    plan["entry_count"] = count_done_entries(lines, start, end)

    if plan["archive_exists"]:
        plan["status"] = "ABORT"
        plan["reason"] = f"archive file already exists: {archive_path}"
        return plan

    plan["status"] = "SPLIT"
    return plan


def apply_split(md_path: Path, plan: dict) -> dict:
    if plan["status"] != "SPLIT":
        return {"applied": False, "reason": plan.get("reason", "unknown")}

    content = md_path.read_text(encoding="utf-8")
    lines = content.splitlines()
    start = plan["done_start"]
    end = plan["done_end"]

    # 本体のバックアップ
    bak_path = md_path.with_suffix(md_path.suffix + ".bak-done-split")
    bak_path.write_text(content, encoding="utf-8")

    # archive.md 作成
    done_lines = lines[start:end]
    archive_path = Path(plan["archive_path"])
    archive_content = build_archive_content(md_path, done_lines)
    archive_path.write_text(archive_content, encoding="utf-8")

    # 本体: DONEセクションをポインタブロックに置換
    pointer = build_pointer_block(plan["archive_stem"])
    new_lines = lines[:start] + pointer + lines[end:]
    md_path.write_text("\n".join(new_lines) + "\n", encoding="utf-8")

    # legacy list のコピー
    legacy_src = md_path.parent / f".obsidian-done-legacy-{md_path.stem}"
    legacy_dst = md_path.parent / f".obsidian-done-legacy-{plan['archive_stem']}"
    legacy_copied = False
    if legacy_src.exists() and not legacy_dst.exists():
        shutil.copy2(legacy_src, legacy_dst)
        legacy_copied = True

    return {
        "applied": True,
        "backup": str(bak_path),
        "archive": str(archive_path),
        "archive_lines": len(archive_content.splitlines()),
        "main_lines_before": len(lines),
        "main_lines_after": len(new_lines),
        "legacy_copied": legacy_copied,
        "legacy_dst": str(legacy_dst) if legacy_copied else "",
    }


def render_dry_run(plan: dict) -> None:
    print(f"[DRY-RUN] Target: {plan['md_path']}")
    print(f"  Status: {plan['status']}")
    if plan["status"] != "SPLIT":
        print(f"  Reason: {plan['reason']}")
        return
    print(f"  Archive destination: {plan['archive_path']}")
    print(f"  DONE section range: L{plan['done_start']+1} - L{plan['done_end']}")
    print(f"  DONE entries (##### ): {plan['entry_count']}")
    print(f"  DONE lines (including section header): {plan['done_lines_count']}")
    print(f"  Main MD total lines: {plan['total_lines']}")
    print(f"  Main MD after split: ~{plan['total_lines'] - plan['done_lines_count'] + 4} lines")
    print(f"  Reduction: ~{plan['done_lines_count'] - 4} lines")


def main() -> int:
    ap = argparse.ArgumentParser(description="Obsidian DONE section splitter")
    group = ap.add_mutually_exclusive_group()
    group.add_argument("--dry-run", action="store_true", default=True, help="プレビューのみ（デフォルト）")
    group.add_argument("--apply", action="store_true", help="実適用")
    ap.add_argument("md_file", help="対象Obsidian MDファイルパス")
    args = ap.parse_args()

    md_path = Path(args.md_file).expanduser().resolve()
    if not md_path.exists():
        print(f"ERROR: file not found: {md_path}", file=sys.stderr)
        return 1
    if md_path.suffix != ".md":
        print(f"ERROR: not a .md file: {md_path}", file=sys.stderr)
        return 1

    plan = plan_split(md_path)
    render_dry_run(plan)

    if plan["status"] == "ABORT":
        print(f"\nABORTED: {plan['reason']}", file=sys.stderr)
        return 2
    if plan["status"] == "SKIP":
        print("\nNothing to do.")
        return 0

    if args.apply:
        print("\n[APPLY] Splitting DONE section...")
        result = apply_split(md_path, plan)
        if not result.get("applied"):
            print(f"FAILED: {result.get('reason')}", file=sys.stderr)
            return 2
        print(f"\nArchive created: {result['archive']}")
        print(f"Archive lines: {result['archive_lines']}")
        print(f"Main MD lines: {result['main_lines_before']} → {result['main_lines_after']}")
        print(f"Backup: {result['backup']}")
        if result["legacy_copied"]:
            print(f"Legacy list copied to: {result['legacy_dst']}")
    else:
        print("\n[DRY-RUN MODE] No files modified. Pass --apply to execute.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
