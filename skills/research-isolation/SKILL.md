---
name: research-isolation
description: >-
  探索・PoCをmainから隔離し確定知見だけ昇格させる3原則ガイド(具体は各projectのdocs/research-workflow.mdへ委譲)。
  トリガー: リサーチ運用,探索的分析,EDA,使い捨てスクリプト,中間データ,worktree隔離,確定知見だけ昇格,残骸を捨てる,データ散らかし防止,research workflow,scratch script,keep main clean。
  NOT for: 通常開発/リファクタ/テスト修正,git安全則→git-safety-reference,台帳化→finding-sync,PIIマスク→SECURITYルール
allowed-tools: [Read, Glob, Grep]
license: proprietary
metadata:
  author: masaaki-nagasawa
  version: 1.0.0
  category: workflow-automation
  tags: [research, exploratory-analysis, worktree, git-hygiene, data-management, scratch-files]
---

# Research Isolation — 探索を本流から隔離する 3 原則

## 発火・詳細（description から移設 2026-07-03）

Keywords(EN 全量): research workflow, exploratory analysis, EDA, scratch script, throwaway file, worktree isolation, promote findings, regenerable data, keep main clean ／ 探索を本流に混ぜない, 分析ファイルが増える, NOT for: 1ファイル修正・docsのみ編集

探索的分析・リサーチ・PoC を「main を汚さず・再生成データを散らかさず・使い捨てファイルを
増やさず」回すための普遍 3 原則ガイド。確定知見だけを本流へ昇格させるワークフローを、特定の
接頭辞・パス・しきい値に依存しない形で提供する（具体化は各プロジェクトの規約ファイル、例
docs/research-workflow.md へ委譲する＝役割分離）。

WHEN: 探索的データ分析や調査を始める前に置き場所と隔離方法を決める / リサーチ用にブランチや
worktree を切るか迷う / 使い捨てスクリプトや中間データ(pkl・CSV)の扱いを決める / 探索成果を
main へ昇格させる / リサーチ worktree を棚卸し撤去する とき。

NOT for: 通常の機能開発・1ファイル修正・リファクタ・テスト修正・docs のみ編集では使わない。
ブランチ削除や rm --cached の git 安全則そのもの(→ git-safety-reference)、確定知見の台帳化
実装(→ project の finding-sync 等)、PII マスク実装(→ project の SECURITY ルール)は扱わない。
「本流から隔離したい / 使い捨て物が出る / 確定知見だけ昇格する」のどれかが見えている時だけ発動する。

探索的分析（リサーチ・PoC・データ深掘り）は、確定するまで本流（main）に痕跡を残さない。
本 skill は **思想（普遍）だけを定義する**。**具体（接頭辞・パス・しきい値・gitignore 実装）は
各プロジェクトが自分の規約ファイル**（例: `docs/research-workflow.md`）で定義し、本流の
CLAUDE.md から 1 行リンクで参照する。

> **役割分離（drift 防止の不変条件）**: 本 skill = *Why と型*。project doc = *固有の具体*。
> **同じ Why を両方に書かない**。project-local の規約ファイルがあれば必ずそちらを優先し、
> 無ければ本 skill のデフォルトに従う。SSoT は常に project doc 側。
> （`vault-report-writing → obsidian-markdown` と同じ「設計担当 / 委譲」構造）

## いつ使う / 使わない

- **使う**: 探索的な分析・調査を始める前（置き場所と隔離方法を決める）/ 使い捨てスクリプト・
  中間データ（pkl・parquet・一時 CSV）の扱いに迷ったとき / 探索で出た知見を本流へ戻す（昇格）とき /
  リサーチ用ブランチ・worktree を棚卸しするとき。
- **使わない**: 通常の機能開発・1 ファイル修正・リファクタ・テスト修正・docs のみ編集。
  これらは「探索」でも「使い捨て物が出る」状況でもない。発動条件は **本流から隔離したい /
  使い捨て物が出る / 確定知見だけ昇格する** のどれかが見えている時に限る。

## 原則 1 — 探索は隔離ブランチ / worktree で行う

探索的分析は **専用の隔離ブランチ（可能なら git worktree）** で行い、確定するまで main に
ファイルを足さない。

- **1 隔離 = 1 テーマ**。テーマが変わったら新しく切る（使い回さない）。混在は履歴と昇格判断を
  曖昧にする。
- 隔離ブランチには **リサーチ専用の命名接頭辞**を付け、機能開発ブランチと一目で区別する。
- **確定知見だけを main へ昇格**する。探索の残骸（使い捨てスクリプト・中間データ）は戻さない。
  隔離ごと撤去すれば消える。
- リサーチ完了（昇格 or 破棄を決めた）後の worktree / ブランチは **放置せず撤去**する。
  隔離が溜まったら棚卸しのサイン。
- 撤去・ブランチ削除は git 安全則に従う（未マージを `-D` で消さない・昇格漏れを先に確認・
  詳細は `git-safety-reference`）。

> worktree は「隔離手段の第一候補」であって必須ではない。worktree が使えない / 不向きな
> リポジトリでは通常の隔離ブランチで同じ思想を満たせばよい。
>
> **project doc で具体化する**: 隔離手段（worktree か通常ブランチか）、ブランチ / ディレクトリの
> 命名（接頭辞・配置）、他用途ブランチとの区別ルール。

## 原則 2 — 再生成可能なデータは git に入れない

リサーチが生むデータを「再生成できるか」で分け、**再生成可能なものは版管理しない**。

- **派生物（中間 pkl / parquet 等）は gitignore**。生成スクリプトが SSoT なので何度でも作れる。
  コミットしようとしない。
- **元データ（重い・機密）も版管理しない**。代わりに **取得元を台帳化**して再取得可能にする。
- **一時集計はファイル化しない**。`print()` で標準出力に出して捨てる。中間 CSV を量産しない。
- **機密・個人情報を外に出さない**。保存・共有が必要なら **プロジェクト指定のマスク経路**を通す。
  生のクエリ結果・DataFrame head を外部 LLM の context に貼らない。

> **project doc で具体化する**: 派生物 / 元データ / レポートの具体パス、gitignore 方式
> （denylist / allowlist）、台帳ファイル名、PII マスク実装と匿名性しきい値。

## 原則 3 — 使い捨てファイルを追跡外に隔離し、確定時だけ昇格する

探索スクリプトでディレクトリが膨れるのを、**命名で git 追跡可否を分ける**ことで止める。

- **使い捨て（探索）**: 追跡外プレフィックスを付ける。`.gitignore` でそのパターンを除外し、
  探索中は何個作っても本流の履歴に乗らない。
- **再利用 util**: 最初から正式名で置く（使い捨てプレフィックスを付けない＝追跡対象）。
- **昇格（確定）**: 確定した分析だけプレフィックスを外し（正式名にリネーム）、**そこで初めて
  `git add`** する。追跡外だったので `git mv` は不要・普通の `mv`。
- **破棄（用済み）**: 単純に `rm`。追跡外なので削除しても git status / 履歴は汚れない。

### 昇格ライフサイクル

```
探索開始 → 追跡外プレフィックスで書く（main を汚さない）
            │
     ┌──────┴──────┐
  確定した         用済み
     │              │
  プレフィックスを   そのまま rm
  外し正式名へ      （ignore なので
  rename = add      履歴に残らない）
  ＝初コミット
```

### gitignore の既知のハマり（一度だけ対処）

`.gitignore` に追加する**前から tracked** だった使い捨てファイルは、git 仕様で ignore が
効かない。一度だけ `git rm --cached <明示パス>` で追跡解除する。**実行前に必ず `git status` で
対象が使い捨てファイルのみであることを確認**（`git add -A` は使わない・パスは明示展開・
詳細は `git-safety-reference`）。

> **project doc で具体化する**: 使い捨て / util / 正式の具体接頭辞、`.gitignore` の glob、
> 昇格先（連番命名・レポート置き場・知見台帳と昇格 skill）。

## プロジェクトへの委譲（まとめ）

本 skill は 3 原則の **Why と型** だけを持つ。各原則末尾の引用ブロックにある「project doc で
具体化する」項目を、プロジェクトの `docs/research-workflow.md`（または同等）に書き、本流
CLAUDE.md からリンクする。

| 原則 | skill が持つ（普遍） | project doc が持つ（固有） |
|---|---|---|
| 1 隔離 | worktree / ブランチ隔離・1 テーマ・確定だけ昇格・撤去 | 接頭辞・命名・配置・他用途区別 |
| 2 データ | 再生成物は ignore・台帳化・標準出力・マスク経路 | 具体パス・ignore 方式・台帳名・マスク実装・しきい値 |
| 3 ファイル数 | プレフィックス隔離・昇格 / 破棄ライフサイクル・`rm --cached` ハマり | 具体接頭辞・glob・昇格先・昇格 skill |

## 関連

- `git-safety-reference` — ブランチ削除・`rm --cached`・明示ステージングの git 安全則
- プロジェクトの規約ファイル（例 `docs/research-workflow.md`）— 上表「固有」列の SSoT
- プロジェクトの確定知見 skill（例 `finding-sync`）— 原則 3 の昇格先
