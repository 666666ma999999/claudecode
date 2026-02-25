---
name: tweet-classifier
description: influxプロジェクトのツイートをLLM分類するスキル。Codex MCPまたはClaude直接分析で7カテゴリに分類し、viewer.htmlを更新する。
trigger: ツイート分類, tweet classify, LLM分類, 分類実行
allowed-tools: Read, Write, Edit, Bash, mcp__codex__codex, Glob, Grep, Task
---

# ツイート分類スキル

## 概要
influxプロジェクトで収集したツイートを7カテゴリに分類し、classified_llm.jsonとviewer.htmlを更新する。

## 分類カテゴリ

| カテゴリキー | 名称 | 判定基準 |
|-------------|------|---------|
| recommended_assets | オススメしている資産・セクター | 「一択」「注目」「おすすめ」「割安」「〜が良い」等の推奨表現 |
| purchased_assets | 個人で購入・保有している資産 | 「買った」「購入」「ナンピン」「利確」「保有」等の売買報告 |
| ipo | 申し込んだIPO | 「IPO」「新規公開」「抽選」「当選」等 |
| market_trend | 市況トレンドに関する見解 | 「相場」「地合い」「先物」「利上げ」「円安」「インフレ」、半導体業界分析、コーポレートアクション等 |
| bullish_assets | 高騰している資産 | 「爆上げ」「急騰」「ストップ高」「上場来高値」「大幅高」等の急騰報告 |
| bearish_assets | 下落している資産 | 「暴落」「急落」「ストップ安」「大幅安」等の急落報告 |
| warning_signals | 警戒すべき動き・逆指標シグナル | 「信用買い残」「バブル」「天井」等の過熱警戒。逆指標アカウントの強気発言もここ |

## 重要ルール

### 逆指標アカウント（is_contrarian=true）
- **強気・楽観的な投資発言** → `warning_signals`（`bullish_assets`ではない）
- **購入報告** → `purchased_assets` + `warning_signals`
- **日常・投資無関係の投稿** → `[]`（空配列）
- 逆指標だからといって全てをwarning_signalsにしない

### 分類除外
- 日常生活ツイート（食事、旅行、運動等） → `[]`
- 政治のみの評論（投資・市場への影響に言及なし） → `[]`
- 投資哲学の一般論（具体的推奨なし） → `[]`
- 内容不明・文脈不足 → `[]`

### カテゴリ区別
- 「株が上がった」報告 = `bullish_assets`
- 「この株がいい」推奨 = `recommended_assets`
- 「この株を買った」報告 = `purchased_assets`
- 複数カテゴリ該当可

### よくある誤分類パターン（注意）
- 「青天井」=上昇余地無限大 ≠ 「天井」(警戒) → `bullish_assets`であって`warning_signals`ではない
- 「金曜」「資金」の「金」 ≠ ゴールド推奨
- 「エプスタイン」の「イン」 ≠ 購入
- 「しないほうがいい」の「がいい」 ≠ 推奨
- 非逆指標アカウントの強気発言に`warning_signals`を付けない

## 実行手順

### Step 1: データ準備
```bash
# 対象ファイル確認
ls output/$(date +%Y-%m-%d)/tweets.json
# または指定日
ls output/2026-02-19/tweets.json
```

### Step 2: 分類実行（方法A: Claude直接分析 - 推奨）
1. tweets.jsonを読み込む
2. 各ツイートを上記ルールに基づき個別分析
3. `llm_categories` (list), `llm_reasoning` (日本語), `llm_confidence` (0.0-1.0) を設定
4. classified_llm.jsonに保存

### Step 2: 分類実行（方法B: Codex MCP小バッチ）
1. 10件ずつバッチに分割
2. 各バッチに分類ルール・Few-shot例・重要ルールを含むプロンプトを作成
3. `mcp__codex__codex` で並列実行
4. 結果をマージしてclassified_llm.jsonに保存

**注意**: Codex MCPは日本語投資文脈の理解が弱いため、結果の手動レビューを推奨

### Step 3: viewer.html更新
```python
import json, re
with open('output/YYYY-MM-DD/classified_llm.json', 'r') as f:
    tweets = json.load(f)
with open('output/viewer.html', 'r') as f:
    html = f.read()
json_str = json.dumps(tweets, ensure_ascii=False, indent=2)
pattern = r'const EMBEDDED_DATA\s*=\s*\[.*?\]\s*;'
replacement = f'const EMBEDDED_DATA = {json_str};'
# IMPORTANT: lambda使用でバックスラッシュ解釈を防止
new_html = re.sub(pattern, lambda m: replacement, html, flags=re.DOTALL)
with open('output/viewer.html', 'w') as f:
    f.write(new_html)
```

### Step 4: 検証
- viewer.htmlをブラウザで開いて各カテゴリタブを確認
- 分類サマリーで件数バランスを確認

## Few-shot例

```json
[
  {"text": "今の相場ならゴールド一択", "categories": ["recommended_assets"]},
  {"text": "トヨタ100株追加購入しました", "categories": ["purchased_assets"]},
  {"text": "利上げ観測で円高に振れてる。地合い悪化の兆し", "categories": ["market_trend"]},
  {"text": "エヌビディア爆上げ！ストップ高まであるぞ", "categories": ["bullish_assets"]},
  {"text": "中国株暴落してるやん", "categories": ["bearish_assets"]},
  {"text": "信用買い残が過去最高。バブルの天井サイン", "categories": ["warning_signals"]},
  {"text": "日経平均年初来高値更新！商社株3銘柄利確した", "categories": ["market_trend", "purchased_assets"]},
  {"text": "今日のランチは天丼でした", "categories": []},
  {"text": "[contrarian] AI関連株が今後10倍！今すぐ買え！", "categories": ["warning_signals"]},
  {"text": "[contrarian] 300万くらい造船株買うつもり", "categories": ["purchased_assets", "warning_signals"]},
  {"text": "[contrarian] 今日のジム最高だった", "categories": []}
]
```

## viewer.html更新時の注意
- `re.sub()` に直接置換文字列を渡すと `\n` が生改行に変換される → **必ず `lambda m: replacement` を使用**
- JSON内の改行は `\\n` でエスケープされていること
