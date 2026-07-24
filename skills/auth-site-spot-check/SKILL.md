---
name: auth-site-spot-check
description: |
  ログイン必須の公式サイトで、疑わしい既存データを本人アカウントにより人在席・少数・読み取り専用で裏取りするcwd非依存スキル。
  トリガー語: ログイン必須サイトで裏取り, 公式サイトで照合, 認証サイトのスポット確認, auth spot check, authenticated site spot check。
  NOT for: X計測(→fetch-engagement), 無人定期収集(→各プロジェクトでCookie方式を個別設計), 公開サイトのスクレイプ(→web-research-tools)
allowed-tools:
  - AskUserQuestion
  - mcp__claude-in-chrome__tabs_context
  - mcp__claude-in-chrome__tabs_create
  - mcp__claude-in-chrome__navigate
  - mcp__claude-in-chrome__read_page
---

# auth-site-spot-check skill

## 発火・詳細

ログイン必須サイト上の疑わしい値だけを、本人アカウントで少数裏取りする。cwd 非依存。全量収集や無人自動化は扱わない。

トリガー: 「ログイン必須サイトで裏取り」「公式サイトで照合」「認証サイトのスポット確認」「auth spot check」など。

NOT for: X 計測（→ `fetch-engagement`）、無人定期収集（→各プロジェクトで Cookie 方式を個別設計）、公開サイトのスクレイプ（→ `web-research-tools`）。

## STEP 0: ホストとログイン状態を確定する

1. ユーザーに、対象サイトへログイン済みと思われる Mac・ブラウザ・プロフィールを一言確認する。
2. `claude-in-chrome` の `tabs_context` で、実際に接続中のホスト、ブラウザ、プロフィール、対象サイトのログイン状態を確認する。推測で進めない。
3. 対象アカウントのログインを実測できなければ中止し、ユーザーに必要なホストとプロフィールでのログイン・接続を依頼する。

Mac が複数ある場合は host-disambiguation-first を守る。`claude-in-chrome` による実 Chrome 操作は人の同席を必須とし、launchd その他の無人自動化には載せない。

## STEP 1: 取得経路を ladder で選ぶ

次の順で、利用可能な最上位の経路だけを使う。

1. 公式 API または公式エクスポートがあれば最優先する。
2. なければ、人在席の `claude-in-chrome` で対象ページを開き、必要な値だけを読み取る。
3. 無人化または大量化を求められたら範囲外と伝え、Cookie 方式を呼び出し元プロジェクトで個別設計する。参考実装は influx の `import_chrome_cookies.py` とするが、そのまま転用しない。

## STEP 2: 安全ゲートを通す

- 読み取りだけを行う。クリックは閲覧ページへの遷移に限定し、更新、購入、送信、設定変更をしない。
- 操作前に対象 URL と件数をユーザーへ明示する。既定上限は 10 件/回とする。
- 429、403、CAPTCHA のいずれかを検知したら即停止し、回避を試みない。
- 低頻度かつ直列で確認する。並列アクセス、proxy による回避、制限回避をしない。
- credential、Cookie 値、アカウント名をスキル、会話上の成果物、プロジェクト成果物へ記録しない。

## STEP 3: 証跡を残す

呼び出し元プロジェクトの task またはレポートへ、各照合について次を記録する。

- 取得日時
- URL
- 見た値
- 既存データとの一致 / 不一致

不一致でも正本データを勝手に書き換えない。プロジェクト側の訂正手順（データ再取得または手動オーバーライド台帳）へ送る。

## 既知の適用例

- PSA 公式 POP 照合（pokeca-invest、2026-07）: GemRate ミラーで疑わしい行（例: PSA 10 = 0）だけを裏取りする。ログインで認証壁のみ解けても Cloudflare の制限は残るため、少数確認に限定する。
