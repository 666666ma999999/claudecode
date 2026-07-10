import os, json, glob, time
from collections import Counter

results = []
for fn in glob.glob('/Users/masaaki_nagasawa/.claude/projects/**/*.jsonl', recursive=True):
    mtime = os.path.getmtime(fn)
    if time.time() - mtime > 30*86400:
        continue
    try:
        id_to_name = {}
        lines = []
        with open(fn) as f:
            for line in f:
                try:
                    obj = json.loads(line)
                except Exception:
                    continue
                lines.append(obj)
        for obj in lines:
            msg = obj.get('message', {})
            content = msg.get('content', [])
            if not isinstance(content, list):
                continue
            for c in content:
                if isinstance(c, dict) and c.get('type') == 'tool_use':
                    id_to_name[c.get('id')] = c.get('name', '')
        for obj in lines:
            msg = obj.get('message', {})
            content = msg.get('content', [])
            if not isinstance(content, list):
                continue
            for c in content:
                if isinstance(c, dict) and c.get('type') == 'tool_result':
                    tool_id = c.get('tool_use_id', '')
                    name = id_to_name.get(tool_id, '')
                    if 'codex' not in name:
                        continue
                    tc = c.get('content', '')
                    text = ''
                    if isinstance(tc, list):
                        for it in tc:
                            if isinstance(it, dict):
                                text += it.get('text', '') + '\n'
                    elif isinstance(tc, str):
                        text = tc
                    lower = text.lower()
                    markers = ['usage limit', 'rate limit', 'quota', '429', 'plan limit',
                               'daily limit', 'weekly limit', 'chatgpt plus', 'chatgpt pro',
                               'you have exceeded', 'reached your limit', 'i ran out', 'try again later',
                               'upgrade your plan']
                    for m in markers:
                        if m in lower:
                            ts = obj.get('timestamp', '?')
                            snippet = text[:400].replace('\n', ' ')
                            results.append((ts, m, fn.split('/')[-2], snippet))
                            break
    except Exception:
        pass

results.sort()
print(f"TOTAL real codex rate-limit tool_results (30d): {len(results)}")
print()
daily = Counter(r[0][:10] for r in results)
for d in sorted(daily):
    print(f"  {d}: {daily[d]}")
print()
print("=== LAST 5 actual errors ===")
for r in results[-5:]:
    print(f"[{r[0]}] marker={r[1]}")
    print(f"  project={r[2]}")
    print(f"  text={r[3][:350]}")
    print()
