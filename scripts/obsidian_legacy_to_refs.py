#!/usr/bin/env python3
"""
~/.claude/scripts/obsidian_legacy_to_refs.py

既存Obsidian MD の LEGACY形式 DONEエントリを NEW形式 (refs/分離) に変換する。

使い方:
    python3 obsidian_legacy_to_refs.py --dry-run <md_file>
    python3 obsidian_legacy_to_refs.py --apply   <md_file>

処理:
    1. ## DONE セクションの ##### エントリを走査
    2. 見出しが "...(YYYY-MM-DD)" 形式のエントリのみ対象
    3. .obsidian-done-legacy-<basename> に列挙されたエントリはスキップ
    4. 既に **プロンプト要約:** を持つエントリはスキップ (冪等)
    5. refs/YYYY-MM-DD_slug.md を作成 (元プロンプト全文)
    6. 元エントリを軽量化 (要約 + refsリンク + 結果)

安全策:
    - dry-run がデフォルト (プレビューのみ)
    - --apply 指定時のみファイル変更
    - 適用前に <md>.bak-refs-migration を作成
"""
from __future__ import annotations

import argparse
import re
import sys
import unicodedata
from dataclasses import dataclass, field
from pathlib import Path


HEADING_DATE_RE = re.compile(r"\((\d{4}-\d{2}-\d{2})\)")
SUMMARY_MARKER = "**プロンプト要約:**"
REFS_MARKER = "**元プロンプト:**"
RESULT_MARKER = "**結果:**"

TITLE_ROW_RE = re.compile(r"^\s*\|?\s*タイトル\s*\|\s*([^|]+?)\s*\|?\s*$", re.MULTILINE)

# 要約抽出時にスキップする定型テンプレ文字列（部分一致）
TEMPLATE_PHRASES = [
    "現状の運用STEP",
    "運用STEP",
    "全8ステップ",
    "占い商品開発",
    "ロジック・原稿仕様",
    "ロジック•原稿仕様",
    "キャラクター設定",
    "執筆要件とデータ参照",
    "添付ファイル（任意）",
    "サイトID・ロジックID",
    "スプレッドシートから商品を登録してください",
    "スプレッドシートから商品を登録して",
]

# 要約抽出時にスキップする行先頭パターン
TEMPLATE_LINE_PREFIX_RE = re.compile(r"^[①②③④⑤⑥⑦⑧⑨⑩「『]")


@dataclass
class Entry:
    heading: str  # 例: "##### test5: ... (2026-04-10)"
    body_lines: list[str] = field(default_factory=list)
    start_idx: int = 0  # content_lines における開始行 (見出し行)
    end_idx: int = 0    # end exclusive

    @property
    def date(self) -> str | None:
        m = HEADING_DATE_RE.search(self.heading)
        return m.group(1) if m else None

    @property
    def body_text(self) -> str:
        return "\n".join(self.body_lines)

    def already_migrated(self) -> bool:
        return SUMMARY_MARKER in self.body_text or REFS_MARKER in self.body_text

    def split_result(self) -> tuple[str, str]:
        """本文を (prompt_part, result_part) に分割。
        result_part は '**結果:**' 行以降 (マーカー含む)。見つからなければ空文字。
        """
        for i, line in enumerate(self.body_lines):
            if line.strip().startswith(RESULT_MARKER):
                prompt = "\n".join(self.body_lines[:i]).rstrip()
                result = "\n".join(self.body_lines[i:]).rstrip()
                return prompt, result
        return self.body_text.rstrip(), ""


def slugify(text: str, maxlen: int = 50) -> str:
    """見出しから日付を除き、英数字とハイフンにする。日本語はローマ字化せず除去。"""
    # 日付・括弧を除去
    t = HEADING_DATE_RE.sub("", text)
    t = re.sub(r"[()（）]", "", t)
    # 見出し記号を除去
    t = t.lstrip("#").strip()
    # Unicode正規化
    t = unicodedata.normalize("NFKC", t)
    # 英数字・空白・ハイフン・コロン以外を削除（日本語は残す）
    t = re.sub(r"[^\w\s\-:ぁ-んァ-ヴー一-龯]", "", t)
    # 区切り文字を - に統一
    t = re.sub(r"[\s:_+]+", "-", t).strip("-")
    t = t.lower()
    if not t:
        return "untitled"
    if len(t) > maxlen:
        t = t[:maxlen].rstrip("-")
    return t


def parse_done_entries(md_path: Path) -> tuple[list[str], int, int, list[Entry]]:
    """(all_lines, done_start_idx, done_end_idx, entries) を返す。
    done_start_idx: '## DONE' 行の次の行
    done_end_idx: 次の '## ' 見出し行 or EOF
    entries: DONE内の ##### エントリ
    """
    lines = md_path.read_text(encoding="utf-8").splitlines()
    done_start = None
    for i, line in enumerate(lines):
        if line.startswith("## DONE"):
            done_start = i + 1
            break
    if done_start is None:
        return lines, -1, -1, []

    done_end = len(lines)
    for i in range(done_start, len(lines)):
        if lines[i].startswith("## ") and not lines[i].startswith("## DONE"):
            done_end = i
            break

    entries: list[Entry] = []
    current: Entry | None = None
    for idx in range(done_start, done_end):
        line = lines[idx]
        if line.startswith("##### "):
            if current is not None:
                current.end_idx = idx
                entries.append(current)
            current = Entry(heading=line, start_idx=idx)
        else:
            if current is not None:
                current.body_lines.append(line)
    if current is not None:
        current.end_idx = done_end
        entries.append(current)

    return lines, done_start, done_end, entries


def load_legacy_list(md_path: Path) -> set[str]:
    legacy_path = md_path.parent / f".obsidian-done-legacy-{md_path.stem}"
    if not legacy_path.exists():
        return set()
    return {
        line.rstrip("\n")
        for line in legacy_path.read_text(encoding="utf-8").splitlines()
        if line.strip()
    }


def _clean_heading(heading: str) -> str:
    cleaned = heading.lstrip("#").strip()
    cleaned = HEADING_DATE_RE.sub("", cleaned).strip()
    return cleaned


def extract_summary(body_text: str, heading: str) -> str:
    """本文からプロンプト要約を自動生成。

    優先度:
      1. タイトル行抽出 → 見出し + 商品タイトル で結合
      2. 本文が短い場合（非空行<10）のみ、narrative 先頭行を採用
      3. それ以外は見出し転写（長文本文はテンプレ混入しやすく信頼性が低いため）
    """
    heading_clean = _clean_heading(heading)

    # 1. タイトル行
    m = TITLE_ROW_RE.search(body_text)
    if m:
        title = m.group(1).strip()
        if title and len(title) > 3:
            title_trim = title if len(title) <= 60 else title[:57] + "..."
            return f"{heading_clean} — 商品: {title_trim}"

    # 2. 本文が短い場合のみ narrative 抽出を試みる
    lines = body_text.splitlines()
    non_empty = sum(1 for l in lines if l.strip())
    if non_empty < 10:
        for raw in lines:
            line = raw.strip()
            if not line:
                continue
            if line.startswith(("#", "|", "│", "```", "---", "===")):
                continue
            if re.match(r"^[■◼▪●◆◇▼▽]", line):
                continue
            if re.match(r"^(STEP\s*\d|Step\s*\d)", line):
                continue
            if re.match(r"^https?://", line):
                continue
            if re.match(r"^/[A-Za-z]", line) and " " not in line[:20]:
                continue
            if any(t in line for t in TEMPLATE_PHRASES):
                continue
            if TEMPLATE_LINE_PREFIX_RE.match(line):
                continue
            if len(line) < 20:
                continue
            if len(line) > 100:
                return line[:97] + "..."
            return line

    # 3. 見出し転写
    return heading_clean or "(要約未生成)"


def plan_migration(md_path: Path) -> list[dict]:
    """移行計画を dict のリストで返す (適用・プレビュー共用)。"""
    lines, done_start, done_end, entries = parse_done_entries(md_path)
    if done_start < 0:
        return []
    legacy = load_legacy_list(md_path)
    plans = []
    for entry in entries:
        heading_stripped = entry.heading.strip()
        plan = {
            "heading": heading_stripped,
            "status": "",
            "reason": "",
            "date": entry.date,
            "slug": "",
            "refs_path": "",
            "summary": "",
            "result_block": "",
            "prompt_body": "",
            "start_idx": entry.start_idx,
            "end_idx": entry.end_idx,
        }
        if entry.date is None:
            plan["status"] = "SKIP"
            plan["reason"] = "見出しに YYYY-MM-DD なし"
            plans.append(plan)
            continue
        if heading_stripped in legacy:
            plan["status"] = "SKIP"
            plan["reason"] = "legacy-excluded"
            plans.append(plan)
            continue
        if entry.already_migrated():
            plan["status"] = "SKIP"
            plan["reason"] = "既にNEW形式 (プロンプト要約マーカーあり)"
            plans.append(plan)
            continue

        slug = slugify(entry.heading)
        refs_rel = f"refs/{entry.date}_{slug}"
        refs_abs = md_path.parent / f"{refs_rel}.md"
        prompt_body, result_block = entry.split_result()
        summary = extract_summary(prompt_body, entry.heading)
        plan.update(
            {
                "status": "MIGRATE",
                "slug": slug,
                "refs_path": str(refs_abs),
                "refs_rel": refs_rel,
                "summary": summary,
                "result_block": result_block,
                "prompt_body": prompt_body,
            }
        )
        plans.append(plan)
    return plans


def build_new_entry(heading: str, summary: str, refs_rel: str, result_block: str) -> list[str]:
    out = [heading]
    out.append(f"{SUMMARY_MARKER} {summary}")
    out.append(f"{REFS_MARKER} [[{refs_rel}]]")
    out.append("")
    if result_block.strip():
        out.append(result_block.rstrip())
    else:
        out.append(f"{RESULT_MARKER} (未記録)")
    out.append("")
    return out


def build_refs_content(md_path: Path, heading: str, prompt_body: str) -> str:
    heading_clean = heading.lstrip("#").strip()
    parent_link = md_path.stem
    return (
        f"# {heading_clean}\n"
        f"参照元: [[../{parent_link}]]\n\n"
        f"---\n\n"
        f"{prompt_body.rstrip()}\n"
    )


def apply_migration(md_path: Path, plans: list[dict]) -> dict:
    """計画を適用。返り値: サマリー dict。"""
    migrate_plans = [p for p in plans if p["status"] == "MIGRATE"]
    if not migrate_plans:
        return {"migrated": 0, "written_refs": 0, "lines_before": 0, "lines_after": 0}

    # Pre-flight: refs/ 既存衝突があれば abort（silent skip で本体だけ書換える事故を防ぐ）
    collisions = []
    for p in migrate_plans:
        refs_abs = Path(p["refs_path"])
        if refs_abs.exists():
            collisions.append((p["heading"], str(refs_abs)))
    if collisions:
        msg_lines = [
            "ERROR: refs/ 既存ファイルとの衝突を検出。適用を中止します。",
            "既存 refs ファイルと migrate 候補の内容が異なる可能性があり、",
            "本体だけ [[refs/...]] リンクに差し替わると誤リンクになります。",
            "",
        ]
        for heading, path in collisions:
            msg_lines.append(f"  - {heading}")
            msg_lines.append(f"    → {path}")
        msg_lines.append("")
        msg_lines.append("対処: 既存 refs を別名に退避するか、該当エントリを legacy list に追加して再実行。")
        raise RuntimeError("\n".join(msg_lines))

    # バックアップ
    bak_path = md_path.with_suffix(md_path.suffix + ".bak-refs-migration")
    bak_path.write_text(md_path.read_text(encoding="utf-8"), encoding="utf-8")

    # refs/ 作成
    refs_dir = md_path.parent / "refs"
    refs_dir.mkdir(exist_ok=True)

    # refs/ ファイル書き出し（衝突は pre-flight で排除済み）
    written = 0
    for p in migrate_plans:
        refs_abs = Path(p["refs_path"])
        content = build_refs_content(md_path, p["heading"], p["prompt_body"])
        refs_abs.write_text(content, encoding="utf-8")
        written += 1

    # メインMD置換 (後ろから処理してインデックスずれ回避)
    lines = md_path.read_text(encoding="utf-8").splitlines()
    lines_before = len(lines)
    for p in sorted(migrate_plans, key=lambda x: x["start_idx"], reverse=True):
        new_block = build_new_entry(p["heading"], p["summary"], p["refs_rel"], p["result_block"])
        lines[p["start_idx"]:p["end_idx"]] = new_block

    md_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    lines_after = len(lines)

    return {
        "migrated": len(migrate_plans),
        "written_refs": written,
        "lines_before": lines_before,
        "lines_after": lines_after,
        "backup": str(bak_path),
    }


def render_dry_run(md_path: Path, plans: list[dict]) -> None:
    print(f"[DRY-RUN] Target: {md_path}")
    print(f"  Entries total: {len(plans)}")
    counts = {}
    for p in plans:
        counts[p["status"]] = counts.get(p["status"], 0) + 1
    for k, v in counts.items():
        print(f"  {k}: {v}")
    print()
    for i, p in enumerate(plans, 1):
        status = p["status"]
        print(f"--- [{i}] {status}: {p['heading']}")
        if status == "SKIP":
            print(f"    reason: {p['reason']}")
            continue
        print(f"    date:   {p['date']}")
        print(f"    slug:   {p['slug']}")
        print(f"    refs:   {p['refs_rel']}")
        print(f"    summary: {p['summary']}")
        has_result = "yes" if p["result_block"].strip() else "no"
        print(f"    result_preserved: {has_result}")
        print(f"    prompt_body_lines: {len(p['prompt_body'].splitlines())}")


def main() -> int:
    ap = argparse.ArgumentParser(description="Obsidian LEGACY→NEW refs migrator")
    group = ap.add_mutually_exclusive_group()
    group.add_argument("--dry-run", action="store_true", default=True, help="プレビューのみ（デフォルト）")
    group.add_argument("--apply", action="store_true", help="実適用")
    ap.add_argument("md_file", help="対象Obsidian MDファイルパス")
    args = ap.parse_args()

    md_path = Path(args.md_file).expanduser().resolve()
    if not md_path.exists():
        print(f"ERROR: file not found: {md_path}", file=sys.stderr)
        return 1
    if not md_path.suffix == ".md":
        print(f"ERROR: not a .md file: {md_path}", file=sys.stderr)
        return 1

    plans = plan_migration(md_path)
    if not plans:
        print(f"No DONE section or entries found in {md_path}")
        return 0

    render_dry_run(md_path, plans)

    if args.apply:
        print("\n[APPLY] Proceeding with migration...")
        try:
            result = apply_migration(md_path, plans)
        except RuntimeError as e:
            print(f"\n{e}", file=sys.stderr)
            return 2
        print(f"\nMigrated entries: {result['migrated']}")
        print(f"Refs files written: {result['written_refs']}")
        print(f"Main MD lines: {result['lines_before']} → {result['lines_after']}")
        if "backup" in result:
            print(f"Backup: {result['backup']}")
    else:
        print("\n[DRY-RUN MODE] No files modified. Pass --apply to execute.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
