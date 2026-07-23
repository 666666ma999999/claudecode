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

# ── 常時見える目印: 窓の色（ポリシー・端末ローカル・Google同期されない） ──
# masa-2=青 / それ以外(MASA等)=赤。--undo で削除。
if [ "${1:-}" = "--undo" ]; then
  defaults delete com.google.Chrome BrowserThemeColor 2>/dev/null || true
  defaults delete com.google.Chrome EnterpriseCustomLabel 2>/dev/null || true
  echo "窓の色ポリシーを削除しました"
else
  case "$HOST" in
    masa-2*) COLOR="#1a73e8";;   # 青
    *)       COLOR="#d93025";;   # 赤
  esac
  defaults write com.google.Chrome BrowserThemeColor -string "$COLOR"
  defaults write com.google.Chrome EnterpriseCustomLabel -string "$HOST"
  echo "窓の色: $COLOR ($HOST) を設定。Chrome 再起動後に反映"
fi
