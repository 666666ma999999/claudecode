---
name: codebase-investigation
description: |
  大規模コードベースの構造把握・リファクタリング初期調査でrepomixを活用し、トークン効率を最大化する。
  キーワード: 構造把握, 全体像, アーキテクチャ, 依存関係, リファクタリング, 大規模調査, コードベース分析
allowed-tools: [Read, Glob, Grep, mcp__repomix__pack_codebase, mcp__repomix__pack_remote_repository, mcp__repomix__grep_repomix_output, mcp__repomix__read_repomix_output, mcp__repomix__attach_packed_output]
compatibility: "requires: repomix MCP server"
license: proprietary
metadata:
  author: masaaki-nagasawa
  version: 1.0.0
  category: testing-qa
  tags: [codebase, repomix, architecture-analysis]
---

# コードベース調査最適化スキル

## repomix 使用判定フロー

```
Q1. 調査の目的は「構造・アーキテクチャの把握」か？
    → NO → Read/Grep/Glob を使用（repomix不要）
    → YES → Q2へ

Q2. 対象コードベースは >100KB か？（または10+ファイルを横断比較するか？）
    → NO → Read/Grep で十分（オーバーヘッド > 利益）
    → YES → repomix を使用
```

## repomix 使用ワークフロー

### Step 1: 圧縮概要の取得
```
pack_codebase(directory="/絶対パス/対象ディレクトリ", compress=true)
```
- Tree-sitter が関数シグネチャ・クラス定義・import のみ抽出
- 実装本体・コメント・ボイラープレートを除去
- 元の約30%のサイズに圧縮

### Step 2: 圧縮概要でパターン検索
```
grep_repomix_output(outputId="Step 1 の出力ID", pattern="検索キーワード")
```
- 全ファイルの構造を横断検索
- 類似パターンの比較に最適

### Step 3: 候補を絞って詳細確認
```
Read で 3-5 ファイルだけ詳細読み込み
```
- repomix で特定した重要ファイルのみ Read する
- 全ファイル Read を避けてトークン節約

## 使用場面

### 1. Explore SubAgent での構造調査
- 初見のコードベースの全体像把握
- モジュール間の依存関係マッピング
- エクスポートされたAPI一覧の取得

### 2. リファクタリング初期調査
- 10+の類似実装から「参考コード」を選定
- 全サービスクラスのインターフェース比較
- 神クラスの責務分析

### 3. リモートリポジトリ分析
```
pack_remote_repository(url="https://github.com/owner/repo")
```
- OSSライブラリの構造理解
- 競合プロジェクトの設計比較
- **典型的な入力元**: `gh-star-harvest` スキルが出力する JSONL の `html_url`（副軸収集→有望リポの実装確認という接続ワークフロー）

## repomix を使わない場面

| 場面 | 理由 | 使うツール |
|------|------|-----------|
| 特定バグの追跡 | 実装詳細が必要 | Read + Grep |
| 1ファイルの修正 | オーバーヘッド > 利益 | 直接 Edit |
| 定数値・設定値の検索 | 値の詳細が必要 | Grep |
| アルゴリズムの理解 | 実装本体が必要 | Read |
| <100KB の小規模プロジェクト | 全部 Read しても安い | Read/Grep |

## トークン削減効果の目安

| 規模 | 従来（Read/Grep） | repomix使用 | 削減率 |
|------|------------------|------------|--------|
| 150KB | ~4,000 tokens | ~1,100 tokens | 72% |
| 500KB | ~14,000 tokens | ~2,700 tokens | 81% |

## 否定断定のゲート

「無い / 存在しない / やっていない」は ①全 repo 全文 grep（拡張子・ディレクトリを絞らない）+ ②`git log origin/main`（未 pull 分含む）確認後のみ。母集合の全件数を先に確認してから絞る。**同じ問いが 2 回来たら探索不足を仮定して範囲を拡大**（同じ方法の再実行は禁止）。JSON を調べるときは全キー dump してから答える。
