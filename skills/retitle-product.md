---
name: retitle-product
description: 占い商品の改題システム。商品名+小見出し+改題変数から新商品を生成する11体Agent Pipeline。
  /retitle コマンドで起動。APIキー不要、Claude Code自身がLLMとして全Agentを実行。
allowed-tools:
  - Read
  - Write
  - Bash
  - Agent
---

# 占い商品改題スキル

## トリガー
- `/retitle` コマンド
- 「改題」「商品名変更」「タイトル変更」「小見出し生成」等のキーワード

## 実行フロー

### Step 0: 入力収集
ユーザーから以下を収集（AskUserQuestionで未入力項目を確認）:
- **商品名**: 【括弧KW】本文 形式
- **小見出し**: 9個前後のリスト
- **改題変数**:
  - 年代: (例: 50代)
  - テーマ: 恋愛/復縁/結婚/仕事/人生
  - シチュエーション: 年の差/職場/既婚/不倫/W不倫/遠距離/LGBT (任意)
  - シーズン: 春/夏/秋/冬/クリスマス/年末年始 (任意)
  - キーワード: SNS疲れ/既読スルー等 (任意)

### Step 1: Planner（企画）
元商品を分解し、改題方針を決める:
1. 括弧KW分解（各KWの軸: 関係性/感情/時期/結果）
2. 小見出し9個に役割コード付与（FOUNDATION/VALIDATION/REVELATION/SECRET/TIMING/DESTINY/WARNING/CLIMAX/ACTION）
3. 改題で変えるもの/変えないものを明確化

### Step 2: Marketer + Fortune Teller（並列）

**Marketer（マーケター）**:
- ターゲットのペルソナ定義
- 最大の「痛み」と「期待」
- 刺さる言葉リスト5個 / NG言葉リスト5個
- 購買動機の核（「〇〇が知りたい」）

**Fortune Teller（占い師）**:
- テーマ別の占い的フレーム
- 占い師が言いそうな言い回し10個
- 9段構造での占い要素配置ガイド

### Step 3: Copywriter + Story Writer（並列）

**Copywriter（コピーライター）** — 商品名3案:
- 制約: 括弧KW 3-4個、3軸以上、30文字以内、同義重複なし
- 各案に選定理由付き

**Story Writer（構成作家）** — 小見出し9個:
- 絶対ルール: #1=土台, #3=核心, #7=警告, #9=行動
- 感情曲線: 安心→高揚→緊張→解決→行動
- 各15-25文字

### Step 4: Rewriter（推敲）
- 語彙統一（商品名↔小見出し間）
- 表現重複排除
- リズム調整
- 商品名3案→最適1案推薦

### Step 5: Editor + Compliance（並列）

**Editor（編集長）** — 6軸評価:
- persona_fit / theme_fit / story_flow / lexical_diversity / searchability / purchase_motivation
- 全軸0.85以上でPASS

**Compliance（コンプラ）**:
- 過度な断定 / 第三者攻撃 / 不倫直接語 / LGBT他者化 / 依存誘導 をチェック

### Step 6: Sales Analyst + Test Customer（並列）

**Sales Analyst（データ分析）**:
- 売上予測スコア A/B/C/D
- 競合差別化度
- CTR改善提案

**Test Customer（テスト顧客）**:
- ペルソナになりきって5段階購買シミュレーション
- 購買確率 0-100%
- 最も刺さったポイント / 最も弱いポイント

### Step 7: Commercial Judge（最終判断）
- GO: 全基準クリア → 最終出力
- REVISE: 1-2項目未達 → Step 4に戻って修正
- KILL: 3項目以上未達 → Step 1から変数変更

## 出力フォーマット

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📦 改題結果
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🏷️ 商品名:
【KW1/KW2/KW3/KW4】タイトル本文

📋 小見出し:
1. [FOUNDATION] xxxxxxxxxx
2. [VALIDATION] xxxxxxxxxx
3. [REVELATION] xxxxxxxxxx ← 購入動機の核
4. [SECRET]     xxxxxxxxxx
5. [TIMING]     xxxxxxxxxx
6. [DESTINY]    xxxxxxxxxx
7. [WARNING]    xxxxxxxxxx ← 感情の谷
8. [CLIMAX]     xxxxxxxxxx
9. [ACTION]     xxxxxxxxxx ← 行動で締め

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 品質評価
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Editor:     persona_fit=X.XX  story_flow=X.XX  ...
Compliance: OK / NG (詳細)
Sales:      A/B/C/D (理由)
TestCustomer: XX% (刺さったポイント)
Commercial: GO / REVISE / KILL

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔄 適用した変換
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
変数: 50代 × 復縁 × 春
語彙シフト: 恋→想い, あの人→あの方, 接近日→再会日
```

## ルールテーブル参照
詳細な変換テーブル・NG表現は以下を参照:
- `~/Desktop/prm/chk/tasks/retitle-handoff.md`（全ルール定義）
- `~/Desktop/prm/rohan/docs/retitle-rules.md`（rohan実装後）
