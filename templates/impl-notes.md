---
project: <project-name>
type: implementation-notes
folder: "02_Ai/<group>/"
categories:
  - "[[<project>_ope]]"
last_updated: YYYY-MM-DD
tags:
  - project/<project-name>
  - type/implementation-notes
---

# <project> Implementation Notes

> 実装中に仕様書・plan.md から逸脱 / 解釈した判断・妥協・要確認を記録する（implementation-notes 運用・Thariq Shihipar 提唱）。本ノートが当プロジェクトの意思決定ログの正本（SSoT）。仕様通りの実装は記録不要。

## Decision Log

| # | 日時 | 判断 | 選択肢 | 選んだ理由 | 却下理由 | 仕様差分 |
|---|------|------|--------|-----------|---------|---------|
| 1 | YYYY-MM-DD | 判断内容 | A vs B | Aを選択: ...（参照: file://.../plan.md#成功基準） | Bは..のため不適 | deviation |

**仕様差分の値**（implementation-notes の 4 観点に対応）:
- `on-spec` — 仕様通り（記録任意）
- `interpreted` — 仕様が曖昧 → 実装側で解釈して進めた
- `deviation` — 仕様から意図的に逸脱した（理由を「選んだ理由」に明記）
- `open-question` — 暫定判断・ユーザーの確認/修正が必要（未解決）

> トレードオフは「選択肢 / 却下理由」列で表現。

## Open Questions

未解決の要確認事項（`open-question` 行から起票。解決したら Decision Log で締めてチェックを入れる）。

- [ ] （ユーザーに確認・修正してほしい点）
