# エクステンションパターンルール

<!-- CMS命名規約（hayatomo/izumo等）はプロジェクト固有の CLAUDE.md に配置すること -->

## エクステンションパターン強制ルール

### 自動検出

マーカーファイルによるプロジェクト判定とルール適用フローは `30-routing.md` の「エクステンション設計の分岐」を参照。

**マーカーファイル検出時のみ、以下のルールが自動的に適用される。**
**マーカーファイルが存在しないプロジェクトには一切適用しない。**

### ハイブリッドプロジェクト（段階的移行中）

以下のプロジェクトはエクステンションアーキテクチャへ段階的に移行中。`backend/core/`にインフラを配置し、既存ルーターを順次extension化する:
- `~/Desktop/prm/rohan` — STEP 1-8パイプライン型ワークフロー。`backend/config/extensions.yaml`マーカーあり。`registration/`がextension化済み。既存ルーターは従来方式のまま維持するが、**新規追加はextension化必須**

### 同一リポ vs 分離リポの判定

両マーカー（`extensions.yaml` + `extensions.json`）が検出された場合:

- **同一リポ**（FE/BEが同じリポジトリ内）: 本ファイルのハイブリッドルールを適用。`fe-be-extension-coordination` スキルは参照しない（分離リポ前提のため）。BE/FEそれぞれのスキル（`be-extension-pattern`, `fe-extension-pattern`）を個別適用する
- **分離リポ**（FE/BEが別リポジトリ）: `fe-be-extension-coordination` スキルを適用。APIコントラクト・デプロイ協調ルールに従う
- **判定不能**: 同一リポか分離リポか判断できない場合は、ユーザーに確認する

### 必須ルール

#### 1. 新機能は必ずエクステンションとして作成

新機能・新エンドポイント・新ページの追加時:
- **必須**: エクステンションディレクトリにエクステンションとして作成（パスはプロジェクト構造に依存: `src/extensions/` or `backend/routers/`）
- **禁止**: core/ディレクトリへの機能追加
- **禁止**: プロジェクトルート直下へのファイル配置（app.py, main.py を除く）
- 実装前に `be-extension-pattern` または `fe-extension-pattern` スキルを参照すること

#### 2. エクステンション間の直接依存禁止

- **禁止**: `from extensions.other_ext import ...` （他extの直接import）
- **同一プロセス内**（BE同士 or FE同士）: ext間通信は EventBus (`event_bus.emit()` / `.on()`) のみ
- **FE-BE間**: APIコントラクト（REST/GraphQL）経由。直接importは物理的に不可能なため対象外
- **禁止**: shared/ や core/ から extensions/ への import
- **例外**: 共有定数・型定義・インターフェースは `shared/` or `core/` に配置してよい。extensions/ からこれらを import するのは許可（依存方向: ext → shared/core のみ）

#### 3. core/ 変更の制限

`src/core/` を変更する場合:
- 新しい HookPoint の追加 → 許可（ただし既存の動作を変えない）
- 新しい Interface の追加 → 許可
- 既存コードの変更 → **ユーザーに確認が必要**
- 機能の追加 → **禁止**（extensions/ に作成すること）

#### 4. エクステンション構造の遵守

各エクステンションは以下を含むこと:
- BE: `__init__.py` に `manifest` (ExtensionManifest) を定義
- FE: `index.ts` に manifest を export
- ext 内に router/service/tests を自己完結させる
- `config/extensions.yaml` (BE) or `config/extensions.json` (FE) に登録

#### 5. テスト隔離

- テストは ext 内に配置 (`extensions/<name>/tests/`)
- 他の ext の fixture を使わない
- ext 単体で実行可能であること

### スキル参照

スキル選択フローは `30-routing.md` の「エクステンション設計の分岐」に従う。
