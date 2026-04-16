"""
transcript-scanner.py

Reads a Claude Code conversation transcript (JSONL) and extracts
X (Twitter) buzz-worthy material using pattern matching.

Usage:
    python3 transcript-scanner.py <transcript_path> <cwd>
"""

import sys
import json
import re
import os
import hashlib
import fcntl
from datetime import date
from pathlib import Path

# Ensure the sibling buzz_patterns module is importable
sys.path.insert(0, str(Path(__file__).parent))

from buzz_patterns import PATTERNS, PREFILTER_REGEX, match_patterns, extract_numbers, generate_title, PatternMatch, story_score, story_elements


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

MAX_READ = 2 * 1024 * 1024  # 2 MB tail read threshold
WINDOW_SIZE = 5
MIN_SCORE = 6.0
MIN_TEXT_LEN = 100
CJK_REGEX = re.compile(r"[\u3000-\u9fff\uf900-\ufaff]")
CJK_MIN_RATIO = 0.20
TOP_K = 5

# System content to strip from messages
SYSTEM_TAG_RE = re.compile(r"<system-reminder[^>]*>.*?</system-reminder>", re.DOTALL)
NOISE_PREFIXES = (
    "Base directory for this skill:",
    "Stop hook",
    "Hook ",
    "<system-reminder",
    "<task-notification",
    "<local-command-caveat",
)

STATE_DIR = Path.home() / ".claude" / "state"
FINGERPRINT_FILE = STATE_DIR / "auto-capture-fingerprints.txt"
QUEUE_FILE = STATE_DIR / "improvement-queue.jsonl"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def get_fingerprint(pattern_name: str, text: str) -> str:
    return hashlib.sha256(f"{pattern_name}:{text[:100]}".encode()).hexdigest()[:16]


def get_next_id() -> int:
    """Read last entry in queue to determine next mat_XXX id."""
    max_id = 0
    if QUEUE_FILE.exists():
        for line in QUEUE_FILE.read_text(encoding="utf-8", errors="replace").strip().splitlines():
            try:
                entry = json.loads(line)
                id_str = entry.get("id", "mat_000")
                num = int(id_str.split("_")[1])
                if num > max_id:
                    max_id = num
            except (json.JSONDecodeError, ValueError, IndexError):
                continue
    return max_id + 1


def extract_project_name(cwd_path: str) -> str:
    return Path(cwd_path).name


def cjk_ratio(text: str) -> float:
    if not text:
        return 0.0
    cjk_chars = len(CJK_REGEX.findall(text))
    return cjk_chars / len(text)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    transcript_path = sys.argv[1]
    cwd = sys.argv[2]

    # ------------------------------------------------------------------
    # Phase 1: Stream parse with tail-seek
    # ------------------------------------------------------------------
    file_size = os.path.getsize(transcript_path)
    messages = []  # list of {"role": str, "text": str, "line_idx": int}

    with open(transcript_path, "r", encoding="utf-8", errors="replace") as f:
        if file_size > 5 * 1024 * 1024:
            f.seek(max(0, file_size - MAX_READ))
            f.readline()  # skip partial first line

        for line_idx, line in enumerate(f):
            # Pre-filter: skip lines without any buzz keywords
            if not PREFILTER_REGEX.search(line):
                continue

            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                continue

            entry_type = entry.get("type", "")
            if entry_type not in ("user", "assistant"):
                continue

            content = entry.get("message", {}).get("content", "")
            raw_texts = []
            if isinstance(content, str):
                raw_texts = [content]
            elif isinstance(content, list):
                raw_texts = [
                    block.get("text", "")
                    for block in content
                    if isinstance(block, dict) and block.get("type") == "text"
                ]

            # Filter out system content / noise
            clean_texts = []
            for t in raw_texts:
                if any(t.lstrip().startswith(p) for p in NOISE_PREFIXES):
                    continue
                # Strip inline system-reminder tags
                t = SYSTEM_TAG_RE.sub("", t).strip()
                if t:
                    clean_texts.append(t)

            text = " ".join(clean_texts)

            if not text or len(text) < 50:
                continue

            messages.append({"role": entry_type, "text": text, "line_idx": line_idx})

    print(f"[transcript-scanner] Parsed {len(messages)} qualifying messages")

    # ------------------------------------------------------------------
    # Phase 2: Sliding window pattern matching
    # ------------------------------------------------------------------
    raw_candidates = []  # {"pattern_name", "matched_text", "keyword_hits", "score", "type", "start_idx"}

    for i in range(len(messages)):
        # Skip windows starting with short messages (acknowledgments/confirmations)
        if len(messages[i]["text"]) < 80:
            continue

        window_end = min(i + WINDOW_SIZE, len(messages))
        window_msgs = [m for m in messages[i:window_end] if len(m["text"]) >= 50]
        if not window_msgs:
            continue
        window_text = "\n".join(m["text"] for m in window_msgs)
        # ユーザー発言のみを分離（結果・価値の判定用）
        user_text = "\n".join(m["text"] for m in window_msgs if m["role"] == "user")

        matches = match_patterns(window_text)
        for m in matches:
            raw_candidates.append({
                "pattern_name": m.pattern_name,
                "matched_text": m.text_excerpt,
                "keyword_hits": m.matched_keywords,
                "score": m.score,
                "type": PATTERNS[m.pattern_name]["type"],
                "start_idx": messages[i]["line_idx"],
                "user_text": user_text,
            })

    # Deduplicate overlapping candidates: same pattern_name + start_idx within WINDOW_SIZE
    # Keep the higher-score entry.
    deduped = {}
    for c in raw_candidates:
        bucket_key = (c["pattern_name"], c["start_idx"] // WINDOW_SIZE)
        existing = deduped.get(bucket_key)
        if existing is None or c["score"] > existing["score"]:
            deduped[bucket_key] = c

    candidates = list(deduped.values())

    # ------------------------------------------------------------------
    # Phase 3: Quality gate (形式チェック + 3要素スコアリング)
    # ------------------------------------------------------------------
    filtered = []
    for c in candidates:
        if c["score"] < MIN_SCORE:
            continue
        if len(c["matched_text"]) < MIN_TEXT_LEN:
            continue
        if cjk_ratio(c["matched_text"]) < CJK_MIN_RATIO:
            continue

        # 3要素スコア: 手段 + 結果 + 価値 (0〜3)
        ss = story_score(c["matched_text"])
        c["story_score"] = ss

        # 0-1点 → 破棄（ストーリーがない）
        if ss <= 1:
            continue

        # 2点 → pending_review, 3点 → pending_ingest
        c["auto_status"] = "pending_ingest" if ss == 3 else "pending_review"
        filtered.append(c)

    # Keep top 5 by score
    filtered.sort(key=lambda x: x["score"], reverse=True)
    filtered = filtered[:TOP_K]

    print(f"[transcript-scanner] {len(raw_candidates)} raw candidates → {len(filtered)} after quality gate (story_scores: {[c['story_score'] for c in filtered]})")

    # ------------------------------------------------------------------
    # Phase 4: Fingerprint dedup
    # ------------------------------------------------------------------
    existing_fps: set = set()
    if FINGERPRINT_FILE.exists():
        existing_fps = set(FINGERPRINT_FILE.read_text(encoding="utf-8", errors="replace").strip().splitlines())

    new_candidates = []
    new_fps = []
    for c in filtered:
        fp = get_fingerprint(c["pattern_name"], c["matched_text"])
        if fp not in existing_fps:
            new_candidates.append(c)
            new_fps.append(fp)
            existing_fps.add(fp)

    # ------------------------------------------------------------------
    # Phase 5: Append to queue
    # ------------------------------------------------------------------
    STATE_DIR.mkdir(parents=True, exist_ok=True)

    next_id = get_next_id()
    entries_written = 0

    for c in new_candidates:
        entry = {
            "id": f"mat_{next_id:03d}",
            "category": PATTERNS[c["pattern_name"]].get("x_category", "tech_tips"),
            "type": c["type"],
            "title": generate_title(c["matched_text"], c["pattern_name"]),
            "content": c["matched_text"][:2000],
            "key_numbers": extract_numbers(c["matched_text"]),
            "quality_score": {
                "metric_significance": round(c["score"], 1),
                "composite": round(c["score"] * 0.7, 1),
            },
            "tags": c["keyword_hits"][:5],
            "collected_at": date.today().isoformat(),
            "source": "session_auto_capture",
            "source_project": extract_project_name(cwd),
            "buzz_pattern": c["pattern_name"],
            "story_score": c.get("story_score", 0),
            "status": c.get("auto_status", "pending_review"),
        }

        with open(QUEUE_FILE, "a", encoding="utf-8") as qf:
            fcntl.flock(qf, fcntl.LOCK_EX)
            try:
                qf.write(json.dumps(entry, ensure_ascii=False) + "\n")
            finally:
                fcntl.flock(qf, fcntl.LOCK_UN)

        next_id += 1
        entries_written += 1

    # Write new fingerprints
    if new_fps:
        with open(FINGERPRINT_FILE, "a", encoding="utf-8") as ff:
            fcntl.flock(ff, fcntl.LOCK_EX)
            try:
                ff.write("\n".join(new_fps) + "\n")
            finally:
                fcntl.flock(ff, fcntl.LOCK_UN)

        # Trim fingerprint file if > 1000 entries
        if FINGERPRINT_FILE.exists():
            all_fps = FINGERPRINT_FILE.read_text(encoding="utf-8", errors="replace").strip().splitlines()
            if len(all_fps) > 1000:
                FINGERPRINT_FILE.write_text("\n".join(all_fps[-500:]) + "\n", encoding="utf-8")

    print(
        f"[transcript-scanner] Scanned {len(messages)} messages, "
        f"found {len(candidates)} candidates, wrote {entries_written} entries"
    )


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"[transcript-scanner] ERROR: {e}", file=sys.stdout)
