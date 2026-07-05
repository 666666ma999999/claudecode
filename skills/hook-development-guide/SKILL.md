---
name: hook-development-guide
description: |
  Claude Code の hook（PreToolUse / PostToolUse / Stop / UserPromptSubmit）を新設・改修するときの設計ガイド。
  state のセッションスコープ化・構造を考慮したテキスト検知・自己制限・headless ガード・誤検知テストを規定し、
  「作って動かないので後追いで修理」の反復を止める。
  キーワード: hook作成, hook修理, フック, 誤検知, 暴発, 誤ブロック, PreToolUse, PostToolUse, Stop hook, UserPromptSubmit, settings.json hooks 配線
  NOT for: settings.json 内のキー配置判断（→ config-placement-guide）／ 環境全体の監査・ヘルスチェック（→ health）／ launchd・定期実行の新設や runner 故障調査（→ codify-config）
allowed-tools: [Read, Glob, Grep, Bash]
license: proprietary
metadata:
  author: masaaki-nagasawa
  version: 1.0.0
  category: workflow-automation
  tags: [hooks, claude-code, false-positive, guard-design]
---

# Hook Development Guide — hook の設計と誤検知防止

**hook は「全セッション・全ターンに黙って割り込む常駐コード」。1 つの誤検知が毎ターン発火し実害になる。**
書く前に下の 4 チェックを通し、書いた後に誤検知テスト 3 種と headless dry-run を必ず実行する。
`~/.claude` の非 auto コミット 66 本中 24 本（36%）が hook 関連で、うち 7 本が「設計不備の後追い修理」だった。その 7 本が潰した罠を先回りするのがこのスキルの目的。

## 設計チェックリスト（新設・改修の前に）

### ① state はセッションスコープ（session_id 複合キー）
共有フラグ（`stop_hook_active` 等）や worktree 単一キーで state を持つと、並行セッションが互いの state を踏んで誤ブロック / 素通しが起きる。
`session_id` を key に混ぜる。**良い実例**: `hooks/session-goal-gate.sh:34-39` — `session_id` があれば `<key>__<sid>.txt` からのみ目標を読み、無い時だけ旧キーへ degrade。`hooks/stop-evidence-footer.sh:128-150` の `already_blocked()` も `session + message-hash + tier` の複合キーで再ブロックを管理（`stop_hook_active` に依存しない理由がコメントに明記）。
修理実績: `9ccf8bef`（verify-step の pending を session スコープ化し並行セッション誤ブロックを解消）。

### ② テキスト検知は構造を考慮（naive grep 禁止）
Markdown / コードを行単位で数えると、**fenced code block 内のテンプレ例示・前置きの引用**を実データと誤認する。
**悪い実例**: `hooks/stop-dup-guard.sh:92-95` の見出し重複検知は全行を `^#{2,3}\s+\S` で拾い fence 内を除外していない。このため fenced code block 内に例示した同一見出しを二重記載と誤検知し、2026-07-05 の監査セッションで同一メッセージに 5 回連続で発火した（同ファイルのブロック重複検知 L110-118 は `in_fence` で除外しているのに、見出し側は未対応という非対称が原因）。
対策: fence 内 / 引用 (`>`) / 前置き例示は検知対象から除外する。除外 basename・frontmatter マーカー（`format: append-only` 等）でのホワイトリストも併用（同ファイル L63-82 が実例）。

### ③ 自己制限（暴発上限を必ず持つ）
block 系 hook は「1 停止・1 メッセージにつき最大 1 回」を state で保証する。無制限だと同じ応答に何度も割り込みループする。
実例: `stop-dup-guard.sh` は「1 停止最大 1 回」、`stop-evidence-footer.sh:131` は `SESSION_CAP = 6` でセッション総ブロック数を最終遮断。state が書けない時は **fail-open**（ブロックしない側に倒す・同 L149-150）。

### ④ 追記型ログは上限キャップ
hook が `>> log.jsonl` で append するなら、無制限増殖を止める retention を同時に用意する。
修理実績: `aaa51127`（追記専用ログの無制限増殖を data-retention で恒久キャップ）。cap の型は `hooks/data-retention.sh`（mtime ベースの世代削除）を踏襲する。

## headless ガード（定期実行での無効化）

Stop / UserPromptSubmit 系の block は、`claude -p` の headless 実行（vault-prompt-runner）では**出力を分断して本文を消す**。定期実行で走る hook は先頭で環境変数ガードして即 exit する。

```bash
# headless 定期実行(vault-prompt-runner)では無効: Stop block は claude -p の出力を分断し本文を消す
[ -n "$VAULT_PROMPT_RUNNER" ] && exit 0
```

実例: `hooks/stop-evidence-footer.sh:23` と `hooks/stop-dup-guard.sh:11`。この 3 本無効化が修理コミット `c6c67eb3`。
対話専用の block hook を新設したら、このガード行を最初から入れること（後付けが `c6c67eb3` の反復原因）。

## 誤検知テスト 3 種（改修後に必ず実行）

hook は JSON を stdin で受ける。`echo '<json>' | bash <hook>` で dry-run し、**出力が期待どおりか**を見る（block hook は誤検知時に `{"decision":"block",...}` を吐く）。

```bash
H=~/.claude/hooks/stop-dup-guard.sh

# (1) 正常系: 該当編集なし → 無出力（block しない）が正しい
echo '{"session_id":"test-none","stop_hook_active":false}' | bash "$H"; echo "exit=$?"

# (2) 前置き・例示を含む文書: fenced code block 内に同一見出しの例示を2回書いた .md
#     → block してはいけない（②の誤検知。現状 stop-dup-guard は誤発火する＝改修対象の再現）
#     見出しテキストは6文字以上にする(stop-dup-guard.sh の重複判定は len(h)>=6 が条件。短いと無関係のフィルタで弾かれ「無出力」になり誤検知を再現できない)
d=$(mktemp -d); printf '# doc\n\n```\n## 例見出し\nfoo\n## 例見出し\nbar\n```\n' > "$d/note.md"
printf '{"tool":"Write","file":"%s","session":"test-fence"}\n' "$d/note.md" >> ~/.claude/state/edit-history.jsonl
echo '{"session_id":"test-fence","stop_hook_active":false}' | bash "$H"; echo "exit=$?"

# (3) 並行セッション: 別 session_id の state が現セッションに漏れないか
#     A にだけ編集履歴を足し、B には足さない → B が A の履歴を拾って誤ブロックしないかを見る(両方 edit-history が空だと自明に無出力になり検証にならない)
dB=$(mktemp -d); printf '# doc\n\n## 見出しA\nx\n\n## 見出しA\ny\n' > "$dB/noteB.md"
printf '{"tool":"Write","file":"%s","session":"sess-A"}\n' "$dB/noteB.md" >> ~/.claude/state/edit-history.jsonl
echo '{"session_id":"sess-A","stop_hook_active":false}' | bash "$H" >/dev/null; echo "A(重複あり): block されるはず"
echo '{"session_id":"sess-B","stop_hook_active":false}' | bash "$H"; echo "B(履歴なし): 無出力になるはず=A の state が漏れていない"
```

期待: (1) 無出力 / (2) fence 内例示なら無出力（誤検知が残るなら②の対策が未実装）/ (3) A はブロックされ B は無出力（B が A の state に影響されない）。
テスト後は `~/.claude/state/edit-history.jsonl` に足したテスト行を削除して原状回復する。

## 配線と発火確認（settings.json）

hook は `settings.json` の `hooks` キーに登録する。matcher はツール名（`Write|Edit` / `Bash` / `EnterPlanMode`）、Stop 系は `matcher: ""`。

```json
{ "matcher": "", "hooks": [ { "type": "command", "command": "~/.claude/hooks/stop-dup-guard.sh" } ] }
```

配線の確認:

```bash
grep -n 'stop-dup-guard.sh' ~/.claude/settings.json           # 登録行の存在
jq -r '.hooks.Stop[].hooks[].command' ~/.claude/settings.json  # Stop hook 一覧を機械抽出
```

## 完了条件（観測可能・全て出力で示す）

- [ ] 誤検知テスト 3 種を実行し、(1) 無出力・(2) fence 内例示で無出力・(3) セッション独立 の実出力を貼る
- [ ] headless dry-run: `echo '{}' | VAULT_PROMPT_RUNNER=1 bash <hook>; echo exit=$?` が無出力かつ `exit=0`（headless で無害）。※環境変数は **`bash` 側**に置く（`VAULT_PROMPT_RUNNER=1 echo ... | bash` は echo にしか効かず hook へ渡らない・実測で誤り確認）
- [ ] block 系は暴発上限を確認: 同一 JSON を 2 回流し、2 回目が block しない（自己制限が効く）出力を貼る
- [ ] 追記ログを持つなら retention の cap 行を提示（`data-retention.sh` 等への配線）
- [ ] 配線: `grep -n '<hook>' ~/.claude/settings.json` の登録行を貼る

## 良い例・悪い例

- **良い例**: `hooks/session-goal-gate.sh:31-39` — state を `<key>__<session_id>.txt` の複合キーで持ち、別会話の目標へ fallback しない。session_id が無い headless 文脈だけ旧キーへ degrade する明示分岐（①の手本）。
- **悪い例**: `hooks/stop-dup-guard.sh:92-95` — 見出し重複検知が fenced code block を除外せず、テンプレ例示を二重記載と誤認。2026-07-05 に同一メッセージへ 5 回連続誤発火（②の反面教師。同ファイル L110-118 のブロック検知は fence 除外できているのに見出し側だけ未対応、という非対称が実害の核）。

## 出典

- 発案根拠: `tasks/p-skills-audit-2026-07-files/audit/offense-synthesis.md` の「N1. hook-development-guide」節（gitignore 内・この Mac のみの履歴資料）
- 修理コミット 7 本（`git log -1 <hash>` で照合可）: `c6c67eb3`（headless で Stop hook 3 本無効化）/ `c9ee0588`（evidence-footer 誤検知修正）/ `9ccf8bef`（verify-step の session スコープ化）/ `aaa51127`（追記ログの retention cap）/ `840f825c`（_profile-wrapper 撤去）/ `65c0fd95`（restrict-cwd-edits の worktree allow）/ `0e3b7f8f`（act-time ガード 3 本新設）
- 誤検知の実測: 2026-07-05 監査セッションで stop-dup-guard が fence 内例示に 5 回連続誤発火
