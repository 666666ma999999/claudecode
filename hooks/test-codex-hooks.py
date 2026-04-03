#!/usr/bin/env python3
"""Test codex review enforcement hooks"""
import subprocess, json, os

state = os.path.expanduser('~/.claude/state')
hooks = os.path.expanduser('~/.claude/hooks')
os.makedirs(state, exist_ok=True)

PENDING = f'{state}/implementation-checklist.pending'
DONE = f'{state}/codex-review.done'
TARGET_CMD = f'rm -f {PENDING}'

def cleanup():
    for f in [PENDING, DONE]:
        try: os.unlink(f)
        except FileNotFoundError: pass

def run_hook(script, inp_str):
    r = subprocess.run(
        ['bash', f'{hooks}/{script}'],
        input=inp_str, capture_output=True, text=True
    )
    return r.returncode, r.stdout.strip()

# Setup
cleanup()

# Test 1: Block when Codex not run
print('=== Test 1: Block without Codex ===')
with open(PENDING, 'w') as f: f.write('test')
inp = json.dumps({'tool_input': {'command': TARGET_CMD}})
code, out = run_hook('block-checklist-clear.sh', inp)
print(f'  exit: {code}, output: {out[:80]}')
assert code == 2, f'Expected 2 got {code}'
print('  PASS')

# Test 2: Allow when Codex was run
print('=== Test 2: Allow with Codex done ===')
with open(DONE, 'w') as f: f.write('done')
code, out = run_hook('block-checklist-clear.sh', inp)
print(f'  exit: {code}, output: {out[:80]}')
assert code == 0, f'Expected 0 got {code}'
assert not os.path.exists(DONE), 'codex-review.done should be cleaned up'
print('  PASS')

# Test 3: Unrelated command passes through
print('=== Test 3: Unrelated command passes ===')
inp2 = json.dumps({'tool_input': {'command': 'ls -la'}})
code, out = run_hook('block-checklist-clear.sh', inp2)
assert code == 0
print('  PASS')

# Test 4: Codex tracker records when pending
print('=== Test 4: Codex tracker records ===')
with open(PENDING, 'w') as f: f.write('test')
code, out = run_hook('codex-review-tracker.sh', '{}')
print(f'  exit: {code}, output: {out[:80]}')
assert os.path.exists(DONE), 'codex-review.done should exist'
print('  PASS')

# Test 5: Codex tracker skips when no pending
print('=== Test 5: Codex tracker skips without pending ===')
cleanup()
code, out = run_hook('codex-review-tracker.sh', '{}')
assert code == 0
assert not os.path.exists(DONE)
print('  PASS')

cleanup()
print('\nAll tests passed!')
