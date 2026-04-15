# /capture-improvement

$ARGUMENTS を改善メモとして使用。引数なしなら AskUserQuestion で改善内容を収集。

このコマンドは `capture-improvement` スキルを起動します。詳細は `~/.claude/skills/capture-improvement/SKILL.md` 参照。

## 核心ルール

**定量的な Before/After がない改善は登録しない。** 感覚的な「良くなった」は対象外。

## 改善カテゴリ 4 分類

| カテゴリ | 測定軸 | 記事化閾値 |
|---|---|---|
| `token_cost` | API token / 呼び出し回数 / 月額コスト | 20% 以上削減 |
| `speed` | テスト実行時間 / ビルド時間 / API 応答時間 | 30% 以上改善 |
| `maintainability` | LOC / 重複 / カバレッジ / エラー率 | LOC 10% 減 or カバレッジ 10pt 増 or エラー半減 |
| `ux` | UI/UX 体験 (定量化必須) | 体感指標でも測定可能な形 |

## 実行手順

1. 改善内容を Before/After の数値で定量化 (`$ARGUMENTS` に含まれない場合は `AskUserQuestion` で確認)
2. 閾値判定: 上記いずれかの閾値を超えるか確認
3. 閾値未達なら登録せず理由を報告
4. 閾値達成なら Material Bank (make_article プロジェクト) に登録

例:
- `/capture-improvement PlaywrightMCP→chrome-devtools で E2E テスト 120s→55s (54% 改善)`
- `/capture-improvement Canonical Module 統合で 5,949 行削除`
- `/capture-improvement プロンプト圧縮で API 費用 月$50→$15 (70% 削減)`
