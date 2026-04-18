---
name: organize-desktop
description: デスクトップのファイル/フォルダを自動分類・整理するスキル。日本語ファイル名・業務データ対応。分析→計画→確認→実行→要約の5ステップで安全に整理。
allowed-tools: "Bash Read Glob Grep"
compatibility: "requires: macOS (trash command recommended)"
license: proprietary
metadata:
  author: masaaki-nagasawa
  version: 1.0.0
  category: file-management
  tags: [desktop, organize, cleanup, file-management]
---

# Desktop Organize スキル

## 概要

デスクトップに散在するファイル/フォルダを安全に自動分類・整理する。
日本語ファイル名・業務固有データ（原稿・教師データ・仕様書）に対応。

## ワークフロー（5ステップ）

### STEP 1: Analyze（分析）

デスクトップの現状を把握する。

```bash
# 1. ファイル/フォルダ一覧取得（隠しファイル除外）
ls -1 ~/Desktop/

# 2. ファイルタイプ別カウント
find ~/Desktop -maxdepth 1 -type f | sed 's/.*\.//' | sort | uniq -c | sort -rn

# 3. gitリポジトリ検出（移動禁止対象の特定）
find ~/Desktop -maxdepth 2 -name ".git" -type d 2>/dev/null

# 4. 展開済みzip検出（zipとフォルダが両方存在するケース）
for z in ~/Desktop/*.zip; do
  base=$(basename "$z" .zip)
  [ -d ~/Desktop/"$base" ] && echo "EXPANDED: $base (.zip + folder both exist)"
done

# 5. バージョン付きファイル検出
ls ~/Desktop/ | grep -E '[-_]v[0-9]+|[-_]V[0-9]+|\([ 0-9]+\)'
```

出力を分析し、以下を特定する:
- 除外対象（後述の除外ルール参照）
- 整理対象ファイル数
- 展開済みzipの有無
- バージョン付きファイルの有無

### STEP 2: Plan（計画）

分析結果に基づき、移動計画を作成する。

**分類先フォルダ:**

| フォルダ | 対象 | 判定基準 |
|---------|------|---------|
| `images/` | 画像ファイル | `.jpg`, `.jpeg`, `.png`, `.gif`, `.webp`, `.svg`, `.ico`, `.heic` |
| `images/screenshots/` | スクリーンショット | ファイル名に「スクリーンショット」or「Screenshot」を含む画像 |
| `docs/` | ドキュメント | `.md`, `.pdf`, `.docx`, `.xlsx`, `.pptx`, `.pages`, `.numbers`, `.key` |
| `docs/specs/` | 仕様書 | ファイル名に「仕様」「spec」を含むドキュメント |
| `data/` | データファイル | `.csv`, `.json`, `.xml`, `.yaml`, `.yml`, `.log`, `.sql`, `.tsv` |
| `data/training/` | 教師データ | ファイル名に「教師データ」を含むファイル/フォルダ |
| `data/manuscripts/` | 原稿データ | ファイル名に「原稿」「全原稿」を含むファイル |
| `videos/` | 動画ファイル | `.mp4`, `.mov`, `.avi`, `.mkv`, `.webm` |
| `config/` | 設定ファイル | `.ini`, `.conf`, `.cfg`, `.env`, `.toml` |
| `archive/` | アーカイブ | `.zip`, `.tar`, `.gz`, `.7z`, `.rar`（展開済みzipの退避先にも使用） |
| `business/` | 業務フォルダ | 上記に該当しないフォルダ（業務関連と判断されるもの） |
| `business/receipts/` | 領収書・経費 | ファイル名に「receipt」「領収」を含むファイル/フォルダ |

**`.txt` ファイルの振り分けロジック:**
- ファイル名に「原稿」「全原稿」→ `data/manuscripts/`
- ファイル名に「メニュー」「一覧」「リスト」「CSV」→ `data/`
- ファイル名に「仕様」「spec」「設計」→ `docs/specs/`
- ファイル名に「メモ」「note」「TODO」→ `docs/`
- 上記に該当しない → `docs/`（デフォルト）

**バージョン付きファイルの整理:**
- 同一ベース名のファイルを検出（例: `spec-v324.md`, `spec-v330.md`）
- 最新バージョンのみ分類先に移動
- 旧バージョンは `archive/old-versions/` に移動
- **判定に迷う場合はユーザーに確認**

**展開済みzipの処理:**
- zipファイルと同名フォルダが両方存在する場合:
  1. `trash` コマンドが使用可能 → zipファイルを `trash` で削除
  2. `trash` 未インストール → zipファイルを `archive/` に移動
- フォルダは適切な分類先に移動

計画を一覧表形式でユーザーに提示する:

```
## 移動計画

| # | ファイル/フォルダ | 移動先 | 備考 |
|---|------------------|--------|------|
| 1 | example.jpg | images/ | 画像 |
| 2 | スクリーンショット 2026-03-02... | images/screenshots/ | SS |
| ...

## 削除計画（展開済みzip）
| # | ファイル | 方法 | 備考 |
|---|---------|------|------|
| 1 | 教師データ0227.zip | trash | フォルダ展開済み |

## バージョン整理
| # | 旧ファイル | 最新ファイル | 旧ファイル移動先 |
|---|-----------|-------------|----------------|
| 1 | spec-v324.md | spec-v330.md | archive/old-versions/ |

## 除外（操作しない）
- prm/ （プロジェクトディレクトリ）
- lotonum-sp/ （プロジェクトディレクトリ）
- ...
```

### STEP 3: Confirm（確認）

**ユーザーに計画を提示し、承認を得る。承認前に一切のファイル操作を行わない。**

確認事項:
- 移動計画全体の承認
- バージョン判定が正しいか
- 削除対象の確認
- 追加の除外対象がないか

### STEP 4: Execute（実行）

承認後、以下の順序で実行する。

**4-1. ロールバックスクリプト生成**

実行前に逆操作スクリプトを生成し保存:

```bash
# ロールバックスクリプトを生成
cat > ~/Desktop/.undo-organize.sh << 'SCRIPT_EOF'
#!/bin/bash
# Generated: $(date)
# Undo script for desktop organization
set -e

# 逆操作コマンドをここに列挙（mv の逆）
# mv ~/Desktop/images/example.jpg ~/Desktop/example.jpg
# ...

echo "Undo complete."
SCRIPT_EOF
chmod +x ~/Desktop/.undo-organize.sh
```

**4-2. フォルダ作成**

```bash
mkdir -p ~/Desktop/{images/screenshots,docs/specs,data/{training,manuscripts},videos,config,archive/old-versions,business/receipts}
```

**4-3. ファイル移動**

承認された計画に従い、`mv` コマンドで移動。1ファイルずつ実行。

**4-4. 展開済みzip処理**

```bash
# trash が使える場合
which trash && trash ~/Desktop/example.zip

# trash がない場合
mv ~/Desktop/example.zip ~/Desktop/archive/
```

**4-5. 空フォルダの確認**

移動後、作成したフォルダが空でないか確認。空のフォルダは削除。

### STEP 5: Summarize（要約）

実行結果を報告する:

```
## 整理結果

- 移動: X ファイル/フォルダ
- 削除（trash）: X ファイル
- アーカイブ退避: X ファイル
- バージョン整理: X セット
- 除外: X 項目
- ロールバック: ~/Desktop/.undo-organize.sh

### フォルダ構成（整理後）
~/Desktop/
├── images/ (X files)
│   └── screenshots/ (X files)
├── docs/ (X files)
│   └── specs/ (X files)
├── data/ (X files)
│   ├── training/ (X files)
│   └── manuscripts/ (X files)
├── ...
└── prm/ (除外)
```

## 除外ルール

以下は**一切操作しない**:

| 除外対象 | 理由 |
|---------|------|
| `prm/` | プロジェクトディレクトリ |
| `lotonum-sp/` | プロジェクトディレクトリ |
| `ref/` | 参照用ディレクトリ |
| `bk/` | バックアップディレクトリ |
| `.git` を含むディレクトリ | gitリポジトリ（検出時は即停止して報告） |
| `.DS_Store` | macOSシステムファイル |
| `.undo-organize.sh` | ロールバックスクリプト |
| `.localized` | macOSシステムファイル |

## 安全ルール

### 確認不要（自動実行可）
- `mkdir -p`（フォルダ作成）
- 承認済み計画内の `mv`（ファイル移動）
- `ls`, `find`, `file` 等の読み取り専用コマンド
- ロールバックスクリプトの生成

### 確認必須（ユーザー承認を待つ）
- **全ての削除操作**（`trash`, `rm`）
- 計画外のファイル移動
- バージョン判定（どれが最新かの確認）
- 不明なフォルダの分類先決定

### 即停止（エラー報告してユーザー指示を待つ）
- `mv` でエラー発生
- 移動先に同名ファイルが既に存在（上書き禁止）
- gitリポジトリを検出（除外リスト外）
- パーミッションエラー

## `--dry-run` モード

`/organize-desktop --dry-run` で実行した場合:
- STEP 1（Analyze）と STEP 2（Plan）のみ実行
- STEP 3 で計画を表示して終了（実行しない）
- 「この計画で実行しますか？」と確認して待機

## 注意事項

- ファイル名にスペースや特殊文字を含む場合、必ずダブルクォートで囲む
- 大量ファイル（50+）の場合はバッチ分割（10ファイル/バッチ）して中間報告
- `mv` は `-n` オプション（上書き禁止）を使用: `mv -n "source" "dest/"`
- 整理対象は `~/Desktop/` 直下のみ（サブディレクトリ内は再帰しない）
