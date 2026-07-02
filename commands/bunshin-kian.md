# bunshin-kian

分身の起案ジェネレータ v0。ユーザー(MASA)本人の起案の型で、一言のテーマから「実装プロンプト(AIに投げる起案文)」を生成する。

どのプロジェクトの cwd からでも使用可。`skills/bunshin-kian/SKILL.md` を実行する。

## 何をするか

1. **現況を先に読む**(NOW.md/plan.md/data/raw ── 本人の #1 基準)
2. **人間専権スロットを質問**(相場観の数値・採算・thesis・会議決定 ── 分身は勝手に埋めない)
3. **本人の4段テンプレで起案文を組む**(背景 → 検討ポイント番号列挙 → 成果物の絶対パス → codex+agent team 検証)
4. **承認と着手を分離**(「このまま投げる/直す」を一言で聞く)

## 使い方

```
/bunshin-kian [起案したいテーマ 一言]
```

## 例

```
/bunshin-kian 指名検索の取りこぼしを回収するCPを作りたい
/bunshin-kian LINE@ の再来訪で AR PU を上げたい
/bunshin-kian ポケカの下落局面で買い時を判定する指標
```

## 出力

- BLUF(3行) + 起案文本体(コピペ即投入可) + codex に叩いてほしい論点3つ
- `<project>/prompts/<project>_INBOX.md` への保存を offer(勝手に保存しない)
