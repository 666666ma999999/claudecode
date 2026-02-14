---
name: full-ui-test
description: |
  Chrome DevTools MCPを使用してWebページ上の全ボタンをクリックし動作確認を行うスキル。
  全UI要素の網羅的テストを自動化。
  キーワード: UIテスト, 全ボタンクリック, Chrome DevTools, 動作確認
allowed-tools: "Bash(node:*) Read Glob Grep"
compatibility: "requires: Chrome DevTools MCP server"
license: proprietary
metadata:
  author: masaaki-nagasawa
  version: 1.0.0
  category: testing-qa
  tags: [ui-test, chrome-devtools, button-click]
---

# Full UI Test

Chrome DevTools MCPを使用して、Webページ上の全ボタンをクリックし、動作確認を行うスキルです。

## トリガー

以下のフレーズで発動します：
- 「全ボタンをテストして」
- 「UIボタンを全てテストして」
- 「画面の全ボタンをクリックしてテスト」
- 「full-ui-test」
- 「/full-ui-test」

## 前提条件

- Chrome DevTools MCP サーバーが起動していること
- テスト対象のページがブラウザで開いていること

## 手順

### 1. ページのスナップショット取得

```
mcp__chrome-devtools__take_snapshot を使用
```

### 2. 全ボタンの抽出

スナップショットから全てのボタンを抽出：

```python
# スナップショットファイルから全ボタンを抽出
import json
import re
with open('snapshot_file.txt', 'r') as f:
    data = json.load(f)
text = data[0]['text']
buttons = []
seen = set()
for line in text.split('\n'):
    if 'button' in line and 'uid=' in line:
        match = re.search(r'button "([^"]+)"', line)
        uid_match = re.search(r'uid=([0-9_]+)', line)
        if match and uid_match:
            name = match.group(1)
            if name not in seen:
                seen.add(name)
                buttons.append({'name': name, 'uid': uid_match.group(1)})
                print(f'{name}: {uid_match.group(1)}')
```

### 3. 各ボタンをクリックしてテスト

各ボタンに対して以下を実行：

1. **クリック前のスナップショット取得**（スナップショットが古い場合）
2. **ボタンをクリック**
   ```
   mcp__chrome-devtools__click uid={ボタンのUID}
   ```
3. **ダイアログ確認**
   ```
   mcp__chrome-devtools__handle_dialog action="accept" または "dismiss"
   ```
4. **ネットワークリクエスト確認**（API呼び出しの場合）
   ```
   mcp__chrome-devtools__list_network_requests
   ```
5. **結果を記録**

### 4. テスト結果の集計

TodoWriteツールで進捗を管理し、テスト結果を一覧表にまとめる。

## ユーザーへの確認事項

以下の判断が必要な場合は AskUserQuestion ツールを使用：
- テスト対象のURL（指定がない場合）
- ダイアログが表示された際の対応（accept/dismiss）
- ファイル添付が必要なボタンのスキップ可否

## 出力形式

テスト完了後、以下の形式で結果を報告：

```markdown
## テスト結果一覧

| ボタン | 結果 | 詳細 |
|--------|------|------|
| ボタン名1 | 成功 | 正常に動作 |
| ボタン名2 | 成功 | ダイアログ表示 |
| ボタン名3 | スキップ | ファイル添付が必要 |
| ボタン名4 | 失敗 | エラーメッセージ |

**テスト対象**: X個のボタン
**成功**: Y個
**失敗**: Z個
```

## 注意事項

1. **スナップショットの更新**: クリック後はスナップショットが古くなるため、次のクリック前に再取得が必要
2. **ダイアログ処理**: alert/confirm/promptダイアログが表示された場合は適切に処理
3. **長時間処理**: API呼び出しを伴うボタンは処理完了まで待機（wait_forまたはnetwork requestsで確認）
4. **クライアント側処理**: ダウンロードなどはネットワークリクエストに現れない場合がある

## 例

### 入力例
```
http://localhost:5558/ の画面で全ボタンをテストして
```

### 実行フロー
1. ページにナビゲート（既に開いている場合はスキップ）
2. スナップショット取得
3. ボタン一覧を抽出（例: 15個のボタンを発見）
4. 各ボタンを順次クリック
5. 結果を表形式で報告

### 出力例
```
## テスト結果一覧

| ボタン | 結果 | 詳細 |
|--------|------|------|
| 占い商品生成 | 成功 | API呼び出し成功（200） |
| サンプル入力 | 成功 | テキスト入力完了 |
| x | 成功 | テキストクリア（277→0文字） |
| 名前を変更 | 成功 | ダイアログ表示 |
| 生成 | スキップ | ファイル添付が必要 |

**テスト対象**: 15個のボタン
**成功**: 14個
**スキップ**: 1個
```
