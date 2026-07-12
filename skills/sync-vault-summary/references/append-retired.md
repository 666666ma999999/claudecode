# RETIRED: MOC append フローの旧仕様（2026-06-14 廃止・再実装禁止）

以下は廃止済み append の旧手順の記録。helper の `append` は no-op（rules/41 §④）。全面改訂は [[vault-restructure-proposal]] で実施予定。

### 2-4. MOC に append
```bash
python3 ~/.claude/scripts/sync-vault-summary.py append "$MOC" "<entry text>"
```

helper が以下を atomic に実行:
- `## 🔁 最新更新ログ (自動生成・β)` セクションを frontmatter 直後に新設 (なければ)
- セクション直下に entry を prepend (newest top)
- 同日+同 basename の重複 entry を merge (置換)
- frontmatter `last_updated` を当日へ
- 既存 H2 (`## 主要 KPI` 等) は絶対に編集しない

