---
name: fetch-engagement
description: influxプロジェクトのVNCコンテナ経由でX(Twitter)投稿のエンゲージメント（likes/views/retweets/replies/bookmarks）を取得する。単体URL・URLリスト・候補Markdown抽出に対応。取得結果を素材テーブルに自動追記できる。
keywords: engagement, エンゲージメント, X投稿, Twitter, likes, views, impression, いいね数, リーチ, 教師データ, 実測検証
triggers:
  - エンゲージメント取得
  - いいね数取得
  - X投稿の実測
  - バズ投稿検証
  - 候補URLの数値確認
  - fetch engagement
---

# X Post Engagement Fetch Skill

## When to use
- Grok検索等で収集したX投稿URLの実測エンゲージメントを取りたい時
- 教師データ候補の振り分け（いいね100+フィルタ）を実行したい時
- 投稿後の実績値を記録したい時
- `/record-result` スキルの裏付け数値が必要な時

## Not for
- ブックマーク一括取得 → `fetch-bookmarks` スキル
- X投稿そのものの生成 → `/generate-x-post`, `/generate-x-article`

## Prerequisites
- influxプロジェクト: `~/Desktop/biz/influx`（`INFLUX_ROOT` 環境変数 or デフォルト）
- Docker: `docker-compose.vnc.yml` が存在すること
- VNCコンテナ `xstock-vnc` が起動可能であること
- `x_profile/cookies.json` が有効であること（14日以上経つと期限切れの可能性）
- make_article側ラッパー: `scripts/fetch_engagement_via_influx.sh` が存在すること

## Workflow

### Step 1: 前提確認
```bash
# make_article 側からの呼び出しを想定
ls scripts/fetch_engagement_via_influx.sh && echo "OK"
```

### Step 2: VNCコンテナ起動確認・起動
ラッパースクリプト側で自動 pre-flight が走るが、明示的に確認したい場合:
```bash
docker ps --filter name=xstock-vnc --filter status=running -q
# 空なら
cd ~/Desktop/biz/influx && docker compose -f docker-compose.vnc.yml up -d
```

### Step 3: Cookie有効性確認（自動実行）
ラッパー `fetch_engagement_via_influx.sh` がバッチ先頭で自動プリフライトする:
- **age < 12日**: `[PRE-FLIGHT] Cookie age=Nd: OK`
- **12日 ≤ age < 14日**: `[WARN]` 近日中に refresh 推奨を表示して続行
- **age ≥ 14日**: `[ERROR]` refresh コマンドを表示して **exit 3**

手動確認したい場合:
```bash
python3 -c "import os, time; p='$HOME/Desktop/biz/influx/x_profile/cookies.json'; print(int((time.time() - os.path.getmtime(p))/86400), 'days')"
```

Cookie期限切れの場合（プリフライト or 実行時にexit code 3）:
```bash
docker exec xstock-vnc rm -f /app/x_profile/SingletonLock /app/x_profile/SingletonCookie /app/x_profile/SingletonSocket
docker exec -d xstock-vnc python scripts/refresh_cookies_vnc.py --timeout 600
echo "http://localhost:6080 でVNCを開きXにログインしてください"
```

### Step 4: エンゲージメント取得

**パターンA: 単体URL**
```bash
bash scripts/fetch_engagement_via_influx.sh --url https://x.com/user/status/123 --no-update-table
```

**パターンB: URLリストファイル**
```bash
bash scripts/fetch_engagement_via_influx.sh --urls-file /tmp/urls.txt
```

**パターンC: 候補Markdown自動抽出**（最頻用）
```bash
bash scripts/fetch_engagement_via_influx.sh --urls-from-candidates
# デフォルト: output/plans/claude_tips_theme_a_b_candidates.md
# デフォルト出力: output/engagement/YYYYMMDD.jsonl
```

共通オプション:
- `--out <path>`: 出力JSONL先
- `--threshold <n>`: 素材テーブル追記閾値（default: 100）
- `--no-update-table`: 素材テーブル更新をスキップ

### Step 5: 結果確認
```bash
wc -l output/engagement/*.jsonl
head -3 output/engagement/*.jsonl | python3 -c "
import sys, json
for l in sys.stdin:
    d = json.loads(l)
    print(f'  {d[\"url\"][:60]}  {d[\"status\"]:12s}  likes={d.get(\"likes\",0)}')
"
```

スキップ記録:
```bash
cat output/engagement/*.skipped.log
```

### Step 6: 素材テーブル更新（手動起動も可）
ラッパーが `--no-update-table` でない限り自動実行。手動起動の場合:
```bash
python3 scripts/update_material_table.py \
  --jsonl output/engagement/YYYYMMDD.jsonl \
  --candidates output/plans/claude_tips_theme_a_b_candidates.md \
  --target output/plans/claude_tips_planmd.md \
  --threshold 100
```

更新ルール:
- status=ok かつ likes >= threshold のみ採用
- candidates.md の「テーマA」→ `### 失敗系(F)` に F1, F2, ...
- candidates.md の「テーマB」→ `### コスト系(C)` に C1, C2, ...
- 既存URLは冪等性のためskip

## Output

### JSONLスキーマ（1URL = 1行）

**成功:**
```json
{"url": "https://x.com/...", "status": "ok", "likes": 123, "views": 4567,
 "retweets": 8, "replies": 2, "bookmarks": 10, "scraped_at": "2026-04-18T17:02:17+09:00"}
```

**失敗:**
```json
{"url": "https://x.com/...", "status": "deleted", "error_detail": "...",
 "scraped_at": "2026-04-18T17:02:17+09:00"}
```

status値:
- `ok`: 正常取得
- `deleted`: 削除済み投稿
- `protected`: 鍵アカウント
- `login_required`: Cookie失効（バッチ途中の場合のみ個別記録、先頭で検出時はexit 3で停止）
- `rate_limited`: X側のレート制限
- `other`: その他エラー（例外メッセージを error_detail に格納）

### 生成ファイル
- 生JSONL: `output/engagement/YYYYMMDD.jsonl`
- スキップログ: `output/engagement/YYYYMMDD.skipped.log`
- 素材テーブル（更新済み）: `output/plans/claude_tips_planmd.md`

## Failure handling

| 症状 | 原因 | 対処 |
|------|------|------|
| exit 3, Cookie期限切れメッセージ | X.com のセッション失効 | `docker exec -d xstock-vnc python scripts/refresh_cookies_vnc.py --timeout 600` → VNC(http://localhost:6080) で再ログイン |
| exit 2, コンテナ起動失敗 | Docker未起動 or compose定義不正 | `cd ~/Desktop/biz/influx && docker compose -f docker-compose.vnc.yml up -d` |
| `Missing X server or $DISPLAY` エラー | DISPLAY未設定で docker exec 実行 | **ラッパー使用必須**。直接呼ぶなら `-e DISPLAY=:99` を必ず付ける |
| 全URLが status=other | DOM selector変化 or BOT検知 | `_scrape_impressions` / `_scrape_metric` の selector を最新仕様に合わせて更新 |
| 特定URLが status=deleted | 投稿削除済み | 正常動作。skipped.log に記録される |

## 実測パフォーマンス
- Cold start含む1URL: 約11.5秒
- 連続処理（ブラウザ再利用）: 1URL 2-3秒
- 34URL完走: 約2分（目標5分以内 ✓）

## 関連ファイル
- ラッパー: `~/Desktop/biz/make_article/scripts/fetch_engagement_via_influx.sh`
- 素材更新: `~/Desktop/biz/make_article/scripts/update_material_table.py`
- 本体: `~/Desktop/biz/influx/scripts/fetch_engagement.py`
- コアクラス: `~/Desktop/biz/influx/extensions/tier3_posting/impression_tracker/scraper.py`
- Cookie管理: `~/Desktop/biz/influx/scripts/refresh_cookies_vnc.py`
