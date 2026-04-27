# E2E Test Report — Modus Data Connector (round 3)

**Round:** 3
**Date:** 2026-04-27
**Project:** `~/dev-projects/PS-metabase-connector/` (greenfield, no source code yet)
**Strategic spec:** `data-connector-spec.md` (43 capabilities, 8 groups, 61 dependency edges, 47 cross-group, max depth 5)
**Plugin version:** `ido4specs` at v0.4.0 (post-spec-quality-skill addition); both bundled validators at `0.8.0`
**Skills exercised:** `/ido4specs:create-spec`, `/ido4specs:synthesize-spec`, `/ido4specs:review-spec`, `/ido4specs:refine-spec`, `/ido4specs:validate-spec`. Full 5-skill pipeline. (`doctor` not exercised.)
**Monitor session:** Separate Claude Code session in `~/dev-projects/ido4specs/`, evaluating against skill/agent definitions in `skills/` and `agents/`.
**Test character:** Larger spec than rounds 1–2 (43 caps vs round 1's 25), greenfield-with-context mode (round 1+2 were similar but smaller), full pipeline including `refine-spec` (rounds 1–2 deferred it). First round to surface a depth issue with `review-spec`'s mechanism, validated alongside `validate-spec`'s pattern as the model for the fix.

---

## Pipeline Summary

| Phase | Skill | Time | Verdict | Friction |
|---|---|---|---|---|
| 1 | `create-spec` | ~26 min | PASS | 2 background filesystem searches (OBS-04); validator inspection loop in Stage 0 (OBS-01) |
| 2 | `synthesize-spec` | ~13 min | PASS | None |
| 3a | `review-spec` | ~6 min | PASS WITH WARNINGS (0E/2W/3S) | **4 permission prompts** (OBS-08) |
| 4 | `refine-spec` | ~36 sec | PASS | First validator call failed via OBS-01 pipe pattern, recovered |
| 3b | `validate-spec` | ~1m 31s | PASS | None |
| **Total** | — | **~47 min** | All artifacts clean end-state | 4 prompts + 2 searches |

**Artifacts produced:**
- `specs/data-connector-tech-canvas.md` (2,440 lines, 21,919 words, 43 `## Capability:` sections)
- `specs/data-connector-tech-spec.md` (1,001 lines, 43 caps, 59 tasks, 112 dep edges after refine, 205 success conditions, max depth 6)

**End-state metrics (post-refine-spec):**
- Validator: 0 errors, 0 warnings (`@ido4/tech-spec-format@0.8.0`)
- T0–T8 content assertions: all green
- Effort: 38 S / 20 M / 1 L / 0 XL
- Risk: 34 low / 22 medium / 3 high / 0 critical
- AI: 24 full / 21 assisted / 14 pair / 0 human
- 8 root tasks (parallelizable), 5 hub tasks (most-depended-upon: QAC-01B 12, SEC-01A 12, CRT-04A 11, CRT-03A 11, CRT-01A 8)

---

## Observations

### OBS-01 — Quality issue — Medium

**Type:** quality-issue / efficiency
**When:** `create-spec` Stage 0 (parsing strategic spec); `refine-spec` post-edit auto-revalidation
**What happened:** Claude invokes the bundled validator and pipes stdout through `python3 -c "import json,sys; ..."` to inspect different fields of the JSON output. In `create-spec` Stage 0, this pattern repeats **5 times in succession** (each call regenerates the full 211-line JSON) to extract: top-level keys, group counts, group listing, dep graph keys, cross-group edges. In `refine-spec`, the same pattern fails on first attempt with a Python `json.load` traceback, then succeeds on a clean retry without the pipe.

**What was expected:** Per `skills/create-spec/SKILL.md:60-77`, Stage 0 says "Parse the JSON output" and "Present the Stage 0 summary." The natural read is one validator call, parse once, present. The validator's stdout JSON is structured and complete on first call — Claude has it in conversation context already.

**Evidence:**
- 5 successive `node spec-validator.js … 2>&1 | python3 -c "import json,sys…"` blocks in Stage 0 trace
- `(3m 40s · ↓ 6.1k tokens)` consumed entirely by Stage 0
- `refine-spec` first validator call: `File "<string>", line 3, in <module> ... File "/Library/Frameworks/Python.framework/Versions/3.12/lib/python3.12/json/__init__.py", line 293, in load`
- `refine-spec` second call (clean): `exit=0 / valid: True / errors: 0`

**Fix candidate:**
- `skills/create-spec/SKILL.md` Stage 0 step 2: spell out the JSON paths to read for the user-facing summary (e.g., `meta.projectName`, `groups[].caps.length`, `metrics.totalEdges`, `metrics.crossGroupEdges`, `metrics.maxDepth`) so Claude doesn't have to explore the schema empirically. Or instruct: "capture the validator output to a file or variable, then inspect once — do not re-run the validator multiple times to extract different fields."
- `skills/refine-spec/SKILL.md` post-edit revalidation step: instruct Claude to run the validator without piping through python3.
- `skills/synthesize-spec/SKILL.md` Stage 1d: trace did not show the python pipe here, but the same instruction would harden the skill.

**Severity rationale:** Medium. ~3 min wasted in Stage 0 of every `create-spec` run + occasional retry latency in `refine-spec`. Doesn't affect correctness; affects user-perceived time.

---

### OBS-04 — Authoring bug — Medium

**Type:** authoring / bug
**When:** Skill body references to plugin-defined agent files
**What happened:** Three skill bodies reference their agent files with bare relative paths (no `${CLAUDE_SKILL_DIR}/` prefix). Claude has no path-resolution rule for those paths and falls back to filesystem searches.

In the round 3 trace, `create-spec` triggered **two background filesystem searches** for `code-analyzer.md`:
- `Background command "Search user home for code-analyzer.md" completed (exit code 0)`
- `Background command "Search filesystem for code-analyzer.md" completed (exit code 0)`

`synthesize-spec` did not show a visible search in this run (path-resolution may have worked heuristically, or the search ran silently), but the same authoring issue exists in its SKILL.md.

**What was expected:** Per CLAUDE.md *Authoring Conventions*: "Describe intent for paths instead of literal relative paths in skill bodies; use `${CLAUDE_SKILL_DIR}` for within-skill references."

**Evidence:** Bare relative paths confirmed in:
- `skills/create-spec/SKILL.md:151` — `agents/code-analyzer.md`
- `skills/synthesize-spec/SKILL.md:59` and `:84` — `agents/technical-spec-writer.md`
- `skills/review-spec/SKILL.md:16, 51, 68, 83, 107` — `agents/spec-reviewer.md` (5 references)

**Fix candidate:** Mechanical replacement — add `${CLAUDE_SKILL_DIR}/` prefix to every bare reference to `agents/*.md` in the three skill bodies. Eight references total across the three files.

**Severity rationale:** Medium. Wastes time per run and is fragile (could find the wrong file if duplicates exist). Conflicts with documented authoring convention. Mechanical fix.

---

### OBS-08 — Architectural concern — High

**Type:** architectural-violation / ux-issue
**When:** `review-spec` Stage 1 (format compliance + quality assessment + downstream awareness)
**What happened:** `review-spec` ran **4 permission prompts** in succession during one run — each for a different multi-line bash script doing structural extraction (header survey, effort/risk/type/ai distribution, per-task `ai: human` and `risk: critical` enumeration, dep graph hub-task analysis). Each script runs grep / awk / sort / uniq pipelines to derive metrics that the bundled validator's JSON output already provides directly.

The fourth prompt's awk script computed task-description char counts by assuming descriptions live "between `> depends_on:` and `**Success conditions:**`" — a layout-dependent assumption that replicates structural-parsing work `@ido4/tech-spec-format` already does correctly.

**What was expected:** Per CLAUDE.md, `review-spec` is "Layer 2 of the two-layer validation pattern — independent LLM-driven review, not the bundled validator." The natural read: the LLM reads the spec content + validator's structured JSON output, applies qualitative judgment on top, produces the report.

**The deeper issue:** "Independent" is being interpreted as "independent of the validator's structural output," pushing `review-spec` to reinvent structural extraction via shell. The right interpretation should be: **independent of the validator's *judgment*** (deterministic checks vs nuanced quality review), but free to *consume* the validator's structured metadata.

**Evidence:**
- 4 permission prompts in the trace, each on a different bash command
- Each prompt's "Yes don't ask again" allowlist would not generalize (next run would re-prompt with different commands)
- `validate-spec` in the same session, on the same spec, ran the **same metadata analysis** with **zero shell pipelines and zero permission prompts** — using the validator JSON output and in-context spec content directly. Total time: 1m 31s vs `review-spec`'s 5m 43s.

**Fix candidate:** Update `skills/review-spec/SKILL.md` to mirror `validate-spec`'s pattern. Concrete language:

> At the start of Stage 1, run the bundled `tech-spec-validator.js` once and capture its JSON output. Use the structured metadata (effort/risk/type/ai distributions, description lengths, dependency edges, success-condition counts, root tasks, hub tasks) for objective measurements — this is the same pattern `validate-spec` uses. Apply your independent qualitative judgment on top of those numbers — descriptions code-grounded? success conditions verifiable? metadata calibrated to canvas complexity? capability coherence? Do not run grep/awk/shell pipelines to enumerate metadata distributions; the validator already provides them.

**Tradeoff:** Layer 2 becomes less *literally* independent of the validator. But the architectural bet was always parser-as-seam — the parser is the single source of truth for structure. Layer 2 should layer judgment on top, not duplicate the parser's job poorly. The fix preserves all the substantive findings from this round (W1, W2, S1-S3, downstream notes, dep graph) — those came from LLM judgment over the spec content, not from the shell pipelines.

**Severity rationale:** High. Most user-visible friction in the pipeline. Affects every `review-spec` run on every project. Reinforces a misreading of "Layer 2 independent" that could spread to other prompt patterns. Fix candidate is concrete and `validate-spec` already demonstrates the target.

---

### OBS-09 — Design gap — Medium

**Type:** design-gap
**When:** End-of-phase messages across `synthesize-spec`, `review-spec`, `refine-spec`
**What happened:** None of the three skills that run *after* a tech spec exists mention `validate-spec` in their cross-reference messages. A user following the in-skill suggestions would never naturally encounter `validate-spec`.

| Skill | End-message points to | Mentions validate-spec? |
|---|---|---|
| `create-spec` | `synthesize-spec` | N/A (no spec yet) |
| `synthesize-spec` | `review-spec`, `refine-spec` | ❌ No |
| `review-spec` (verdict question) | `refine-spec` (or proceed) | ❌ No |
| `refine-spec` | `review-spec` | ❌ No |
| `validate-spec` | `review-spec` | (correctly suggests review-spec) |

**What was expected:** `validate-spec` provides the **8 content assertions T0–T8** that no other skill runs. Per CLAUDE.md, it's "Layer 1 of the two-layer validation pattern." For the two-layer pattern to deliver value, users need to run *both* layers — but the prescribed end-messages only surface Layer 2 (`review-spec`).

**Evidence (in this round):** The user — who knew about `validate-spec` from rounds 1–2 — explicitly asked "but it seems that /ido4specs:validate-spec wasn't suggested at the end of previous steps... am I wrong?" The skill is genuinely orphaned in the in-product navigation.

**Why this matters technically:**
- `synthesize-spec` Stage 1d auto-runs the bundled parser → that's a structural smoke test, not the T0–T8 layer
- `review-spec` is the LLM-driven qualitative review → it does its own analysis but does not run the deterministic T0–T8 checks
- `refine-spec` re-runs the bundled parser after edits → smoke test again, not T0–T8

T0–T8 (description quality, success-condition specificity, metadata calibration, single-task-cap relaxation, etc.) is **unique to `validate-spec`**.

**Fix candidate:** Update three SKILL.md end-message templates to surface `validate-spec` as a peer to `review-spec`:

- `skills/synthesize-spec/SKILL.md:161` — add validate-spec as a third option:
  > Review it, then run `/ido4specs:review-spec ...` for qualitative review, `/ido4specs:validate-spec ...` for deterministic content checks (T0–T8), or `/ido4specs:refine-spec ...` to edit.
- `skills/review-spec/SKILL.md` (closing prompt for PASS / PASS WITH WARNINGS):
  > ... or run `/ido4specs:validate-spec` if you want the deterministic content-assertion pass too.
- `skills/refine-spec/SKILL.md` end-message:
  > Consider `/ido4specs:review-spec` for qualitative review or `/ido4specs:validate-spec` for the content-assertion layer if you want fresh checks on the patched spec.

Or more architecturally — frame `validate-spec` and `review-spec` as paired Phase-3 entry points consistently across all three predecessor skills' end-messages. The current asymmetry silently devalues Layer 1.

**Severity rationale:** Medium. Skill is functional but not discoverable. Could explain why earlier rounds also under-exercised it. Mechanical fix.

---

### Watch items (not OBS, no fix yet)

**WATCH-1 — Pre-edit vs post-edit ripple-effect surfacing in `refine-spec`.** CLAUDE.md says `refine-spec` should "surface ripple effects before making changes." Round 3's edits were small (add 3 deps to fix 2 named warnings) and Claude applied them first, then surfaced ripples in the summary. Fine for this case; unverified for larger refine requests (e.g., "split capability X into two"). Watch in future rounds.

**WATCH-2 — `synthesize-spec` filesystem search for agent file.** The trace did not show a `Search filesystem for technical-spec-writer.md` background command (compare to `create-spec`'s 2 searches for `code-analyzer.md`). May be that path-resolution heuristically worked, or the search happened silently. OBS-04 fix would resolve regardless.

**WATCH-3 — `doctor` parallel-call cancel-and-retry pattern from round 2 OBS-01.** Not exercised this round (`doctor` not run). Carry forward to round 4+ if `doctor` is exercised.

---

## Positives (selected — full set is POS-01 through POS-27)

### Architectural invariants — held end-to-end across all 5 skills

- ✓ **Parser-as-seam** — every structural validation goes through the bundled `tech-spec-validator.js` or `spec-validator.js`. No back-channel parser calls, no reimplemented checks. (One caveat: `review-spec`'s shell pipelines reimplement structural extraction — that's OBS-08, the only invariant under stress.)
- ✓ **Methodology neutrality** — no Scrum / Shape-Up / Hydro / sprints / cycles / containers / methodology profiles in any skill output. The S1 suggestion in the review report specifically said *"the spec preserves the strategic-capability hierarchy for traceability"* — methodology-neutral framing of what could've been a "should this be a Hill / Pitch / Scope?" question.
- ✓ **Inline execution** — `code-analyzer.md`, `technical-spec-writer.md`, `spec-reviewer.md` all read inline by main Claude. No `Agent(code-analyzer)` / `Agent(technical-spec-writer)` / `Agent(spec-reviewer)` spawns. Only built-in `Explore` was spawned (in `create-spec` Stage 1a, 1 target, 32 tool uses, 87.5k tokens, 3m 26s).
- ✓ **Zero runtime coupling** — no `mcp__` calls, no `parse_strategic_spec`, no `ingest_spec`, no `@ido4/mcp` references. The only cross-plugin signal is the `.ido4/project-info.json` filesystem probe in the cross-sell footer (which fired the correct "absent" variant — the install-ido4dev message — since the workspace has no marker).

### POS-04 — "Ask, give it a beat, then resume with justification" pattern

Claude paused at the end of Stage 0.5 ("Awaiting your call on integration targets"), waited a beat, then self-resumed with explicit justification: *"Proceeding — the target is clear and your earlier instruction was to use judgment."* This calibrated against the user's preamble ("ask me only when is unclear" + "use your own skills") better than a hard block-on-input would have. Worth considering whether to formalize this in `create-spec` Stage 1a as a soft pause specifically in `greenfield-with-context` mode where target identification is the model's most likely miss.

### POS-05 — Proactive D-reference enrichment for context preservation

Between Stage 1a and 1c, Claude noted: *"Let me also pull the D-references (D-001..D-020) that the strategic spec cites repeatedly but doesn't restate, so the canvas is self-sufficient for Phase 2."* The strategic spec referenced decisions externally; a literal verbatim-only canvas would carry forward dangling refs that Phase 2 couldn't resolve. This is the inline-execution architectural bet paying out — main Claude has the strategic-spec text, Stage 1a Explore returns, and the SKILL.md emphasis on context preservation all in one place. A forked subagent context wouldn't have made the connection.

### POS-13 — Risk strands flagged unprompted at synthesis time

Stage 1c of `synthesize-spec` surfaced 5 specific synthesis-time observations the user can act on (DCT-07 + SMQ-06 + WHF-03 highest-risk strand, QAC-01A research spike with #159 canary, SEC-02 re-cut risk, TLS/network-policy as infra-not-Python, 5 research tasks). Same strand was independently re-surfaced as Suggestion S2 in `review-spec`'s report — Phase 2 and Phase 3 reviewer agree on the v1 risk concentration without drift.

### POS-15 — Both review-spec warnings evidence-backed and code-grounded

W1 (DCT-01A missing CRT-03A and SEC-01A in depends_on) was derived from DCT-01A's *own description text* — *"Returns Response[CatalogDescription] per CRT-03's envelope"* and *"Required scope: general (every authenticated consumer can discover)"* — then confirmed by sibling-pattern check across all other DCT-* RPCs. W2 (OPS-06A missing CRT-02B) followed the same evidence pattern. Both warnings came from substantive review work; the user fixed both with surgical `refine-spec` edits.

### POS-22 — Refine-spec ripple-effect framing distinguishes structural change from risk change

Post-edit summary: *"Dependency edges: 109 → 112 (+3, matches the three added refs). Max dep depth: 5 → 6. The original critical path via the SMQ-06 / DCT-07 strand still dominates risk-wise; the depth increase is purely accounting."* Naive ripple surfacing would alarm the user about depth increase; this one separates **graph-structure change** from **risk-profile change**. Right interpretive frame.

### POS-25 — `validate-spec` demonstrates the OBS-08 fix in action

`validate-spec` ran one bash call (the bundled validator), parsed the JSON output in conversation context, and produced its entire T0–T8 analysis without any shell pipelines or permission prompts. **Total time: 1m 31s.** This is the model `review-spec`'s redesign should target. The fix candidate I sketched ("consume validator JSON, layer judgment on top") is not speculative — it's how `validate-spec` already works.

### POS-27 — T8 (1–8) relaxation durable across 3 rounds

Round 1: 3 T8 false-positives on single-task M-effort caps (later identified as architecturally justified). Round 2 (post-v0.2.0 fix): 0 T8 warnings. Round 3 (this run): 0 T8 warnings + the relaxation clause cited inline in `validate-spec`'s output: *"not a violation per T8's 'well-scoped strategic capabilities often decompose into exactly one coherent implementation task' clause."* The fix is durable, well-understood, and self-explaining.

---

## Resolved during round (not in final OBS list)

- **OBS-02** — KeyError recovery in Stage 0 schema exploration. Subsumed by OBS-01 fix.
- **OBS-03** — Stage 0 took ~3m 40s. Caused by OBS-01; fix resolves.
- **OBS-05** — Duration advisory calibration concern. Actual time fell within the prescribed 10–25 min range (18m 57s for 43 caps). Calibration is fine.
- **OBS-06** — Canvas header appeared malformed in Write tool preview (`> Source: ./data-connector-spec.mdnector`). Verified via direct file read: file is clean (`> Source: ./data-connector-spec.md`). Write tool preview soft-wrap concatenation artifact, not a real bug.
- **OBS-07** — Tech spec format marker appeared malformed in Write tool preview (`> format: tech-spec | version: 1.0 Spec`). Verified via direct file read: file is clean (`> format: tech-spec | version: 1.0`). Same Write tool preview artifact pattern.

---

## Assessment

**Round 3 verdict: pipeline is production-functional, with one architectural concern and one design gap to address before v0.5.0.**

The 5-skill pipeline produced a correct, structurally-clean, content-asserted, qualitatively-reviewed, edited-and-re-validated technical spec for a 43-cap / 59-task / 112-edge greenfield-with-context project in ~47 minutes. End-to-end metric coherence (root tasks, hub counts, critical path) was preserved across phases. T8 relaxation worked as intended on a 29-single-task-cap spec. All four architectural invariants held.

**However**, two issues now warrant a v0.3.x or v0.5.0 patch:

1. **OBS-08 (High)** — `review-spec`'s shell-pipeline metadata extraction creates 4 permission prompts per run, replicates parser work poorly (fragile awk on description char counts), and stresses the parser-as-seam invariant. `validate-spec` demonstrates the target pattern with zero friction. Fix is concrete: instruct `review-spec` to consume validator JSON for measurements and layer judgment on top.

2. **OBS-09 (Medium)** — `validate-spec` is orphaned in the skill cross-reference graph. None of the three predecessor skills' end-messages mention it. The two-layer validation pattern's value depends on users running both layers; the in-product paths only surface one. Mechanical fix in three SKILL.md end-message templates.

Two smaller items round out the patch:

3. **OBS-04 (Medium)** — Bare relative paths to agent files in three skill bodies. Mechanical fix: add `${CLAUDE_SKILL_DIR}/` prefix to 8 references.
4. **OBS-01 (Medium)** — Validator-pipe-through-python3 anti-pattern in `create-spec` Stage 0 (5 redundant calls) and `refine-spec` post-edit revalidation (one fail-then-recover). Spell out JSON paths in `create-spec` Stage 0; instruct `refine-spec` not to pipe through python3.

None of the four observations is a correctness issue. The end-state spec is clean. The fixes target *user-perceived friction*, *architectural consistency*, and *skill discoverability*.

---

## Next steps

1. **Patch OBS-04, OBS-09, OBS-01** in v0.3.x or fold into next minor release. Mechanical, low-risk, no parser or validator changes needed.
2. **Patch OBS-08** as a focused redesign of `skills/review-spec/SKILL.md`. Prescribe consuming validator JSON for measurement; preserve the LLM-driven qualitative judgment. Use `validate-spec`'s pattern as the reference. Run `bash tests/validate-plugin.sh` after the patch (the language-hygiene and methodology-neutrality guards should pass unchanged).
3. **Round 4** — once OBS-08 is patched, re-run `review-spec` on a similar-size spec to verify the redesign preserves report depth (W1/W2-style evidence-backed warnings, S1–S3-style suggestions, hub-task / root-task / critical-path coverage in Downstream Notes + Dep Graph) without the permission-prompt friction.
4. **Carry watch items** WATCH-1 (refine-spec pre-edit ripple analysis on bigger refines), WATCH-3 (doctor parallel-call cancel-and-retry recurrence) into round 4+.
5. **Audit habit** — for every E2E round, audit cross-skill navigation graph completeness (each skill's end-message → which other skills?) in addition to per-skill end-message verification. OBS-09 was caught by the user, not me, in this round.

---

## Design questions for v0.5+ (not fixes — future-iteration backlog)

These are structural questions the round 3 retro surfaced that don't fit the per-OBS frame. They're design conversations, not patches. Captured here so they don't evaporate between rounds.

### Q1 — User-profiling at pipeline entry

**The question:** The agent's adherence to a user's interaction preferences is currently *implicit*. In round 3, the user prefaced with *"involve me in decision-making… ask only when unclear."* The agent calibrated against that preamble correctly at one point (Stage 0.5 target-confirmation pause) but not at others (4 tool-permission prompts in `review-spec`, no surface of the "no technical-only capabilities" architectural decision, single-pass `refine-spec` edit batching). The preamble was a soft signal across a 47-minute session and predictably decayed.

**The proposal:** A `SessionStart` or `create-spec` Stage 0 prompt asking the user to declare interaction posture once, explicitly. Three plausible modes:

- **Driver** — autonomous run end-to-end, stop only on real findings (dep cycles, missing context, validator failures)
- **Co-pilot** — pause at architectural decision points (tech-only-cap creation, target identification, batching of refine edits, branch in mode detection)
- **Inspector** — confirm before tool actions, including bash beyond the bundled validators

Skills then calibrate decision-pause density and tool-permission posture from that signal. Mode is sticky for the session but overridable mid-flight.

**Why this matters more than per-OBS fixes:** OBS-08 is *one symptom* of the bigger issue — the agent doesn't know what kind of user it has. Fixing OBS-08 in `review-spec` patches one skill; profiling fixes the *class*. A future skill added to the pipeline would inherit the profile signal automatically.

**Open design points:**
- Where to declare the mode (SessionStart vs first-skill prompt vs CLAUDE.md project-level setting)
- How modes interact with Claude Code's existing `acceptEdits` / `bypassPermissions` settings
- Whether modes are documented per-skill (each skill says "in driver mode I do X, in inspector mode I do Y") or pipeline-global
- Whether the mode is queryable by skills (e.g., a `${CLAUDE_INTERACTION_MODE}` env var the SessionStart hook sets)

### Q2 — Two-layer validation framing is muddier than the design

**The question:** `validate-spec` (Layer 1+) and `review-spec` (Layer 2) are supposed to be *independent* validation layers. In practice they converge to nearly the same output (same hub tasks, same critical path, same risk-strand identification, similar metric tables) and diverge only by *mechanism* (parser-driven vs LLM-driven shell pipelines). That's a tooling difference, not a value difference.

**Two paths:**

- **(a) Merge** — Fold T0–T8 into `synthesize-spec` Stage 1d so structural validation always = parser + T0–T8. `validate-spec` becomes a re-validator after manual edits (parallel to `refine-spec`'s post-edit revalidation). `review-spec` carries the qualitative-judgment work. Two skills with sharper concerns.
- **(b) Separate harder** — Keep both. Sharpen `review-spec` to focus on *narrative-grade* judgment (does this read well? are stakeholders attributed at the right depth? are descriptions actionable for the team?). `validate-spec` carries metrics + assertions. Each layer has a distinct value proposition the user can articulate.

OBS-08's redesign moves toward (b). The deeper question is whether to also do (a), which would simplify the pipeline.

**Why this matters:** The current state is the worst of both — overlapping concerns, asymmetric discoverability (OBS-09), 4× friction in `review-spec` from "must be independent of validator" being misread as "must reimplement structural extraction."

### Q3 — Pipeline orchestrator skill (or `--through` flag)

**The question:** The current pipeline is 5 separate user-invoked skills with explicit human-in-the-loop checkpoints between each. That's right for first-time users and high-stakes specs. It's heavy for a returning user who already trusts the pipeline and just wants to get from `data-connector-spec.md` to `data-connector-tech-spec.md` with the boring parts skipped.

**Proposal options:**

- **(a) Orchestrator skill** — `/ido4specs:run` (or `/ido4specs:pipeline`) takes a strategic spec path, runs `create-spec → synthesize-spec → validate-spec → review-spec` end-to-end, stops only on real findings (canvas incomplete, validator errors, review warnings).
- **(b) `--through` flag on individual skills** — `/ido4specs:create-spec foo.md --through synthesize` runs Phase 1 + Phase 2 with one approval. `--through review` runs the lot.
- **(c) Mode-driven** — driver mode (Q1) implicitly enables auto-progression; co-pilot keeps the manual checkpoints.

(c) is the most elegant if Q1 lands. (b) is the cheapest. (a) is the most explicit.

### Q4 — `create-spec` is doing two distinct things

**The observation:** Stage 0 (parse strategic spec) and Stages 1a–d (codebase / integration-target analysis + canvas synthesis) have wildly asymmetric time profiles — seconds vs ~25 minutes. The natural review checkpoint is *between* them. In round 3, Stage 0.5's target-confirmation pause effectively *was* that checkpoint, but it's not formally framed that way.

**Possible split:**
- `/ido4specs:parse-spec foo.md` — Stage 0 + Stage 0.5 only (parse + mode + artifact dir + target identification). Outputs a parse summary; suggests targets if greenfield-with-context. Sub-minute runtime.
- `/ido4specs:create-spec foo.md` (or `/ido4specs:analyze`) — Stages 1a–d, given the parse + targets are settled.

**Tradeoff:** More skills to remember and surface. Probably not worth doing standalone — but it's the kind of thing that would feel natural inside an orchestrator (Q3) where the user invokes one thing and sees stage transitions.

### Q5 — Cross-sell footer at every phase boundary

**The question:** Each skill's end-message includes the cross-sell footer (`To turn this spec into GitHub issues: install ido4dev…`). That's correct for the *terminal* phase (a spec is ready and ingestion is the next move) but it appears on *every* phase boundary, including ones where ingestion isn't yet meaningful (canvas-only, mid-refine).

**Worth thinking about:** Should the cross-sell only fire when the artifact is *ingestion-ready* — e.g., `synthesize-spec` PASS, `validate-spec` PASS, `refine-spec` PASS post-revalidation? It currently fires from `validate-spec` and `synthesize-spec` and `refine-spec`. Probably right, but worth a sanity audit — does the canvas-only end-message in `create-spec` mention ido4dev? (No, currently — good. So the rule is implicit; worth making explicit in CLAUDE.md.)

---

These five questions don't have right answers yet. They're design conversations for after v0.4.x patch lands and we've seen round 4's data on whether OBS-08's mechanical fix is sufficient.
