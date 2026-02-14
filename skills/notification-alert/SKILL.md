---
name: notification-alert
description: Claude Codeの入力待ち・許可要求時に通知（音声+ダイアログ+最前面化）を行う設定の管理とテスト。「通知テスト」「通知設定」「アラート確認」などのリクエストで発動。
compatibility: "requires: macOS (osascript, terminal-notifier)"
metadata:
  author: masaaki-nagasawa
  version: 1.0.0
---

# Notification Alert スキル

## 概要

Claude Codeが指示待ち状態になったとき、以下の方法で通知します：
- **Terminal最前面化**: 他のアプリを使用中でも気づける
- **音声読み上げ**: ミュート解除時に聞こえる
- **ダイアログ表示**: OKを押すまで消えない

## 自動有効化機能

**Claude Code起動時に自動で設定を確認し、通知設定がなければ自動追加します。**

仕組み：
1. `SessionStart` hookでスクリプトが実行される
2. `~/.claude/settings.json` に `Notification` 設定があるか確認
3. なければ自動で追加

これにより、新しいマシンでも `SessionStart` hookさえ設定すれば通知が自動有効化されます。

## 通知タイミング

| イベント | 発火条件 | メッセージ |
|----------|----------|------------|
| `idle_prompt` | 60秒以上ユーザー入力待ち | 「入力待ちです」 |
| `permission_prompt` | パーミッション要求時 | 「許可が必要です」 |

## コマンド

### 通知テスト
ユーザーが「通知テスト」「アラートテスト」と言った場合、以下を実行：

```bash
osascript -e 'tell application "Terminal" to activate' & say '入力待ちです' & osascript -e 'display dialog "入力待ちです" with title "Claude Code" buttons {"OK"} default button "OK"'
```

### 設定確認
ユーザーが「通知設定確認」と言った場合、`~/.claude/settings.json` のhooksセクションを表示。

### 手動有効化
ユーザーが「通知を有効化」と言った場合、スクリプトを実行：

```bash
~/.claude/skills/notification-alert/scripts/check-and-enable.sh
```

### 設定無効化
ユーザーが「通知を無効化」と言った場合、`~/.claude/settings.json` から `Notification` セクションを削除。

## 新しいマシンへの移行手順

### 方法1: settings.jsonをコピー（推奨）
```bash
# 移行元マシンで
scp ~/.claude/settings.json user@newmachine:~/.claude/

# スキルもコピー
scp -r ~/.claude/skills/notification-alert user@newmachine:~/.claude/skills/
```

### 方法2: 最小設定のみ追加
新しいマシンで `~/.claude/settings.json` に以下を追加すれば、次回起動時に自動で通知設定が追加されます：

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/skills/notification-alert/scripts/check-and-enable.sh"
          }
        ]
      }
    ]
  }
}
```

## iTerm2ユーザー向け

iTerm2を使用している場合は、スクリプト内の `Terminal` を `iTerm` に置き換えてください。

## ファイル構成

```
~/.claude/skills/notification-alert/
├── SKILL.md                      # このファイル
└── scripts/
    └── check-and-enable.sh       # 自動有効化スクリプト
```

## 前提条件

- macOS環境
- Python3（macOS標準インストール済み）
- `say` コマンド（macOS標準）
- `osascript` コマンド（macOS標準）

## 注意事項

- Linuxの場合は `notify-send` と `espeak` を使用するよう設定を変更する必要あり
- Windowsの場合は PowerShell の通知機能を使用
- スクリプトはPython3を使用（jq不要）

---

## 汎用知見: macOS通知方法の選定ガイド

### 通知方法の比較

| 方法 | コマンド | メリット | デメリット |
|------|---------|---------|-----------|
| **通知センター** | `osascript -e 'display notification "msg"'` | 軽量、邪魔にならない | 設定で無効化されていると表示されない |
| **ダイアログ** | `osascript -e 'display dialog "msg"'` | 確実に表示される | 作業を中断する |
| **音声** | `say 'msg'` | 離席中でも気づける | ミュート時は聞こえない |
| **システム音** | `afplay /System/Library/Sounds/Glass.aiff` | シンプル | ミュート時は聞こえない |
| **Dockバウンス** | `tell application "X" to activate` | 視覚的に目立つ | 気づきにくい場合も |

### 通知が届かない場合のトラブルシューティング

1. **通知センターが表示されない**
   - システム設定 → 通知 → スクリプトエディタ の通知を有効化
   - または、ダイアログ方式に切り替え

2. **音声が聞こえない**
   - ミュート設定を確認
   - 音量を確認
   - または、視覚的通知と併用

3. **ダイアログが見えない（他のアプリに隠れる）**
   - `tell application "Terminal" to activate` でアプリを最前面化
   - デュアルディスプレイでも気づけるようになる

### 推奨: 複合通知

確実に気づくために複数の方法を組み合わせる：

```bash
# 最前面化 + 音声 + ダイアログ
osascript -e 'tell application "Terminal" to activate' & say 'メッセージ' & osascript -e 'display dialog "メッセージ" buttons {"OK"}'
```

### ダイアログのオプション

```bash
# 5秒で自動で消える（離席中は見逃す可能性あり）
osascript -e 'display dialog "msg" giving up after 5'

# OKを押すまで消えない（確実に気づく）
osascript -e 'display dialog "msg" buttons {"OK"} default button "OK"'
```

### SessionStart hookの活用パターン

起動時に設定をチェック・自動修復する仕組み：

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "/path/to/setup-script.sh"
          }
        ]
      }
    ]
  }
}
```

- ユーザーへの確認なしで自動実行される
- 設定の自動復旧、環境チェックなどに活用可能
- Python3はmacOS標準なので、jqなしでJSON操作可能
