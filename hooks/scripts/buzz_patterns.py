"""
Pattern definitions for detecting X (Twitter) buzz-worthy content
in Claude Code conversation transcripts.
"""

import re
from dataclasses import dataclass

PATTERNS = {
    "数値Before/After": {
        "keywords": ["削減", "短縮", "改善", "→", "%", "秒", "時間", "LOC", "token", "トークン", "高速化", "倍"],
        "min_keywords": 2,
        "type": "data_point",
        "base_score": 8.0,
    },
    "失敗→復旧ストーリー": {
        "keywords": ["バグ", "エラー", "修正", "原因", "解決", "ハマった", "壊れ", "障害", "復旧"],
        "min_keywords": 2,
        "type": "experience",
        "base_score": 7.5,
    },
    "TIL": {
        "keywords": ["知らなかった", "発見", "初めて", "わかった", "実は", "盲点", "気づ"],
        "min_keywords": 1,
        "type": "insight",
        "base_score": 6.5,
    },
    "Builder's Diary": {
        "keywords": ["実装", "作った", "構築", "完成", "リリース", "デプロイ", "設計"],
        "min_keywords": 2,
        "type": "experience",
        "base_score": 7.0,
    },
    "ツール比較/発見": {
        "keywords": ["比較", "試した", "使ってみた", "vs", "乗り換え", "移行", "導入"],
        "min_keywords": 2,
        "type": "experience",
        "base_score": 7.0,
    },
    "Vibe Coding体験": {
        "keywords": ["Claude", "自動", "Agent", "一発で", "AI", "Copilot", "MCP", "自律"],
        "min_keywords": 2,
        "type": "experience",
        "base_score": 7.5,
    },
}

# Build a compiled regex that ORs all keywords from all patterns
# Used for fast pre-filtering of raw text lines before JSON parsing
_all_keywords = []
for _pattern in PATTERNS.values():
    _all_keywords.extend(_pattern["keywords"])
_unique_keywords = list(dict.fromkeys(_all_keywords))  # deduplicate preserving order
PREFILTER_REGEX = re.compile("|".join(re.escape(kw) for kw in _unique_keywords))


@dataclass
class PatternMatch:
    pattern_name: str
    matched_keywords: list
    score: float
    text_excerpt: str  # max 2000 chars


def match_patterns(text: str) -> list:
    """
    For each pattern, count how many distinct keywords appear in text.
    If count >= min_keywords, create a PatternMatch.
    Score = base_score + 0.1 * (count - min_keywords), capped at base_score + 1.0.
    text_excerpt = first 2000 chars of text.
    """
    results = []
    excerpt = text[:2000]

    for pattern_name, pattern_def in PATTERNS.items():
        keywords = pattern_def["keywords"]
        min_keywords = pattern_def["min_keywords"]
        base_score = pattern_def["base_score"]

        matched = [kw for kw in keywords if kw in text]
        # Deduplicate while preserving order
        seen = set()
        distinct_matched = []
        for kw in matched:
            if kw not in seen:
                seen.add(kw)
                distinct_matched.append(kw)

        count = len(distinct_matched)
        if count >= min_keywords:
            raw_score = base_score + 0.1 * (count - min_keywords)
            score = min(raw_score, base_score + 1.0)
            results.append(PatternMatch(
                pattern_name=pattern_name,
                matched_keywords=distinct_matched,
                score=round(score, 2),
                text_excerpt=excerpt,
            ))

    return results


def extract_numbers(text: str) -> list:
    """
    Find numeric patterns like "5000→3000", "30%削減", "10秒→2秒", etc.
    Returns list of matched strings, max 5 items.
    """
    pattern = re.compile(
        r'\d+(?:\.\d+)?'
        r'(?:'
        r'[→\-–—]'
        r'\d+(?:\.\d+)?'
        r'(?:[秒分時間%倍mssMB GB KB LOC token]|トークン)?'
        r'|'
        r'[%倍](?:削減|短縮|改善|高速化)?'
        r'|'
        r'[秒分時間](?:→\d+(?:\.\d+)?[秒分時間])?'
        r')'
    )
    matches = pattern.findall(text)
    return matches[:5]


def generate_title(matched_text: str, pattern_name: str) -> str:
    """
    Extract first sentence (up to 。or . or newline).
    Truncate to 60 chars.
    If no sentence found, use first 60 chars + "...".
    """
    # Find first sentence boundary
    m = re.search(r'[。.\n]', matched_text)
    if m:
        sentence = matched_text[:m.start()]
    else:
        sentence = ""

    if sentence:
        if len(sentence) > 60:
            return sentence[:60]
        return sentence
    else:
        if len(matched_text) > 60:
            return matched_text[:60] + "..."
        return matched_text
