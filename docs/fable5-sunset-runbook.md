# Fable 5 サンセット切替 Runbook（Fable5ライク運用）

**作成: 2026-07-06 / 出典: INBOX投函 X記事2本のファクトチェック結果**

## ✅ 結論（3行）
- **Fable 5 は 2026-07-13 時点で提供継続中**。切替はモデルピッカー/実リクエストで提供終了を観測してから**手動判断のみ**で行う（固定日での自動切替はしない）
- 移植できるのは「振る舞い」だけ。素の賢さ・思考の深さの機構は移植できない（期待値注意）
- output style `Fable5-like` は Fable 以外のモデルに切り替えた時だけ有効化する。**Fable 5 使用中は有効化しない**（本体ハーネスと二重指示になり品質低下）

> **自動切替は退役済み（2026-07-13）**: 旧 `hooks/fable5-sunset-autoswitch.sh` は 7/9 02:12 に発火して model を opus に格下げしたが、Fable 5 は実際には提供継続中で「予防切替の空振り」となった（prime_suite での指示追従低下の主因）。7/13 に model 復旧・SessionStart 登録解除・本体を `hooks/_retired/` へ移動。
> **masa-2 側の手順（重要・順序厳守）**: marker（`state/fable5-sunset-switched.done`）と `settings.local.json` は git 管理外のため、masa-2 では旧 hook が生き残っている可能性がある。**Claude を起動する前に** `cd ~/.claude && git pull` で退役変更を先に取り込むこと。先に起動してしまう場合は `touch ~/.claude/state/fable5-sunset-switched.done` で発火を止めてから。model はマシン固有（`settings.local.json`）管理なので、pull 後に `/model` で Fable 5 を設定する。

---

## 切替手順（コピペ可）

1. **モデル切替**: `/model opus`（または `/model sonnet`）と入力する。
   `settings.json` を直接編集する場合は `"model": "claude-opus-4-8"` か `"claude-sonnet-5"`（エイリアス `opus`/`sonnet` も可）。
   現在値は `"model": "claude-fable-5[1m]"`。
   Sonnet 5 は Claude Code v2.1.197+、Opus 4.8 は v2.1.154+ が必要（現環境 v2.1.201 なので両方 OK）。
   出典: https://code.claude.com/docs/en/model-config

> **⚠️ 2026-07-13 更新（案① 恒久化）**: `model` と `outputStyle` は git 同期の `settings.json` に**ベタ書きしない**（2台 Mac で pull 衝突＋Fable 機での二重がけの元）。マシン固有値は `~/.claude/settings.local.json`（.gitignore 済・優先度は settings.json より上）に置き、`hooks/machine-local-bootstrap.sh` が SessionStart でキー単位に冪等補正する（`masaaki_nagasawa`→model=fable・outputStyle なし／その他→model=sonnet・outputStyle=Fable5-like）。下記手順で settings.json を直接編集する案内は旧方式。手で切り替えたい時も settings.local.json を編集すること。

2. **output style 有効化**: `~/.claude/settings.local.json` に `"outputStyle": "Fable5-like"` を置く（bootstrap が自動生成するので通常は手作業不要）。旧: `~/.claude/settings.json` へ追加、または `/config` → "Output style" で選ぶ。
   スタイル本体は `~/.claude/output-styles/fable5-like.md` に作成済み。
   `/config` で選ぶと project の `.claude/settings.local.json` に保存される点に注意（global にしたければ settings.json に手書きする）。
   **注意（古い情報に釣られない）**: `/output-style` スラッシュコマンドは v2.1.73 で deprecated、v2.1.91 で削除済み。X記事等の古い解説がこれを紹介していても実行できない。
   出典: https://code.claude.com/docs/en/output-styles
   設定後、必ず `/clear` するか Claude Code を再起動して新セッションで確認する（output style は system prompt の一部としてセッション開始時に適用されるため、設定変更だけでは現行セッションに効かない）。
   競合確認:
   ```
   grep -n 'outputStyle\|"model"\|effortLevel' ~/.claude/settings.json ~/.claude/.claude/settings.local.json
   ```
   project-local の settings.local.json が global を上書きするため、切替が効かない時はまずこれで競合を確認する（2026-07-06 実測: settings.local.json は permissions のみで競合なし）。

3. **思考の深さ（effort）を確認**: `settings.json` の `"effortLevel"` は現在 `"high"`。
   **これは Sonnet 5 / Opus 4.8 の既定値なので、指定しても変化はない**（「high にせよ」という記事のアドバイスは実質意味がない）。
   深くする目的なら `"effortLevel": "xhigh"`（persist 可能なのは low/medium/high/xhigh）。max は session 限定。low/medium は浅く（速く・安く）する方向で実効がある。
   session 限定で深くするには `/effort` コマンド（max / ultracode）。環境変数 `CLAUDE_CODE_EFFORT_LEVEL` で指定できるのは max まで（ultracode は環境変数・settings.json とも不可、`/effort` のみ）。
   プロンプト中に `ultrathink` と書けば、その1回だけ深く考えさせられる。
   出典: https://code.claude.com/docs/en/model-config#adjust-effort-level
   参考（未検証）: connect24h 記事は公式移行ガイドの逆読みから『Fable の high ≒ Opus 4.8 の xhigh』とし、Opus 切替時は xhigh を推奨している。

4. **（任意）フォールバック設定**: `"fallbackModel": ["claude-sonnet-5", "claude-haiku-4-5"]`（配列・最大3つ）。
   Anthropic 側が過負荷のときに自動で切り替わる可用性フォールバック。
   出典: https://code.claude.com/docs/en/model-config

5. **（任意）SubAgent のコスト分割**: メイン担当（設計・監査）に Opus、SubAgent（実装・調査）に Sonnet を割り当てる運用。
   設定経路は3つ: Agent 呼び出し時の model パラメータ／subagent の frontmatter の `model`／環境変数 `CLAUDE_CODE_SUBAGENT_MODEL`。
   出典: https://code.claude.com/docs/en/model-config
   公式エイリアス `opusplan` もある（挙動の詳細は model-config docs 参照）。
   **注意: output style は Task/Agent で起動する SubAgent には効かない**（公式 docs の比較表: Agents は独自の system prompt を持つ）。SubAgent へ委譲するときは、`output-styles/fable5-like.md` 末尾の凝縮版ブロックを委譲プロンプトの末尾に貼る（connect24h 記事本文で同手法を確認）。

---

## 7/7 までにやる仕込み（任意）: リハーサル往復

Fable 5 がいるうちにしかできない検証ループ（noel_ai_lab 記事の最重要提案）。切替後の構成を試運転し、ズレを **Fable 5 自身に修正させる**。期間終了後は「直せる側の AI」が手元にいない。

1. 別ターミナルで試運転セッションを起動（`--settings` は CLI v2.1.201 実測で実在するフラグ）:
   ```
   claude --model claude-sonnet-5 --settings '{"outputStyle":"Fable5-like"}'
   ```
2. 実タスクを 1 つやらせて、ズレをメモ（結論が後回し／過剰な確認／検証の省略 など）
3. Fable 5 のセッションに戻り、ズレを渡して「`output-styles/fable5-like.md` を修正して」と依頼
4. もう 1 往復して収束させる

**実施記録（2026-07-06・Fable 5 セッションで実施済み）**: headless（`claude -p` + Sonnet 5 + 本スタイル）で 4 プローブ実施 — ①スタイル読込（本文を一字一句引用で確認）②観測ベース報告（Stop hook 数 13 を実測回答・正解）③自発検証（fizzbuzz 作成で指示なしに実行検証してから完了報告。出力は独立検証で期待値と完全一致）④相談モード（「原因なんだろう？」に対しファイル無編集=MD5 前後一致・所見+選択肢のみ）→ **全 PASS・スタイル修正なしで収束**。
**注意**: `~/.claude` 配下は headless セッションでは sensitive-file 扱いになり Write が自動拒否される（実測）。リハーサルの作業タスクは `/tmp` など別ディレクトリで行うこと。

---

## 切り戻し（Fable 5 復帰時）

復帰判定は観測で行う: model picker（`/model`）に fable が出る、または `claude --model fable` の初回応答が成功したら復帰とみなす（時期の目安: 8日以降の従量課金 or 再開放）。
復帰と判定したら、`settings.json` から `"outputStyle"` の指定を外す（または `"Default"` に戻す）。

**理由**: Anthropic 公式ガイドが「Fable 5 に旧来の過剰な指示スキャフォールドを与えると出力品質が下がる」と明言している。Fable 5 自身にこの output style の指示を与えると、harness（Fable 5 本体の挙動制御機構）と指示内容が二重になり、かえって足を引っ張る。
出典: https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5

---

## ファクトチェック表

| 主張 | 出どころ | VERDICT | 根拠 |
|---|---|---|---|
| Fable 5 の「振る舞い」は Anthropic 公式素材から output style として移植できる | connect24h 記事（タイトル+リード） | **一部真** | output style 機構と公式スニペットは実在（公式サンクション済みの経路）。ただし Fable 5 挙動の再現度そのものは未保証 → 2026-07-06 記事本文取得後の照合で CONFIRM（記事自身も能力・safety classifier の限界を明記＝当表の評価と一致） |
| output style は `/output-style` コマンドで有効化 | 同時期のX記事群 | **偽（古い）** | v2.1.91 で削除済み。`/config` か `outputStyle` キーで有効化。なお connect24h 記事本文は `/config → Output style → /clear` の正手順を案内しており誤りなし（偽なのは同時期の他記事群） |
| settings.json `"effortLevel": "high"` で Sonnet 5 の思考が深くなる | @armadillo_ai 記事ミラー | **偽（high は no-op）** | high は既定値。深くするなら xhigh（persist可）/ max（session限定）。low/medium は浅くする方向で実効あり |
| Anthropic は Fable 5 のシステムプロンプトを公式公開している | connect24h 記事リード | **真（ただし claude.ai 用）** | platform.claude.com/docs/en/release-notes/system-prompts に 2026-06-09 付で掲載。Claude Code harness prompt とは別物 → 本文照合で CONFIRM（connect24h が参考文献として明記） |
| Fable 5 がいるうちに「頭の中」を資産として抜き取っておくべき | noel_ai_lab 記事（タイトル+リード） | **真（本文確認済み）・処方箋は別軸** | 本文を influx Cookie 経路で取得し確認。記事の処方箋は①チャット限定成果物の回収②後任AI向け引き継ぎ書③リハーサル往復。本 runbook が実施したのは『振る舞い移植』であり別軸。③は下記『7/7 までにやる仕込み』として採用 |
| モデルID は claude-opus-4-8 / claude-sonnet-5 | 記事群 | **真** | model-config docs（`claude --help` が直接表示するのはエイリアスと claude-fable-5 の例のみ） → 本文照合で矛盾なし |
| Fable の effort high は Opus 4.8 の xhigh に相当（公式移行ガイドの逆読み） | connect24h 記事本文 | **未検証** | もっともらしいが移行ガイド原文での裏取り未実施。Opus 切替時に xhigh を試す価値はある |

---

## 移植できないもの（期待値設定）

- **素の能力**（一発正答率・数日規模の自律走行・画像読解・SubAgent 采配の質）— これは weights（モデル本体の学習内容）由来で、output style では再現できない
- **effort の適応思考機構そのもの**（Fable 5 は思考を無効化できない設計になっている）と、**Fable 専用の安全分類器**（サイバー攻撃・バイオリスクの話題を検知して自動で Opus にフォールバックする仕組み）
- 出典: https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5 と https://code.claude.com/docs/en/model-config

---

## プロンプト例（切替後の動作確認）

```
# 切替後の動作確認（新セッションで貼る）
今のセッションの model・effort・output style を実測で報告して。
そのあと「このタスクの成功基準を先に定義→実行→観測ベースで完了報告」の型が
効いているか、ダミータスク（このrepoのREADME要約）で1周見せて。
```

---

## 出典

- https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5
- https://platform.claude.com/docs/en/release-notes/system-prompts
- https://code.claude.com/docs/en/output-styles
- https://code.claude.com/docs/en/model-config
- 記事1: https://x.com/connect24h/status/2073364135111508418 （2026-07-06 本文取得済み・influx Cookie 経路。全文: ~/Desktop/biz/influx/output/x_articles/connect24h.txt）
- 記事2: https://x.com/noel_ai_lab/status/2073039341992194336 （同上・noel_ai_lab.txt）
