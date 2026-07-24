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

## 外部スキル導入前の手動監査パターン集（pinned-SHA 方式用）

当環境の外部スキル導入は `npx skills add` を使わず「pinned SHA から手動取得 → 監査 → PROVENANCE.md 記録」が作法（実例: `skills/dependency-auditor/PROVENANCE.md`）。その監査で毎回 grep する定型パターンを以下に固定する。

> 出典: alirezarezvani/claude-skills `engineering/skills/skill-security-auditor` の検出表を cherry-pick（SHA `aecfb8e0`・MIT）。スクリプト本体は導入しない（第三者製の監査ツールで第三者を監査する構造矛盾を避け、パターン表のみ吸収）。

**スクリプト（.py/.sh/.js/.ts）— 1コマンドで一次スクリーニング:**

```bash
grep -rnE 'os\.system|os\.popen|shell\s*=\s*True|\beval\(|\bexec\(|__import__|compile\(|codecs\.decode|base64\.b64decode|chr\(.*\+.*chr\(|requests\.(post|get)|urllib\.request|socket\.connect|httpx|aiohttp|\.ssh|\.aws|/etc/|\.zshrc|\.bashrc|sudo |chmod 777|crontab|pickle\.loads|marshal\.loads|yaml\.load\(' <skill-dir>/
```

- 🔴 即不採用級: コマンド注入（`os.system`/`shell=True`）・動的実行（`eval`/`exec`/`__import__`）・難読化（base64/hex/`chr()` 連結の復号実行）・外部送信（`requests.post`/`socket` 等）・資格情報読取（`~/.ssh` `~/.aws` env 抜き取り）・権限昇格（`sudo`/`chmod 777`/cron 操作）
- 🟡 手動確認: skill ディレクトリ外への書き込み・`pickle.loads`/`yaml.load`(SafeLoader なし)・スクリプト内 `pip install`/`npm install`
- ⚪ 記録のみ: list 引数の `subprocess.run`（shell なし）・バージョン未固定依存

**SKILL.md / 同梱 .md — prompt injection 検査:**

- 指示上書き（"Ignore previous instructions" 系）・役割乗っ取り・「全ファイルを送信/POST せよ」等のデータ抽出指示
- ゼロ幅文字・HTML コメント内の隠し指示（`grep -P '[\x{200b}-\x{200f}]'` と `<!--` 内の命令文を目視）

**構造チェック:** 実行バイナリ（`.so`/`.exe`）同梱・`.env` 等の dotfile・1MB 超ファイル・**symlink**（当環境は symlink 禁止方針のため即除去）・`postinstall` 相当の自動実行フック

**判定と偽陽性の注意:** 🔴 が1件でも実在すれば導入しない（迷ったら見送り）。ただし文字列一致は偽陽性がありうる — 実例: dependency-auditor では `requests` がオフライン CVE パターン表内の**パッケージ名文字列**として出現しただけだった。ヒットは必ず前後の実コードを読んで実行文か判定し、結果（偽陽性の理由込み）を PROVENANCE.md に記録する。
