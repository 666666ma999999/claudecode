# Xスクレイピング プロジェクトテンプレート

## ディレクトリ構成

```
project/
├── collector/
│   ├── __init__.py
│   ├── config.py          # 設定（インフルエンサー、URL等）
│   ├── x_collector.py     # 収集クラス
│   └── classifier.py      # 分類クラス（オプション）
├── scripts/
│   ├── collect_tweets.py  # 収集実行スクリプト
│   └── setup_cookies.py   # Cookie取得スクリプト
├── x_profile/
│   └── cookies.json       # 認証Cookie（git ignore推奨）
├── output/                # 収集結果
├── requirements.txt
├── .gitignore
└── README.md
```

## 最小構成ファイル

### requirements.txt
```
playwright==1.57.0
python-dateutil>=2.8.2
```

### .gitignore
```
venv/
__pycache__/
*.pyc
x_profile/
output/
.env
```

### collector/__init__.py
```python
from .x_collector import SafeXCollector
from .config import INFLUENCER_GROUPS, SEARCH_URLS

__all__ = ['SafeXCollector', 'INFLUENCER_GROUPS', 'SEARCH_URLS']
```

### scripts/collect_tweets.py
```python
#!/usr/bin/env python3
import sys
import argparse
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from collector import SafeXCollector, SEARCH_URLS, INFLUENCER_GROUPS


def main():
    parser = argparse.ArgumentParser(description="Xツイート収集")
    parser.add_argument("--groups", nargs="+", default=list(SEARCH_URLS.keys()))
    parser.add_argument("--scrolls", type=int, default=10)
    parser.add_argument("--output", default="output")
    args = parser.parse_args()

    collector = SafeXCollector()

    for group in args.groups:
        if group not in SEARCH_URLS:
            print(f"[警告] 不明なグループ: {group}")
            continue

        tweets = collector.collect(
            search_url=SEARCH_URLS[group],
            max_scrolls=args.scrolls,
            group_name=group
        )

        if tweets:
            collector.save_to_json(output_dir=args.output)


if __name__ == "__main__":
    main()
```

## 初期セットアップ手順

```bash
# 1. プロジェクト作成
mkdir my-x-scraper && cd my-x-scraper

# 2. 仮想環境
python3 -m venv venv
source venv/bin/activate

# 3. 依存インストール
pip install playwright python-dateutil
playwright install chromium

# 4. ディレクトリ作成
mkdir -p collector scripts x_profile output

# 5. 設定ファイル作成（config.py等）

# 6. Cookie取得
# → 別途Chrome起動してログイン後に取得

# 7. 実行テスト
python scripts/collect_tweets.py --groups group1 --scrolls 2
```

## 検索URL例

```python
# いいね500以上、特定ユーザー
"https://twitter.com/search?q=min_faves:500 from:user1&f=live"

# いいね100以上、複数ユーザー
"https://twitter.com/search?q=min_faves:100 (from:user1 OR from:user2)&f=live"

# キーワード検索
"https://twitter.com/search?q=min_faves:50 株&f=live"
```

## 動作確認チェックリスト

- [ ] venv作成・有効化
- [ ] playwright, python-dateutil インストール
- [ ] playwright install chromium 実行
- [ ] Chrome終了確認 (`pgrep Chrome`)
- [ ] デバッグモードでChrome起動
- [ ] ChromeでXにログイン
- [ ] Cookie取得・保存確認
- [ ] テスト収集実行
- [ ] 結果JSON確認
