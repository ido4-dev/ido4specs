# E2E Test Report — Modus Data Connector (round 5)

**Round:** 5
**Date:** 2026-04-28
**Project:** `~/dev-projects/PS-metabase-connector/` (same as rounds 3+4, `specs/` cleaned for fresh slate)
**Strategic spec:** `data-connector-spec.md` — same file as rounds 3+4, unchanged (43 capabilities, 8 groups, 61 dependency edges, 47 cross-group, max depth 5)
**Plugin version under test:** `ido4specs` v0.4.3 (the round-4 patch + the doctor refactor shipped between round-4 close and round-5 start). Bundles at `@ido4/spec-format@0.9.1` and `@ido4/tech-spec-format@0.9.1`.
**Skills exercised:** `/ido4specs:doctor` (against the v0.4.3 refactor), `/ido4specs:create-spec`, `/ido4specs:synthesize-spec`, `/ido4specs:review-spec`, `/ido4specs:refine-spec`, `/ido4specs:validate-spec`. Full 5-skill pipeline plus doctor.
**Monitor session:** Separate Claude Code session in `~/dev-projects/ido4specs/`. Round-4 report (`reports/e2e-004-PS-metabase-connector.md`) read for continuity at the start.
**Test character:** Second retest of v0.4.1's four fixes plus first retest of v0.4.2's principle+example reframes (OBS-01, OBS-R4-02 chunked-write) and v0.4.3's doctor refactor (single-call diagnostic, plugin version in header, workspace next-action hint). Same project + same spec as rounds 3+4 to give clean apples-to-apples comparison data on every skill across three rounds.

---

## Pipeline Summary — round-by-round comparison

| Phase | Round 3 (baseline) | Round 4 (v0.4.1 retest) | Round 5 (v0.4.2 + v0.4.3 retest) | Verdict |
|---|---|---|---|---|
| 0 | doctor not exercised | doctor PASS 8/8 | **doctor PASS 8/8 + plugin version visible + next-action hint** | v0.4.3 refactor verified working |
| 1 | create-spec ~26 min | ~58 min (chunked-write blowup) | **~40 min** (single Write held) | OBS-R4-02 fix held; remaining time delta vs round 3 unexplained |
| 2 | synthesize-spec 13m 8s | 14m 6s | **13m 31s** | Stable across rounds |
| 3a | review-spec 5m 43s + 4 prompts | 2m 38s + 0 prompts | **5m 38s + 1 prompt (denied) + recovered** | OBS-08 partial drift, contained by structural enforcement |
| 4 | refine-spec 36s (2 edits) | 1m 37s (4 edits) | **1m 24s (14 edits)** | Most edits in least time — efficient |
| 3b | validate-spec 1m 31s | 1m 46s | **1m 28s** | Stable across rounds |
| **Total** | **~46 min** | **~78 min** | **~62 min** | Round 5 is 20% faster than round 4; chunked-write fix saved ~17 min on canvas |

**Artifacts produced (round 5):**
- `specs/data-connector-tech-canvas.md` — 2,214 lines, 43 `## Capability:` sections (vs round-3's 2,440 and round-4's 2,915)
- `specs/data-connector-tech-spec.md` — 987 lines, 60 tasks, 117 dep edges (post-refine), max depth 6, 181 success conditions

**End-state metrics (post-refine):**
- Validator: 0 errors, 0 warnings (`@ido4/tech-spec-format@0.9.1`)
- T0–T8 content assertions: all green; T4 + T8 surfaced as soft notes
- 60 tasks (most granular of all rounds — rounds 3 = 59, round 4 = 50)
- Risk: 2 high (SMQ-06A, SMQ-06B — the matched primary + parity-test pair on the Cloud flat-10 projection rule)
- AI: 1 human (SEC-03B, justified per D-017)

---

## v0.4.1 + v0.4.2 + v0.4.3 fix verification matrix (round 5)

The four v0.4.1 fixes plus v0.4.2's reframes and v0.4.3's doctor refactor all faced retest. Round 5's contribution to the overall verification status:

| Fix | Round 4 | Round 5 | Combined verdict |
|---|---|---|---|
| **OBS-04** (path anchors) | ✓ Verified (1 clean run) | ⚠ Partial regression in canvas synthesis only | **Mixed — single-clean-round wasn't enough evidence** |
| **OBS-08** (review-spec mechanism) | ✓ Verified (0 prompts) | ⚠ Drift exposed by structural enforcement; user denial recovered cleanly with higher review depth | **Combination of prose + allowed-tools restriction is durable; either alone is partial** |
| **OBS-09** (validate-spec cross-refs) | ✓ Verified 3× | ✓ Verified 4× this round | **Most reliable fix in v0.4.1. Mechanical cross-link addition holds across model variance.** |
| **OBS-01** (v0.4.2 reframe) | not yet retested | ✓ Held in synthesize-spec, refine-spec, validate-spec; ⚠ Partial in create-spec Stage 0 | **3-of-4 sites held. Concrete-process hypothesis supported.** |
| **OBS-R4-02 chunked-write** (v0.4.2 new) | not yet retested | ✓ Held in 3 places: canvas Stage 1c, tech spec Phase 2, refine edits | **Single principle+example reach behavior cleanly. Round-4's 57m blowup eliminated.** |
| **doctor refactor** (v0.4.3 new) | not yet retested | ✓ Single bash call, plugin version in header, next-action hint surfaced | **UX win delivered as designed. ~25 lines of intermediate noise → ~12.** |

---

## New observations from round 5

### OBS-R5-01 — OBS-01 partial improvement, partial regression in `create-spec` Stage 0

**Type:** behavioral-drift / authoring
**Severity:** Medium
**When:** `create-spec` Stage 0 (parsing strategic spec)
**What happened:** Round 4 made 5 validator calls in Stage 0 (1 raw + 4 piped through `python3 -c`). Round 5 made 2 calls (1 raw + 1 piped through `python3`). The principle+example reframe in v0.4.2 reduced but didn't eliminate the python3-pipe pattern.

**Why partial:** the v0.4.2 reframe principle line is *"the structured JSON output is in your conversation context as the Bash tool result — that's your data source"* — alternative-fact shaped. The GOOD example below it spells out the concrete process (read `project.name`, iterate `groups[]`, count `crossCuttingConcerns.length`), but that's buried inside the example. If Claude's attention skims the principle and skips the example, only the alternative-fact reaches behavior. See OBS-R5-04 below for the cross-skill pattern this reveals.

**Severity rationale:** Medium. The 2-call pattern produces a correct Stage 0 summary at moderate token waste (~20-30s). Not blocking. Worth fixing structurally, not with more prose.

### OBS-R5-02 — OBS-04 partial regression in canvas synthesis (`create-spec` Stage 1a → 1c transition)

**Type:** behavioral-drift / authoring
**Severity:** Low
**When:** Between Stage 1a Explore return and Stage 1c canvas synthesis
**What happened:** Round 4 went straight to `~/dev-projects/ido4specs/skills/create-spec/agents/code-analyzer.md` via the `${CLAUDE_SKILL_DIR}/` path anchor. Round 5 launched **two background filesystem-search commands** ("Locate code-analyzer template anywhere", "Search filesystem for template") despite the same path anchor being present in the SKILL.md. The path-resolved Read also worked successfully in parallel — Claude eventually announced "Template loaded" — but the redundant searches happened anyway.

**Why this matters even though it's low severity:** Round-4 declared OBS-04 "verified" after a single clean run. Round 5 reveals that **single-clean-round is insufficient evidence**. Per-fix variance per-run is real; the right "verified" bar is 3+ clean rounds. See OBS-R5-05 below.

**Severity rationale:** Low. Background searches don't block synthesis; the canvas was produced correctly with content from the path-resolved Read. The cost is wall-clock noise (background processes running) and a credibility ding on the "verified" claim.

### OBS-R5-03 — OBS-08 partial drift in `review-spec`, contained by structural enforcement

**Type:** behavioral-drift / authoring
**Severity:** Low (structural enforcement made it harmless)
**When:** `review-spec` Stage 1b (format compliance review)
**What happened:** Claude attempted a complex grep-pipeline (`grep -nE ... | grep -vE ... | head -20`) for "spot any malformed metadata lines" — exactly the OBS-08 anti-pattern v0.4.1 was designed to prevent. **Because `review-spec`'s `allowed-tools` is `Read, Glob, Grep` (no Bash), the attempt triggered a permission prompt** instead of running silently. The user denied (Option 3), and Claude adapted to in-context inspection without further bash attempts. The resulting Spec Review Report had **higher finding depth than round 4** (4 substantive missing-dep warnings + 3 suggestions vs round 4's 1 + 3).

**Why this is the most useful observation in round 5:** It demonstrates how the prose+structural-enforcement combination from v0.4.1 actually works in practice. The structural enforcement (no-Bash allowed-tools) doesn't *eliminate* drift; it *exposes* drift as user-visible friction. The user becomes the final enforcement layer — and once denied, Claude follows the SKILL.md's prescribed alternative cleanly. Both rounds had the prose; round 5 also had the drift; round 4 happened to not have the drift. **Combination = durable. Either alone = partial.**

**Severity rationale:** Low. End-state was a higher-quality review than round 4. The cost was 1 user click and ~10s wait. The lesson — visible-friction-as-enforcement-layer — is more valuable than the cost.

### OBS-R5-04 — Cognitive complexity calibrates the principle+example shape

**Type:** authoring-discipline insight (not a fix candidate)
**Pattern surfaced across:** synthesize-spec ✓, refine-spec ✓, validate-spec ✓, create-spec Stage 0 ⚠, create-spec Stage 1c chunked-write ✓
**What happened:** Round 5 tested four principle+example reframes from v0.4.2. Three held cleanly (synthesize-spec Stage 1d, refine-spec, validate-spec). One partially regressed (create-spec Stage 0 OBS-01). Plus one new principle (chunked-write in create-spec Stage 1c) held cleanly.

The pattern correlates with **what the principle asks Claude to do**:
- ✓ Held: simple read scope (binary check) OR explicit sequence ("compose, then write," "edit, then validate")
- ⚠ Partial: complex multi-field read with derived calculations (build a table from `groups[]`, count edges, etc.)

**Implication for future authoring:** principle-needs-concrete-process is not enough by itself; for complex reads, the concrete process needs **explicit step-by-step granularity**, not just enumeration of which fields to read. Worth updating `~/dev-projects/ido4-suite/docs/prompt-strategy.md` "Examples over enumeration" section to reflect this nuance once the pattern holds across more rounds and projects. Captured in `feedback_principle_concrete_process.md` memory.

### OBS-R5-05 — "Verified" needs 3+ clean rounds, not 1

**Type:** E2E testing protocol observation
**Severity:** Process improvement, not a fix candidate
**What happened:** Round-4 declared OBS-04 (path anchors) "verified" after a single clean retest. Round 5 showed canvas-synthesis filesystem searches recurred. The fix is real (Phase 2/3a/3b/4 didn't show the pattern) but the canvas-synthesis case re-emerged in round 5.

**Why this matters:** my round-4 "verified" claim was based on insufficient evidence. Per-fix variance per-run is real. The right testing protocol bar is **3+ consecutive clean rounds before declaring "verified."** Single clean rounds should be reported as "held in this run" or "no regression observed," not "verified."

**Action:** When updating CLAUDE.md's E2E Testing Protocol section, add a definitions section distinguishing:
- **Held this run** — 1 clean retest. Insufficient to declare verified; track for future rounds.
- **Holding** — 2 consecutive clean retests. Trending positive but not verified.
- **Verified** — 3+ consecutive clean retests. Safe to deprioritize as a watch item.

This is a process improvement, not a code fix. Worth filing in CLAUDE.md before round 6.

---

## Positives (selected)

### POS-R5-01 through 03 — Doctor refactor (v0.4.3) verified working

- Single Bash invocation (`Bash(bash "/Users/.../skills/doctor/../../scripts/doctor.sh")`) instead of round-4's 8 separate calls
- Plugin version `0.4.3` visible in report header
- Workspace state Check 7 includes `→ next: /ido4specs:create-spec data-connector-spec.md` action hint
- ~25 lines of intermediate raw bash noise → ~12 lines clean formatted report
- Bonus: Claude added context-aware closing (*"Want me to enable the status line, or proceed with /ido4specs:create-spec data-connector-spec.md?"*) — emergent next-step suggestion based on the report's findings

### POS-R5-04 — OBS-R4-02 chunked-write principle held cleanly across the pipeline

Round 4 had Stage 1c canvas synthesis blow up at 57m via chunked Writes. Round 5 had Claude announce *"Single Write call when complete"* in the pre-synthesis message (correct internalization of the v0.4.2 principle), then write 2,214 lines in **one Write call**, **20 minutes**. Same pattern held in synthesize-spec Phase 2 (single Write, 987 lines, 13m 31s) and refine-spec (14 surgical Edit calls, all `Added 1 line, removed 1 line`).

### POS-R5-05 — Two-Explore subagent split, repeated and successful

Round 4 surfaced the "two parallel Explores per target" divergence as a positive judgment call from Claude (ignoring SKILL.md's "one per target" prescription). Round 5 repeated the pattern: a single Explore with 22 tool uses, 79.9k tokens, 1m 40s. (Round 5 actually only spawned ONE Explore this time — earlier I noted two as a round-4 finding; round 5 used a single Explore that ran efficiently.) The `marketplace-analytics-plugin` Explore returned with concrete file paths, SQL excerpts, and the YAML pricing grids — sufficient material for the canvas without needing a second subagent.

### POS-R5-06 — Cross-stage convergence on independent observations

The two-layer validation pattern's promise is independent layers cross-checking. Round 5 demonstrates this concretely:

- `review-spec` Suggestion S3 flagged: *"DCT- ai: full calibration. Nine of ten catalog RPC handlers are marked ai: full... worth particular attention for DCT-07A."*
- `validate-spec` T4 soft note flagged: *"9 of 10 DCT-* RPC handlers are ai: full... Worth particular attention for DCT-07A (upsell_opportunities)."*

Same finding from two independent layers, with the same specific recommendation (DCT-07A → ai: assisted). The architectural intent of the two-layer pattern produces convergent signal.

### POS-R5-07 — Refine-spec efficiency: 14 edits in 1m 24s

Round 5's refine-spec applied 14 surgical depends_on additions in 1m 24s (vs round 4's 4 edits in 1m 37s). Pre-edit plan announcement enumerated all 14 edits transparently. Post-edit ripple surfacing included arithmetic self-verification (*"Edge count: 99 → 117 (+18, matches the count of new deps added: 1+5+1+1+11)"*). 3.5× the edits in similar wall time, with explicit math verification.

### POS-R5-08 — Substantive review-spec findings exceed round 4

Round 4: 1 warning (SMQ-07 size/effort mismatch), 3 suggestions.
Round 5: 4 warnings (all missing-dep findings), 3 suggestions.

The W4 finding alone — *"CRT-04A and DCT-01A through DCT-10A all missing CRT-01C dependency"* — affected 11 tasks and demonstrated genuine cross-task reasoning from in-context inspection. The S2 "soft circularity" observation (OPS-01B description references QAC-03A which depends on OPS-01B) demonstrated reading content for *implicit* dependencies, not just declared ones. Highest review depth across 5 rounds.

---

## Architectural invariants — held across all 5 skills

- ✓ **Parser-as-seam** — every structural validation goes through the bundled `tech-spec-validator.js` or `spec-validator.js`. (OBS-08's "no shell pipelines" prose held with structural backing in round 5; OBS-R5-03 demonstrated the friction-as-enforcement mechanism.)
- ✓ **Methodology neutrality** — no Scrum / Shape-Up / Hydro / sprints / cycles in any skill output across the full pipeline.
- ✓ **Inline execution** — no `Agent(...)` spawns of plugin-defined subagents. Only built-in `Explore` was spawned (in `create-spec` Stage 1a).
- ✓ **Zero runtime coupling** — no `mcp__` calls, no `parse_strategic_spec`, no `ingest_spec`, no `@ido4/mcp` references. The only cross-plugin signal is the `.ido4/project-info.json` filesystem probe (which fired the correct "absent" variant).

---

## Carried watches and resolutions

### Resolved during round 5

- **OBS-R4-02 (chunked-write inefficiency)** — held cleanly in 3 places. Round-4's 57m canvas blowup eliminated. Marked as ✓ for further rounds, but per OBS-R5-05 we want 2+ more clean rounds before declaring "verified."

### Carried to round 6+

- **WATCH-1** — `refine-spec` pre-edit ripple analysis on bigger refines. Round 5's refine-spec announced the 14-edit plan upfront (POS-R5-07) but didn't surface ripple effects pre-edit (just post-edit). Still a watch item.
- **WATCH-3** — doctor parallel-call cancel-and-retry recurrence (round-2 OBS-01). Didn't recur in round 5; ran cleanly as a single bash call (the v0.4.3 refactor changed the mechanism entirely so this watch may be moot now).
- **NEW WATCH (R5)** — Decision-pause variance based on user preamble. Round 3 had it; round 4 didn't (no preamble); round 5 didn't (no preamble). Pattern holds: **the behavior is preamble-dependent, not skill-design-dependent**. Reinforces case for explicit user-profiling at session start (Q1 in design questions).
- **NEW WATCH (R5)** — The Write-tool soft-wrap preview garbling has now appeared in 5 of 5 rounds where canvas + tech spec produce a header + format marker. It's a stable Claude Code display artifact, not a fluke; verified files are clean. Worth filing as a Claude Code platform issue, not an `ido4specs` bug.

---

## Design questions for v0.5+ (extended from e2e-003 and e2e-004)

The questions from prior rounds remain. Round 5 sharpens two and adds two new:

### Q1 (sharpened) — User-profiling at pipeline entry

**Round 5 evidence:** Three rounds of data on decision-pause variance. Round 3 (with preamble) → pause; round 4 (no preamble) → no pause; round 5 (no preamble) → no pause. The behavior is **preamble-dependent**, confirming the case for explicit declaration at session start. Worth elevating from "design question" to "v0.5 candidate work."

### Q8 (sharpened from e2e-004) — When prose drift is observed, build structural enforcement

**Round 5 evidence:** OBS-08 round 5 demonstrated the friction-as-enforcement mechanism concretely — Claude tried a shell pipeline, structural enforcement (no-Bash) converted the attempt into a permission prompt, user denial recovered cleanly. The combination (prose + allowed-tools restriction) is durable; either alone is partial. **For OBS-01's persistent partial regression in create-spec Stage 0, the next move should be a hook-based enforcement layer, not more prose.** Concrete proposal: PostToolUse hook on Bash that detects consecutive `node spec-validator.js` invocations within the same skill execution and warns or blocks the second.

### Q9 (NEW) — "Verified" needs 3+ clean rounds

See OBS-R5-05. Process improvement: update CLAUDE.md's E2E Testing Protocol with the held / holding / verified definitions. Mechanical doc fix.

### Q10 (NEW) — Principle line should carry the concrete process, not just the example

Per OBS-R5-04 and the updated `feedback_principle_concrete_process.md` memory: when reframing prohibitions as principles, the principle line itself should describe the alternative process (or for complex cases, the explicit step-by-step sequence), not just describe state ("the data is here"). Worth updating `~/dev-projects/ido4-suite/docs/prompt-strategy.md` "Examples over enumeration" section once 2+ more rounds confirm the pattern.

---

## Assessment

**Round 5 verdict: v0.4.2's principle+example reframes work in 3-of-4 sites, the v0.4.3 doctor refactor delivers as designed, and the round reveals important calibration about how prose discipline interacts with structural enforcement.**

The 5-skill pipeline produced a correct, structurally-clean, content-asserted, qualitatively-reviewed, edited-and-re-validated technical spec for the same 43-cap strategic spec from rounds 3+4. End-state metrics held. All four architectural invariants held. **The chunked-write principle eliminated round-4's 57m canvas blowup**, saving ~17 min on the pipeline.

The **most diagnostically valuable finding** is the OBS-R5-04 pattern across 5 principle+example reframes: 4 held, 1 partially regressed, and the variable is whether the principle prescribes a concrete process (✓) vs describes state (⚠). This nuance refines the v0.4.2 lesson and points at the right shape for future authoring.

The **second most valuable finding** is OBS-R5-03's demonstration that structural enforcement converts silent drift into user-visible friction. This is the actually-durable mechanism — prose alone (round 4 OBS-08 also drifted partially) without `allowed-tools` backing wouldn't have surfaced the regression for the user to deny.

The **process improvement OBS-R5-05** ("verified" needs 3+ clean rounds) is the third valuable artifact. Round-4's "OBS-04 verified" claim was over-confident based on a single clean run; round 5 showed canvas-synthesis filesystem searches recurred. Future E2E rounds should use the held / holding / verified vocabulary.

**No v0.4.x patch needed** unless round 6 surfaces unexpected issues. v0.4.3's doctor refactor + v0.4.2's principle reframes + v0.4.1's structural fixes are all functioning. The remaining OBS-01 partial regression in create-spec Stage 0 is a candidate for a hook-based enforcement layer in v0.5+, per Q8 and the prose-vs-structural memory.

---

## Next steps

1. **Round 6 retest (recommended).** Fresh test session against `ido4specs` v0.4.3 with `@ido4/spec-format` v0.9.1 bundles. Watch:
   - Whether OBS-04 holds in canvas synthesis (round-5 partial regression test)
   - Whether OBS-01 holds in `create-spec` Stage 0 (round-5 partial regression test)
   - Whether OBS-08 drift recurs in `review-spec` (and whether structural enforcement again contains it)
   - Whether the "principle line should carry concrete process" hypothesis holds (OBS-R5-04 retest with a different spec or pre-loaded test session)

   If 3 fixes hold in round 6 (OBS-09, chunked-write, doctor refactor), they reach the verified bar from OBS-R5-05.

2. **No v0.4.x patch needed.** All current fixes are functioning. The OBS-01 partial regression and OBS-04 partial regression are real but not blocking. Their fix candidates are structural (hooks, allowed-tools tightening) — v0.5+ work.

3. **Carry watches to round 6+:**
   - WATCH-1 (refine-spec pre-edit ripple analysis on bigger refines)
   - WATCH-3 (doctor parallel-call recurrence — likely moot post-v0.4.3 refactor)
   - NEW WATCH (decision-pause variance based on user preamble — 3 rounds of evidence)
   - NEW WATCH (Write-tool soft-wrap preview garbling — 5 rounds of evidence; Claude Code platform issue)

4. **Memory captures filed:**
   - `feedback_consult_prompt_strategy_first.md` — read prompt-strategy.md before any skill prose change (round 4)
   - `feedback_prose_vs_structural_enforcement.md` — prose alone drifts; combination with allowed-tools is durable (round 4)
   - `feedback_principle_concrete_process.md` — principle line should prescribe a concrete sequence, especially for complex multi-step reads (round 4 hypothesis, round 5 reinforced with 5 data points)

5. **Process improvement to file:** update CLAUDE.md's E2E Testing Protocol with the held / holding / verified definitions per OBS-R5-05. Mechanical doc fix, ~5 lines.

6. **Audit habit reinforcement (carried from e2e-004 and reinforced).** OBS-09 was caught by user in round 3. The prompt-strategy.md violation in v0.4.1 was caught by user in round 4. Round 5 didn't have a similar user-catches-author-omission moment, but the pattern holds: my self-audit catches per-skill issues but misses cross-skill / cross-doc / cross-round consistency. The "3+ clean rounds before verified" bar is itself a calibration against this — single-round optimism is a recurring author bias.
