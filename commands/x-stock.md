# x-stock

X 記事ネタを vault グローバルストック（x-article-stock.md）に append する。

どのプロジェクトの cwd からでも使用可。記事ネタを思いついた瞬間にその場で保存。

## 使い方

```
/x-stock [memo]
```

## 例

```
/x-stock CPA悪化の真因を3層で切り分ける手順
/x-stock passVault で鍵管理を自動化した話
/x-stock settings.json deny の優先順位トラップ
```

## 関連

- vault: `~/Documents/Obsidian Vault/x-article-stock.md`
- skill: `~/.claude/skills/x-stock/SKILL.md`
- 記事化（draft→posted）: `make_article` cwd で別フロー
