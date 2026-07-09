# story-test-loop

プロダクト全機能をユーザーストーリー台帳（単一正準 CSV）に棚卸しし、
全数テスト → エラー文書化 → まとめて修正 → 全数再テスト を全 pass まで回す回帰ループ。

どのプロダクトの cwd からでも使用可。台帳がループ進行状態の正本なので、
セッションを跨いでも `/story-test-loop` 一発で続きから走る。

## 使い方

```
/story-test-loop              # 台帳の状態から現 phase を自動判定して続行
/story-test-loop init [path]  # 初回: Phase 0-1（scope/harness 決定 + 全機能棚卸し→台帳生成）
/story-test-loop test         # Phase 2: 全数テスト（修正禁止・エラー文書化のみ）
/story-test-loop fix          # Phase 3: fail をまとめて修正（→ retest へ）
/story-test-loop retest       # Phase 4: 再テスト（中間=targeted / 最終=full 全数）
/story-test-loop status       # 台帳の status 集計だけ表示（status 一覧は SKILL.md §台帳 参照）
```

## 常駐実行（tomosman の /goal ループ相当）

```
/loop /story-test-loop
```

## 生成物（各プロダクト repo 内）

- `tests/<project>-user-stories.csv` — 単一正準台帳（SSoT）
- `tests/<project>-story-loop-log.md` — Harness Map・エラー詳細・Round 履歴

## 関連

- skill: `~/.claude/skills/story-test-loop/SKILL.md`
- 元ネタ: https://x.com/tomosman/status/2068692611334893582
- 棲み分け: 単一変更の確認 → verify / implementation-checklist、テスト修正のみ → test-fixing
