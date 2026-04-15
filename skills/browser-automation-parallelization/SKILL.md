---
name: browser-automation-parallelization
description: Playwrightベースのブラウザ自動化バッチを並列化する設計パターン。BrowserContext分離+Semaphoreスロット制御により、既存のグローバルmutexをコンバージョン単位の並行実行に置き換える。28時間→10時間程度への短縮を目的としたい時に使用。
keywords: Playwright, 並列化, 並行実行, BrowserContext, Semaphore, ブラウザ自動化, スロット制御, mutex, batch parallelization, throughput
triggers:
  - Playwright並列化
  - ブラウザ自動化の高速化
  - バッチスループット向上
  - mutex競合解消
  - 並列CMS登録
---

# Browser Automation Parallelization

Playwrightベースの長時間バッチ処理を並列化するための設計パターン。

## When to use

- 複数コンバージョン × 複数STEPの順次ブラウザ自動化バッチで処理時間が長すぎる
- グローバルmutexで並列実行がブロックされている
- Docker環境でメモリ制約がある（8GB程度）
- CMS登録・スクレイピング・フォーム入力など、Playwright async APIで実装済み

## When NOT to use

- 単発のブラウザ操作（並列化する対象がない）
- 各STEPがCMS側で重いロックを持つ（並列化しても効果なし）
- 外部APIの厳しいレート制限がある（並列化が逆効果）

## 並列化の4選択肢と推奨

| 選択肢 | メモリコスト | 独立性 | 実装規模 | 推奨度 |
|--------|:----------:|:------:|:--------:|:------:|
| **A: 複数BrowserContext** | 低 | 中（Cookie/Session分離OK） | 小〜中 | **推奨** |
| B: 複数Chromium | 中 | 強 | 中 | A失敗時 |
| C: Firefox/WebKit併用 | 中 | 強 | 中 | 非推奨（互換性リスク） |
| D: 複数Dockerコンテナ | 高 | 最強 | 大 | スケール時 |

### Option A を最優先する理由

1. **メモリ効率**: 1 Chromiumプロセスに複数Contextなのでメモリオーバーヘッド最小
2. **実装最小**: 既存のPlaywright async APIをほぼそのまま使える
3. **Session分離**: `browser.new_context()` でCookie/localStorage/認証を完全分離
4. **Docker 8GB制約でもN=2〜3が現実的**

## 実装パターン

### ステップ1: 既存mutexを確認

```python
# BAD: グローバルmutexで全STEPが直列化
_GLOBAL_MUTEX = asyncio.Lock()

async def execute_step_generic(session_id, step):
    async with _GLOBAL_MUTEX:  # ← 全体が1つずつしか動かない
        ...
```

### ステップ2: スロットベースSemaphoreに置き換え

```python
# GOOD: N個のスロットを並列実行可
BROWSER_SLOTS = asyncio.Semaphore(2)  # まずN=2から

async def execute_conversion(conv):
    async with BROWSER_SLOTS:
        # このコンバージョンは全STEP 2-8を連続実行
        # （mutexのような「STEPごと」ではなく「コンバージョンごと」）
        for step in [2, 3, 4, 5, 6, 8]:
            await execute_step(conv.session_id, step)
```

### ステップ3: BrowserContext分離

```python
async def launch_browser_for_conversion():
    browser = await playwright.chromium.launch(proxy=PROXY_CONFIG)
    # 各コンバージョン専用のContextを作成
    context = await browser.new_context(
        storage_state=None,  # 毎回fresh start
        ignore_https_errors=True,
    )
    try:
        yield context
    finally:
        await context.close()
        await browser.close()
```

## パーティショニング方針

**❌ ステップ単位で並列化しない**
- Site A のSTEP 2 と Site A のSTEP 3 を並列 → データ競合（同じsession_id）

**✅ コンバージョン単位で並列化**
- Site A のSTEP 2 と Site B のSTEP 5 を並列 → 独立（別session_id, 別Context）

## 段階的拡張

```
Phase 1: N=2 で試験実装（8-16時間）
  - 安定性確認、メモリ監視
  - 1バッチ完走で問題なければPhase 2へ

Phase 2: N=3 にチューニング（4-6時間）
  - CMS側のレート制限確認
  - Squidプロキシの帯域確認

Phase 3: Option B/D へ拡張（必要時のみ）
  - Chromiumクラッシュ頻発 → Option B
  - 更なるスループット必要 → Option D
```

## 主なリスク

| リスク | 対策 |
|--------|------|
| CMS側のレート制限 | CMS単位のレート制限を別途追加（per-CMS semaphore） |
| Squidプロキシ帯域 | プロキシ接続数を監視、必要なら別プロキシ追加 |
| 同一CMSアカウント並行ログイン禁止 | CMSごとに別アカウント準備 |
| Chromiumメモリ成長 | N時間/N件ごとにブラウザ再起動、OOM監視 |
| 1ブラウザクラッシュで全Context停止 | 例外時に各コンバージョンへ分岐（try/except） |

## 検証チェックリスト

- [ ] N=2 でメモリ消費が安定（2-3GB増に収まる）
- [ ] 2コンバージョン並列でCookie/Session混線なし
- [ ] CMSからのレート制限エラー（429等）が出ない
- [ ] ブラウザクラッシュ時に片方だけ失敗、もう片方は継続
- [ ] 実測スループットが1.8x以上（N=2で理想は2.0x）

## 関連スキル

- `max-scroll-scrape`: Playwrightスクレイピング全般（逐次パターン）
- `execution-patterns`: SubAgent並列委託との使い分け
- `tool-selection-reference`: Playwright vs Firecrawl の選択基準
