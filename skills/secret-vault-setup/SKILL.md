---
name: secret-vault-setup
description: |
  銀行/証券/仮想通貨等の高機密情報を Obsidian で2台 Mac 間管理する基盤構築スキル。
  既存 vault のリスク監査 (Twin Hacker 並列分析) → アーキテクチャ決定 → 暗号化 APFS Volume +
  Syncthing P2P 同期 + 別 vault 分離の構築手順 → OPSEC ルール付き記録テンプレ生成までを一貫提供。
  キーワード: パスワード管理, 機密ノート, password vault, secret vault, Obsidian で金融情報,
  銀行 仮想通貨 obsidian, passvault, 暗号化 APFS, Syncthing 2台同期, Dropbox から移行
  NOT for: 単純な .env / API key 管理 (→ secret-management), 1Password 単独運用 (本スキル不要)
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Agent, AskUserQuestion
---

# Secret Vault Setup

## いつ使うか

- 「Obsidian でパスワード管理したい」「機密ノートを2台 Mac で同期したい」
- 「Dropbox に置いてた銀行情報を移したい」
- 「証券口座/仮想通貨アドレス/シードフレーズを安全に保管したい」
- 既存の Obsidian Vault に機密情報が紛れていないか監査したい

**NOT for**: `.env` や API key 管理 (`secret-management`), 1Password 単独運用ですむケース。

---

## Phase 0: 既存環境リスク監査（必須・最初に必ず実行）

### Step 0.1: Twin Hacker 並列分析を起動

3並列 Agent で攻撃面と防御策を洗い出す:

```
Agent (general-purpose / codex): アーキ案 3-4 比較
Agent (black-hacker):           漏洩経路の網羅列挙
Agent (white-hacker):           防御設計の具体手順
```

**観点固定リスト**（プロンプトに必ず含める）:
- `~/.claude/settings.json` の `permissions.deny` に vault Read 禁止があるか
- 既存 Obsidian Vault の `.obsidian/plugins/obsidian-git` 自動 push 設定
- `~/.claude/hooks/auto-git-push.sh` 等 auto-commit hook の影響範囲
- クラウド同期 (Dropbox/iCloud) のバージョン履歴・サブプロセッサリスク
- Spotlight インデックス・Time Machine 暗号化状況
- Obsidian コミュニティプラグインのサプライチェーン

### Step 0.2: 機密漏洩状況スキャン

```bash
grep -ri -l -E "(password|パスワード|シード|seed phrase|秘密鍵|private key)" \
  "${EXISTING_VAULT_PATH}/" 2>/dev/null | head -30
```

ヒットしたら**目視確認**（Claude に読ませず、ユーザーが Obsidian で開く）。

---

## Phase 1: アーキテクチャ判断

### 推奨構成（既定）

```
~/PassVault (symlink) → /Volumes/PassVault (暗号化 APFS, パスフレーズ)
   ↕ Syncthing (P2P, TLS1.3, デバイス相互承認)
他 Mac: ~/PassVault (symlink) → /Volumes/PassVault
```

**4層防御**:
1. **vault 分離**: 既存 Obsidian Vault と物理分離（hook/git 経路を完全遮断）
2. **暗号化 APFS Volume**: `diskutil apfs encryptVolume` でパスフレーズ保護
3. **Syncthing P2P**: クラウド経由しない、TLS1.3 + 公開鍵認証
4. **Meld Encrypt**: 高機密 note の note 内パスフレーズ再暗号化

### 代替案を選ぶ条件

| 条件 | 推奨 |
|---|---|
| ユーザーが 1Password/Bitwarden 契約済 | **ハイブリッド案**: 実 password は 1Password、Obsidian はメタ情報のみ |
| 2台目 Mac が物理的に無い | 1台運用 + iCloud 暗号化バックアップ |
| 完全オフライン要件 | USB 物理転送 + air-gapped |

---

## Phase 2: 構築手順

### Step 2.1: Claude Code deny 強化（最初に必ず）

`~/.claude/settings.json` の `permissions.deny` に追加:

```json
"Read(~/PassVault/**)",
"Read(/Volumes/PassVault/**)",
"Write(~/PassVault/**)",
"Write(/Volumes/PassVault/**)",
"Edit(~/PassVault/**)",
"Edit(/Volumes/PassVault/**)",
"Bash(cat ~/PassVault*)",
"Bash(cat /Volumes/PassVault*)",
"Bash(less ~/PassVault*)",
"Bash(head ~/PassVault*)",
"Bash(tail ~/PassVault*)",
"Bash(grep * ~/PassVault*)",
"Bash(grep * /Volumes/PassVault*)",
"Read(${EXISTING_VAULT}/**/*password*)",
"Read(${EXISTING_VAULT}/**/*secret*)",
"Read(${EXISTING_VAULT}/**/*wallet*)",
"Read(${EXISTING_VAULT}/**/*seed*)"
```

### Step 2.2: 暗号化 APFS Volume 作成（ユーザー手動・対話入力）

```bash
# Volume 追加（Claude 経由 OK）
diskutil apfs addVolume disk3 APFS PassVault

# 暗号化（ターミナル.app で実行必須・! プレフィックスは対話入力非対応）
diskutil apfs encryptVolume /Volumes/PassVault -user disk
# → パスフレーズを 2回入力（16文字以上、英数記号混合推奨）

# symlink
ln -s /Volumes/PassVault ~/PassVault
```

**重要**: パスフレーズは絶対に Claude/チャットに貼らせない。`! prefix` は対話入力非対応のため必ず Terminal.app で実行。

### Step 2.3: Obsidian で別 vault として開く

- Obsidian 起動 → 「Open another vault」→ `~/PassVault/` 選択
- **絶対インストール禁止プラグイン**: `obsidian-git` (タイマー自動 push)
- 推奨プラグイン: `Meld Encrypt` のみ

### Step 2.4: Syncthing 2台同期

```bash
brew install syncthing
brew services start syncthing
# Web UI: http://127.0.0.1:8384
```

両機のデバイス ID を **対面/音声で照合**して相互承認 → フォルダ追加 `/Volumes/PassVault` を「送受信」モード共有。

### Step 2.5: Dropbox 等からの移管

1. 既存パスワードファイル所在を特定
2. 内容を `~/PassVault/` に Obsidian note として再構成
3. Dropbox 上のファイルを完全削除（ゴミ箱からも削除）
4. **Dropbox バージョン履歴削除**（Plus/Pro: 設定から / 無料: アカウント解約で30日後完全削除）

### Step 2.6: 多層防御確認

- FileVault ON 確認
- Spotlight 除外: `/Volumes/PassVault` をプライバシー対象外に
- Time Machine 暗号化 ON 確認

---

## Phase 3: 記録・X 投稿 OPSEC

### 二系統で物理分離

| 系統 | 場所 | 公開可否 |
|---|---|---|
| 公開用素材 | `${EXISTING_VAULT}/01_Biz/x-drafts/passvault-build-memo.md` | OK |
| 自分用 raw | `~/PassVault/journal.md` | NG（暗号化内）|

### 公開メモ NG リスト（絶対書かない）

- 銀行・証券・仮想通貨の**組み合わせ明示** (標的価値シグナル)
- GitHub アカウント名・リポ URL
- 実 vault パス (`/Users/<name>/...` → `<REDACTED>` に置換)
- Syncthing デバイス ID / IP / ホスト名
- disk identifier (`disk3s7` 等) / Volume UUID
- パスフレーズの長さ・文字種
- 4層防御の完全構成図 (防御強度の開示 = 価値ある資産の公告)

### 投稿タイミング

**完了 + 2週間〜1ヶ月後**を最低ラインに。
理由: 構築直後は設定が不安定で攻撃の旬。Syncthing 通信パターンとの突合リスク。

### 切り口判定基準

- Claude Code / AI 文脈で書く → `@twittora_` 適合度高
- 一般 OPSEC のみ → 別アカウント / 別タイミング

---

## 公開メモテンプレ

`references/passvault-memo-template.md` を Vault 内 `01_Biz/x-drafts/` にコピーする。

---

## Verification

- `diskutil apfs list | grep PassVault` で `FileVault: Yes` 確認
- Syncthing Web UI で両機 "Up to Date" 表示
- Claude Code セッションで `Read("/Volumes/PassVault/test.md")` が deny されること
- Dropbox.com で「削除済みファイル」にも残っていないこと

---

## Red Flags（実行中に検知したら停止）

- `obsidian-git` プラグインが `~/PassVault/.obsidian/plugins/` にインストールされている
- `~/PassVault/.git` ディレクトリが存在する（**絶対 git init してはいけない**）
- パスフレーズがチャット履歴に残っている
- 公開メモに実パス / device ID / disk identifier が含まれている
- 移行完了前に X 投稿を作成している

---

## 関連

- 設計議論ベース: 2026-05-15〜16 セッション (Codex + Black/White Twin Hacker 分析)
- 関連スキル: `secret-management` (=.zshrc/MCP), `security-twin-audit` (=分析手法元)
- 関連ルール: `~/.claude/rules/40-obsidian.md` (既存 vault 不変ルール)
