#!/bin/bash
# TaskCompleted hook: X投稿バズ素材を自動検出し /capture-improvement を提案する
# 7つのバズパターンを検出。セッション中1回のみ発火。
#
# バズ型:
#   1. 数値Before/After  2. 失敗→復旧  3. TIL  4. Builder's Diary
#   5. ツール発見  6. Vibe Coding  7. 逆張り

set -uo pipefail

STATE_DIR="$HOME/.claude/state"
PENDING_FILE="$STATE_DIR/implementation-checklist.pending"
DONE_FILE="$STATE_DIR/improvement-capture.done"

cat > /dev/null

# Guards
[ -f "$DONE_FILE" ] && exit 0
[ ! -f "$PENDING_FILE" ] || [ ! -s "$PENDING_FILE" ] && exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

FILE_LIST=$(tail -n +2 "$PENDING_FILE" 2>/dev/null || true)
[ -z "$FILE_LIST" ] && exit 0

RESULT=$(FILELIST="$FILE_LIST" python3 -c "
import os, subprocess, re
from datetime import datetime

raw = os.environ.get('FILELIST', '')
files = [l.strip() for l in raw.split('\n') if l.strip()]
if not files:
    print('SKIP'); raise SystemExit(0)

def run(cmd, t=3):
    try: return subprocess.check_output(cmd, stderr=subprocess.DEVNULL, timeout=t).decode()
    except Exception: return ''

# Git data prefetch
G = {
    'ds': run(['git','diff','--stat','HEAD~5..HEAD']),
    'dn': run(['git','diff','--name-status','HEAD~5..HEAD']),
    'l5': run(['git','log','--oneline','-5']),
    'l10': run(['git','log','--oneline','-10']),
    'ld': run(['git','log','--format=%aI','-10']),
    'rf': run(['git','reflog','--oneline','-20']),
}

sigs = []  # (type, label, detail, conf, tip)

# === Signal 1: numeric_improvement ===
summary = G['ds'].strip().split('\n')[-1] if G['ds'].strip() else ''
ins = dels = 0
for p in summary.split(','):
    p = p.strip()
    if 'insertion' in p: ins = int(p.split()[0])
    elif 'deletion' in p: dels = int(p.split()[0])
net = dels - ins
if dels > 50 and net > 0:
    c = min(0.9, 0.5 + net / 500)
    sigs.append(('numeric', '\u6570\u5024Before/After', f'{dels}\u884c\u524a\u9664\uff08\u7d14\u6e1b{net}\u884c\uff09', c,
                 f'\u300c{net}\u884c\u524a\u6e1b\u300d\u306f\u6570\u5024\u30a4\u30f3\u30d1\u30af\u30c8\u304c\u5f37\u3044\u8a18\u4e8b\u7d20\u6750\u3067\u3059'))
m = re.search(r'(\d+\.?\d*)\s*(?:\u2192|->)\s*(\d+\.?\d*)', G['l5'])
if m:
    sigs.append(('numeric', '\u6570\u5024Before/After', f'Before\u2192After: {m.group(0)}', 0.85,
                 f'\u300c{m.group(0)}\u300d\u306e\u6570\u5024\u5909\u5316\u306fX\u6295\u7a3f\u3067\u6700\u3082\u3044\u3044\u306d\u304c\u4ed8\u304f\u30d1\u30bf\u30fc\u30f3\u3067\u3059'))

# === Signal 2: failure_recovery ===
lines = G['rf'].strip().split('\n')
rv = ['reset:', 'rebase', 'checkout:', 'revert']
fv = ''
for line in lines:
    lo = line.lower()
    if not fv:
        for v in rv:
            if v in lo: fv = v.rstrip(':'); break
    elif 'commit' in lo:
        sigs.append(('failure', '\u5931\u6557\u2192\u5fa9\u65e7\u30b9\u30c8\u30fc\u30ea\u30fc', f'git {fv}\u5f8c\u306b\u6b63\u5e38\u5fa9\u5e30', 0.7,
                     f'\u300c{fv}\u3067\u623b\u3057\u305f\u2192\u5fa9\u65e7\u3057\u305f\u300d\u30b9\u30c8\u30fc\u30ea\u30fc\u306f\u5171\u611f\u3092\u547c\u3076\u8a18\u4e8b\u7d20\u6750\u3067\u3059'))
        break
log10 = G['l10'].lower()
if re.search(r'(broke|\u58ca|bug|\u969c\u5bb3|error|crash|panic)', log10) and re.search(r'(fix|\u4fee\u6b63|hotfix|revert|recover)', log10):
    sigs.append(('failure', '\u5931\u6557\u2192\u5fa9\u65e7\u30b9\u30c8\u30fc\u30ea\u30fc', '\u30b3\u30df\u30c3\u30c8\u5c65\u6b74\u306b\u969c\u5bb3\u2192\u4fee\u6b63\u30d1\u30bf\u30fc\u30f3', 0.65,
                 '\u300c\u58ca\u3057\u305f\u2192\u76f4\u3057\u305f\u300d\u30b9\u30c8\u30fc\u30ea\u30fc\u306f\u30a8\u30f3\u30b8\u30cb\u30a2\u306e\u5171\u611f\u3092\u6700\u3082\u96c6\u3081\u307e\u3059'))

# === Signal 3: til_discovery ===
til_kw = ['til','learn','\u767a\u898b','\u77e5\u3089\u306a\u304b\u3063\u305f','\u521d\u3081\u3066','turns out','discovered']
l5lo = G['l5'].lower()
hits = [k for k in til_kw if k in l5lo]
if hits:
    sigs.append(('til', 'TIL\uff08Today I Learned\uff09', f'\u5b66\u3073\u30ad\u30fc\u30ef\u30fc\u30c9: {\",\".join(hits)}', 0.6,
                 f'\u300c{hits[0]}\u300d\u306fTIL\u8a18\u4e8b\u306e\u7d20\u6750\u3002\u77ed\u3044\u6295\u7a3f\u3067\u3082\u3044\u3044\u306d\u304c\u4ed8\u304d\u307e\u3059'))
rare = ['bisect','worktree','cherry-pick','filter-branch','subtree']
used = [c for c in rare if c in G['rf'].lower()]
if used:
    sigs.append(('til', 'TIL\uff08Today I Learned\uff09', f'\u30ec\u30a2git\u30b3\u30de\u30f3\u30c9: {\",\".join(used)}', 0.55,
                 f'\u300cgit {used[0]}\u3067\u3053\u3046\u3084\u3063\u305f\u300d\u306f\u521d\u5fc3\u8005\u306b\u523a\u3055\u308bTIL\u7d20\u6750\u3067\u3059'))

# === Signal 4: builder_diary ===
cp = ['hooks/','skills/','CLAUDE.md','settings.json','.claude/','commands/']
cf = [f for f in files if any(p in f for p in cp)]
if cf:
    sigs.append(('builder', \"Builder's Diary\", f'Claude\u8a2d\u5b9a\u5909\u66f4: {len(cf)}\u30d5\u30a1\u30a4\u30eb', 0.6,
                 'Claude Code\u8a2d\u5b9a\u306e\u5de5\u592b\u306f\u300c\u79c1\u306eClaude\u904b\u7528\u300d\u8a18\u4e8b\u3068\u3057\u3066\u30d0\u30ba\u308a\u307e\u3059'))
ip = ['Makefile','Dockerfile','.github/','docker-compose','.gitlab-ci','Jenkinsfile','terraform/']
inf = [f for f in files if any(p in f for p in ip)]
if inf:
    sigs.append(('builder', \"Builder's Diary\", f'\u30a4\u30f3\u30d5\u30e9\u81ea\u52d5\u5316: {len(inf)}\u30d5\u30a1\u30a4\u30eb', 0.5,
                 '\u958b\u767a\u74b0\u5883\u306e\u6539\u5584\u306f\u300c\u5c0f\u3055\u306a\u81ea\u52d5\u5316\u306e\u7a4d\u307f\u91cd\u306d\u300d\u8a18\u4e8b\u306e\u7d20\u6750\u3067\u3059'))

# === Signal 5: tool_discovery ===
dn = ['package.json','requirements.txt','pyproject.toml','Cargo.toml','go.mod','Gemfile']
df = [f for f in files if any(f.endswith(d) for d in dn)]
if df:
    sigs.append(('tool', '\u30c4\u30fc\u30eb\u6bd4\u8f03/\u767a\u898b', f'\u4f9d\u5b58\u30d5\u30a1\u30a4\u30eb\u5909\u66f4: {os.path.basename(df[0])}', 0.5,
                 '\u65b0\u30c4\u30fc\u30eb\u5c0e\u5165\u306e\u7d4c\u7def\u306f\u300c\u25cb\u25cb vs \u25b3\u25b3\u300d\u6bd4\u8f03\u8a18\u4e8b\u306e\u7d20\u6750\u306b\u306a\u308a\u307e\u3059'))
mcp = [f for f in files if '.mcp.json' in f]
if mcp:
    sigs.append(('tool', '\u30c4\u30fc\u30eb\u6bd4\u8f03/\u767a\u898b', 'MCP\u8a2d\u5b9a\u5909\u66f4\u3092\u691c\u51fa', 0.6,
                 'MCP\u63a5\u7d9a\u306e\u5909\u66f4\u306f\u300cClaude Code \u00d7 \u5916\u90e8\u30c4\u30fc\u30eb\u9023\u643a\u300d\u8a18\u4e8b\u306e\u7d20\u6750\u3067\u3059'))

# === Signal 6: vibe_coding ===
tss = []
for line in G['ld'].strip().split('\n'):
    if line.strip():
        try: tss.append(datetime.fromisoformat(line.strip()))
        except: pass
if len(tss) >= 3:
    span = (tss[0] - tss[2]).total_seconds()
    if 0 < span < 600:
        sigs.append(('vibe', 'Vibe Coding\u4f53\u9a13', f'{len(tss)}\u30b3\u30df\u30c3\u30c8\u304c{int(span/60)}\u5206\u4ee5\u5185', 0.55,
                     '\u300cAI\u304c\u81ea\u5f8b\u3067\u5b8c\u4e86\u3057\u305f\u300d\u4f53\u9a13\u306fVibe Coding\u8a18\u4e8b\u306e\u7d20\u6750\u3067\u3059'))
vkw = ['auto:','agent','team','autonomous','auto-','batch','pipeline']
vh = [k for k in vkw if k in l5lo]
if len(vh) >= 2:
    sigs.append(('vibe', 'Vibe Coding\u4f53\u9a13', f'\u81ea\u5f8b\u30ad\u30fc\u30ef\u30fc\u30c9: {\",\".join(vh)}', 0.5,
                 '\u300c\u6307\u793a\u3057\u305f\u3089\u52dd\u624b\u306b\u5b8c\u6210\u3057\u305f\u300d\u4f53\u9a13\u8ac7\u306f\u30d0\u30ba\u306e\u5b9a\u756a\u3067\u3059'))

# === Signal 7: contrarian_pattern ===
tp = ['test_','_test.','.test.','.spec.','tests/']
td = [l[2:] for l in G['dn'].strip().split('\n') if l.startswith('D\t') and any(p in l for p in tp)]
if td:
    sigs.append(('contrarian', '\u9006\u5f35\u308a\uff08\u5e38\u8b58\u3078\u306e\u6311\u6226\uff09', f'\u30c6\u30b9\u30c8\u30d5\u30a1\u30a4\u30eb{len(td)}\u4ef6\u524a\u9664', 0.65,
                 '\u300c\u30c6\u30b9\u30c8\u3092\u524a\u9664\u3057\u305f\u7406\u7531\u300d\u306f\u9006\u5f35\u308a\u8a18\u4e8b\u3068\u3057\u3066\u6ce8\u76ee\u3092\u96c6\u3081\u307e\u3059'))
ad = [l for l in G['dn'].strip().split('\n') if l.startswith('D\t')]
if len(ad) >= 5:
    sigs.append(('contrarian', '\u9006\u5f35\u308a\uff08\u5e38\u8b58\u3078\u306e\u6311\u6226\uff09', f'{len(ad)}\u30d5\u30a1\u30a4\u30eb\u524a\u9664', 0.55,
                 '\u5927\u91cf\u524a\u9664\u306f\u300c\u6368\u3066\u308b\u52c7\u6c17\u300d\u8a18\u4e8b\u306e\u7d20\u6750\u306b\u306a\u308a\u307e\u3059'))

# === Filter + Format ===
valid = [s for s in sigs if s[3] >= 0.5]
if not valid:
    print('SKIP'); raise SystemExit(0)
valid.sort(key=lambda x: x[3], reverse=True)
# Dedupe by type
seen = set(); uniq = []
for s in valid:
    if s[0] not in seen: seen.add(s[0]); uniq.append(s)
best = uniq[:2]

lines = ['X_MATERIAL DETECTED:']
for s in best:
    lines.append(f'  [{s[1]}] {s[2]}')
lines.append(f'  {best[0][4]}')
lines.append('')
lines.append('\u8a18\u9332\u3059\u308b\u5834\u5408: /capture-improvement [\u6539\u5584\u306e\u8981\u7d04]')
lines.append('\u30b9\u30ad\u30c3\u30d7: \u305d\u306e\u307e\u307e\u7d9a\u884c')
print('MSG:' + '\n'.join(lines))
" 2>/dev/null)

case "$RESULT" in
    SKIP) exit 0 ;;
    MSG:*)
        MSG="${RESULT#MSG:}"
        mkdir -p "$STATE_DIR"
        echo "$MSG"
        date '+%Y-%m-%d %H:%M:%S' > "$DONE_FILE"
        ;;
esac

exit 0
