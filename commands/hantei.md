---
description: 承認カードの✅/❌/⏸裁定の後処理（INBOX記帳・任意でinterventions.csv）を1コマンドで反映する（hantei_apply.py 起動）
argument-hint: "[report.md ...] [--apply] [--create-csv]（省略時は隔週/週次の2ボードを自動走査・既定はdry-run）"
---

# /hantei

トリガー語:「裁定反映して」「裁定を反映」「hantei」。**人の✅/❌/⏸判断はそのまま尊重し、事務（記帳・転記）だけを自動化する**。判断ロジックは持たない。

## 実行内容

`~/.claude/scripts/hantei_apply.py` を実行し、以下を行う:

1. **裁定抽出**: 対象レポート（省略時は `adscrm-biweekly-ads-pdca-result.md` + `adscrm-weekly-ops-review-result.md`）の承認カード（`[!todo]` callout の「あなたの返事」表セル）から、まだ処理していない✅/❌/⏸裁定を抽出する。プレースホルダー（`✅ / ❌ / ⏸` のような選択肢列挙のまま）は未回答として自動でskip
2. **INBOX 裁定ログ 1行追記**: `AIads_INBOX.md` の `## ✅ 裁定ログ` 見出し直下（コメント行の後・既存エントリの前）へ、今回処理した全裁定をまとめた1行を追記
3. **INBOX 📒 原文転記**: 同ファイルの📒セクションへ〈日付｜対象｜裁定｜原文〉のタプル形式で1裁定1行ずつ追記（原文＝回答セルの内容そのまま）
4. **(任意) interventions.csv**: 既にファイルがあれば追記。無い場合は `--create-csv` を明示した時のみ `docs/pdca-data-scheme.md` のスキーマ（13列）で新規作成
5. **M番号カードは提案表示のみ**: カード見出しに `M番号`（例: 「M1」）が明記されている場合、`tasks/mN-*.md` の Metadata Status 更新の**提案**を出力に表示するだけで、実際の書込は行わない

## 安全弁（既定の動作）

- **既定は dry-run**。`--apply` を付けない限り一切書き込まず、追記されるはずの内容をプレビュー表示するだけ
- **`tasks/NOW.md` への書込は行わない**（2026-07-11 team-lead 裁定: 実体がこのMacに存在せず masa-2 側が正本の可能性があるため、自動書込対象から外し「手動確認」に留める。Q番号→M番号の自動対応表も作らない）
- **`interventions.csv` は既定では新規作成しない**（masa-2 側が正本の可能性を尊重）。ファイル不在時は `--create-csv` を明示しない限りスキップし、その旨を出力する
- **冪等（出力先自己照合）**: 冪等キーは「Q/M番号（無ければ正規化した対象名）＋レポート期間＋回答セル正規化」。追記直前に出力先本文（INBOX / csv）自身に同一キーのマーカー（`<!-- hantei:KEY -->` / `key=KEY`）が既にあるか確認してから書くため、`~/.claude/state/hantei-apply.jsonl`（`pending→inbox_done→csv_done→done` のジャーナル・監査ログ）が壊れても二重追記しない。見出しの説明文だけが変わっても同一裁定として扱う
- **並行編集検知**: INBOX読取直後のhashを保持し、書込直前に再読して不一致なら何も書かず中止（再実行を促す）
- **部分失敗からの復帰**: csv書込に失敗（権限/ヘッダー不一致等）してもINBOX側は既に反映済みのまま維持され、次回実行時はcsvの不足分だけ補完される
- csv行の `action`/`level`/`target_id` 等は自動判定せず空欄のまま・`note` 列に原文と出典を残すだけ（誤分類での正本汚染を避けるため）

## 使い方

```bash
python3 ~/.claude/scripts/hantei_apply.py                       # 2ボード自動走査・dry-run（既定）
python3 ~/.claude/scripts/hantei_apply.py --apply                # INBOXへ実書込（csv/NOW.mdは対象外）
python3 ~/.claude/scripts/hantei_apply.py --apply --create-csv   # csv不在なら新規作成も実行
python3 ~/.claude/scripts/hantei_apply.py <report.md> --apply    # 個別レポート指定
```

## 前提条件

- INBOX 正本: `~/Documents/Obsidian Vault/02_Ai/AI_adscrm/AIads/prompts/AIads_INBOX.md`
- レポート正本: `~/Documents/Obsidian Vault/02_Ai/AI_adscrm/AIads/reports/`
- interventions.csv 正本候補: `~/Desktop/prm/prime_suite/prime_ad/metrics/interventions.csv`（2026-07時点でこのMacには実在しない可能性が高い＝masa-2側）
- 「あなたの返事」表セルを持つのは現時点で隔週レポート（`adscrm-biweekly-ads-pdca-result.md`）のみ。週次レポートのカードは承認欄が無い形式のため自動的に0件検出となる（正常動作）

## 本番初回実行の手順

1. **masa-2 側で実行することを推奨**（interventions.csv / tasks/NOW.md の正本が存在する環境）
2. このMac上で運用する場合は、まず `--apply` なしで dry-run 出力を目視確認し、抽出された裁定と追記内容が想定通りであることを確認してから `--apply` を付ける
3. `--create-csv` は csv の実物が masa-2 に存在しないと確認できた場合のみ使う

## NOT for

- 管理画面への実投入そのもの → 人間の手番（fail-close・本ツールは記帳のみ）
- `tasks/mN-*.md` Metadata の自動更新 → 今回スコープ外（提案表示のみ。Q→M対応表が確定してから再検討）
- 承認カード自体の生成・裁定の判断そのもの → 既存の隔週/週次レビュー運用（`vault-prompt-runner.sh` 等）
