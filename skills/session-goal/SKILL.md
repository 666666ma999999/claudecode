---
name: session-goal
description: |
  セッション目標を1行保存し statusline に常時表示するアンカー。cwd非依存・会話単位。
  トリガー: 今回の目標, このセッションの目標, セッションの目標, 今日の目標, 目標をセット, 目標を設定, ゴールは, /session-goal, /goal, session goal, 目標を消して, 目標クリア, 今の目標は, 目標を見せて
  NOT for: 永続目的(→plan.md/CLAUDE.md), タスク分解(→task-planner), wiki知識化(→/save)
user-invocable: true
argument-hint: "[今回の目標テキスト | --clear | (空=表示)]"
allowed-tools:
  - Bash
---

# session-goal skill

## 発火・詳細（description から移設 2026-07-03）

「今回のセッションでやろうとしている目標」を1行で保存し、statusline 4行目 (🎯 今回の目標: …) に常時表示する。
作業に没頭しても「今これは何のためにやっているか」を AI もユーザーも見失わないためのアンカー。
cwd 非依存・どのプロジェクトのどのセッションからでも発火可。**セッション(会話)単位で保存** (2026-06-23〜・同じフォルダ/worktree でも会話ごとに別々の目標を持てる)。resume / /clear で session_id が変わると新しい会話扱い=目標は引き継がない。
NOT for: プロジェクトの永続的な目的 (→ 各 repo の plan.md / CLAUDE.md), タスク分解 (→ task-planner), wiki 知識化 (→ /save)

「今回のセッション目標」を保存して statusline に出す。**実体は `~/.claude/scripts/session-goal.sh`。このスキルはそれを呼ぶだけの薄いラッパー**。

## 動作

ユーザー発話から目標テキストを取り出し、**今いるプロジェクト**に対して set / show / clear する。

| ユーザー発話の例 | 実行するコマンド |
|---|---|
| 「今回の目標は <X>」「/session-goal <X>」「ゴールは <X>」 | `~/.claude/scripts/session-goal.sh "<X>"` |
| 「今の目標は?」「目標を見せて」（テキストなし） | `~/.claude/scripts/session-goal.sh` |
| 「目標を消して」「/session-goal --clear」 | `~/.claude/scripts/session-goal.sh --clear` |

## ルール

- **cwd を変えない**。スクリプトは **セッション(会話)単位** で保存する＝同じフォルダ(worktree)でも会話ごとに別々の目標を持てる。session_id は gate(`session-goal-gate.sh`)が毎ターン stdin から読み `.current-<key>` ポインタに書き、writer/statusline はそれと同じ session_id でキーを作るので3接点で一致する。
- 目標は**1行**。長文で言われたら要点だけに圧縮する（statusline は約40字で … 省略）。
- 実行後は、コマンドの出力（`🎯 …`）を**そのまま1行**で報告するだけ。「画面下に出ます」程度の一言でよく、長い説明は不要。
- git 管理外のフォルダで呼ばれた場合はそのフォルダ単位で保存される（スクリプトが pwd にフォールバック）。

## やらないこと

- プロジェクトの永続目的（CLAUDE.md / plan.md）は編集しない
- 複数行・段落の保存はしない（1行サマリのみ）
- 目標の達成判定・進捗管理はしない（→ task-progress）

## 仕組み（参考）

- 保存先: `~/.claude/state/session-goals/<worktree-key>__<session_id>.txt`（**repo 外**なので git を汚さない。**セッション(会話)単位**なので同じフォルダでも会話ごとに別目標）。現セッションポインタ `.current-<worktree-key>` を gate が毎ターン更新し、writer がそれを読む。
- 表示: `~/.claude/statusline.sh` の4行目が stdin の session_id で同じ複合キーを読み、`🎯 今回の目標: …` を出す。未設定なら4行目は出ない（雑音なし）。
- 注意: resume / `/clear` / compaction で session_id が変わると目標は引き継がれない（新しい会話＝未設定に戻る）。同じ会話の中では維持される。旧 worktree 単一キーは headless 等で session_id が無い時のみ degrade 使用。
