---
name: kpi-tree-first
description: |
  KPI計算式ツリーを正本として定義・参照してから実装するスキル。
  KPIの表示・分解・ドリルダウン・因果分析など、数値指標に関わる実装の前に
  計算式ツリー（docs/kpi_tree.yaml）を確認・作成し、葉ノードまで展開してから実装する。
  データアナリストagentへの委託時にも本スキルを指示に含める。
  使用タイミング:
  (1) KPIの表示・ドリルダウンUIを実装する
  (2) KPIの構成要素を分析・可視化する
  (3) 売上・粗利・コストの分解ロジックを実装する
  (4) データアナリストagentにKPI分析を委託する
  (5) 新しいKPIを追加する、既存KPIの計算式を変更する
  キーワード: KPI, 計算式, 分解, ドリルダウン, 構成要素, 葉ノード, 因果分解, 売上分解, 粗利構成
  NOT for: 単純な集計（SUM/AVG）、KPI定義が不要な1回限りのアドホック分析
allowed-tools: "Read Write Edit Glob Grep Bash"
license: proprietary
metadata:
  author: masaaki-nagasawa
  version: 1.0.0
  category: data-processing
  tags: [kpi, formula, decomposition, analytics, data-analysis]
---

# KPI Tree First スキル

## 原則

**KPIの計算式を推測しない。正本を参照し、葉ノードまで展開してから実装する。**

## なぜ必要か

LLMはKPIの計算式を一般知識で推測する傾向がある。例:
- `従量売上 = PU × ARPPU` で止めてしまう
- 実際は `PU = 入会数 × PUR` なので `従量売上 = 入会数 × PUR × ARPPU`
- 中間ノード（PU）で止めると、表示すべき葉ノード（入会数、PUR）が欠落する

この問題はKPI数が増えるほど深刻化する。計算式ツリーを正本として定義し、必ず参照する。

---

## Phase 1: KPIツリーの確認・作成

### Step 1: 既存ツリーの確認

```
docs/kpi_tree.yaml が存在するか確認
```

- **存在する** → Step 3 へ（参照フェーズ）
- **存在しない** → Step 2 へ（作成フェーズ）

### Step 2: KPIツリーの新規作成

以下のフォーマットで `docs/kpi_tree.yaml` を作成する:

```yaml
version: 1

# KPI定義: 1ノードにつき以下を記載
kpi_id:
  label: 表示名
  kind: derived | leaf    # derived=他KPIから算出, leaf=これ以上分解不可
  unit: 円 | 人 | "%" | ratio
  formula: 人間向け計算式  # derivedのみ
  children:               # derivedのみ。葉ノードまで展開すること
    - child_kpi_id_1
    - child_kpi_id_2
  datasource:             # leafのみ
    file: データソースファイル名
    category: CSVカテゴリ名
    metric: CSV指標名
  note: フォールバックや注意点
  fallback:               # 代替データソースがある場合
    condition: いつ発動するか
    source: 代替元
    warning: true
```

#### 作成ルール

1. **葉ノードまで必ず展開する**: `A = B × C` で `B = D × E` なら、Aのchildrenは `[D, E, C]` とする（Bは中間ノードとしてnote記載）
2. **全ての children が定義内に存在する**: 参照先が未定義ならエラー
3. **kind: leaf は datasource 必須**: データがどこから来るか明記
4. **kind: derived は formula + children 必須**: 計算式と構成要素の両方
5. **単位を明記**: 表示時の変換（円→万円）はUI層の責務。ツリーでは原単位

### Step 3: 既存ツリーの参照

タスクに関連するKPIノードを特定し、以下を確認:
- そのKPIの `children`（構成要素）は何か
- 葉ノード（`kind: leaf`）まで辿れているか
- UIに表示すべきは葉ノードか、中間の derived ノードか

---

## Phase 2: 実装

### KPI表示・ドリルダウンUIの場合

1. 対象KPIの `children` を取得
2. 各 child が `derived` なら、さらにその `children` を再帰的に辿る
3. **UIに表示するのは葉ノード**（kind: leaf）のみ
4. 中間ノードは表示しない（中間値で止めると構成要素が欠落する）
5. 表示順序は計算式の論理順に従う

### KPI分解・因果分析の場合

1. 対象KPIの計算式ツリーを葉ノードまで展開
2. 各葉ノードの変動（前期比）を計算
3. 因果寄与度 = 他の葉ノードを固定した場合の変動分
4. ツリー構造に沿って寄与度を積み上げる

### データアナリストagentへの委託時

委託プロンプトに以下を含める:

```
KPI定義の正本: docs/kpi_tree.yaml
分析対象KPI: [ノードID]
ルール: KPIの構成要素はツリーの葉ノード（kind: leaf）まで展開すること。
中間ノード（kind: derived）で分解を止めないこと。
```

---

## Phase 3: 検証

### チェックリスト

- [ ] 表示している構成KPIは、kpi_tree.yaml の葉ノードと一致するか
- [ ] 中間ノードで止めていないか（derived のまま表示していないか）
- [ ] 計算式の検算: 葉ノードの値から親ノードの値を再計算できるか
- [ ] children の参照先が全て kpi_tree.yaml に定義されているか
- [ ] 新しいKPIを追加した場合、kpi_tree.yaml を先に更新したか

### 検算コマンド（Python）

```python
import yaml
with open('docs/kpi_tree.yaml') as f:
    tree = yaml.safe_load(f)
# 全 children 参照が存在するか検証
for k, v in tree.items():
    if isinstance(v, dict) and 'children' in v:
        for child in v['children']:
            assert child in tree, f'{k} -> {child} NOT FOUND'
print('All references valid')
```

---

## 禁止事項

- KPIの計算式をコード内でハードコードして kpi_tree.yaml と乖離させること
- `PU × ARPPU` のように中間ノードで分解を止めること
- kpi_tree.yaml を参照せずにKPIの構成要素を推測で決めること
- データアナリストagentに委託する際にツリー定義を渡さないこと

---

## kpi_tree.yaml がまだないプロジェクトでの初回対応

1. 対象KPIをユーザーにヒアリング
2. 計算式を確認（ドキュメント、コード、ユーザーから）
3. docs/kpi_tree.yaml を作成
4. CLAUDE.md に「KPI定義の正本は docs/kpi_tree.yaml」を追記
5. 以降の実装はツリーを参照

---

## 発火条件

以下のいずれかに該当する場合、本スキルを自動参照する:

- KPIの表示・追加・変更に関する実装指示
- 「分解」「構成要素」「内訳」「ドリルダウン」「因果分析」に関する指示
- データアナリストagentへのKPI分析委託
- `docs/kpi_tree.yaml` が存在するプロジェクトでの数値関連変更
- 粗利・売上・コストの計算ロジック変更
