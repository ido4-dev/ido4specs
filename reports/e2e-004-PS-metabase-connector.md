# E2E Test Report — Modus Data Connector (round 4)

**Round:** 4
**Date:** 2026-04-28
**Project:** `~/dev-projects/PS-metabase-connector/` (same as round 3, `specs/` cleaned for fresh slate)
**Strategic spec:** `data-connector-spec.md` — same file as round 3, unchanged (43 capabilities, 8 groups, 61 dependency edges, 47 cross-group, max depth 5)
**Plugin version under test:** `ido4specs` v0.4.1 (the round-3 patch). Round-4 surfaced an upstream prefix-derivation regression in the bundled validator that required a side-quest fix to `@ido4/spec-format` (released as v0.9.1) before the test could continue cleanly. Round 4 closed by shipping `ido4specs` v0.4.2 with v0.4.1's surviving prose reframed as principles per `prompt-strategy.md`.
**Bundled validators:** v0.9.0 at the start of round 4 (auto-merged during v0.4.1 release work). v0.9.1 mid-round after the upstream fix landed and propagated.
**Skills exercised:** `/ido4specs:doctor`, `/ido4specs:create-spec`, `/ido4specs:synthesize-spec`, `/ido4specs:review-spec`, `/ido4specs:refine-spec`, `/ido4specs:validate-spec`. Full 5-skill pipeline plus doctor.
**Monitor session:** Separate Claude Code session in `~/dev-projects/ido4specs/`. Round-3 report (`reports/e2e-003-PS-metabase-connector.md`) read for continuity at the start.
**Test character:** First retest of v0.4.1's four fixes (OBS-04, OBS-01, OBS-08, OBS-09). Same project + same spec as round 3 to give clean apples-to-apples comparison data on every skill.

---

## Pipeline Summary

| Phase | Skill | Round 3 | Round 4 | Verdict | Notes |
|---|---|---|---|---|---|
| 0 | `doctor` | not run | <30s | PASS (8/8) | v0.9.1 bundles confirmed loaded after `/reload-plugins` |
| 1 | `create-spec` | ~26 min | ~58 min | PASS, slow | OBS-01 regressed (5 redundant validator calls); OBS-R4-02 new chunked-write inefficiency in Stage 1c (57m for canvas vs 19m round-3 baseline) |
| 2 | `synthesize-spec` | 13m 8s | 14m 6s | PASS | OBS-01 mild regression (2 calls in Stage 1d). 50 tasks (vs 59 round 3). |
| 3a | `review-spec` | 5m 43s + 4 prompts | **2m 38s + 0 prompts** | PASS WITH WARNINGS | **OBS-08 fix verified — biggest win.** 53% time reduction, zero permission prompts. PASS WITH WARNINGS (1W + 3S). |
| 4 | `refine-spec` | 36s | 1m 37s | PASS | OBS-01 fix held here (single validator call). NEW behavior: scope-by-severity decision pause before edits. |
| 3b | `validate-spec` | 1m 31s | 1m 46s | PASS | OBS-01 fix held here too. T0–T8 all green. |
| **Total** | — | **~46 min** | **~78 min** | All artifacts clean end-state | Canvas chunked-write inefficiency dominates the time delta. Without it, round 4 would land at ~38 min. |

**Artifacts produced:**
- `specs/data-connector-tech-canvas.md` — 2,915 lines, 43 `## Capability:` sections (vs round-3's 2,440 — ~19% larger, depth justified)
- `specs/data-connector-tech-spec.md` — 933 lines, 50 tasks, 82 dep edges, max depth 6, 205 success conditions

**End-state metrics (post-refine):**
- Validator: 0 errors, 0 warnings (`@ido4/tech-spec-format@0.9.1`)
- T0–T8 content assertions: all green
- Effort: 1 L / 18 M / 31 S
- Risk: 2 high (SMQ-06A, DCT-07A) / 14 medium / 34 low / 0 critical
- AI: 5 full / 32 assisted / 11 pair / 2 human
- 6 root tasks, 5 hub tasks (CRT-03A 9, SEC-01A 10, QAC-01B 9, CRT-01A, OPS-01B)

---

## Side-quest — upstream `@ido4/spec-format` v0.9.1 fix

Mid-round, `create-spec` Stage 0 produced group prefixes like `WF—VAPT`, `SMQ—VCB`, `VC—1R` — em-dash characters in supposedly-valid prefixes that violate the downstream `[A-Z]{2,5}-\d{2,3}[A-Z]?` task-ref regex. Initial diagnosis blamed v0.9.0 as a regression vs v0.8.0 (auto-merged into `ido4specs` during v0.4.1 release work). Investigation found the bug was older — the spec-format `derivePrefix(groupName)` function in `packages/spec-format/src/spec-parse-utils.ts:26-35` had been letting em-dashes leak into prefixes since at least v0.8.0. Round 3 worked because Claude implicitly ignored the broken `groups[].prefix` field and inferred clean prefixes from capability IDs. v0.4.1's Stage 0 SKILL.md edit explicitly instructed Claude to read `groups[].prefix` directly, **surfacing** the upstream bug rather than causing it.

**Decision:** patch only upstream, not in `ido4specs`. Adding a workaround in `ido4specs` SKILL.md ("ignore broken prefix, derive from cap-refs") would have made the bug invisible to anyone using the plugin, removing the forcing function for an upstream fix. The user pushed back on the workaround path — correctly. Round 4 paused while the upstream was fixed.

The upstream fix landed as `@ido4/spec-format` v0.9.1 (commit `6d4d079` in `ido4-dev/ido4`), with two layers per the prompt-strategy.md decision test:

- **Layer 1** (`spec-parse-utils.ts`) — `derivePrefix(groupName)` strips non-letter characters and caps output at 5 chars.
- **Layer 2** (`strategic-spec-parser.ts`) — post-process pass overrides each group's prefix with the prefix portion of its first capability ref when present (e.g., `WHF-01` → `WHF`). The author has already encoded their intent in capability IDs; that's the source of truth.

Plus 33 new tests in `tests/spec-parse-utils.test.ts` (basic cases, separators, all-symbols, length cap) + cap-ref-override tests in `tests/strategic-spec-parser.test.ts`. The auto-update pipeline pulled the v0.9.1 bundle into `ido4specs` via PRs #8 and #9; v0.4.1's CI runs continued to pass at 166 checks.

The deeper test gap revealed by this side-quest: **the `@ido4/spec-format` ↔ `@ido4/tech-spec-format` contract has no integration test**. Spec-format produces prefixes; tech-spec-format consumes them via the heading regex. Both packages had passing tests, but no test asserted that derived prefixes satisfy the consuming regex. The v0.9.1 fix added producer-side unit tests (correct location per the upstream session's audit — putting the contract assertion at the producer keeps both packages independent). This is the cleanest lesson in round 4 about test-surface ratios for utility functions.

---

## v0.4.1 verification matrix

The four v0.4.1 fixes faced their first retest in round 4. Results:

### OBS-04 (path anchors) — ✓ Verified

Round 3 trace contained:
```
Background command "Search user home for code-analyzer.md" completed (exit code 0)
Background command "Search filesystem for code-analyzer.md" completed (exit code 0)
```

Round 4 trace went straight to:
```
Searching for 1 pattern, reading 2 files…
~/dev-projects/ido4specs/skills/create-spec/agents/code-analyzer.md
```

Direct path resolution via `${CLAUDE_SKILL_DIR}/` prefix. No `$HOME`-wide search. **Mechanical fix, mechanically verified.** Same pattern held in `synthesize-spec` (no filesystem search for `technical-spec-writer.md` either).

### OBS-09 (`validate-spec` cross-references) — ✓ Verified across all three skills

Round-3 end-of-phase messages from `synthesize-spec`, `review-spec`, and `refine-spec` did not mention `/ido4specs:validate-spec`. The deterministic content-assertion layer (T0–T8) was orphaned in the in-product navigation graph.

Round-4 end-messages, all three skills:

- `synthesize-spec` end-of-Phase-2: *"Review it, then run `/ido4specs:review-spec` for qualitative review, `/ido4specs:validate-spec` for the deterministic content-assertion pass (T0–T8), or `/ido4specs:refine-spec` to edit."* ✓
- `review-spec` PASS WITH WARNINGS verdict: *"Run `/ido4specs:refine-spec` to address these, run `/ido4specs:validate-spec` for the deterministic content-assertion pass (T0–T8) if you haven't yet, or proceed with the caveats."* ✓
- `refine-spec` end-message: *"Consider running `/ido4specs:review-spec` for qualitative review and/or `/ido4specs:validate-spec` for the deterministic content-assertion pass (T0–T8)."* ✓

Three for three. **Cleanest, most reliable fix in the v0.4.1 patch.** Mechanical text addition to three SKILL.md files; no model-variance risk.

### OBS-08 (review-spec mechanism redesign) — ✓ VERIFIED, biggest win

| Metric | Round 3 | Round 4 |
|---|---|---|
| Total time | 5m 43s | **2m 38s (-53%)** |
| Permission prompts | **4** | **0** |
| Bash shell-pipeline calls | Multiple `grep \| sort \| uniq`, `awk` | **None** |
| Hub-task identification | Yes (via awk pipeline) | Yes (in-context derivation) |
| Critical path | Yes | Yes |
| Effort/risk/type/ai distributions | Yes (via shell counting) | Yes (in-context) |
| Report structure (6 sections) | All present | All present |
| Substantive findings | 0E / 2W / 3S | 0E / 1W / 3S |

**Trace shows only Read + Grep tool usage — no Bash for metadata extraction.** The mechanism redesign in `skills/review-spec/SKILL.md` (forbid shell pipelines, derive from in-context spec content, use Grep tool not Bash for verification) did exactly what it was designed to do.

The W1 finding (SMQ-07 capability `size: S` with sole task `effort: M` — sibling-pattern check vs SMQ-05) demonstrates the **substantive review depth was preserved**, not flattened, by removing shell pipelines. Hub-task identification (CRT-03A, SEC-01A, QAC-01B, CRT-01A, OPS-01B) — which round 3 produced via a complex `grep | tr | sed | tr | grep | grep | sort | uniq -c | sort -rn` pipeline — was reproduced in round 4 from in-context inspection alone.

This is the headline win of the v0.4.1 patch.

### OBS-01 (no python pipe in validator calls) — ⚠ Mixed

| Skill | Round 3 | Round 4 | Held? |
|---|---|---|---|
| `create-spec` Stage 0 | 5 calls | **5 calls** | ✗ Regressed |
| `synthesize-spec` Stage 1d | (auto-validation; round-3 didn't show pattern) | 2 calls | ✗ Mild regression |
| `refine-spec` baseline + post-edit | 1+1 calls | 1+1 calls | ✓ Held |
| `validate-spec` | 1 call | 1 call | ✓ Held |

The mixed result was the **most diagnostically valuable observation in round 4**. It revealed the asymmetry that the v0.4.1 patch authoring missed — see "The asymmetry" section below.

---

## New observations from round 4

### OBS-R4-01 — OBS-01 partial regression, prose discipline insufficient

**Type:** behavioral-drift / authoring
**Severity:** Medium
**When:** `create-spec` Stage 0 (5 calls), `synthesize-spec` Stage 1d (2 calls)
**What happened:** v0.4.1's SKILL.md said *"Run the bundled strategic-spec validator **once** and parse its JSON output directly… Do not pipe the validator output through `python3 -c` or run multiple validator invocations."* Round 4 trace showed Claude making 5 successive validator calls in Stage 0 (output sizes 211 / 87 / 6 / 70 / 70 lines, with output shape differences confirming `python3` filters between them) despite the explicit prohibition.

**Recovery test:** When the user denied the python pipe at the permission prompt and prompted Claude to read the JSON from context, Claude recovered cleanly and produced the Stage 0 summary by reading field values directly. So Claude *can* read JSON from conversation context; it just doesn't *default* to it under v0.4.1's wording.

**Diagnostic verdict:** the v0.4.1 fix was *underweighted but recoverable with prompting*. The prose was rule-shaped (`once`, `Do not… under any circumstances`) but had no enforcement layer behind it (Bash is allowlisted in `create-spec`, so attempted shell calls don't trigger permission prompts the way they do in `review-spec`).

**Fix candidate (shipped in v0.4.2):** Reframe as principle + BAD/GOOD example pair per `prompt-strategy.md` decision test. See "v0.4.2 — authoring discipline patch" below.

### OBS-R4-02 — Chunked-write inefficiency in canvas synthesis

**Type:** behavioral-drift / quality-issue
**Severity:** Medium (output correct, mechanism wasteful)
**When:** `create-spec` Stage 1c (canvas synthesis) — same pattern recurred mildly in `synthesize-spec` Stage 1b (tech-spec writing)
**What happened:** Claude announced *"I'll build the canvas in chunks via append-style writes to stay within output limits"* — a behavior pattern not prescribed in the SKILL.md. Round 3 wrote the entire 2,440-line canvas in a single Write call in 18m 57s. Round 4 ran 57m 11s with multiple Write calls and intermediate file-reads, consuming ~219k tokens.

**Verification:** the canvas DID complete correctly — 2,915 lines, 43 / 43 capability sections, content quality comparable to round 3 (slightly more thorough in some sections). My initial "stuck in a loop" panic was wrong. The mechanism was inefficient, not broken. End-state was a high-quality artifact at 3× the runtime cost.

**Why the pattern emerged in round 4 but not round 3:** Likely an interaction between (a) the parallel-Explore output (128k tokens of subagent return material) priming Claude to perceive output-budget pressure, and (b) v0.4.1's slightly verbose Stage 0 SKILL.md changing the planning context. Cannot fully isolate the cause without a controlled run.

**Why Phase 2 didn't blow up:** `synthesize-spec` chunked too but produced a 933-line tech spec in 14m 6s — comparable to round-3's 13m 8s. The chunked-write O(n²) pattern only manifests catastrophically at canvas-scale (~2,500 lines).

**Fix candidate (shipped in v0.4.2):** Principle + BAD/GOOD example in `create-spec` Stage 1c — "Write the entire canvas in a single Write call; iterative chunked writes either lose prior content or force you to re-encode everything-prior-plus-new on each call (the latter is O(n²) in tokens)."

---

## The asymmetry — round 4's most useful insight

OBS-08 fix held cleanly under round-4 retest. OBS-01 fix did not. Both were prose-shaped instructions added in the same v0.4.1 patch by the same author with the same authoring style. The variable was structural enforcement.

| Fix | Skill | `allowed-tools` | Result |
|---|---|---|---|
| OBS-08 (no shell pipelines) | `review-spec` | `Read, Glob, Grep` (no Bash) | **Held**. Bash isn't allowlisted, so attempted shell calls trigger permission prompts. Prose + structure together did the job. |
| OBS-01 (no python pipe) | `create-spec` | `Read, Write, Glob, Grep, Bash` | **Drifted**. Bash is allowlisted, so attempted shell calls run silently. Prose alone, no enforcement layer. |

This is exactly the principle stated in `~/dev-projects/ido4-suite/docs/prompt-strategy.md` lines 30-32: *"If an instruction's enforcement layer is 'prose only' and the instruction is qualitative, it should be a principle, not a rule."* The doc had been there the whole time; v0.4.1 was authored without consulting it. Round 4 demonstrated the cost of that omission.

The user's intervention — *"are you aware about prompt, and skills best practices documented in the folder of ido4-suite?"* — caught the error before v0.4.2 doubled down on the same pattern. The first v0.4.2 draft I produced included `exactly once`, `under any circumstances`, and stacked prohibitions — the iteration-accumulation antipattern the doc explicitly warns against (lines 211-219). Reading prompt-strategy.md cover to cover reframed the patch from "stronger language" to "different shape."

---

## v0.4.2 — authoring discipline patch

Released 2026-04-28 (commit `2561e88`, release commit `d64e940`, hand-corrected CHANGELOG `272a160`).

### Changes

| File | Lines | Shape |
|---|---|---|
| `skills/create-spec/SKILL.md` | +37 / −1 | Stage 0 prohibition replaced with principle + BAD/GOOD example pair (5 invocations vs 1 invocation). Stage 1c new chunked-write principle + BAD/GOOD example pair (57m chunked vs ~20m single-Write). |
| `skills/synthesize-spec/SKILL.md` | +2 / 0 | Stage 1d brief positive principle added (validator JSON in context, no need for second invocation). |
| `skills/refine-spec/SKILL.md` | +2 / −2 | Two prohibitions ("do not pipe through python3") rewritten as positive statements ("pull `valid` / `errors[]` / `warnings[]` from there directly"). Same line count. |

### Why principle+example shape

Per the prompt-strategy.md decision test (lines 26-32):

- Is there an enforcement layer that catches violations of "do not pipe validator output through python3"? **No.** Bash is allowlisted in the affected skills.
- Is there an enforcement layer that catches "do not chunk Writes"? **No.** Write is allowlisted; multiple Write calls are not detected.
- Therefore: **principle, not rule**.

Per the language guidance (lines 46-65):

- Replace `MUST` / `NEVER` / `under any circumstances` with normal-case imperatives. v0.4.1 had `**once**` (bolded emphasis-as-rule); v0.4.2 has *"the structured JSON output is in your conversation context as the Bash tool result — that's your data source"* (positive, descriptive).
- WHY-motivated: each principle states the reason. *"Re-running the validator… produces the same information at higher latency and token cost."* *"The Write tool overwrites rather than appends, so iterative chunked writes either lose prior content or force you to re-encode everything-prior-plus-new on each call. The latter is O(n²) in tokens."*

Per examples-over-enumeration (lines 66-99):

- Each principle paired with one BAD/GOOD example pair grounded in observed round-4 behavior (5-invocation pattern from the trace; 57m chunked canvas from the runtime).
- Multi-line BAD examples kept validator+`python3` tokens on different lines so the existing TEST 15 anti-pattern regex doesn't trip.

Per net-reduction discipline (lines 207-219):

- Refine-spec prohibitions REPLACED in-place (not added on top). Same line count.
- Create-spec Stage 0 prohibition REPLACED. Net +37 lines, but those 37 lines include the BAD/GOOD example pair the prior wording lacked.
- Did NOT touch `review-spec`'s OBS-08 fix — currently working, structurally backed by allowed-tools, "don't fix what isn't broken."

### What v0.4.2 does NOT change

- `tests/validate-plugin.sh` — TEST 15's existing checks still apply. The principle+example wording doesn't introduce new patterns to test. All 166 plugin-validation checks still pass.
- `review-spec/SKILL.md` — held cleanly in round 4; reframing now would be rule-churn.
- The bundled validators — already at v0.9.1 from the upstream side-quest fix.

### Round-5 hypothesis

If OBS-01 still regresses on the principle+example wording in round 5, the conclusion will be: *prose alone is insufficient when there's no structural enforcement, regardless of language shape*. The next move would be either:

- A PostToolUse hook on Bash that warns/blocks consecutive validator invocations.
- Tightening `allowed-tools` for `create-spec` (remove Bash? but Bash is needed for the validator call itself).
- Accepting the inefficiency as a model behavior characteristic and not fixing further.

Either way, that's a v0.5+ design decision — not more rule-stacking in v0.4.x.

---

## Positives (selected)

### POS-R4-01 — Recovery from deny + nudge

After the user denied the python pipe at the Stage 0 permission prompt and prompted Claude to read JSON from context, Claude:
- Read its conversation context for the validator JSON output
- Produced a comprehensive Stage 0 summary **without** re-running the validator and **without** any external parser
- Moved cleanly to Stage 0.5

**Diagnostic verdict on OBS-01 fix:** Claude *can* read JSON from context — it just doesn't *default* to it. Distinction matters for the v0.4.2 fix shape.

### POS-R4-02 — Stage 0 summary depth equals or exceeds round 3

Comprehensive structure when Claude got there:
- Project name, validation status, group table with priority and counts, total capabilities, orphan count, dependency structure (61 edges, 47 cross-group, max depth 5)
- **Hub identification call-out** (CRT-03 + SEC-01 as runtime backbones) — *new* vs round 3, surfaced unprompted
- 9 cross-cutting concerns enumerated
- Derived `{spec-name}` correctly

The "notable hub" line was not in round 3's Stage 0. Claude added analytical depth, not just data restatement. Worth keeping that pattern.

### POS-R4-03 — Two-Explore divergence (positive judgment call)

`skills/create-spec/SKILL.md:154-170` says *"one per target."* Round 3 obeyed literally — one target, one Explore (32 tool uses, 87.5k tokens, 3m 26s).

Round 4 had effectively the same target (`marketplace-analytics-plugin`) but Claude reinterpreted the prescription as *"one per exploration concern within a target"* and split into two parallel Explores:

| Subagent | Tool uses | Tokens | Focus |
|---|---|---|---|
| Plugin canonical-rule SQL extraction | 19 | 65.2k | SMQ saved-question + DCT RPC SQL bodies |
| Plugin runtime architecture map | 19 | 63.0k | OPS-04 parity reference + plugin patterns |

Combined: 38 tool uses, 128.2k tokens, ~4m 5s wall. Two focused briefs are more cognitively coherent than one omnibus brief. Worth considering whether to formalize the pattern in the SKILL.md: *"For each integration target, spawn one Explore per coherent exploration concern (typically 1–3 per target)"*. Not a fix; a design-question item for v0.5+.

### POS-R4-04 — Canvas content quality, comparable depth to round 3

Despite the chunked-write inefficiency, the resulting canvas is high-quality (assessment in mid-session retrospective): structurally complete (43/43 capability sections), code-grounded (verbatim SQL from plugin skills, file paths, Pydantic typing examples), strategically preserved (D-references inline, stakeholder attributions, group context), discoveries-rich (8 shared infrastructure items, 5 dependency-order adjustments, 5 surprises, 4 research-task candidates), with a Risk Assessment Summary table covering all 43 capabilities including a "canvas concur" column allowing the canvas to disagree with spec risk where warranted.

### POS-R4-05 — `synthesize-spec` end-message OBS-09 fix verified

The end-of-Phase-2 message surfaced all three Phase-3 paths with their distinct value propositions: review-spec (qualitative), validate-spec (T0–T8 deterministic), refine-spec (edit). Compare to round-3 where validate-spec was orphaned. **First clean OBS-09 verification.**

### POS-R4-06 — `review-spec` mechanism redesign produces equivalent depth at zero friction

See OBS-08 verification matrix above. The W1 finding (SMQ-07 capability size/effort mismatch — size:S | effort:M, with sibling-pattern check against SMQ-05's correctly-rolled-up size:M) demonstrates evidence-backed review work derived from in-context content alone.

### POS-R4-07 — Decision pause in `refine-spec` start (NEW behavior)

Claude opened with: *"The review surfaced 1 Warning (W1) and 3 Suggestions. Before editing, which would you like me to apply?"* — then categorized by severity ("Quick fixes (low-risk, recommended)" vs "Optional improvements (moderate, judgment calls)"). Asked the user to scope.

This isn't in the SKILL.md prescription. Round 3's refine-spec applied both fixes in one pass without offering scope. Round 4's behavior is **discretionary judgment by Claude** — when the prior skill (review-spec) has produced multiple findings of varying severity, refine-spec lets the user pick scope before editing. Useful pattern. Worth filing for the v0.5+ design questions: should this be formalized in the SKILL.md, or kept as discretionary Claude judgment that calibrates against findings density?

### POS-R4-08 — High-quality refine edits, especially for nuanced suggestions

S2 (OPS-04A tolerance value) and S3 (DCT-09A flaky parallelism check) edits show real engineering work, not just JSON wrangling:

- S2: rewrote description to frame `±0.5%` as starting-point proposal; added explicit *"Numeric tolerance is a load-bearing decision (this is the parity test that protects the brief's $1.15M motivating example)"* preserving stakes; added confirmation gate; updated success condition to require recording confirmation in commit message or `docs/decisions/parity-tolerance.md`.
- S3: replaced flaky latency-arithmetic assertion with deterministic respx-stub in-flight-call count, with specific threshold (`≥ 2 concurrent Metabase calls during peak orchestration`).

### POS-R4-09 — `validate-spec` cross-stage awareness in end-message

> *"Ready for `/ido4specs:review-spec` (qualitative review — already run; pass-with-warnings reduced to clean after `/ido4specs:refine-spec`)."*

`validate-spec` knows the prior runs and references them. Emergent context-aware behavior, not prescribed.

---

## Architectural invariants — held across all 5 skills

- ✓ **Parser-as-seam** — every structural validation goes through the bundled `tech-spec-validator.js` or `spec-validator.js`. (Caveat: `review-spec`'s OBS-08 fix was specifically the elimination of shell-pipeline reimplementation of parser work — that fix held in round 4.)
- ✓ **Methodology neutrality** — no Scrum / Shape-Up / Hydro / sprints / cycles / containers / methodology profiles in any skill output across the full pipeline.
- ✓ **Inline execution** — `code-analyzer.md`, `technical-spec-writer.md`, `spec-reviewer.md` all read inline by main Claude. No `Agent(...)` spawns of plugin-defined subagents. Only built-in `Explore` was spawned (in `create-spec` Stage 1a — round 4 spawned **two** Explores in parallel, see POS-R4-03).
- ✓ **Zero runtime coupling** — no `mcp__` calls, no `parse_strategic_spec`, no `ingest_spec`, no `@ido4/mcp` references. The only cross-plugin signal is the `.ido4/project-info.json` filesystem probe in the cross-sell footer (which fired the correct "absent" variant).

---

## Resolved or carried-forward observations

### Resolved during round

- **Round-3 OBS-01 (doctor parallel-call cancel-and-retry, watch item).** Doctor ran cleanly in round 4 (8/8 PASS, no parallel-call hiccup). One clean run isn't enough to clear the watch item, but encouraging.
- **POS-R4-04 watch — D-reference enrichment didn't fire.** Round 3 had POS-05 — Claude proactively pulled D-001..D-020 to make the canvas self-sufficient. Round 4 didn't. Verified by reading the strategic spec: it's 657 lines (vs round 3's smaller version) and self-contains the D-references inline. Round 4 correctly didn't enrich what was already inlined. **Not a regression.**

### Carried forward to round 5+

- **WATCH-1 — `refine-spec` pre-edit ripple analysis on bigger refines.** Round-3's CLAUDE.md note: *"refine-spec should surface ripple effects before making changes."* Round 4's refine-spec applied 4 edits but didn't pre-surface ripples (round-3's behavior was post-edit ripples too, so consistent). Watch on a bigger refine request.
- **WATCH-3 — doctor parallel-call cancel-and-retry recurrence.** Round 4 didn't reproduce; one more clean round before clearing.
- **NEW WATCH — Decision-pause variance based on user preamble.** Round 3 (with "involve me in decisions" preamble) had Stage 0.5 target-confirmation pause. Round 4 (no preamble) didn't. Reinforces the case for explicit user-profiling at session start (Q1 in design questions).

---

## Design questions for v0.5+ (extending e2e-003's list)

**These are the e2e-003 questions that round-4 evidence sharpens, plus three new ones surfaced this round.**

### Q1 (from e2e-003) — User-profiling at pipeline entry

Round 4 reinforced this. Round-3's user said *"involve me in decisions"* in their preamble; Claude calibrated against that with a Stage 0.5 target-confirmation pause. Round-4's user just said *"hello"* + ran the command; same skill body, same agent, no pause. The interaction-style behavior is **preamble-dependent, not skill-design-dependent**.

The case for explicit declaration at session start (driver/co-pilot/inspector mode or similar) is now stronger than e2e-003 articulated. Round 4 also showed a similar discretionary-judgment moment in `refine-spec` (POS-R4-07 — scope-by-severity offer when multiple findings exist) that depends on context Claude happens to have. Worth considering whether the same profile signal could calibrate decision-pause density across the full pipeline.

### Q2 (from e2e-003) — Two-layer validation framing convergence

Round-4 evidence: validate-spec ran in 1m 46s with full T0–T8 + supporting metrics + structural-observation framing. review-spec ran in 2m 38s (post-OBS-08-fix) with W1 + 3 suggestions + downstream notes + dep graph. **Both layers now run cheaply and produce non-overlapping value** — review-spec catches qualitative issues (the SMQ-07 size/effort rollup), validate-spec confirms T0–T8 + provides metrics. The merge-vs-separate question is less urgent now that OBS-08 is fixed and they no longer overlap mechanically.

Net: lower priority for v0.5. Could stay as-is.

### Q3 (from e2e-003) — Pipeline orchestrator skill (or `--through` flag)

Round-4 total time was ~78 min (vs round-3's ~46 min, mostly due to OBS-R4-02's chunked-write blowup). Even at round-3's pace, a returning user invoking 5 skills sequentially is a meaningful UX cost. The orchestrator option (or driver-mode auto-progression) becomes more compelling with each round of evidence that the per-skill checkpoints are useful for first-time users but heavy for returning ones.

### Q4 (from e2e-003) — `create-spec` doing two distinct things

Round-4 ran Stage 0 + 0.5 in <1 min (post-recovery), and Stage 1a–c in 4–58 min. The asymmetry is sharp. Plus round 4 surfaced the chunked-write inefficiency only in Stage 1c — splitting parse-spec from analyze would isolate the heavy stage. Lower priority though — the canvas-write inefficiency is now patched in v0.4.2.

### Q5 (from e2e-003) — Cross-sell footer at every phase boundary

Unchanged from e2e-003. Worth a v0.5 audit pass.

### Q6 (NEW) — Formalize "one Explore per concern within target"

Round 4 spawned 2 Explores for one target, splitting concerns (canonical-rule SQL extraction vs runtime architecture). The SKILL.md says *"one per target"*. Claude's reinterpretation produced more focused subagent briefs and comparable wall time (~40s extra for double the depth). If this consistently produces better canvas output, formalize the pattern: *"For each integration target, spawn one Explore per coherent exploration concern (typically 1–3 per target). Each brief stays under 300 tokens; concerns should be cleanly separable so subagents don't duplicate work."*

Risk: more parallel subagents = more context fan-in for the synthesis step. Worth measuring on a controlled test before formalizing.

### Q7 (NEW) — Decision-pause in `refine-spec` when prior skill produced multiple findings

Round 4's `refine-spec` opened with a scope-by-severity offer (W1 vs S1–S3) before applying any edits. Round-3's `refine-spec` applied edits directly. The difference appears to be: round-4's prior skill (`review-spec`) produced 4 findings; round-3's `refine-spec` was directed by the user with explicit fix scope.

Should the SKILL.md prescribe: *"If the most recent review produced 3+ findings of mixed severity, offer scope-by-severity before editing"* — formalizing what was discretionary judgment in round 4? Or leave as Claude's calibration based on findings density?

### Q8 (NEW) — When prose drift is observed, build a hook before strengthening prose

This is the meta-lesson from round-4 → v0.4.2. The `prompt-strategy.md` decision test is clear: if prose alone has no enforcement layer and drifts, the next step should be hooks/structural-enforcement, not stronger prose. Round-4 demonstrated this concretely (OBS-08 held with allowed-tools backing; OBS-01 didn't without it).

Worth codifying as suite-wide practice: when an E2E round surfaces prose drift, the patch should either (a) reframe to principle+example AND verify it holds in the next round, or (b) build the structural enforcement that backs the prose. Adding "stronger" prose without structural backing is the iteration-accumulation antipattern.

This may already be implicit in `prompt-strategy.md` lines 207-219. Round 4 makes it observable.

---

## Assessment

**Round 4 verdict: v0.4.1 partially verified, the partial regression revealed an authoring discipline gap that v0.4.2 addressed structurally, and the upstream `@ido4/spec-format` v0.9.1 fix unblocked the round.**

The 5-skill pipeline produced a correct, structurally-clean, content-asserted, qualitatively-reviewed, edited-and-re-validated technical spec for the same 43-cap / 8-group / 657-line strategic spec from round 3. End-state metrics held. All four architectural invariants held. The **OBS-08 fix is the headline win** — 53% time reduction in `review-spec` with zero permission prompts and equivalent finding depth.

The **OBS-01 partial regression** was the most diagnostically valuable observation. It revealed the asymmetry between prose-with-structural-backing (held) and prose-only (drifted), which is exactly the principle stated in `prompt-strategy.md` lines 30-32. The lesson cost ~30 minutes of round-4 retest time and a v0.4.2 patch; the meta-lesson is now captured in two new feedback memories and the v0.4.2 CHANGELOG.

The **chunked-write inefficiency (OBS-R4-02)** was new in round 4 and dominates the time delta vs round 3. Output quality wasn't compromised. v0.4.2 added the principle+example fix.

The **upstream `@ido4/spec-format` v0.9.1 fix** is independently valuable beyond round 4 — the prefix-derivation bug had been latent since v0.8.0, masked by Claude's implicit good judgment. The producer-side unit tests added in the upstream fix close the test gap that allowed the regression to ship.

---

## Next steps

1. **Round 5 retest (recommended).** Fresh test session against `ido4specs` v0.4.2 with `@ido4/spec-format` v0.9.1 bundles. Specifically watching:
   - Whether OBS-01 holds under principle+example wording in `create-spec` Stage 0 (the prose-vs-structural hypothesis test)
   - Whether OBS-R4-02 (chunked-write) disappears with the new Stage 1c principle
   - Stage 0 group prefixes match `WHF / SMQ / CRT / SEC / DCT / QAC / DOC / OPS` (post-v0.9.1)
   - Whether decision-pause behavior shows up consistently or remains preamble-dependent (Q1 evidence)

   If OBS-01 still regresses on principle+example wording, escalate to a hook-based fix (Q8). If OBS-01 holds, the prose-vs-structural hypothesis is supported and we have a generalizable rule for future authoring.

2. **No v0.4.x patch needed unless round 5 surfaces issues.** Current state is stable: 5-skill pipeline produces correct artifacts, all four architectural invariants hold, two structural fixes (OBS-08, OBS-09) verified, two prose fixes (OBS-01, OBS-R4-02) reframed and pending verification.

3. **Carry watch items to round 5+:**
   - WATCH-1 (refine-spec pre-edit ripple analysis on bigger refines)
   - WATCH-3 (doctor parallel-call cancel-and-retry recurrence)
   - NEW WATCH (decision-pause variance based on user preamble)

4. **Memory captures already filed:**
   - `feedback_consult_prompt_strategy_first.md` — read prompt-strategy.md before any skill prose change
   - `feedback_prose_vs_structural_enforcement.md` — the asymmetry is generalizable

5. **Audit habit reinforcement.** OBS-09 was caught by the user in round 3. The prompt-strategy.md violation in v0.4.1 was caught by the user in round 4. **Pattern: my self-audit catches per-skill issues but misses cross-skill / cross-doc issues.** Worth adding to the E2E protocol in CLAUDE.md: explicitly cross-reference the skill cross-link graph AND prompt-strategy.md compliance during patch authoring, not after the user asks.
