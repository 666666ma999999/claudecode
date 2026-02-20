# 高度なパターン

## 環境選択: ローカル vs Docker

### 結論: ローカル実行を推奨

| 環境 | 評価 | 理由 |
|------|------|------|
| **ローカル (venv)** | 推奨 | セットアップ簡単、CDP接続可能、デバッグ容易 |
| Docker + VNC | 非推奨 | 設定複雑、接続不安定、トラブル多発 |
| Docker headless | 条件付き | bot検知されやすい、事前Cookie取得必須 |

### Docker + VNC で遭遇した問題

- VNC接続後に画面が表示されない
- noVNCのパス変更でスクリプト修正が必要
- X11転送設定が複雑（macOS + XQuartz）

**-> 詳細は `playwright-browser-automation` スキルの「Docker + VNC でのGUI実行は不安定」を参照**

## Cookie有効期限の管理

### XのCookie有効期間

約数週間〜数ヶ月（変動あり）

### 再取得が必要なタイミング

- 収集スクリプトで「ログインしていません」エラー
- 認証トークン（auth_token）が期限切れ

### 推奨フロー

```
収集実行
  |
ログイン確認失敗？
  | Yes
Cookie再取得（CDP接続で手動ログイン）
  |
再実行
```

**-> 詳細は `playwright-browser-automation` スキルの「Cookie有効期限の管理パターン」を参照**

## 検索URL構文

```
min_faves:500                    # いいね500以上
from:username                    # 特定ユーザー
(from:user1 OR from:user2)       # 複数ユーザー
min_faves:100 from:user          # 組み合わせ
since:2026-01-27                 # 開始日（この日以降）
until:2026-01-29                 # 終了日（この日未満）
&f=live                          # 最新順
```

### 日付フィルタの注意点

- `since:YYYY-MM-DD` と `until:YYYY-MM-DD` で期間指定
- `until` は**その日を含まない**ため、1/27-1/28を取得するには `until:2026-01-29` が必要
- URLエンコード例: `since%3A2026-01-27%20until%3A2026-01-29`

## 動的終了判定パターン

### 概要

スクロール回数を固定せず、「新規ツイート0件がN回連続」で終了する方式。
効率的かつ取りこぼしを防ぐ。

### 実装例（Python）

```python
consecutive_empty = 0
stop_after_empty = 3  # 3回連続で終了

for i in range(max_scrolls):
    new_count = self._collect_visible_tweets(page)

    if new_count == 0:
        consecutive_empty += 1
        if consecutive_empty >= stop_after_empty:
            print(f"新規0件が{stop_after_empty}回連続のため終了")
            break
    else:
        consecutive_empty = 0  # リセット

    self._human_scroll(page)
    self._human_wait(2, 5)
```

### 実装例（Playwright MCP JavaScript）

Playwright MCPの`browser_run_code`で使用可能なJavaScriptパターン:

```javascript
async (page) => {
  const allTweets = [];
  const seenUrls = new Set();

  const maxScrolls = 50;
  const stopAfterEmpty = 3;
  let consecutiveEmpty = 0;

  for (let scrollCount = 0; scrollCount < maxScrolls; scrollCount++) {
    const prevCount = allTweets.length;

    const cards = await page.$$('[data-testid="tweet"]');

    for (const card of cards) {
      try {
        // ユーザー名
        const userElem = await card.$('[data-testid="User-Name"]');
        const usernameText = userElem ? await userElem.innerText() : '';
        const usernameMatch = usernameText.match(/@(\w+)/);
        const username = usernameMatch ? usernameMatch[1] : '';

        // 本文
        const textElem = await card.$('[data-testid="tweetText"]');
        const text = textElem ? await textElem.innerText() : '';

        // URL
        const links = await card.$$('a[href*="/status/"]');
        let url = '';
        for (const link of links) {
          const href = await link.getAttribute('href');
          if (href && href.includes('/status/')) {
            url = href.startsWith('/') ? `https://x.com${href}` : href;
            break;
          }
        }

        if (!url || seenUrls.has(url)) continue;
        seenUrls.add(url);

        // 投稿時間
        const timeElem = await card.$('time');
        const postedAt = timeElem ? await timeElem.getAttribute('datetime') : null;

        // いいね数（K/M対応）
        const likeElem = await card.$('[data-testid="like"] span span');
        const likeText = likeElem ? await likeElem.innerText() : '';
        let likes = null;
        if (likeText) {
          const upper = likeText.trim().toUpperCase();
          if (upper.includes('K')) likes = Math.round(parseFloat(upper.replace('K', '')) * 1000);
          else if (upper.includes('M')) likes = Math.round(parseFloat(upper.replace('M', '')) * 1000000);
          else likes = parseInt(upper.replace(/,/g, '')) || null;
        }

        allTweets.push({ username, text, url, posted_at: postedAt, likes });
      } catch (e) {}
    }

    // 動的終了判定
    const newCount = allTweets.length - prevCount;
    if (newCount === 0) {
      consecutiveEmpty++;
      if (consecutiveEmpty >= stopAfterEmpty) {
        return { total: allTweets.length, tweets: allTweets, reason: '3回連続空で終了' };
      }
    } else {
      consecutiveEmpty = 0;
    }

    await page.mouse.wheel(0, 800);
    await page.waitForTimeout(1500);
  }

  return { total: allTweets.length, tweets: allTweets, reason: '最大スクロール到達' };
}
```

### maxScrollsの目安（実績ベース）

2日間（since/until）の収集における実績値:

| グループ | アカウント数 | min_faves | ツイート数 | 必要スクロール | 推奨maxScrolls |
|----------|-------------|-----------|------------|----------------|----------------|
| 7名 | 100 | 25件 | ~20回 | 30 |
| 22名 | 72 | 161件 | 126回 | **130以上** |
| 1名 | 50 | 15件 | ~10回 | 20 |

**重要**: アカウント数が多く min_faves が低いグループ（22名/72いいね等）は、100回以上のスクロールが必要になる場合がある。maxScrollsが不足すると動的終了条件が発動せず、ツイートを取りこぼす。

推奨アプローチ:
1. まず maxScrolls=50 で試す
2. 「最大スクロール到達」で終了した場合 -> maxScrolls を段階的に増やす（70->100->130）
3. 「3回連続空で終了」になるまで繰り返す

### Playwright MCP での注意事項

| 問題 | 原因 | 解決策 |
|------|------|--------|
| `ReferenceError: setTimeout is not defined` | Playwright MCP環境ではNode.jsのsetTimeoutが使えない | `page.waitForTimeout(ms)` を使用 |

```javascript
// NG: setTimeout は使えない
await new Promise(r => setTimeout(r, 2000));

// OK: page.waitForTimeout を使用
await page.waitForTimeout(2000 + Math.floor(Math.random() * 1500));
```

## min_faves閾値の調整

| 状況 | 対応 |
|------|------|
| 取得件数が少ない | min_favesを下げる（500->100など） |
| ノイズが多い | min_favesを上げる |
| 特定期間のみ取得 | since/untilで日付フィルタ追加 |

## LLM分類（Claude API）

### 概要

キーワードベース分類に加え、Claude API（Haiku）を使ったLLM分類機能を実装済み。

### ファイル構成

| ファイル | 役割 |
|---------|------|
| `collector/llm_classifier.py` | LLM分類器本体（urllib.requestで依存追加なし） |
| `data/few_shot_examples.json` | Few-shot例（24件、7カテゴリ+該当なし+複数カテゴリ） |
| `scripts/classify_tweets.py` | 分類実行スクリプト（キーワード/LLM比較、viewer.html再生成） |
| `collector/config.py` の `LLM_CONFIG` | モデル名、バッチサイズ等の設定 |

### 実行方法

```bash
# ANTHROPIC_API_KEY環境変数を設定
export ANTHROPIC_API_KEY=sk-ant-...

# 最新のツイートJSONを自動検出して分類
python scripts/classify_tweets.py

# 入力ファイル指定
python scripts/classify_tweets.py --input output/tweets_YYYYMMDD_HHMMSS.json

# viewer.html再生成をスキップ
python scripts/classify_tweets.py --no-viewer
```

### 精度改善

- `data/few_shot_examples.json` に誤分類例を追加してリラン
- viewer.htmlにカテゴリフィルタタブあり（LLM/キーワード両方の分類バッジ表示）
- 逆指標アカウント（is_contrarian=true）の強気ツイート -> warning_signalsに自動分類
