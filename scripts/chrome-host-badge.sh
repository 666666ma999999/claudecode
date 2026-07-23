#!/bin/bash
# Chrome の各プロフィール表示名に【ホスト名】を刻む（2台Mac取り違え防止・2026-07-23）
# - 窓の右上アバター/新しい窓/プロフィール切替メニューに常時表示される「端末ローカルの名前」を書き換える
# - Chrome 終了中に実行すること（起動中は Chrome が上書きするため中断する）
# - 冪等: 既に【host】が付いていればスキップ。元に戻す: --undo
set -eu
HOST=$(hostname -s)
LS="$HOME/Library/Application Support/Google/Chrome/Local State"
[ -f "$LS" ] || { echo "Local State が見つかりません"; exit 1; }
if pgrep -x "Google Chrome" >/dev/null; then
  echo "❌ Chrome が起動中です。Chrome を完全終了（⌘Q）してから再実行してください"; exit 2
fi
cp "$LS" "$LS.bak-hostbadge"
python3 - "$LS" "$HOST" "${1:-}" <<'PY'
import json, sys
path, host, mode = sys.argv[1], sys.argv[2], sys.argv[3]
d = json.load(open(path, encoding="utf-8"))
info = d.get("profile", {}).get("info_cache", {})
tag = f"【{host}】"
changed = []
for k, meta in info.items():
    name = meta.get("name", "")
    if mode == "--undo":
        if name.startswith(tag):
            meta["name"] = name[len(tag):]; changed.append(k)
    else:
        if not name.startswith(tag):
            meta["name"] = tag + name; changed.append(k)
json.dump(d, open(path, "w", encoding="utf-8"), ensure_ascii=False)
print(f"更新: {changed or 'なし（適用済み）'}")
for k, meta in info.items():
    print(f"  {k}: {meta.get('name')}")
PY
echo "✅ 完了。Chrome を起動すると各窓の名前に ${HOST} が表示されます"
