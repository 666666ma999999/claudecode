---
name: x-scraping
description: |
  X(Twitter)からツイートを安全に収集するスキル。bot検知を回避しながらPlaywrightでスクレイピングを実行。
  Cookieベース認証、人間らしい操作パターン、いいね数フィルタリングに対応。
  キーワード: X, Twitter, スクレイピング, ツイート収集, インフルエンサー
compatibility: "requires: Playwright, Python 3.x, X(Twitter) cookies"
metadata:
  author: masaaki-nagasawa
  version: 1.1.0
---

# X (Twitter) スクレイピングスキル

## 使用タイミング

以下のリクエストで発動:
- 「Xからツイートを収集」
- 「Twitterスクレイピング」
- 「インフルエンサーの投稿を取得」
- 「X収集システムを構築」

## 重要な制約

### Xのbot検知対策
1. **Playwrightで直接ログイン不可** - ユーザー名入力時点でブロックされる
2. **必ず手動ログイン後のCookie利用** - リモートChromeデバッグ経由で取得
3. **週1-2回程度の使用推奨** - 頻繁なアクセスはアカウント凍結リスク

### 技術的制約
- X APIは有料（月額$100〜）のため、ブラウザ自動化を採用
- 通知メール経由ではいいね数を取得できない
- Nitterミラーは多くが機能停止

## セットアップ手順

### 1. プロジェクト構成

```
project/
├── collector/
│   ├── __init__.py
│   ├── config.py        # インフルエンサー設定、検索URL
│   ├── x_collector.py   # メイン収集クラス
│   └── classifier.py    # ツイート分類（オプション）
├── scripts/
│   └── collect_tweets.py
├── x_profile/
│   └── cookies.json     # 認証Cookie
├── output/              # 収集結果
├── requirements.txt
└── venv/
```

### 2. 依存パッケージ・Cookie取得

-> 詳細手順は `references/setup-guide.md` を参照

**要点:**
1. `playwright==1.57.0` と `python-dateutil>=2.8.2` をインストール
2. 全Chrome終了 -> デバッグモードChrome起動(`--remote-debugging-port=9222`)
3. ChromeでX.comに手動ログイン
4. Playwright CDPでCookie取得・保存
5. デバッグChrome終了 -> 通常Chrome復帰

## コア実装概要

| コンポーネント | 役割 |
|---------------|------|
| `config.py` | インフルエンサーグループ定義、検索URL生成、収集設定（待機時間等） |
| `x_collector.py` | `SafeXCollector`クラス: Cookie読込、ブラウザ起動、人間らしいスクロール、ツイート解析 |
| `classifier.py` | LLM分類（オプション）: Claude API (Haiku) によるツイート分類 |

**主要セレクタ:**
- ツイートカード: `[data-testid="tweet"]`
- ユーザー名: `[data-testid="User-Name"]`
- 本文: `[data-testid="tweetText"]`
- いいね: `[data-testid="like"] span span`
- ログイン確認: `[data-testid="SideNav_AccountSwitcher_Button"]`

-> 完全なコードは `references/core-implementation.md` を参照

## クイック実行

```bash
# 環境準備
cd /path/to/project
source venv/bin/activate

# 特定グループ収集
python scripts/collect_tweets.py --groups group1 --scrolls 5

# 全グループ収集
python scripts/collect_tweets.py --scrolls 10
```

## 検索URL構文（早見表）

```
min_faves:500              # いいね500以上
from:username              # 特定ユーザー
(from:user1 OR from:user2) # 複数ユーザー
since:2026-01-27           # 開始日（この日以降）
until:2026-01-29           # 終了日（この日未満、1/28まで取得）
&f=live                    # 最新順
```

-> 日付フィルタの注意点・詳細は `references/advanced-patterns.md` を参照

## 詳細リファレンス

| トピック | ファイル |
|---------|---------|
| Cookie取得・依存パッケージ | `references/setup-guide.md` |
| config.py・x_collector.py実装 | `references/core-implementation.md` |
| プロジェクト構成テンプレート | `references/project-template.md` |
| トラブルシューティング | `references/troubleshooting.md` |
| 動的終了判定・検索構文・LLM分類 | `references/advanced-patterns.md` |

## 関連ガイド
- ツール選択基準: `~/.claude/rules/tool-selection.md` を参照
- ブラウザ自動化: `playwright-browser-automation` スキルを参照
