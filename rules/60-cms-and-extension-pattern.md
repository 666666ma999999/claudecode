# エクステンションパターンルール

<!-- CMS命名規約（hayatomo/izumo等）はプロジェクト固有の CLAUDE.md に配置すること -->

## エクステンションパターン強制ルール

### 自動検出

マーカーファイルによるプロジェクト判定とルール適用フローは `30-routing.md` の「エクステンション設計の分岐」を参照。

**マーカーファイル検出時のみ、以下のルールが自動的に適用される。**
**マーカーファイルが存在しないプロジェクトには一切適用しない。**

### ハイブリッドプロジェクト（段階的移行中）

エクステンションアーキテクチャへ段階的に移行中のプロジェクトでは、`backend/core/`にインフラを配置し、既存ルーターを順次extension化する。
具体的なプロジェクト固有情報（パス・移行状況）は各プロジェクトの CLAUDE.md に記載すること。

### 同一リポ vs 分離リポの判定

両マーカー（`extensions.yaml` + `extensions.json`）が検出された場合:

- **同一リポ**（FE/BEが同じリポジトリ内）: 本ファイルのハイブリッドルールを適用。`fe-be-extension-coordination` スキルは参照しない（分離リポ前提のため）。BE/FEそれぞれのスキル（`be-extension-pattern`, `fe-extension-pattern`）を個別適用する
- **分離リポ**（FE/BEが別リポジトリ）: `fe-be-extension-coordination` スキルを適用。APIコントラクト・デプロイ協調ルールに従う
- **判定不能**: 同一リポか分離リポか判断できない場合は、ユーザーに確認する

### 必須ルール（要点）

1. **新機能は必ず ext として作成** — `src/extensions/` or `backend/routers/` 配下。core/ への機能追加・ルート直下配置は禁止
2. **ext 間の直接依存禁止** — 同一プロセス内は EventBus 経由、FE-BE 間は API コントラクト経由。`shared/`・`core/` から `extensions/` への import も禁止（依存方向: ext → shared/core のみ）
3. **core/ 変更の制限** — HookPoint/Interface 追加は許可、既存コード変更はユーザー確認必須、機能追加は禁止（ext に作成）
4. **構造遵守** — BE: `__init__.py` に `manifest`、FE: `index.ts` から manifest export、ext 内に router/service/tests を自己完結、config に登録
5. **テスト隔離** — テストは ext 内 (`extensions/<name>/tests/`)、他 ext の fixture 不使用、ext 単体で実行可能

実装手順・コード例は `be-extension-pattern` / `fe-extension-pattern` スキルが正典。スキル選択フローは `30-routing.md` の「エクステンション設計の分岐」参照。
