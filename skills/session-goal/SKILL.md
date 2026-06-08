---
name: session-goal
description: |
  「今回のセッションでやろうとしている目標」を1行で保存し、statusline 4行目 (🎯 今回の目標: …) に常時表示する。
  作業に没頭しても「今これは何のためにやっているか」を AI もユーザーも見失わないためのアンカー。
  cwd 非依存・どのプロジェクトのどのセッションからでも発火可。作業ツリー (worktree) 単位で保存 (worktree ごとに別々の目標を持てる・メインリポジトリも 1 つの作業ツリーとして独立)。
  トリガー語: "今回の目標" / "このセッションの目標" / "セッションの目標" / "今日の目標"
              "目標をセット" / "目標を設定" / "ゴールは" / "/session-goal" / "/goal" / "session goal"
              "目標を消して" / "目標クリア" / "今の目標は" / "目標を見せて"
  NOT for: プロジェクトの永続的な目的 (→ 各 repo の plan.md / CLAUDE.md), タスク分解 (→ task-planner), wiki 知識化 (→ /save)
user-invocable: true
argument-hint: "[今回の目標テキスト | --clear | (空=表示)]"
allowed-tools:
  - Bash
---

# session-goal skill

「今回のセッション目標」を保存して statusline に出す。**実体は `~/.claude/scripts/session-goal.sh`。このスキルはそれを呼ぶだけの薄いラッパー**。

## 動作

ユーザー発話から目標テキストを取り出し、**今いるプロジェクト**に対して set / show / clear する。

| ユーザー発話の例 | 実行するコマンド |
|---|---|
| 「今回の目標は <X>」「/session-goal <X>」「ゴールは <X>」 | `~/.claude/scripts/session-goal.sh "<X>"` |
| 「今の目標は?」「目標を見せて」（テキストなし） | `~/.claude/scripts/session-goal.sh` |
| 「目標を消して」「/session-goal --clear」 | `~/.claude/scripts/session-goal.sh --clear` |

## ルール

- **cwd を変えない**。スクリプトは cwd が属する**作業ツリー (worktree)** 単位 (`--show-toplevel`) で保存する＝worktree ごとに別々の目標を持てる (メインリポジトリも 1 つの作業ツリーとして独立)。同じパスに worktree を作り直せば残る。statusline 側も同じ基準で読むので必ず一致する。
- 目標は**1行**。長文で言われたら要点だけに圧縮する（statusline は約40字で … 省略）。
- 実行後は、コマンドの出力（`🎯 …`）を**そのまま1行**で報告するだけ。「画面下に出ます」程度の一言でよく、長い説明は不要。
- git 管理外のフォルダで呼ばれた場合はそのフォルダ単位で保存される（スクリプトが pwd にフォールバック）。

## やらないこと

- プロジェクトの永続目的（CLAUDE.md / plan.md）は編集しない
- 複数行・段落の保存はしない（1行サマリのみ）
- 目標の達成判定・進捗管理はしない（→ task-progress）

## 仕組み（参考）

- 保存先: `~/.claude/state/session-goals/<worktree-root をサニタイズ>.txt`（**repo 外**なので git を汚さない。作業ツリー単位なので**worktree ごとに別々の目標**を持てる。同じパスに worktree を作り直せば残る）
- 表示: `~/.claude/statusline.sh` の4行目が同じキーでこのファイルを読み、`🎯 今回の目標: …` を出す。未設定なら4行目は出ない（雑音なし）。
