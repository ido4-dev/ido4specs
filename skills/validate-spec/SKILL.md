---
name: validate-spec
description: >
  Validates a technical spec artifact for format compliance and content quality.
  Two-pass: deterministic structural check via the bundled @ido4/tech-spec-format
  parser, then qualitative content assertions. Returns PASS / PASS WITH WARNINGS
  / FAIL with line-referenced findings. Use when the user says "validate the spec",
  "check the tech spec", "is this ready for ingest", "verify the spec", or wants
  to confirm a -tech-spec.md before handing it downstream. Pass the file path as
  argument: /ido4specs:validate-spec specs/notification-system-tech-spec.md
allowed-tools: Read, Glob, Grep, Bash
---

## What to validate

Look for technical spec artifacts (`*-tech-spec.md`) in the project's `specs/` or `docs/specs/` directory. If a path was passed as `$ARGUMENTS`, use that. If the path doesn't end in `-tech-spec.md`, warn the user — the file may be a strategic spec (`-strategic-spec.md` or `-spec.md`) that belongs upstream in `/ido4shape:validate-spec`, not here.

## Two-pass validation

This skill performs validation in two passes. Both passes are required.

### Pass 1 — Structural validation (deterministic)

Run the bundled technical-spec parser against the artifact:

```bash
node "${CLAUDE_PLUGIN_DATA}/tech-spec-validator.js" <path-to-tech-spec.md>
```

The parser outputs JSON to stdout. Parse it and use the full output for intelligent interpretation. If the CLI is not available (file not found or node error), note it in the report and skip this pass — do not attempt to replicate the parser's structural checks manually. The whole point is deterministic validation.

#### Interpreting parser output

Diagnose errors, don't just relay them. Every error has a root cause and a specific fix.

**Broken `depends_on` references** (`depends on "X" which does not exist`):
- Look at the `tasks` array in the parser output to find which task IDs DO exist
- Infer the intended target from the broken ref's prefix and the task's description
- Example: `NCO-03B` depends on `NCO-99` — look at existing `NCO-*` tasks, read `NCO-03B`'s description, suggest the correct dependency

**Circular dependencies** (`Circular dependency detected: A → B → A`):
- Read each task description to understand the intended data or control flow
- Identify which dependency direction is wrong — usually the one that reverses the natural flow (migration before service, types before consumers, infrastructure before features)
- Suggest which specific edge to remove and why

**Duplicate task refs** (`Duplicate task ref: X`):
- Identify both tasks with the same ref
- Suggest renaming the second one — derive the next available letter suffix (`NCO-03A` → `NCO-03B`) or integer (`NCO-03` → `NCO-04`) depending on the existing pattern

**Missing format marker**:
- The file is missing `> format: tech-spec | version: 1.0` in the project header block
- Show what the line should look like and where it goes (first `>` line after the `# Project Name` heading)

**Invalid metadata values** (wrong effort, risk, type, ai, unknown keys):
- Show the allowed values: `effort: S|M|L|XL`, `risk: low|medium|high|critical`, `type: feature|bug|research|infrastructure`, `ai: full|assisted|pair|human`
- If the value is close to a valid one (`"cricital"` vs `"critical"`), suggest the correct spelling
- If strategic-level keys appear (`priority`, capability-level metadata that belongs to strategic specs only), explain these belong in the strategic spec, not the technical spec

**Task ref pattern violations** (doesn't match `[A-Z]{2,5}-\d{2,3}[A-Z]?`):
- Show the pattern
- Note that suffixed refs like `NCO-01A` are valid (they trace sub-tasks to their strategic capability), unsuffixed like `NCO-01` are valid, but lowercase or non-hyphen patterns are not

**Metric anomalies** — interpret the `metrics` object:
- Empty capabilities (declared but no tasks): likely incomplete decomposition
- Orphan tasks (outside any capability): need a home
- Unbalanced capabilities (one has 8 tasks, another has 1): consider merging the small one or splitting the large one
- Max dependency depth > 4: deep chains make execution sequencing painful — look for parallelization opportunities
- Zero dependency edges with many tasks: suspicious for a real system — infrastructure tasks usually have dependents

### Pass 2 — Content quality (LLM judgment)

Read the spec file directly. Apply assertions about whether the content is fit for downstream ingestion — an automated executor that will read this spec, consume each task as a unit of work, and produce code. Each assertion is binary: satisfied or violated. Violations escalate to **FAIL** when they would break downstream execution, **WARNING** when they degrade usefulness without breaking it.

Pass 1 (parser) guards structure and presence. Pass 2 (this) guards substance. No character thresholds, no counting — assertions are answered by reading the spec as a downstream executor would.

#### Project-level assertions

**T0. Project description carries WHY + constraints + stakes.** A downstream reader with no other context should understand what problem this addresses, what must not change, and what the stakes are.
- Violated → **FAIL** when: single summary sentence, no constraints, no problem framing
- Violated → **WARNING** when: present but thin on constraints or stakes

#### Task-level assertions

For each task, read its description, metadata, success conditions, and dependencies.

**T1. Task descriptions are code-grounded.** Descriptions reference real file paths, services, modules, or architectural patterns. A technical spec that reads like a strategic spec (pure outcome language, no code citations) is not decomposed enough.
- Violated → **FAIL** when: descriptions are pure title restatement with no codebase reference
- Violated → **WARNING** when: some tasks grounded, others vague

**T2. Effort estimates traceable to complexity assessment.** Effort values (S/M/L/XL) reflect the complexity the canvas described — established patterns are S or M, new patterns are L, architectural changes are XL. Guessed effort produces bad planning.
- Violated → **WARNING** when: metadata seems pulled from thin air with no canvas linkage

**T3. Risk labels reflect real unknowns.** Risk labels (low/medium/high/critical) reflect genuine uncertainty — coupling, test coverage, integration surface, new technology — not code-complexity or feature-novelty confusion.
- Violated → **WARNING** when: risk seems miscalibrated (critical on a boilerplate task, low on an unclear integration)

**T4. `ai` suitability calibrated.** External integrations should rarely be `ai: full` (they depend on external contracts the agent can't verify). Schema definitions and boilerplate often can be `ai: full`. Architectural decisions are `ai: pair` or `ai: human`. Review decisions are `ai: human`.
- Violated → **WARNING** when: `ai: full` appears on clearly human-judgment tasks, or `ai: human` appears on clearly automatable work

**T5. Success conditions are code-verifiable.** Conditions are specific, independently testable, and expressible as concrete checks — not "works correctly" or "is reliable".
- Violated → **FAIL** when: conditions are vague or circular ("X is done when X works")
- Violated → **WARNING** when: mix of specific and vague

**T6. Stakeholder attributions preserved.** When the upstream strategic spec captured attributed perspectives ("Per Marcus: needs idempotency key"), they appear in relevant task descriptions or capability bodies. Downstream executors lose design rationale when attribution is dropped.
- Violated → **WARNING** when: strategic-spec attributions present upstream but absent in tasks that implement the attributed concerns

**T7. Dependency graph is sensible.** Topologically valid, minimal cross-capability coordination, infrastructure before consumers.
- Violated → **FAIL** when: cycles exist (already caught by Pass 1 — double-check)
- Violated → **WARNING** when: excessive cross-capability dependencies suggest the capability boundaries are wrong

**T8. Capability coherence.** Each capability contains 2–8 related tasks. Tasks within a capability serve the capability's purpose and share a domain. One-task capabilities usually want merging; 12-task capabilities usually want splitting.
- Violated → **WARNING** when: task counts outside the range, OR tasks feel unrelated to their parent capability

#### Framing findings for the user

Frame all Pass 2 findings in terms of what downstream execution needs:

- Thin descriptions mean the task executor operates without context — output quality degrades
- Vague success conditions mean "done" is undefined — the executor guesses and reviewers can't verify
- Missing attribution means design rationale is lost — future changes repeat settled debates
- Bad metadata means planning is wrong — sprint sizing, risk attention, and AI-automation decisions all cascade from it

## Combined report

Findings fall into two categories with different audiences:

**Format findings (Pass 1)** — structural issues caused by writer drift: wrong heading format, missing metadata, broken `depends_on`, duplicate refs. These are mechanical and often auto-fixable in `/ido4specs:refine-spec`. The user didn't hand-write this spec; format drift is the system's problem.

**Content findings (Pass 2)** — substance issues that need the user's judgment: thin descriptions, vague success conditions, missing attribution, miscalibrated metadata. These are the user's domain.

### Report structure

**Verdict (first, one line):**
- `PASS` — "Spec is ready for downstream ingestion."
- `PASS WITH WARNINGS` — "Spec is mostly solid but has N issues worth reviewing."
- `FAIL` — "Spec has N issues that need attention before ingestion."

The verdict reflects Pass 2 content findings primarily. Pass 1 structural findings are auto-fix candidates — if a Pass 1 finding cannot be auto-fixed (ambiguous circular dependency needing user judgment), it escalates as a content-level decision point at FAIL severity.

**What's working** (one paragraph): content strengths in plain language — code grounding, metadata calibration, attribution preservation, dependency sanity. No assertion IDs.

**What needs your input** (content findings only): Pass 2 violations, ordered FAIL-severity first, then WARNING. For each:
- The issue in user terms (not parser field names)
- Which capability or task
- Why it matters for downstream ingestion
- What to do about it

**Format issues resolved** (one sentence, if applicable): "N format issues are auto-fix candidates — run `/ido4specs:refine-spec` to address them." No detail unless the user asks.

**Next step:**
- Content findings exist → "Run `/ido4specs:refine-spec <path>` to address these, then re-run `/ido4specs:validate-spec`."
- Clean spec and `.ido4/project-info.json` exists in the workspace → "Ready for `/ido4specs:review-spec <path>` (qualitative review) or `/ido4dev:ingest-spec <path>` (create GitHub issues)."
- Clean spec without the marker file → "Ready for `/ido4specs:review-spec <path>`. To turn this into GitHub issues, install `ido4dev` (`/plugin install ido4dev@ido4-plugins`), run `/ido4dev:onboard`, then `/ido4dev:ingest-spec <path>`. Or pipe the file to your own tooling."

**Supporting metrics** (short, last): counts — capabilities, tasks, dependency edges, max depth, cross-capability edges. One paragraph.

### Verdict rollup rules

- Any Pass 2 assertion violated at FAIL severity → **FAIL**
- Only WARNING-grade Pass 2 violations → **PASS WITH WARNINGS**
- All Pass 2 assertions satisfied (regardless of Pass 1 state) → **PASS**
- Pass 1 structural findings that can be auto-fixed by `refine-spec` don't affect the verdict. Pass 1 findings that need user judgment (ambiguous circular dep) escalate to the user as FAIL-severity content decisions.

### Handoff to refine-spec

When pointing the user at `/ido4specs:refine-spec`, include each finding with the specific edit needed so refine-spec can act precisely instead of re-diagnosing.
