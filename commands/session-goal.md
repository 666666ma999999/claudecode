# session-goal

「今回のセッションの目標」を1行で保存し、statusline 4行目（🎯 今回の目標: …）に常時表示する。

どのプロジェクトの cwd からでも使用可。**セッション(会話)単位で保存**（2026-06-23〜・同じフォルダ/worktree でも会話ごとに別々の目標を持てる。resume/`/clear` で session_id が変わると新しい会話扱い＝未設定に戻る）。

## 使い方

```
/session-goal [目標テキスト]     # 今いるプロジェクトの目標を設定（上書き）
/session-goal                    # 現在の目標を表示
/session-goal --clear            # 目標を消す（4行目が消える）
```

引数 `$ARGUMENTS` をそのまま `~/.claude/scripts/session-goal.sh` に渡して実行し、出力（🎯 …）を1行で報告する。

## 例

```
/session-goal 英語PSA10・直近2週間で+20%・¥3万超のカードを取得する
/session-goal CPA を保ったまま月CVを+50%する施策の検証
/session-goal --clear
```

## 関連

- skill: `~/.claude/skills/session-goal/SKILL.md`
- 実体スクリプト: `~/.claude/scripts/session-goal.sh`
- 保存先: `~/.claude/state/session-goals/<worktree-key>__<session_id>.txt`（repo 外・git を汚さない・**セッション(会話)単位**）
- 表示: `~/.claude/statusline.sh` 4行目
