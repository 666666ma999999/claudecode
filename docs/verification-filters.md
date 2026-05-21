# 検証出力フィルタ（トークン節約）

重い検証は raw stdout を読まず、フィルタ + tail で要点取得する:

```bash
python3 verify.py > /tmp/v.log 2>&1; rg -n "FAIL|ERROR|Traceback|✗" /tmp/v.log | tail -20 || echo OK
docker compose logs backend --tail=200 2>&1 | rg -n "ERROR|CRITICAL|Traceback" | tail -20
pytest tests/ 2>&1 | rg -n "FAILED|ERROR|passed|failed" | tail -10
```

## 運用ルール

- 成功時は `echo OK` のみで完了報告
- 失敗詳細は二段階: `/tmp/v.log` を `sed -n '<L-5>,<L+20>p'` で局所読み
- 100 行超 raw stdout を `Bash` で受け取らない（context 浪費）
- 重い検証は `Agent` (subagent) に隔離
