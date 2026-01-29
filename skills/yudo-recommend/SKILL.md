# LLM Few-shot レコメンド機能作成スキル

## 概要

CSVデータから関連アイテムを推定するレコメンド機能を、LLM Few-shotアプローチで作成するスキル。

## 発動条件

以下のキーワードで発動:
- 「レコメンド機能を作成」
- 「推定機能を作成」
- 「Few-shotで推定」
- 「CSVから関連を推定」
- 「誘導先を自動生成」

## 実装手順

### Phase 1: データ分析

1. **CSVデータの読み込み・構造確認**
   ```python
   import csv
   with open(csv_path, 'r', encoding='utf-8') as f:
       reader = csv.DictReader(f)
       print("カラム名:", list(reader.fieldnames))
   ```

2. **既存パターンの分析**
   - 推定対象の頻度分布を確認
   - カテゴリ別のパターンを分析
   - 人気の推定先（頻出値）を特定

3. **セット関係の確認**
   - ID と付随情報がセットかどうか確認
   - マッピングテーブルを構築

### Phase 2: 推定モジュール作成

**ファイル構成例**: `backend/utils/xxx_predictor.py`

```python
"""
レコメンド推定モジュール
LLM Few-shot アプローチで [特徴列] から [推定対象] を推定
"""

import csv
import re
import os
import json
import logging
from typing import List, Dict, Tuple, Optional
from dataclasses import dataclass

import google.generativeai as genai

logger = logging.getLogger(__name__)

GEMINI_API_KEY = os.getenv('GEMINI_API_KEY') or os.getenv('GOOGLE_API_KEY')
GEMINI_MODEL = os.getenv('GEMINI_MODEL', 'gemini-2.5-flash')


@dataclass
class Item:
    """アイテムデータクラス"""
    id: str
    feature1: str  # 特徴列1（例: title）
    feature2: str  # 特徴列2（例: guide）
    target_id: str = ""  # 推定対象ID
    target_sub: str = ""  # 推定対象の付随情報
    category: str = ""


@dataclass
class RecommendTarget:
    """推定結果（IDと付随情報のペア）"""
    target_id: str
    target_sub: str

    def __str__(self):
        return f"{self.target_id} / {self.target_sub}"


def classify_category(text: str) -> str:
    """カテゴリ分類（ルールベース）"""
    # プロジェクト固有のキーワードでカテゴリ分類
    CATEGORY_KEYWORDS = {
        'カテゴリA': ['キーワード1', 'キーワード2'],
        'カテゴリB': ['キーワード3', 'キーワード4'],
    }
    for cat, keywords in CATEGORY_KEYWORDS.items():
        if any(kw in text for kw in keywords):
            return cat
    return 'その他'


def load_data(csv_path: str) -> List[Item]:
    """CSVからデータを読み込み"""
    items = []
    with open(csv_path, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            # CSVカラム名に合わせて修正
            items.append(Item(
                id=row.get('id', ''),
                feature1=row.get('feature1', ''),
                feature2=row.get('feature2', ''),
                target_id=row.get('target_id', ''),
                target_sub=row.get('target_sub', ''),
                category=classify_category(row.get('feature1', ''))
            ))
    return items


def build_id_to_sub_mapping(items: List[Item]) -> Dict[str, str]:
    """ID → 付随情報のマッピングを構築"""
    from collections import Counter

    id_sub_counts = {}
    for item in items:
        if item.target_id and item.target_sub:
            if item.target_id not in id_sub_counts:
                id_sub_counts[item.target_id] = Counter()
            id_sub_counts[item.target_id][item.target_sub] += 1

    # 最頻出を選択
    return {
        tid: counter.most_common(1)[0][0]
        for tid, counter in id_sub_counts.items()
        if counter.most_common(1)
    }


def get_popular_targets(items: List[Item], top_n: int = 15) -> List[Tuple[str, int]]:
    """頻出する推定先を取得"""
    from collections import Counter
    counts = Counter(item.target_id for item in items if item.target_id)
    return counts.most_common(top_n)


def select_few_shot_examples(items: List[Item], n: int = 8) -> List[Item]:
    """Few-shot用のサンプルを選択（カテゴリバランス考慮）"""
    from collections import defaultdict
    by_category = defaultdict(list)
    for item in items:
        if item.target_id:
            by_category[item.category].append(item)

    examples = []
    per_cat = max(1, n // len(by_category))
    for cat_items in by_category.values():
        examples.extend(cat_items[:per_cat])
    return examples[:n]


def build_prompt(items: List[Item], target: Item, popular: List[Tuple[str, int]]) -> str:
    """Few-shotプロンプトを構築"""
    examples = select_few_shot_examples([i for i in items if i.id != target.id])

    popular_list = "\n".join([f"  - {tid}: {count}回使用" for tid, count in popular])

    examples_text = ""
    for ex in examples:
        examples_text += f"""
【入力】
id: {ex.id}
feature1: {ex.feature1[:60]}
feature2: {ex.feature2[:80]}
category: {ex.category}

【出力】
target_id: {ex.target_id}
---
"""

    return f"""あなたは[ドメイン]のレコメンド設定の専門家です。
入力データから、最適な推定先を推薦してください。

## ルール
1. 同じカテゴリに推薦することが多い
2. 人気の推定先を優先
3. 自分自身には推薦しない

## 人気の推定先（頻出順）
{popular_list}

## 既存の設定例
{examples_text}

## 推定対象
【入力】
id: {target.id}
feature1: {target.feature1[:80]}
feature2: {target.feature2[:120]}
category: {target.category}

【出力】
JSON形式で回答: {{"target_id": "xxx"}}
"""


class Predictor:
    """推定クラス"""

    def __init__(self, csv_path: str):
        if not GEMINI_API_KEY:
            raise ValueError("GEMINI_API_KEY を設定してください")

        genai.configure(api_key=GEMINI_API_KEY)
        self.model = genai.GenerativeModel(GEMINI_MODEL)
        self.items = load_data(csv_path)
        self.popular = get_popular_targets(self.items)
        self.id_to_sub = build_id_to_sub_mapping(self.items)

    def predict(self, target: Item) -> RecommendTarget:
        """推定実行"""
        prompt = build_prompt(self.items, target, self.popular)

        try:
            response = self.model.generate_content(prompt)
            if response.candidates and response.candidates[0].content:
                text = response.candidates[0].content.parts[0].text
                # JSON抽出
                import json
                data = json.loads(text.strip().replace('```json', '').replace('```', ''))
                target_id = data.get('target_id', '')
                target_sub = self.id_to_sub.get(target_id, '')
                return RecommendTarget(target_id, target_sub)
        except Exception as e:
            logger.error(f"推定エラー: {e}")

        return RecommendTarget("", "")
```

### Phase 3: APIエンドポイント追加

**ファイル**: `backend/routers/xxx.py`

```python
class RecommendRequest(BaseModel):
    feature1: str = Field(..., description="特徴1")
    feature2: str = Field("", description="特徴2")
    csv_path: str = Field("/path/to/data.csv", description="学習用CSV")


class RecommendResponse(BaseModel):
    success: bool
    target_id: str = ""
    target_sub: str = ""
    model_used: str = ""
    message: str = ""


@router.post("/api/recommend", response_model=RecommendResponse)
async def recommend(request: RecommendRequest):
    """レコメンドAPI"""
    from utils.xxx_predictor import Predictor, Item, classify_category

    predictor = Predictor(request.csv_path)

    target = Item(
        id="NEW",
        feature1=request.feature1,
        feature2=request.feature2,
        category=classify_category(request.feature1)
    )

    result = predictor.predict(target)

    return RecommendResponse(
        success=bool(result.target_id),
        target_id=result.target_id,
        target_sub=result.target_sub,
        model_used="gemini",
        message="レコメンド完了"
    )
```

### Phase 4: フロントエンド統合

1. **グローバル変数追加**
   ```javascript
   let recommendResult = null;
   ```

2. **API呼び出し追加**
   ```javascript
   const response = await fetch('/api/recommend', {
       method: 'POST',
       headers: { 'Content-Type': 'application/json' },
       body: JSON.stringify({ feature1: xxx, feature2: yyy })
   });
   recommendResult = await response.json();
   ```

3. **表示関数追加**
   ```javascript
   function displayRecommend(result) {
       const el = document.getElementById('recommend-inline');
       if (result && result.success) {
           el.style.display = 'block';
           el.innerHTML = `
               <span class="label">推定結果</span>
               <div>${result.target_id} / ${result.target_sub}</div>
           `;
       }
   }
   ```

4. **後続処理で使用**
   ```javascript
   body: JSON.stringify({
       target_id: recommendResult?.success ? recommendResult.target_id : null,
       target_sub: recommendResult?.success ? recommendResult.target_sub : null,
   })
   ```

## プロンプトテンプレート

ユーザーへの依頼時に使用:

```markdown
# 依頼内容

CSVデータから [推定したい項目] を自動生成する機能を作成してください。

## データ構造

入力CSVの主要カラム:
- [ID列]: 例) item_id
- [特徴列1]: 例) title - 商品名
- [特徴列2]: 例) description - 説明文
- [推定対象1]: 例) recommend_id - 推薦先ID
- [推定対象2]: 例) recommend_sub - 推薦先の付随情報

## サンプルデータ（3-5件）

ID: 001
title: xxxxx
description: xxxxx
推定対象: yyy / zzz

## 要件

1. [特徴列] から [推定対象] を推定する
2. [推定対象1] と [推定対象2] はセットで管理
3. 既存データのパターンを学習して推定

## 出力形式

ID: 001
推定結果: [推定対象1] / [推定対象2]
```

## 注意事項

- **セット関係を明示**: IDと付随情報がセットの場合、必ず明記
- **サンプルデータ提示**: 3-5件の具体例を提示
- **マッピングテーブル**: ID→付随情報のマッピングを構築
- **カテゴリ分類**: ルールベースでカテゴリ分類し、同カテゴリ優先
- **人気推定先**: 頻出する推定先を優先的に提案

## 実装例

- `/Users/masaaki/Desktop/prm/rohan/backend/utils/yudo_predictor.py`
- `/Users/masaaki/Desktop/prm/rohan/backend/routers/registration.py` (`/api/yudo-recommend`)
- `/Users/masaaki/Desktop/prm/rohan/frontend/auto.html` (`displayYudoRecommend`)
