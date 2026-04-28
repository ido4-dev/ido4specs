---
name: create-spec
description: >
  Phase 1 — strategic spec + codebase → technical canvas. Takes a strategic spec
  (typically from ido4shape), parses it via the bundled @ido4/spec-format
  validator, detects
  project mode (existing / greenfield-with-context / greenfield-standalone),
  spawns parallel Explore subagents for codebase or integration-target analysis,
  and synthesizes a technical canvas that becomes the input to
  /ido4specs:synthesize-spec. Use when the user says "create a spec", "start the
  tech spec", "decompose this project", "analyze the codebase against this
  spec", or has a -strategic-spec.md ready for technical planning. Pass the
  strategic-spec path as argument:
  /ido4specs:create-spec specs/notification-system-strategic-spec.md
allowed-tools: Read, Write, Glob, Grep, Bash
user-invocable: true
---

You are Phase 1 of the technical-spec pipeline. You take a strategic spec (produced by ido4shape), parse it, detect the project mode, gather codebase or integration-target context via parallel `Explore` subagents, and synthesize a **technical canvas** — a markdown artifact that maps each strategic capability to concrete codebase knowledge. The canvas is the intermediate artifact that becomes the input to `/ido4specs:synthesize-spec`.

## Pipeline context

The `ido4specs` pipeline runs as three user-invocable phases, each producing a review-worthy artifact:

| Phase | Skill | Produces |
|---|---|---|
| 1 (this skill) | `/ido4specs:create-spec` | Technical canvas (`*-tech-canvas.md`) |
| 2 | `/ido4specs:synthesize-spec` | Technical spec (`*-tech-spec.md`) |
| 3 | `/ido4specs:review-spec` + `/ido4specs:validate-spec` | Qualitative + structural review |

Each phase ends at its natural boundary so the user can review before proceeding.

## Behavioral guardrail

When something is missing — spec file path, project configuration — ask the user and stop. Do not auto-search, auto-initialize, or auto-resolve. The user knows which spec they want to decompose.

## Communication

- Report progress at stage boundaries, not individual tool calls
- Report decisions and findings
- Be concise — highlight surprises, not expected patterns
- Use `TaskCreate` at the start of this skill to track stages, and `TaskUpdate` to mark progress as you move through each one. Stages to track: *Stage 0: Parse strategic spec*, *Stage 0.5: Determine artifact dir and project mode*, *Stage 1a: Explore integration targets in parallel*, *Stage 1b: Read the strategic spec*, *Stage 1c: Synthesize technical canvas*, *Stage 1d: Verify and write canvas*

Use `$ARGUMENTS` as the path to the strategic spec file.

---

## Stage 0: Parse the strategic spec

If `$ARGUMENTS` is empty, output exactly:

> I need the path to the strategic spec file. Usage: `/ido4specs:create-spec <path-to-strategic-spec.md>`

...and stop. Do not search for spec files yourself — the user knows which spec they want.

Otherwise:

1. Verify the strategic spec file exists at `$ARGUMENTS` using the `Read` tool. If the file doesn't exist, report the missing path and stop.

2. Run the bundled strategic-spec validator. After the call, the structured JSON output is in your conversation context as the Bash tool result — that's your data source for the Stage 0 summary.

   ```bash
   node "${CLAUDE_PLUGIN_DATA}/spec-validator.js" "$ARGUMENTS"
   ```

   The data is already in your context. Re-running the validator with a different shape, or piping the output through an external parser to extract slices, produces the same information at higher latency and token cost.

   *Example — extracting summary fields from the validator output:*

   *BAD (5 invocations):*
   - Call 1: bare validator → 211-line JSON in tool result.
   - Call 2: validator piped through a Python one-liner to print `valid` / `errors` / `warnings`.
   - Call 3: piped through Python to list group names and capability counts.
   - Call 4: piped through Python to extract dependency-graph keys.
   - Call 5: piped through Python to count cross-group edges.
   - Same data the first call already returned, with five-fold latency and token cost.

   *GOOD (1 invocation):*
   - One call to the validator. The 211-line JSON is in your conversation context.
   - Read `project.name` for the summary header.
   - Iterate `groups[]` for the per-group rows.
   - Count `crossCuttingConcerns.length` for the cross-cutting summary.
   - Done.

   The output JSON top-level shape is `{ valid, meta, metrics, project, crossCuttingConcerns, groups, orphanCapabilities, dependencyGraph, errors, warnings }`. The fields you need for Stage 0:
   - `valid`, `errors`, `warnings` — gating
   - `project.name` — project name for the summary
   - `groups[]` — each group has `name`, `prefix`, `priority`, `capabilityCount`, and `capabilities[]`
   - `metrics.dependencyEdgeCount`, `metrics.maxDependencyDepth` — dependency structure
   - `metrics.crossCuttingConcernCount` (or `crossCuttingConcerns[]` for the names)
   - `dependencyGraph` — map of `cap.id → [dep ids]`; iterate and compare against `groups[].capabilities[].id` to count cross-group edges if useful

3. Review the parse result:
   - If `errors.length > 0`, stop and report them. The strategic spec must be fixed before `create-spec` can proceed.
   - If `warnings.length > 0`, report them but continue.

4. Present the Stage 0 summary to the user:
   - Project name (`project.name`)
   - Capabilities grouped by ido4shape groups (count per group from `groups[i].capabilityCount`)
   - Group priorities (`groups[i].priority`)
   - Dependency structure (`metrics.dependencyEdgeCount` total, `metrics.maxDependencyDepth`, plus cross-group count derived from `dependencyGraph` if surfacing it)
   - Cross-cutting concerns (`metrics.crossCuttingConcernCount`)

5. Derive the `{spec-name}` from the input path for use in downstream artifact filenames. Strip `.md`, then strip the first matching trailing suffix from the priority list:
   - `-strategic-spec` (canonical recommended name)
   - `-tech-spec` (if the user somehow passed a technical spec here — which would be wrong)
   - `-tech-canvas` (same — wrong input)
   - `-spec` (raw ido4shape output before the user renamed it)

   Examples:
   - `specs/notification-system-strategic-spec.md` → `notification-system`
   - `./notification-system-spec.md` → `notification-system`
   - `docs/product-v2.md` → `product-v2`

   The result is the `{spec-name}` base used for the canvas and, later, the technical spec filenames.

---

## Stage 0.5: Determine artifact directory and detect project mode

### Artifact directory

Determine the directory where the canvas and later the technical spec will be written:

1. If `specs/` exists in the project root, use it
2. Else if `docs/specs/` exists, use it
3. Else if `docs/` exists, create and use `docs/specs/`
4. Else create and use `specs/`

### Project mode

Determine the project mode:

1. Glob for source directories (`src/`, `app/`, `lib/`, `packages/`)
2. Check for project manifest files with dependencies (`package.json` with `dependencies`, `go.mod`, `Cargo.toml`, `pyproject.toml`)
3. Count non-config source files

**Mode assignment:**

- Source code exists → `existing`
- No source code, but the parsed strategic spec references integration targets (external systems, APIs, existing repos, named services in project context, cross-cutting concerns, or capability descriptions) → `greenfield-with-context`
- No source code, no integration targets → `greenfield-standalone`

### Path-reporting and co-location nudge

Report both paths clearly to the user. The output shape is:

```
Strategic spec:     {strategic-spec-path}
Artifact directory: {artifact-dir}/  ({existing | created})
Project mode:       {existing | greenfield-with-context | greenfield-standalone}

Your technical artifacts will land at:
  {artifact-dir}/{spec-name}-tech-canvas.md   (this skill's output)
  {artifact-dir}/{spec-name}-tech-spec.md     (next skill's output)
```

If the strategic spec's directory is different from `{artifact-dir}`, append a one-time co-location hint:

> Your strategic spec is outside the work area. If you'd like everything co-located under `{artifact-dir}/`, you can move and rename it for symmetry with the technical artifacts:
>
>     mv {strategic-spec-path} {artifact-dir}/{spec-name}-strategic-spec.md
>
> `ido4specs` will find it there next time. This is optional — the current path is also fine.

The nudge is informational. Do not wait for a reply, do not block the next stage on it, do not emit it again if the user invokes `create-spec` later with the strategic spec still at its original location.

Add a short explanation of the project mode choice:

> Detected mode: `{existing | greenfield-with-context | greenfield-standalone}`. {One sentence explaining why.}

---

## Stage 1: Analyze and synthesize the canvas

`${CLAUDE_SKILL_DIR}/agents/code-analyzer.md` is a **canvas template and rules reference** — read it for the canvas structure, per-capability template, context-preservation rules, and mode-specific guidance. Do not spawn it as a subagent; you are the orchestrator AND synthesizer for Stage 1. This matters: inline synthesis with full conversation context produces stronger results than forked subagent contexts, and it avoids a Claude Code constraint where plugin-defined subagents hang at ~25–30 tool uses.

### Stage 1a: Gather integration target summaries (parallel)

Determine integration targets based on the detected project mode:

- **`existing`**: the current project's codebase is the target
- **`greenfield-with-context`**: targets are the external systems, repos, or services the strategic spec references (sibling plugin repos, upstream APIs, shared libraries)
- **`greenfield-standalone`**: no integration targets — skip to Stage 1b

Spawn parallel `Explore` subagents (Claude Code's built-in subagent type — NOT plugin-defined subagents), one per target. Each brief should be under 300 tokens and contain:

1. Target path and name
2. One sentence explaining why it matters (e.g., "The PLUG group of capabilities modifies this plugin")
3. Exactly what to return: tech stack, directory structure, key modules with file paths, architectural patterns, relevant conventions, and anything specifically relevant to the strategic spec's requirements
4. Size cap: "Return in under 2000 words"

Do not pass the full strategic spec or the code-analyzer template into the Explore briefs — keep them lean and focused. The subagents only need enough context to explore their target intelligently.

Run all Explore subagents in a **single message with multiple tool uses** for true parallelism.

### Stage 1b: Read the strategic spec

Use the `Read` tool to load the strategic spec text directly. You need the raw text for verbatim context preservation — capability descriptions, success conditions, stakeholder attributions, group descriptions, constraints, non-goals. Summarizing is not sufficient; the downstream spec-writer receives ONLY the canvas and needs strategic context preserved word-for-word.

### Stage 1c: Synthesize the canvas inline

**Duration advisory:** For specs with 10+ capabilities, canvas synthesis typically takes 10–25 minutes. For smaller specs (under 10 capabilities), 3–10 minutes. The progress indicator shows active token generation — as long as the token count is increasing, synthesis is proceeding normally. Tell the user the expected duration before starting, so they don't mistake active synthesis for a stall.

Compose the complete technical canvas following the template in `${CLAUDE_SKILL_DIR}/agents/code-analyzer.md`:

- Use the Explore subagents' summaries for **Ecosystem Architecture** / **Codebase Overview** and for **Integration Target Analysis** / **Codebase Analysis** per capability
- Use the strategic spec text (from Stage 1b) for verbatim context preservation — do not summarize or rephrase capability descriptions, success conditions, stakeholder attributions, or group descriptions
- Use your own analysis for **Cross-Cutting Concern Mapping**, **Dependency Layers**, **Risk Assessment Summary**, **Discoveries & Adjustments**, and the project-level **What Exists vs What's Built** rollup

Every strategic capability must have its own `## Capability:` section — no summary tables, no collapsing, no shortcuts. The canvas is the context preservation layer for the entire pipeline: Phase 2 (`synthesize-spec`) receives ONLY this canvas, not the strategic spec. If the canvas loses context, everything downstream fails.

Write the complete canvas to `{artifact-dir}/{spec-name}-tech-canvas.md` using the `Write` tool.

A 30+ capability greenfield-with-context canvas typically lands at 2,000–3,000 lines. That's normal for the artifact — write it as a single Write call. The Write tool overwrites rather than appends, so iterative chunked writes either lose prior content or force you to re-encode everything-prior-plus-new on each call. The latter is O(n²) in tokens.

*Example — writing a 2,500-line canvas:*

*BAD (chunked, observed at 57 minutes for a 43-cap canvas):*
- "I'll build the canvas in chunks via append-style writes to stay within output limits."
- First Write: ~300 lines.
- Re-read source material to compose next section.
- Second Write: now has to include all of section 1 + section 2 (Write overwrites).
- Re-read again. Third Write: sections 1 + 2 + 3.
- Each chunk re-encodes everything before it.

*GOOD (single Write, ~20 minutes for the same canvas):*
- Compose the entire canvas in your reasoning.
- Single Write call with the complete content.
- If the initial output appears truncated by an output budget, retry the single Write — that's the fix, not switching into chunked-append mode.

### Stage 1d: Verify and summarize

1. Verify the canvas file was written to the expected path.

2. Count `## Capability:` sections in the written canvas (`grep -c '^## Capability:' {path}`). The count must match the strategic capability count from Stage 0. If it doesn't, the canvas is incomplete — report the mismatch and ask the user whether to retry Stage 1c or abort. This is a load-bearing check: canvas drift here cascades into malformed technical specs downstream.

3. On successful verification, present the Stage 1 summary to the user:
   - Canvas file path and line count
   - Number of capabilities analyzed
   - Key findings: what exists vs what's new
   - Shared infrastructure discovered across capabilities
   - Any surprises or adjustments to the strategic dependency order
   - Cross-cutting concern coverage

---

## End of Phase 1

Phase 1 is complete. Your final output to the user must be exactly this guidance (substituting the canvas path):

> ✓ Canvas ready at `{artifact-dir}/{spec-name}-tech-canvas.md`. Review it, then run `/ido4specs:synthesize-spec {artifact-dir}/{spec-name}-tech-canvas.md` when you're ready to produce the technical spec.

Then stop. Do not invoke `/ido4specs:synthesize-spec` yourself — the user re-invokes it when ready. This is a hard boundary: Phase 1's responsibility ends at the canvas. Phase 2 is a separate user decision.

---

## Error handling

- **Missing strategic spec path**: stop and ask, as specified in Stage 0.
- **Strategic spec file not found**: report the missing path and stop.
- **Strategic spec parse errors**: stop. Report errors. The user must fix the strategic spec (typically using `/ido4shape:refine-spec` or hand-editing).
- **Subagent or synthesis failure**: if an `Explore` subagent fails, or the canvas synthesis is incomplete (missing capability sections, truncated content), report the failure with specifics. Do not retry automatically — ask the user if they want to re-run Stage 1 or abort.
- **Codebase exploration gaps**: the canvas will note gaps as research-task candidates; Phase 2's spec-writer will convert them into `type: research` tasks.

## Files produced

| File | Lifecycle |
|---|---|
| `{artifact-dir}/{spec-name}-tech-canvas.md` | Permanent — kept for history, re-synthesis, and future `repair-spec` grounding |
