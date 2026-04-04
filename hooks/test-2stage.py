#!/usr/bin/env python3
"""Test 2-stage Codex review tracking"""
import subprocess, os

state = os.path.expanduser('~/.claude/state')
hooks = os.path.expanduser('~/.claude/hooks')
PENDING = f'{state}/implementation-checklist.pending'
COUNT = f'{state}/codex-review.count'
DONE = f'{state}/codex-review.done'
TARGET_CMD = f'rm -f {PENDING}'

def cleanup():
    for f in [PENDING, COUNT, DONE]:
        try: os.unlink(f)
        except FileNotFoundError: pass

def run(script, inp='{}'):
    r = subprocess.run(['bash', f'{hooks}/{script}'], input=inp, capture_output=True, text=True)
    return r.returncode, r.stdout.strip()

import json
rm_inp = json.dumps({'tool_input': {'command': TARGET_CMD}})

cleanup()

# Test 1: Stage 1 only — .done should NOT exist
print('=== Test 1: Stage 1 only ===')
with open(PENDING, 'w') as f: f.write('test')
code, out = run('codex-review-tracker.sh')
print(f'  {out}')
assert os.path.exists(COUNT), 'count file should exist'
assert open(COUNT).read().strip() == '1', f'count should be 1'
assert not os.path.exists(DONE), '.done should NOT exist after Stage 1'
print('  PASS')

# Test 2: Block pending removal after Stage 1 only
print('=== Test 2: Block after Stage 1 ===')
code, out = run('block-checklist-clear.sh', rm_inp)
assert code == 2, f'Expected block (2), got {code}'
print('  PASS')

# Test 3: Stage 2 — .done should exist
print('=== Test 3: Stage 2 completes ===')
code, out = run('codex-review-tracker.sh')
print(f'  {out}')
assert open(COUNT).read().strip() == '2', 'count should be 2'
assert os.path.exists(DONE), '.done should exist after Stage 2'
print('  PASS')

# Test 4: Allow pending removal after both stages
print('=== Test 4: Allow after both stages ===')
code, out = run('block-checklist-clear.sh', rm_inp)
assert code == 0, f'Expected allow (0), got {code}'
assert not os.path.exists(DONE), '.done should be cleaned up'
assert not os.path.exists(COUNT), 'count should be cleaned up'
print('  PASS')

# Test 5: Extra Codex calls after .done don't re-increment
print('=== Test 5: Extra calls after .done ===')
with open(PENDING, 'w') as f: f.write('test')
run('codex-review-tracker.sh')  # Stage 1
run('codex-review-tracker.sh')  # Stage 2 -> .done
run('codex-review-tracker.sh')  # Extra call
assert open(COUNT).read().strip() == '2', 'count should stay 2'
print('  PASS')

# Test 6: No tracking without pending
print('=== Test 6: No tracking without pending ===')
cleanup()
run('codex-review-tracker.sh')
assert not os.path.exists(COUNT), 'count should not exist without pending'
assert not os.path.exists(DONE), '.done should not exist without pending'
print('  PASS')

cleanup()
print('\nAll 2-stage tests passed!')
