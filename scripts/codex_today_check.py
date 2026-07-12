import os, json, glob, time
from collections import Counter

total_calls = 0
success = 0
errors = []
for fn in glob.glob('/Users/masaaki_nagasawa/.claude/projects/**/*.jsonl', recursive=True):
    mtime = os.path.getmtime(fn)
    if time.time() - mtime > 3*86400:
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
            ts = obj.get('timestamp', '')
            if not ts.startswith('2026-04-23') and not ts.startswith('2026-04-24'):
                continue
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
                    total_calls += 1
                    tc = c.get('content', '')
                    text = ''
                    if isinstance(tc, list):
                        for it in tc:
                            if isinstance(it, dict):
                                text += it.get('text', '') + '\n'
                    elif isinstance(tc, str):
                        text = tc
                    lower = text.lower()
                    if 'quota exceeded' in lower or 'rate limit' in lower or '429' in lower or 'usage limit' in lower:
                        errors.append((ts, text[:200].replace('\n',' ')))
                    else:
                        success += 1
    except Exception:
        pass

print(f"Codex calls 2026-04-23 ~ 2026-04-24: {total_calls}")
print(f"  Success (no quota/rate): {success}")
print(f"  Errors: {len(errors)}")
print()
print("=== By day ===")
by_day = Counter()
err_day = Counter()
for fn in glob.glob('/Users/masaaki_nagasawa/.claude/projects/**/*.jsonl', recursive=True):
    mtime = os.path.getmtime(fn)
    if time.time() - mtime > 3*86400:
        continue
    try:
        id_to_name = {}
        lines = []
        with open(fn) as f:
            for line in f:
                try: obj = json.loads(line)
                except: continue
                lines.append(obj)
        for obj in lines:
            msg = obj.get('message', {})
            content = msg.get('content', [])
            if not isinstance(content, list): continue
            for c in content:
                if isinstance(c, dict) and c.get('type') == 'tool_use':
                    id_to_name[c.get('id')] = c.get('name','')
        for obj in lines:
            ts = obj.get('timestamp','')
            day = ts[:10]
            if day not in ('2026-04-23','2026-04-24'): continue
            msg = obj.get('message', {})
            content = msg.get('content', [])
            if not isinstance(content, list): continue
            for c in content:
                if isinstance(c, dict) and c.get('type') == 'tool_result':
                    tool_id = c.get('tool_use_id','')
                    name = id_to_name.get(tool_id,'')
                    if 'codex' not in name: continue
                    by_day[day] += 1
                    tc = c.get('content','')
                    text = ''
                    if isinstance(tc, list):
                        for it in tc:
                            if isinstance(it, dict):
                                text += it.get('text','') + '\n'
                    elif isinstance(tc, str): text = tc
                    lower = text.lower()
                    if 'quota exceeded' in lower or 'rate limit' in lower or '429' in lower or 'usage limit' in lower:
                        err_day[day] += 1
    except: pass

for d in sorted(by_day):
    print(f"  {d}: total={by_day[d]}, errors={err_day[d]}, success={by_day[d]-err_day[d]}")

print()
print("=== All error timestamps on 2026-04-23/24 ===")
for ts, txt in errors:
    print(f"  {ts}: {txt[:120]}")
