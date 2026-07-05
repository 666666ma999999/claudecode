---
name: autoresearch
description: >
  Autonomous research loop: web search, synthesis, wiki filing.
  Triggers: /autoresearch, autoresearch, research [topic], deep dive into [topic],
  investigate [topic], find everything about [topic], research and file,
  go research, build a wiki on.
allowed-tools: Read Write Edit Glob Grep WebFetch WebSearch
---

# autoresearch: Autonomous Research Loop

## 発火・詳細（description から移設 2026-07-03）

Autonomous iterative research loop. Takes a topic, runs web searches, fetches sources,
synthesizes findings, and files everything into the wiki as structured pages.
Based on Karpathy's autoresearch pattern: program.md configures objectives and constraints,
the loop runs until depth is reached, output goes directly into the knowledge base.
Triggers on: "/autoresearch", "autoresearch", "research [topic]", "deep dive into [topic]",
"investigate [topic]", "find everything about [topic]", "research and file",
"go research", "build a wiki on".

You are a research agent. You take a topic, run iterative web searches, synthesize findings, and file everything into the wiki. The user gets wiki pages, not a chat response.

This is based on Karpathy's autoresearch pattern: a configurable program defines your objectives. You run the loop until depth is reached. Output goes into the knowledge base.

---

## Before Starting

Read `references/program.md` to load the research objectives and constraints. This file is user-configurable. It defines what sources to prefer, how to score confidence, and any domain-specific constraints.

---

## Topic Selection

Three paths to a topic:

### A. Explicit topic (always respected)
When the user says `/autoresearch [topic]` or "research X", use the given topic verbatim and skip the sections below.

### B. Boundary-first selection (agenda control, opt-in)
**This is agenda control, not pure memory.** DragonScale Memory.md Mechanism 4 labels this mechanism as such because it shapes which direction the research agent moves next. Users who want a strict memory-layer subset should omit this path entirely.

> [!note] 2026-07-04 監査時点: `scripts/boundary-score.py` / `.vault-meta` / `DragonScale Memory.md` は本環境のどこにも存在しない。下の feature detection は常に `BOUNDARY_MODE=0` となり Section C に fallback する(意図された挙動・設置するまで Section B は休眠)。

When `/autoresearch` is invoked WITHOUT a topic AND the vault has adopted DragonScale, default to surfacing the frontier of the vault as a set of candidate topics the user can accept, override, or decline.

Feature detection (shell):

```bash
if [ -x ./scripts/boundary-score.py ] && [ -d ./.vault-meta ] && command -v python3 >/dev/null 2>&1; then
  BOUNDARY_MODE=1
else
  BOUNDARY_MODE=0
fi
```

When `BOUNDARY_MODE=1`:

1. Run `./scripts/boundary-score.py --json --top 5`. Returns the top 5 frontier pages by `boundary_score = (out_degree - in_degree) * recency_weight`.
2. **Helper failure handling**: if the helper exits non-zero, emits invalid JSON, or returns an empty `results` array, set `BOUNDARY_MODE=0` and fall through to section C below. Do NOT prompt the user with an empty candidate list, and do NOT improvise a topic.
3. Present the candidate list to the user: "Your top frontier pages are: [list]. Research which one? (1-5, or type a topic to override, or say 'cancel' to be asked normally.)"
4. If the user picks 1-5, use the selected page's title as the topic.
5. If the user types free text, use that.
6. If the user cancels or does not choose, fall through to C.

The boundary score is a heuristic, not an objective measure of what SHOULD be researched. The user always has the option to type a free-text topic to override the surfaced candidates.

**Link-resolution semantics**: the boundary helper uses **filename-stem wikilink resolution only**. `[[Foo]]` is counted as an edge to `Foo.md` anywhere in the vault. Aliases declared via frontmatter `aliases:` are **not** parsed. Folder-qualified links (e.g. `[[notes/Foo]]`) are resolved by stem only. This matches default Obsidian behavior for unique filenames but does not implement full Obsidian alias resolution.

### C. User-chosen (default when B is unavailable)
When `BOUNDARY_MODE=0` or the user declined every frontier pick, ask: "What topic should I research?"

---

## Research Loop + Filing + Synthesis 構造

ループ手順 (5 iteration 上限)、ファイル配置基準、synthesis ページのフロントマター/セクション構造の詳細は `references/loop-and-synthesis.md` を参照。

## 出典検証（必須・skill 等の再利用資産に入れる場合）

リサーチ agent の「verified」自己申告を信用しない。全出典を**全件独立再 fetch** して主張と突合する。スポットチェックは代替にならない（「実在 URL に別内容を当てる」型のハルシネーションはスポットを通過する。2026-05-30 に 48 出典中 26 件問題の実測）。

## After Filing

1. Update `wiki/index.md`. Add all new pages to the right sections
2. Append to `wiki/log.md` (at the TOP):
   ```
   ## [YYYY-MM-DD] autoresearch | [Topic]
   - Rounds: N
   - Sources found: N
   - Pages created: [[Page 1]], [[Page 2]], ...
   - Synthesis: [[Research: Topic]]
   - Key finding: [one sentence]
   ```
3. Update `wiki/hot.md` with the research summary

---

## Report to User

After filing everything:

```
Research complete: [Topic]

Rounds: N | Searches: N | Pages created: N

Created:
  wiki/questions/Research: [Topic].md (synthesis)
  wiki/sources/[Source 1].md
  wiki/concepts/[Concept 1].md
  wiki/entities/[Entity 1].md

# ⚠️ Project-specific analysis (prime_crm の hvs-/keyword-/first-menu-/top200-/uranai- 等) は
#    wiki/concepts/ ではなく 02_Ai/<group>/<sub>/research/{,_raw,_archive}/ 配下に出力する (rules/42 §0-6)。
#    wiki/concepts/ は Claude × Obsidian 自身のメタ概念や横断的フレームワーク用のみ。

Key findings:
- [Finding 1]
- [Finding 2]
- [Finding 3]

Open questions filed: N
```

---

## Constraints

Follow the limits in `references/program.md`:
- Max rounds (default: 3)
- Max pages per session (default: 15)
- Confidence scoring rules
- Source preference rules

If a constraint conflicts with completeness, respect the constraint and note what was left out in the Open Questions section.
