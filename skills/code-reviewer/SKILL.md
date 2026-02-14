---
name: code-reviewer
description: |
  FE/BE間の定数・変数・関数の多重管理を自動検知し、新規コード追加時に重複を予防するコードレビュースキル。
  `/review` コマンド実行時、新規定数・マジックナンバー追加時、FE/BEの設定値変更時に自動発動。
compatibility: "requires: Codex MCP server"
metadata:
  author: masaaki-nagasawa
  version: 1.0.0
---

# code-reviewer

## 自動発動条件

- `/review` コマンド実行時に追加チェックとして発動
- 新規定数・マジックナンバー追加時
- FE/BEの設定値変更時

## レビュー手順

### Layer 1: 多重定義検知

`references/duplication-registry.md` に登録済みの値が新たにハードコードされていないか、以下のgrepパターンで自動チェック：

```bash
# 高リスク定数のハードコード検知
grep -rn "2000" frontend/ backend/ --include="*.py" --include="*.js" --include="*.html" --include="*.json" | grep -v "node_modules" | grep -v "__pycache__"
grep -rn "1026" frontend/ backend/ --include="*.py" --include="*.js" --include="*.html" --include="*.json"
grep -rn "【冒頭/あいさつ】\|【締め/メッセージ】" frontend/ backend/ --include="*.py" --include="*.js" --include="*.html"
grep -rn "180000" frontend/ --include="*.html" --include="*.js"
grep -rn "5000" frontend/ backend/ --include="*.py" --include="*.js" --include="*.html" --include="*.json" | grep -i "prompt\|char\|max\|limit"
```

**チェック対象の値一覧:**
| 値 | 正規定義元 | 意味 |
|----|-----------|------|
| 2000 | backend/routers/config.py:90 REGISTRATION_CONSTANTS["default_price"] | デフォルト料金 |
| 1026 | backend/routers/config.py:87 REGISTRATION_CONSTANTS["opening_closing_mid_id"] | 冒頭締めMID ID |
| 【冒頭/あいさつ】 | backend/routers/config.py:92 REGISTRATION_CONSTANTS["opening_marker"] | 冒頭マーカー |
| 【締め/メッセージ】 | backend/routers/config.py:93 REGISTRATION_CONSTANTS["closing_marker"] | 締めマーカー |
| 1/999 | backend/routers/config.py:88 REGISTRATION_CONSTANTS["site_id_range"] | サイトID範囲 |
| 5 (PPV桁数) | backend/routers/config.py:89 REGISTRATION_CONSTANTS["ppv_id_digits"] | PPV桁数 |
| 5000 | backend/utils/path_constants.py:256 | MAX_PROMPT_CHARS |
| 10 (小見出し数) | backend/utils/path_constants.py:260 | DEFAULT_SUBTITLE_COUNT |
| 180000 | frontend/auto.html | FETCH_TIMEOUT |

### Layer 2: プロジェクト固有ルール

以下のスキル・ルールとの整合性を確認：
- **coding-standards**: 命名規則（snake_case/camelCase）、CamelCaseModel使用
- **development**: 既存コード拡張の原則、共通パターンの再利用
- **fe-be-integration**: FE/BE境界のルール

### Layer 3: 修正提案

多重定義を検知した場合、Single Source of Truth への参照に置換するコードを提示：

```python
# ❌ ハードコード
price = 2000

# ✅ 定数参照
from backend.routers.config import REGISTRATION_CONSTANTS
price = REGISTRATION_CONSTANTS["default_price"]
```

```javascript
// ❌ ハードコード（FE側）
const timeout = 180000;

// ✅ app-config.json または定数ファイルから取得
const timeout = appConfig.fetchTimeout;
```

## レビュー結果フォーマット

```
## 多重定義チェック結果

### 検知された問題
- [ ] {ファイル}:{行} - `{値}` がハードコード → `{正規定義元}` を参照すべき

### 既存の多重定義（要修正）
- 詳細は duplication-registry.md を参照

### 推奨アクション
1. {具体的な修正内容}
```
