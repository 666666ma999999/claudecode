# エクステンションパターン強制ルール

## 自動検出

以下のマーカーファイルが CWD に存在する場合、そのプロジェクトは**エクステンションアーキテクチャ**を採用している：
- `config/extensions.yaml` → BE エクステンションプロジェクト
- `config/extensions.json` → FE エクステンションプロジェクト

**マーカーファイル検出時のみ、以下のルールが自動的に適用される。**
**マーカーファイルが存在しないプロジェクトには一切適用しない。**

### ハイブリッドプロジェクト（段階的移行中）

以下のプロジェクトはエクステンションアーキテクチャへ段階的に移行中。`backend/core/`にインフラを配置し、既存ルーターを順次extension化する:
- `~/Desktop/prm/rohan` — STEP 1-8パイプライン型ワークフロー。`backend/config/extensions.yaml`マーカーあり。`registration/`がextension化済み。他ルーターは従来方式維持

## 必須ルール

### 1. 新機能は必ずエクステンションとして作成

新機能・新エンドポイント・新ページの追加時:
- **必須**: `src/extensions/<feature-name>/` にエクステンションとして作成
- **禁止**: `src/core/` への機能追加
- **禁止**: `src/` 直下へのファイル配置（app.py, main.py を除く）
- 実装前に `be-extension-pattern` または `fe-extension-pattern` スキルを参照すること

### 2. エクステンション間の直接依存禁止

- **禁止**: `from extensions.other_ext import ...` （他extの直接import）
- **必須**: ext間通信は EventBus (`event_bus.emit()` / `.on()`) のみ
- **禁止**: shared/ や core/ から extensions/ への import

### 3. core/ 変更の制限

`src/core/` を変更する場合:
- 新しい HookPoint の追加 → 許可（ただし既存の動作を変えない）
- 新しい Interface の追加 → 許可
- 既存コードの変更 → **ユーザーに確認が必要**
- 機能の追加 → **禁止**（extensions/ に作成すること）

### 4. エクステンション構造の遵守

各エクステンションは以下を含むこと:
- BE: `__init__.py` に `manifest` (ExtensionManifest) を定義
- FE: `index.ts` に manifest を export
- ext 内に router/service/tests を自己完結させる
- `config/extensions.yaml` (BE) or `config/extensions.json` (FE) に登録

### 5. テスト隔離

- テストは ext 内に配置 (`extensions/<name>/tests/`)
- 他の ext の fixture を使わない
- ext 単体で実行可能であること

## スキル参照

- BE プロジェクト: `be-extension-pattern` スキル
- FE プロジェクト: `fe-extension-pattern` スキル
- FE+BE 連携: `fe-be-extension-coordination` スキル
