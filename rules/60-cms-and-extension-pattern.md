# ドメイン固有ルール

## CMS命名規約（ドメイン略称方式）

各CMSはドメインのサブドメイン部分から一意な識別子を導出する。

### CMS一覧

| 識別子 | 正式名 | ドメイン | 用途 | プロジェクト |
|--------|--------|---------|------|-------------|
| hayatomo | 原稿管理CMS | hayatomo2-dev.ura9.com/manuscript/ | 原稿登録・PPV管理 | chk, rohan |
| izumo-dev | izumo開発CMS | izumo-dev.uranai-gogo.com/admin/ | 小見出し・従量更新 | rohan |
| izumo-chk | izumo検証CMS | izumo-chk.uranai-gogo.com/admin/ | 本番同期確認 | rohan |

### 命名パターン

| コンテキスト | パターン | 例 |
|-------------|---------|-----|
| config定数 | `{CMS_ID}_CMS_{用途}` | `HAYATOMO_CMS_BASE_URL` |
| env var | `{CMS_ID}_CMS_{用途}` | `HAYATOMO_CMS_USER` |
| ログタグ | `[CMS:{cms_id}]` | `[CMS:hayatomo]` |
| ドキュメント | `{cms_id} CMS` | `hayatomo CMS` |
| 会話 | 文脈明確なら「CMS」可、複数文脈では識別子必須 | |

### 新CMS追加

1. サブドメインから識別子導出 → 上記テーブルに追加
2. config.pyに `{ID}_CMS_*` 定数追加
3. auto memory (`~/.claude/projects/*/memory/MEMORY.md`) に記載

### 禁止

- 汎用名 `CMS_*`（識別子プレフィックス必須）
- 識別子なしの `[CMS]` ログタグ（`[CMS:{id}]` を使う）

## エクステンションパターン強制ルール

### 自動検出

以下のマーカーファイルが CWD に存在する場合、そのプロジェクトは**エクステンションアーキテクチャ**を採用している：
- `config/extensions.yaml` → BE エクステンションプロジェクト
- `config/extensions.json` → FE エクステンションプロジェクト

**マーカーファイル検出時のみ、以下のルールが自動的に適用される。**
**マーカーファイルが存在しないプロジェクトには一切適用しない。**

### ハイブリッドプロジェクト（段階的移行中）

以下のプロジェクトはエクステンションアーキテクチャへ段階的に移行中。`backend/core/`にインフラを配置し、既存ルーターを順次extension化する:
- `~/Desktop/prm/rohan` — STEP 1-8パイプライン型ワークフロー。`backend/config/extensions.yaml`マーカーあり。`registration/`がextension化済み。他ルーターは従来方式維持

### 必須ルール

#### 1. 新機能は必ずエクステンションとして作成

新機能・新エンドポイント・新ページの追加時:
- **必須**: エクステンションディレクトリにエクステンションとして作成（パスはプロジェクト構造に依存: `src/extensions/` or `backend/routers/`）
- **禁止**: core/ディレクトリへの機能追加
- **禁止**: プロジェクトルート直下へのファイル配置（app.py, main.py を除く）
- 実装前に `be-extension-pattern` または `fe-extension-pattern` スキルを参照すること

#### 2. エクステンション間の直接依存禁止

- **禁止**: `from extensions.other_ext import ...` （他extの直接import）
- **必須**: ext間通信は EventBus (`event_bus.emit()` / `.on()`) またはプロジェクト固有の連携方式（API呼び出し等）のみ
- **禁止**: shared/ や core/ から extensions/ への import

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

- BE プロジェクト: `be-extension-pattern` スキル
- FE プロジェクト: `fe-extension-pattern` スキル
- FE+BE 連携: `fe-be-extension-coordination` スキル
