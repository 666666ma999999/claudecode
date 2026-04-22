---
name: fe-extension-pattern
description: |
  FEプロジェクトでエクステンションパターン（プラグインアーキテクチャ）に従った実装を指導するスキル。
  新エクステンション作成、ページ追加、ウィジェット追加、MountPoint実装、Zustandストア設計、
  EventBusによるext間通信のガイド。FE新機能追加・ページ追加・ウィジェット追加時に使用。
  キーワード: エクステンション作成, ページ追加, ウィジェット追加, FEアーキテクチャ, MountPoint, EventBus, Zustand
  NOT for: バックエンド実装, インフラ構成, DB設計, 既存バグ修正（アーキテクチャ変更を伴わない場合）
allowed-tools: [Read, Glob, Grep]
---

# FE エクステンションパターン ガイド

## Read This First

このファイルにはアーキテクチャ概要・10のルール・チェックリストを記載。
実装コードが必要なときのみ references/ を参照。

- 新エクステンション作成（Step 1-9のコード例） → `references/step-by-step-creation.md`
- Manifest詳細・MountPoint・ページ・Zustand・EventBusパターン → `references/implementation-patterns.md`

---

## 1. アーキテクチャ概要

エクステンションパターンは、FEアプリケーションをプラグイン形式で拡張するアーキテクチャ。

```
src/
├── core/           # フレームワーク（変更しない）
│   ├── types/      # 共通型定義
│   ├── registry/   # エクステンション登録
│   ├── services/   # コアサービス
│   ├── providers/  # Reactプロバイダー
│   ├── components/ # コアコンポーネント
│   └── index.ts    # パブリックAPI
├── shared/         # 共有UIコンポーネント
│   └── components/ # Button, Card etc.
├── extensions/     # 各エクステンション（ここに機能を追加）
│   ├── ext-a/
│   └── ext-b/
├── app/            # Next.js App Router
│   ├── layout.tsx
│   ├── (core)/     # コアページ
│   └── (extensions)/ # エクステンションルーティング
└── config/
    └── extensions.json  # 有効なエクステンション一覧
```

### 設計原則

- **Core は変更しない**: `src/core/` はフレームワーク。機能追加は `src/extensions/` のみ
- **隔離**: エクステンション同士は直接importしない
- **プラグイン**: enable/disable で機能の ON/OFF が可能
- **依存方向**: `extensions → core` / `extensions → shared` のみ許可

---

## 2. 新エクステンション作成手順（概要）

9ステップで作成。詳細コードは `references/step-by-step-creation.md` を参照。

1. **ディレクトリ作成** — `src/extensions/{ext-name}/{types,components,hooks,pages,widgets,store}`
2. **型定義** — `types/` に Entity interface
3. **ストア** — `store/` に Zustand ストア（ext内に閉じる）
4. **フック** — `hooks/` にデータ取得カスタムフック
5. **コンポーネント** — `components/` にUI部品
6. **ページ** — `pages/` に `default export`（lazy import対応）
7. **ウィジェット** — `widgets/` に MountPoint対応コンポーネント
8. **マニフェスト** — `index.ts` に ExtensionManifest
9. **登録** — `config/extensions.json` に追加 + codegen実行

---

## 3. 10のルール（チートシート）

| # | ルール | 違反例 | 正解 |
|---|--------|--------|------|
| 1 | `src/core/` は変更しない | core に新しい型を追加 | ext 内に型を定義 |
| 2 | ext 間の直接 import 禁止 | `import { X } from '../other-ext/...'` | EventBus で通信 |
| 3 | 依存方向: ext → core, ext → shared のみ | shared から ext を import | shared は ext を知らない |
| 4 | 各 ext に `index.ts` (manifest) 必須 | manifest なしの ext | ExtensionManifest を export |
| 5 | ページは `pages/` に配置、lazy import | 直接 import でバンドル肥大化 | `() => import('./pages/...')` |
| 6 | ウィジェットは `widgets/` に配置 | コンポーネントに MountPoint ロジック混在 | MountPointProps を受け取る widget |
| 7 | ストアは ext 内に閉じる | グローバルストアに ext のステートを追加 | ext 内 Zustand ストア |
| 8 | ext 間通信は EventBus のみ | 共有グローバル変数 | `services.events.emit()` / `.on()` |
| 9 | `config/extensions.json` で ON/OFF | ハードコードされた import | enabled 配列から削除で無効化 |
| 10 | ESLint zones で隔離を強制 | zone 設定なしでレビュー頼み | `generate-eslint-zones.ts` 実行 |

---

## 4. 検証チェックリスト

### 隔離性チェック

- [ ] `src/extensions/{ext}/` 内からの import が `@/core`, `@/shared/*`, 自ext内のみ
- [ ] 他の ext ディレクトリからの import がない
- [ ] `src/core/` を変更していない
- [ ] ESLint zones で違反なし（`npx ts-node scripts/validate-extension-isolation.ts`）

### Enable/Disable チェック

- [ ] `config/extensions.json` から ext を除外してもビルドエラーにならない
- [ ] 他の ext が正常に動作する（依存していない）
- [ ] ナビゲーション、ルーティング、MountPoint が消える

### マニフェストチェック

- [ ] `id` がユニーク
- [ ] `navigation` の `path` が他と衝突しない
- [ ] `routes` の `path` が他と衝突しない
- [ ] `mountPoints` の `mountPoint` が存在する MountPoint 名
- [ ] すべてのコンポーネントが lazy import (`() => import(...)`)

### コード品質チェック

- [ ] `default export` が pages/ と widgets/ の全ファイルにある
- [ ] カスタムフックがデータ取得を担当
- [ ] Loading / Error 状態のハンドリングがある
- [ ] TypeScript strict モードでエラーなし
