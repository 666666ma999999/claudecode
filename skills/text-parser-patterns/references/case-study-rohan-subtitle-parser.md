# ケーススタディ: Rohan小見出しパーサーのバグ修正

## 概要
- **日付**: 2026-01-27
- **症状**: 10個指定した小見出しが4個しか登録されない
- **原因**: パーサーが`「`で始まる行を新セクションと誤認して早期終了
- **修正時間**: 約30分（調査含む）

---

## 症状の発見

### ユーザーの報告
```
小見出しは10個で指定したのですが、なぜ6つなんですか？
```

### コンソールログ
```
✅ 構造化原稿パースAPI使用: 4 件
STEP 2 │ メニュー登録 │ 6件の小見出しを保存
```
（6件 = 冒頭 + 4小見出し + 締め）

---

## 調査プロセス

### ステップ1: セッションデータの確認
```bash
python3 << 'EOF'
import json
with open('data/sessions/reg_xxx.json') as f:
    data = json.load(f)

# 入力の小見出し数
print(f"product.subtitles: {len(data['product']['subtitles'])}個")
# → 10個（正しい）

# パース後の小見出し数
print(f"structured_manuscript.subtitles: {len(data['product']['structured_manuscript']['subtitles'])}個")
# → 4個（問題）
EOF
```

### ステップ2: 原稿内のマーカー確認
```bash
# 原稿内の[小見出しN]マーカーを検索
markers = re.findall(r'\[小見出し\d+\]', manuscript)
print(f"マーカー数: {len(markers)}")
# → 4個（原稿生成時点で4つしか作られていない）
```

### ステップ3: 生成ログの確認
```bash
# manuscript_logsのメタデータを確認
{
  "subtitle_count": 4  # ← ここで既に4になっている
}
```

### ステップ4: 入力パース処理の特定
```python
# main.py の extract_subtitles_from_fortune_result 関数
# ここで入力から小見出しを抽出
subtitle_texts, subtitle_count = extract_subtitle_info(fortune_result)
```

---

## 根本原因

### 問題のコード
```python
# main.py 行2583-2590
if in_subtitle_section and line.strip() and (
    line.strip().startswith('【') or
    line.strip().startswith('「') or  # ← この条件が問題
    line.strip().startswith('■') or
    line.strip().startswith('▪') or
    line.strip().startswith('●')
):
    break  # セクション終了と判断
```

### 問題の入力データ
```
【小見出し】
1. 間違いなく彼が運命の人！...
2. 運命の歯車が...
3. 実はもう見つめられてるんです...
4. 彼のこの一言で...
5. 「この人しかいない」彼も出会った瞬間...  ← ここで break!
6. 怖いほどピッタリ！【二人の相性∞保存版】...
...
```

5番目の小見出しが`「`で始まっているため、パーサーが「新しいセクションが始まった」と誤認してループを終了。

---

## 修正内容

### Before
```python
if in_subtitle_section and line.strip() and (
    line.strip().startswith('【') or
    line.strip().startswith('「') or
    line.strip().startswith('■') or
    line.strip().startswith('▪') or
    line.strip().startswith('●')
):
    break
```

### After
```python
stripped = line.strip()
if in_subtitle_section and stripped:
    # 既知のセクションヘッダーパターン
    section_headers = ['【占い商品】', '【ロジック】', '【締め】', '【冒頭】', '【メッセージ】']

    # セクションヘッダーの判定条件
    is_section_header = (
        stripped in section_headers or
        (stripped.startswith('【') and stripped.endswith('】') and
         '小見出し' not in stripped and len(stripped) <= 20)
    )

    # 箇条書きマーカー
    is_bullet_list = (
        stripped.startswith('■') or
        stripped.startswith('▪') or
        stripped.startswith('●')
    )

    if is_section_header or is_bullet_list:
        break
```

### 修正のポイント
1. `「`で始まる行を一律に除外しない
2. 【】については「短い」かつ「セクション名らしい」場合のみ終了
3. 既知のセクションヘッダーをホワイトリストで管理

---

## 検証

```bash
# 修正後のAPIテスト
curl -X POST /api/parse-metadata -d '{"fortune_result": "..."}'

# 結果
{
  "subtitle_count": 10,  # 修正前: 4
  "subtitles": {
    "1": "間違いなく彼が運命の人！...",
    ...
    "5": "「この人しかいない」彼も出会った瞬間...",  # 正しく抽出
    "6": "怖いほどピッタリ！【二人の相性∞保存版】...",  # 正しく抽出
    ...
    "10": "この恋は、すべて決まっていたことなんです..."
  }
}
```

---

## 教訓

1. **区切り文字の曖昧性**: `「」【】`はコンテンツにも区切りにも使われる
2. **ホワイトリスト優先**: 「何を除外するか」より「何を許可するか」で判定
3. **セッションデータ活用**: 入力→処理→出力の各段階のデータを保存・確認
4. **生成ログ確認**: 問題がパースか生成かを切り分けるために中間ログを確認
