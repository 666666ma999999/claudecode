---
description: グローバル/プロジェクト設定の配置判断と検証ガイド
triggers:
  - 設定配置
  - グローバル vs プロジェクト
  - config placement
  - 設定優先順位
  - settings scope
allowed-tools: []
---

# 設定配置ガイド

## 優先順位テーブル

| 機能 | マージ方式 | 優先順位 (高 → 低) |
|------|-----------|---------------------|
| CLAUDE.md | 加算的 (全て読み込み) | より具体的な指示が優先 |
| Rules | 加算的 | Project > User |
| Skills | 名前でオーバーライド | Managed > User > Project |
| Subagents | 名前でオーバーライド | CLI > Project > User > Plugin |
| Hooks | 全てマージ (並列発火) | 全ソースが発火 |
| Settings | オーバーライド | Managed > CLI > Local > Project > User |
| MCP | 名前でオーバーライド | Local > Project > User |

## 配置判断フロー

```
新しい設定/ルールを追加したい
  │
  ├─ 全プロジェクト共通か？
  │   ├─ YES → ~/.claude/ (グローバル)
  │   │   ├─ ルール → ~/.claude/rules/XX-name.md
  │   │   ├─ スキル → ~/.claude/skills/<name>/SKILL.md
  │   │   ├─ 設定値 → ~/.claude/settings.json
  │   │   └─ MCP   → ~/.claude/.mcp.json
  │   │
  │   └─ NO → プロジェクト配下
  │       ├─ ルール → .claude/rules/XX-name.md
  │       ├─ スキル → .claude/skills/<name>/SKILL.md
  │       ├─ 設定値 → .claude/settings.json
  │       └─ MCP   → .claude/.mcp.json
  │
  └─ git管理外にしたいか？ (個人設定)
      ├─ YES → .claude/settings.local.json / .mcp.local.json
      └─ NO  → 上記の通常パスへ
```

## 注意事項

### Skills の逆転優先順位

Skills は **User (`~/.claude/skills/`) > Project (`.claude/skills/`)** の順で解決される。同名スキルはユーザー側が勝つ。

- プロジェクト固有スキルを確実に使いたい場合: **プロジェクト名をプレフィックスにしたユニーク名** を付ける
  - 例: `myapp-deploy-guide` (グローバルの `deploy-guide` と衝突しない)
- グローバルで汎用スキルを置く場合: 汎用的な名前で可 (`debugging-guide` 等)

### Hooks 設計パターン

全ソースの hooks がマージされ並列発火するため、**スクリプト内部でスコープ判定** する。

```bash
#!/bin/bash
# hooks/PreToolUse/check-something.sh

# CWD判定: 特定プロジェクトでのみ実行
if [[ "$PWD" != */my-project* ]]; then
  exit 0
fi

# マーカーファイル判定
if [[ ! -f "config/extensions.yaml" ]]; then
  exit 0
fi

# 本処理
...
```

### settings.local.json の落とし穴

**Issue #17017**: `settings.local.json` に空の `deny` 配列を置くと、上位 (`settings.json`) の `deny` 設定が無効化される。

```jsonc
// NG: 上位のdenyリストを消してしまう
{ "permissions": { "deny": [] } }

// OK: 不要なキーは配置しない
{ "permissions": { "allow": ["Bash(git status)"] } }
```

原則: **変更したいキーだけを記述し、不要なキーは配置しない**。

### MCP 設定のスコープ

| スコープ | ファイル | git管理 |
|---------|---------|---------|
| Local | `.claude/.mcp.local.json` | 対象外 |
| Project | `.claude/.mcp.json` | 対象 |
| User | `~/.claude/.mcp.json` | 対象外 |

- シークレットは `${VAR}` プレースホルダー必須 (直書き禁止)
- 同名MCPサーバーは Local > Project > User でオーバーライド
- ローカルで一時的に無効化したい場合: `.mcp.local.json` で同名サーバーを `"disabled": true` に設定

## 検証コマンド

### セッション開始時の自動診断

`config-diagnostic.sh` hook がセッション開始時に設定の読み込み状態を出力する (設定済みの場合)。

### 手動確認

```bash
# グローバル設定の確認
cat ~/.claude/settings.json | python3 -m json.tool

# プロジェクト設定の確認
cat .claude/settings.json | python3 -m json.tool

# ローカル設定の確認
cat .claude/settings.local.json | python3 -m json.tool 2>/dev/null || echo "No local settings"

# MCP設定の確認 (全スコープ)
echo "=== User ===" && cat ~/.claude/.mcp.json 2>/dev/null | python3 -m json.tool
echo "=== Project ===" && cat .claude/.mcp.json 2>/dev/null | python3 -m json.tool
echo "=== Local ===" && cat .claude/.mcp.local.json 2>/dev/null | python3 -m json.tool

# Rules一覧 (適用順)
echo "=== User Rules ===" && ls ~/.claude/rules/ 2>/dev/null
echo "=== Project Rules ===" && ls .claude/rules/ 2>/dev/null

# Skills一覧 (優先順位順)
echo "=== User Skills (優先) ===" && ls ~/.claude/skills/ 2>/dev/null
echo "=== Project Skills ===" && ls .claude/skills/ 2>/dev/null

# 設定マージ結果の簡易確認 (deny衝突チェック)
python3 -c "
import json, pathlib
for p in ['.claude/settings.local.json', '.claude/settings.json', str(pathlib.Path.home()/'.claude/settings.json')]:
    try:
        d = json.loads(pathlib.Path(p).read_text())
        perms = d.get('permissions', {})
        if 'deny' in perms and perms['deny'] == []:
            print(f'WARNING: {p} has empty deny array (may override upper deny)')
    except: pass
print('Done')
"
```

## クイックリファレンス

| やりたいこと | 配置先 |
|-------------|--------|
| 全プロジェクトで Bash(rm) を禁止 | `~/.claude/settings.json` の `deny` |
| 特定プロジェクトだけ Docker 許可 | `.claude/settings.json` の `allow` |
| 個人的に MCP サーバー追加 | `~/.claude/.mcp.json` |
| プロジェクト共有 MCP 設定 | `.claude/.mcp.json` (git管理) |
| チーム共通コーディングルール | `.claude/rules/` (git管理) |
| 個人的な作業習慣ルール | `~/.claude/rules/` |
| プロジェクト固有スキル | `.claude/skills/<project-prefix>-<name>/` |
| 汎用スキル | `~/.claude/skills/<name>/` |
