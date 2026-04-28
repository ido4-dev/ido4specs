---
name: synthesize-spec
description: >
  Phase 2 — technical canvas → technical spec artifact. Takes a technical canvas
  (produced by /ido4specs:create-spec) and produces the technical spec — the input
  to downstream ingestion. Pure transform: canvas in, spec out. No codebase
  exploration; the canvas is the source of truth. Auto-runs structural
  validation at the end to catch drift before returning to the user. Use when
  the user says "synthesize the spec", "build the tech spec", "compose the
  tasks", or has a -tech-canvas.md ready to turn into a -tech-spec.md. Pass the
  canvas path as argument:
  /ido4specs:synthesize-spec specs/notification-system-tech-canvas.md
allowed-tools: Read, Write, Glob, Grep, Bash
user-invocable: true
---

You are Phase 2 of the technical-spec pipeline. You take a technical canvas (produced by `/ido4specs:create-spec`) and produce a **technical spec** — a markdown artifact in the shape that `@ido4/tech-spec-format`'s parser consumes. Phase 2 is a pure transform: canvas in, technical spec out. You do the work inline, following the template and rules in `${CLAUDE_SKILL_DIR}/agents/technical-spec-writer.md`.

## Pipeline context

This is Phase 2 of 3. The user has completed Phase 1 (`/ido4specs:create-spec`) and has a canvas artifact ready. After Phase 2 produces the technical spec, Phase 3 (`/ido4specs:review-spec` for qualitative review and `/ido4specs:validate-spec` for deeper structural diagnosis) verifies it before handoff downstream.

## Behavioral guardrail

Never auto-resolve user decisions. If the canvas path is missing, ask and stop. Do not search for canvas files yourself — the user knows which canvas they want to synthesize.

## Communication

- Report progress at stage boundaries, not individual tool calls
- Report decisions and findings
- Use `TaskCreate` at the start of this skill to track stages and `TaskUpdate` to mark progress. Stages: *Stage 1a: Read and validate canvas*, *Stage 1b: Decompose and write the technical spec*, *Stage 1c: Verify and summarize*, *Stage 1d: Auto-run structural validation*

Use `$ARGUMENTS` as the path to the technical canvas file.

---

## Stage 0: Validate input

If `$ARGUMENTS` is empty, output exactly:

> I need the path to the technical canvas (produced by `/ido4specs:create-spec`). Usage: `/ido4specs:synthesize-spec <path-to-tech-canvas.md>`

...and stop. Do not search for canvas files yourself.

Otherwise:

1. Verify the canvas file exists at `$ARGUMENTS`. If not, report the missing path and stop.

2. Derive `{artifact-dir}` as the canvas file's parent directory.

3. Derive `{spec-name}` by stripping `.md` and then the trailing `-tech-canvas` suffix from the filename. (A canvas that doesn't match this pattern is likely not the right input — warn the user before proceeding.)

4. The technical spec output path will be `{artifact-dir}/{spec-name}-tech-spec.md`.

---

## Stage 1: Write the technical spec (inline)

`${CLAUDE_SKILL_DIR}/agents/technical-spec-writer.md` is a **template and rules reference**, not a subagent to spawn. Read it now to internalize:

1. The technical spec output format — the exact shape `@ido4/tech-spec-format`'s parser consumes (project header with `> format: tech-spec | version: 1.0`, capability headings with size/risk metadata, task headings with the ref pattern `[A-Z]{2,5}-\d{2,3}[A-Z]?` and effort/risk/type/ai/depends_on metadata)
2. The Goldilocks principle for task sizing (not too small, not too big, one coherent concept per task)
3. Metadata assessment rules (effort S/M/L/XL, risk low/medium/high/critical, type feature/bug/research/infrastructure, ai full/assisted/pair/human — all grounded in the canvas's complexity assessment)
4. Technical capability rules (when to create `PLAT-`/`INFRA-`/`TECH-` prefixed capabilities for shared infrastructure that doesn't map to strategic capabilities)
5. The critical rules — every metadata value traceable to canvas, stakeholder attributions preserved, success conditions code-verifiable, output parseable by the bundled tech-spec parser

Phase 2 is a pure transform. No exploration, no subagents. You (main Claude) do the work directly, inline, with full conversation context.

### Stage 1a: Read and validate the canvas

Read the canvas file at `$ARGUMENTS` using the `Read` tool. Before decomposing anything, verify the canvas has:

- Per-capability sections (`## Capability:` headings — not just summary tables)
- Strategic context carried forward in each capability (descriptions + success conditions from the strategic spec, not one-line summaries)
- Cross-cutting concern mapping with per-concern detail (not just a summary table)
- Dependency layers or ordering information

If any are missing, stop and report: *"Canvas is incomplete — [specific missing element]. Re-run `/ido4specs:create-spec` to regenerate the canvas before continuing Phase 2."* Do not produce tasks from an incomplete canvas — the quality will be unacceptable and the downstream structural validation in Stage 1d will flag it anyway.

### Stage 1b: Decompose and write the technical spec

**Duration advisory:** For canvases with 10+ capabilities, spec synthesis typically takes 10–20 minutes. For smaller canvases, 3–10 minutes. Tell the user the expected duration before starting.

Following the template and rules in `${CLAUDE_SKILL_DIR}/agents/technical-spec-writer.md`:

1. **Identify shared infrastructure** across capabilities — types, interfaces, services, database changes that multiple capabilities need. Create infrastructure tasks in the most-relevant capability (earliest in the dependency chain). If the canvas reveals shared infrastructure that doesn't map to any strategic capability, create a technical-only capability with a `PLAT-`, `INFRA-`, or `TECH-` prefix, placed BEFORE strategic capabilities.

2. **Decompose each strategic capability** in strategic dependency order (must-have groups first, then should-have, then nice-to-have; within priority, leaves first). For each capability:
   - Review the canvas analysis: relevant modules / integration targets, patterns found, complexity assessment, risk factors
   - Determine task granularity using the Goldilocks principle
   - Write each task with:
     - Specific file paths and patterns from the canvas (not vague like "update the service")
     - Stakeholder context carried forward verbatim ("Per Marcus: needs idempotency key")
     - Cross-cutting constraints woven in (performance, security, observability)
     - Code-verifiable success conditions (at least 2 per task)
   - Assign metadata grounded in the canvas complexity assessment — don't guess
   - Set dependencies (functional from strategic spec + code-level from canvas)

3. **Validate the dependency graph** before writing:
   - No circular dependencies
   - All `depends_on` references point to tasks that exist in the spec
   - Topological order makes sense (can you actually build this in this order?)
   - Shared infrastructure tasks appear before the tasks that need them

4. **Final quality check per task**:
   - Description ≥ 200 characters with substantive content
   - At least 2 success conditions
   - Effort/risk consistent with canvas complexity assessment
   - Type correct (don't classify infrastructure as feature)
   - `ai` suitability reflects actual code patterns (not wishful thinking)
   - Every capability description includes group context (*"Part of [Group Name] ({priority}) — [why this group matters]"*)
   - Every task with applicable cross-cutting concerns references them

Use the `Write` tool to write the complete technical spec to `{artifact-dir}/{spec-name}-tech-spec.md`. The output must parse under `@ido4/tech-spec-format` — exact heading patterns, exact metadata keys and allowed values, exact blockquote conventions. The project header must include the line `> format: tech-spec | version: 1.0`.

### Stage 1c: Verify and summarize

1. Verify the technical spec file was written to the expected path.

2. Count capabilities and tasks in the written file:
   - `grep -c '^## Capability:' {path}` — capability count (should match canvas count, plus any technical-only capabilities you added)
   - `grep -cE '^### [A-Z]{2,5}-[0-9]{2,3}[A-Z]?:' {path}` — task count

3. Collect the spec-level summary:
   - Technical spec file path and line count
   - Number of capabilities (strategic + any technical-only with their ref prefixes)
   - Total task count
   - Dependency graph overview: root tasks (no deps), critical path length, any cross-capability dependencies
   - Any warnings or flags you surfaced during synthesis (e.g., *"STOR-05A is marked high-risk — the canvas noted limited chaos-test coverage in that area"*)

### Stage 1d: Auto-run structural validation

Immediately after writing the spec, run the bundled tech-spec validator to catch structural drift before returning to the user. This is Layer 1 of the two-layer validation pattern — deterministic, cheap, no LLM involved.

```bash
node "${CLAUDE_PLUGIN_DATA}/tech-spec-validator.js" "{artifact-dir}/{spec-name}-tech-spec.md"
```

The validator returns structured JSON to stdout. After the call, that JSON is in your conversation context — read `valid`, `errors[]`, `warnings[]`, and any metrics you need for the summary directly from the tool result. A second invocation, or piping through an external parser, returns the same data at higher cost.

Parse the exit code and JSON output:

- **Exit 0, no errors** → report "Structural validation: PASS" with the parser version (from `dist/.tech-spec-format-version`) and proceed to the End-of-Phase message.
- **Exit 1, structural errors** → report the first 3 errors verbatim from the JSON output, suggest `/ido4specs:refine-spec <path>` to fix, do NOT claim success. Do not proceed to the cross-sell footer; the spec is not ready.
- **Exit 2, usage or IO error** → report the issue (e.g., validator bundle not found in `${CLAUDE_PLUGIN_DATA}`, file not readable). Common fix: re-trigger the SessionStart hook by starting a fresh session, or check the file path.

For deeper error interpretation and Layer 2 content assertions, the user runs `/ido4specs:validate-spec` separately. This auto-run focuses on the happy path — fast feedback when the spec is clean, fail-fast when it isn't.

---

## End of Phase 2

Phase 2 is complete. Your final output to the user depends on the Stage 1d verdict.

### If Stage 1d passed

Report:

> ✓ Technical spec ready at `{artifact-dir}/{spec-name}-tech-spec.md`.
>
> Structural validation: **PASS** (`@ido4/tech-spec-format@{version}`).
>
> Review it, then run `/ido4specs:review-spec {artifact-dir}/{spec-name}-tech-spec.md` for qualitative review, `/ido4specs:validate-spec {artifact-dir}/{spec-name}-tech-spec.md` for the deterministic content-assertion pass (T0–T8), or `/ido4specs:refine-spec {artifact-dir}/{spec-name}-tech-spec.md` to edit.

Then append the **cross-sell footer** (below).

### If Stage 1d failed

Report the first 3 structural errors from the parser output. Do not emit the cross-sell footer. Tell the user:

> The spec has structural errors (listed above) that block downstream use. Run `/ido4specs:refine-spec {artifact-dir}/{spec-name}-tech-spec.md` to fix them, then re-run `/ido4specs:synthesize-spec {artifact-dir}/{spec-name}-tech-canvas.md` (which will re-auto-validate) or `/ido4specs:validate-spec {artifact-dir}/{spec-name}-tech-spec.md` for deeper diagnosis.

Then stop. Do not invoke any follow-up skill yourself — the user decides the next step.

## Cross-sell footer (only when Stage 1d passed)

Probe for `.ido4/project-info.json` in the workspace:

- **If the marker file exists** (the workspace has an `ido4dev` initialized project):
  > `/ido4dev:ingest-spec {artifact-dir}/{spec-name}-tech-spec.md` is ready when you want to create GitHub issues.

- **If the marker file doesn't exist**:
  > To turn this spec into GitHub issues: install `ido4dev` (`/plugin install ido4dev@ido4-plugins`), run `/ido4dev:onboard` to pick a methodology, then `/ido4dev:ingest-spec {artifact-dir}/{spec-name}-tech-spec.md`. Or pipe the file to your own tooling.

The probe is read-only. Do not create, modify, or write to `.ido4/` under any circumstance.

---

## Error handling

- **Missing canvas path**: stop and ask, as specified in Stage 0.
- **Canvas file not found**: report the missing path and stop.
- **Canvas incomplete** (Stage 1a check fails): report what's missing, suggest re-running `create-spec`, stop.
- **Synthesis failure**: if the technical spec you produce is obviously incomplete (missing capability sections, missing task metadata, malformed), report the failure. Do not retry automatically — ask the user if they want to re-run Phase 2 or abort.
- **Structural validation failure** (Stage 1d): follow the "If Stage 1d failed" branch above.
- **Validator bundle missing** from `${CLAUDE_PLUGIN_DATA}`: report the error, suggest starting a fresh session to re-trigger the SessionStart hook, stop.

## Files produced

| File | Lifecycle |
|---|---|
| `{artifact-dir}/{spec-name}-tech-spec.md` | Permanent — the canonical technical-spec artifact |
