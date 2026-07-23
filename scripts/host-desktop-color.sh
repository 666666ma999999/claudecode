#!/bin/bash
# デスクトップを単色にして「今どのMacか」を一目で分かる目印にする（2台取り違え防止・2026-07-23）
# masa-2 = 青 / それ以外(MASA等) = 赤。 --undo で標準壁紙に戻す。依存ゼロ(純正python)。
set -eu
HOST=$(hostname -s)
IMG="$HOME/.claude/state/host-wallpaper.png"
if [ "${1:-}" = "--undo" ]; then
  DEF="/System/Library/CoreServices/DefaultDesktop.heic"
  osascript -e "tell application \"System Events\" to tell every desktop to set picture to \"$DEF\"" 2>/dev/null
  echo "標準壁紙に戻しました"; exit 0
fi
case "$HOST" in
  masa-2*) R=26; G=115; B=232; NAME="青";;   # #1a73e8
  *)       R=217; G=48; B=37;  NAME="赤";;   # #d93025
esac
python3 - "$IMG" "$R" "$G" "$B" <<'PY'
import sys, zlib, struct
path=sys.argv[1]; R,G,B=int(sys.argv[2]),int(sys.argv[3]),int(sys.argv[4])
W,H=256,160
raw=(b'\x00'+bytes([R,G,B])*W)*H
def ch(t,d):
    c=t+d; return struct.pack(">I",len(d))+c+struct.pack(">I",zlib.crc32(c)&0xffffffff)
png=b'\x89PNG\r\n\x1a\n'+ch(b'IHDR',struct.pack(">IIBBBBB",W,H,8,2,0,0,0))+ch(b'IDAT',zlib.compress(raw,9))+ch(b'IEND',b'')
open(path,"wb").write(png)
PY
osascript -e "tell application \"System Events\" to tell every desktop to set picture to \"$IMG\"" 2>/dev/null
echo "デスクトップを${NAME}にしました（$HOST）"
