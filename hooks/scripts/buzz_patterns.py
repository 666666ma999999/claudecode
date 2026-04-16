"""
Pattern definitions for detecting X (Twitter) buzz-worthy content
in Claude Code conversation transcripts.
"""

import re
from dataclasses import dataclass

PATTERNS = {
    # === 既存カテゴリ ===
    "効率化": {
        "keywords": [
            "削減", "短縮", "改善", "高速化", "倍", "自動化", "自動",
            "→", "%", "秒", "時間", "LOC", "token", "トークン",
            "簡略化", "整理", "まとめ", "Obsidian",
        ],
        "min_keywords": 2,
        "type": "data_point",
        "base_score": 8.0,
        "x_category": "tech_tips",
    },
    "こんなことできるんだ": {
        "keywords": [
            "API", "連携", "gog", "gogcli", "GA", "広告",
            "比較", "試した", "使ってみた", "vs", "導入",
            "知らなかった", "発見", "初めて", "わかった", "実は", "盲点",
        ],
        "min_keywords": 2,
        "type": "insight",
        "base_score": 7.5,
        "x_category": "tech_tips",
    },
    "堅牢化": {
        "keywords": [
            "セキュリティ", "パスワード", "pass", "credential", "認証",
            "暗号", "漏洩", "権限", "gitignore", "secret", "env",
            "管理", "保護", "バックアップ",
        ],
        "min_keywords": 2,
        "type": "experience",
        "base_score": 7.0,
        "x_category": "tech_tips",
    },
    # === 新規カテゴリ ===
    "仕組み化": {
        "keywords": [
            "hook", "cron", "定期", "毎朝", "毎日", "自動実行",
            "パイプライン", "ワークフロー", "仕組み", "Routine",
            "通知", "Slack", "自動集計", "レポート",
            "設計", "アーキテクチャ", "スキル作成",
        ],
        "min_keywords": 2,
        "type": "experience",
        "base_score": 7.5,
        "x_category": "tech_tips",
    },
    "売上直結": {
        "keywords": [
            "売上", "問い合わせ", "成約", "CVR", "コンバージョン",
            "ROI", "コスト", "利益", "粗利", "KPI",
            "顧客", "LP", "広告費", "単価",
            "円", "万", "件", "率",
        ],
        "min_keywords": 2,
        "type": "data_point",
        "base_score": 8.5,
        "x_category": "ceo_perspective",
    },
    "非エンジニアでもできた": {
        "keywords": [
            "コード書かず", "コード0行", "ノーコード", "プログラミング不要",
            "素人", "初心者", "非エンジニア", "営業", "事務",
            "簡単", "誰でも", "すぐできる", "2時間", "30分",
            "Claude Code", "AI", "Copilot",
        ],
        "min_keywords": 2,
        "type": "experience",
        "base_score": 8.0,
        "x_category": "tech_tips",
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
