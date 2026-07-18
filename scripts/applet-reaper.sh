#!/bin/bash
# applet-reaper.sh — ChatCards/VaultJobs の applet 残留プロセスを掃除する見張り（30分毎 launchd）
#
# なぜ: 2026-07-17 21:18 の ChatCards 実行が処理完了後も親 applet が居座り（子なし・state S）、
#       launchd は同一ラベルの生存中は次の発火をスキップするため、以降12時間の毎時実行が全て
#       塞がれた（実障害）。通常実行は4〜6分なので、30分超の applet は異常とみなして kill する。
# 注意: TCC 保護領域には触れない（pgrep/kill のみ）ため bash 直実行で問題ない。
set -uo pipefail

LIMIT=1800  # 30分

for PID in $(pgrep -f "(ChatCards|VaultJobs)\.app/Contents/MacOS/applet" || true); do
  ET=$(ps -o etime= -p "$PID" 2>/dev/null | tr -d ' ') || continue
  [ -z "$ET" ] && continue
  # etime 形式 [[dd-]hh:]mm:ss を秒に変換
  SEC=$(echo "$ET" | awk -F'[-:]' '{
    if (NF==4) print $1*86400+$2*3600+$3*60+$4;
    else if (NF==3) print $1*3600+$2*60+$3;
    else print $1*60+$2 }')
  if [ "${SEC:-0}" -gt "$LIMIT" ]; then
    echo "[reaper] $(date '+%F %T') kill applet pid=$PID elapsed=${ET}"
    kill "$PID" 2>/dev/null
    sleep 5
    kill -0 "$PID" 2>/dev/null && kill -9 "$PID" 2>/dev/null
  fi
done
exit 0
