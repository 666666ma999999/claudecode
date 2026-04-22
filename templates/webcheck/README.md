# WEBチェック セットアップ テンプレ

FEを含む新規プロジェクトで WEBチェック用 Playwright MCP を準ゼロコンフィグで導入するテンプレ集。

## 判定フロー

```
FE (HTML/JS/TS/React/Vue) を含む?
  ├─ No  → WEBチェック不要、セットアップ不要
  └─ Yes → 社内ドメイン (*.mkb.ne.jp, *.ura9.com 等) を扱う?
            ├─ Yes → mcp-playwright-mkb.json.template を使用
            └─ No  → mcp-playwright.json.template を使用
```

## セットアップ手順（1分以内）

対象プロジェクトのルートで:

```bash
# 1. .mcp.json を配置（素版の場合）
cp ~/.claude/templates/webcheck/mcp-playwright.json.template .mcp.json
# または社内版
cp ~/.claude/templates/webcheck/mcp-playwright-mkb.json.template .mcp.json

# 2. settings.local.json を配置し、サーバー名を置換
mkdir -p .claude
cp ~/.claude/templates/webcheck/settings.local.json.template .claude/settings.local.json
# 素版: playwright, 社内版: playwright-mkb
sed -i '' 's/__SERVER_NAME__/playwright/g' .claude/settings.local.json

# 3. .gitignore に追加
cat ~/.claude/templates/webcheck/gitignore.snippet >> .gitignore
```

## 検証4点セット（FE編集後に必須）

1. `browser_navigate` → ページ開く（HTTP 200系確認）
2. `browser_wait_for` → 描画完了待ち（セレクタまたはテキスト指定）
3. `browser_console_messages` → error/warning 件数が 0 件であることを確認
4. `browser_take_screenshot` → 視覚エビデンス

この4点を同一セッションで実行しない限り、`verify-step.pending` は解除されず FE編集3回目でブロックされる。

## 既存プロジェクトの参考

| プロジェクト | 使用サーバー | プロキシ |
|---|---|---|
| rohan | playwright-mkb | MKB |
| chk | playwright-mkb | MKB |
| collect_receipt | playwright | なし |

## トラブルシュート

- `mcp__playwright__*` が承認UIで毎回聞かれる → settings.local.json の `permissions.allow` が正しく置換されているか確認
- `.playwright-mcp/profile` が git に含まれる → `.gitignore` に snippet を追加したか確認
- 社内サイトに繋がらない → mkb 版を使っているか、プロキシサーバーURLが最新か確認
