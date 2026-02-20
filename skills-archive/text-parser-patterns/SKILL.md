---
name: text-parser-patterns
description: |
  構造化テキスト（設定ファイル、マークアップ、ユーザー入力など）をパースする際の実装パターン集。
  エッジケース処理、デバッグ手法、よくある落とし穴と解決策を提供。
  キーワード: パーサー, パース, 抽出, 解析, セクション区切り, テキスト処理
allowed-tools: "Read Glob Grep"
license: proprietary
metadata:
  author: masaaki-nagasawa
  version: 1.1.0
  category: guide-reference
  tags: [parser, text-processing, regex, edge-cases]
---

# テキストパーサー実装パターン

## 概要

構造化テキスト（設定ファイル、マークアップ、ユーザー入力など）をパースする際の実装パターン集。
エッジケース処理、デバッグ手法、よくある落とし穴と解決策を提供。

## 発動条件

以下のキーワード・状況で使用：
- 「パーサー」「パース」「抽出」「解析」を含むテキスト処理
- 「セクション」「区切り」「マーカー」の検出ロジック実装
- 「N個指定したのにM個しか」のようなパース結果の不一致
- 構造化テキストの読み込み・変換処理
- 「自動モードでは動くが手動モードでは動かない」等のモード間不整合
- 「番号付け」「正規化」「フォーマット統一」を含む前処理

---

## パターン一覧

| # | パターン | 用途 | 詳細 |
|---|---------|------|------|
| 1 | 区切り文字とコンテンツの曖昧性解決 | 区切り文字がコンテンツにも現れる場合 | [delimiter-patterns.md](references/delimiter-patterns.md) |
| 2 | セクション境界の検出戦略 | マーカー完全一致/開始+終了/インデント | [delimiter-patterns.md](references/delimiter-patterns.md) |
| 3 | パースエラーのデバッグ手順 | 入力確認→マーカー検出→中間検証→比較 | [debugging-patterns.md](references/debugging-patterns.md) |
| 4 | よくある落とし穴 | 正規表現$, 空白, 早期終了, \s*, リセット忘れ | [debugging-patterns.md](references/debugging-patterns.md) |
| 5 | テスト戦略 | エッジケーステストデータ | [testing-patterns.md](references/testing-patterns.md) |
| 6 | 複数入力モードのフォーマット統一 | 自動/手動で出力不統一 | [multi-mode-patterns.md](references/multi-mode-patterns.md) |
| 7 | 同一機能の実装分散リスク | 同じ機能の異なる実装が複数箇所 | [multi-mode-patterns.md](references/multi-mode-patterns.md) |
| 8 | API層とコア関数のテスト分離 | APIテスト成功+内部処理失敗 | [multi-mode-patterns.md](references/multi-mode-patterns.md) |
| 9 | 処理モード別のセクション検出スキップ | モードでマーカー有無が異なる | [multi-mode-patterns.md](references/multi-mode-patterns.md) |

---

## 実装チェックリスト

- [ ] 区切り文字がコンテンツにも現れる可能性を考慮したか
- [ ] 既知のセクションヘッダーをホワイトリストで管理しているか
- [ ] 入力データのデバッグログを出力できるか
- [ ] マーカー検出のトレースログを追加したか
- [ ] 期待値と実際の結果を比較する検証を入れたか
- [ ] 空入力、空行、特殊文字のエッジケースをテストしたか
- [ ] ループの早期終了が意図したものか確認したか
- [ ] 状態変数のリセットを明示的に行っているか
- [ ] 複数の入力モード（自動/手動等）で出力フォーマットが統一されているか
- [ ] 後続処理が期待するフォーマットを入力データが満たしているか
- [ ] **同一機能の実装が複数箇所に分散していないか確認したか**
- [ ] **API層テストだけでなく、コア関数の直接テストも行ったか**
- [ ] **新フォーマット追加時、全ての関連パース関数に適用したか**

---

## リファレンス一覧

| ファイル | 内容 |
|---------|------|
| [references/delimiter-patterns.md](references/delimiter-patterns.md) | パターン1-2: 区切り文字の曖昧性解決、セクション境界検出戦略 |
| [references/debugging-patterns.md](references/debugging-patterns.md) | パターン3-4: パースエラーのデバッグ手順、よくある落とし穴5選 |
| [references/testing-patterns.md](references/testing-patterns.md) | パターン5: エッジケーステストデータの設計 |
| [references/multi-mode-patterns.md](references/multi-mode-patterns.md) | パターン6-9: 複数モードのフォーマット統一、実装分散リスク、テスト分離、検出スキップ |
| [references/case-study-rohan-subtitle-parser.md](references/case-study-rohan-subtitle-parser.md) | ケーススタディ: Rohan小見出しパーサーの実例 |
