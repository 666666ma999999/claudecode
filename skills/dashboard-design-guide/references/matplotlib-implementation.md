dashboard-design-guide の詳細（本文から 2026-07-11 P8 分離・内容不変）

## matplotlib実装ルール

- 実行環境: ホスト python3 に matplotlib は入っていない（ホストへのパッケージ導入は CLAUDE.md Docker-Only ルールで禁止）。対象プロジェクトの Docker/仮想環境経由で実行する。どちらも無い場合は実行方法をユーザーに確認する
- フォント: macOSは `Hiragino Sans`、Linuxは `Noto Sans CJK JP`
- `axes.unicode_minus = False`
- 保存: `PNG`, `dpi=150`
- 背景色: 白系 `#F8F8FB`
- 不要な枠線は消す
- 値ラベルは必要な箇所だけ
- 注釈は最大 `3` 個まで
- `figsize=(16, 9)` を基本
- `GridSpec(6, 6)` で配置
