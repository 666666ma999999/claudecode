# ~/.claude/hooks/

Claude Code フック実装のディレクトリ。

## 構造

| ディレクトリ | 意味 | 復活手順 |
|---|---|---|
| `hooks/*.sh` `hooks/*.py` | **active**: settings.json から実行される現役フック（40 本） | — |
| `hooks/_*.sh` `hooks/_*.py` | **infrastructure**: フック自体ではなく支援スクリプト（`_profile-wrapper.sh` 等） | — |
| `hooks/_dormant/` | **休眠**: 過去登録解除した便利系。settings.json に再登録すれば復活 | settings.json に command path を再追加 |
| `hooks/_archive/` | **退役**: 実害があり再採用しない。削除候補（要レビュー） | 復活非推奨 |

## 命名規則

- `_` (アンダースコア) prefix = フック以外（ラッパー / アナライザー / archive / dormant）
- それ以外の `*.sh` / `*.py` = フック実装

## settings.json と物理ファイルの整合性チェック

```bash
python3 << 'PY'
import json, re
from pathlib import Path
d = json.load(open(Path.home() / ".claude/settings.json"))
referenced = set()
for arr in d["hooks"].values():
    for e in arr:
        for h in e.get("hooks", []):
            for m in re.findall(r'~/\.claude/hooks/([\w\-\.]+\.(?:sh|py))', h.get("command", "")):
                referenced.add(m)
physical = {p.name for p in (Path.home() / ".claude/hooks").iterdir() if p.is_file() and p.suffix in (".sh", ".py")}
print("registered_but_missing:", referenced - physical)
print("physical_but_unregistered:", physical - referenced)
PY
```

両方空ならクリーン。前者があればフック実行が壊れている、後者は orphan（要分類）。

## 履歴

- 2026-04-25: Phase 1A/1B（hook 削減 54→41）の後、orphan 12 本を分類
- `_archive/`: Phase 1A 由来 3 本（block-checklist-clear / filter-test-output / memory-warn）
- `_dormant/`: Phase 1B 由来 8 本（auto-git-pull-pre/pull / task-progress-check / detect-extension-project / improvement-ingest-check / improvement-capture-prompt / promote-lessons / sessionend-summary）
