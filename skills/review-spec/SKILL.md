---
name: review-spec
description: >
  Runs a qualitative review of a technical spec artifact — two-stage protocol
  (format compliance then content quality) applied inline via the spec-reviewer
  agent on Sonnet. Returns PASS / PASS WITH WARNINGS / FAIL with structured
  findings and a Spec Review Report. Layer 2 of the two-layer validation
  pattern — pairs with /ido4specs:validate-spec (Layer 1 — structural parser).
  Use when the user says "review the spec", "check the quality", "is this ready
  for ingest", "run the reviewer". Pass the spec path as argument:
  /ido4specs:review-spec specs/notification-system-tech-spec.md
allowed-tools: Read, Glob, Grep
user-invocable: true
---

You review a technical spec artifact for format compliance and content quality, inline, following the review protocol in `agents/spec-reviewer.md`. This is Layer 2 of the two-layer validation pattern — qualitative LLM judgment on top of the deterministic parser check that `/ido4specs:validate-spec` provides.

## Pipeline context

This skill is the qualitative companion to `/ido4specs:validate-spec`. Both take a technical spec path as input. `validate-spec` wraps the bundled parser (Layer 1 — structural, deterministic, fast). `review-spec` applies qualitative assessment (Layer 2 — content quality, descriptions, metadata calibration, dependency sanity). Together they form the handoff boundary between `ido4specs` and any downstream ingestion tool.

Typical usage: run `validate-spec` first to catch structural issues, fix those in `refine-spec`, then run `review-spec` on the structurally-clean spec for content assessment. Either skill can be run independently.

## Behavioral guardrail

Do not auto-resolve user decisions. If the spec path is missing, ask and stop. Do not search for spec files unless explicitly asked.

## Communication

- Report progress at stage boundaries
- Use `TaskCreate` at the start of this skill to track the review stages and `TaskUpdate` to mark progress. Stages: *Stage 1a: Read technical spec*, *Stage 1b: Format compliance review*, *Stage 1c: Quality assessment review*, *Stage 1d: Downstream awareness check*, *Stage 1e: Produce review report*

Use `$ARGUMENTS` as the path to the technical spec file.

---

## Stage 0: Validate input

If `$ARGUMENTS` is empty, output exactly:

> I need the path to the technical spec. Usage: `/ido4specs:review-spec <path-to-tech-spec.md>`

...and stop. If the path doesn't end in `-tech-spec.md`, warn the user — this skill reviews technical specs, not strategic specs. Strategic-spec review lives upstream in `/ido4shape:review-spec`.

Otherwise, verify the technical spec file exists at `$ARGUMENTS`. If not, report the missing path and stop.

---

## Stage 1: Inline review via spec-reviewer

`agents/spec-reviewer.md` is a **review protocol and rules reference**, not a subagent to spawn. Read it now to internalize:

1. The two-stage review protocol (format compliance first, then content quality)
2. Format compliance checks (project header with `> format: tech-spec | version: 1.0`, capability headings with size/risk metadata, task headings with ref pattern `[A-Z]{2,5}-\d{2,3}[A-Z]?`, metadata keys and values, `depends_on` references, no circular dependencies)
3. Quality assessment checks (description substance, code-grounding, success condition specificity, effort/risk grounding, `ai` suitability appropriateness, capability coherence, dependency graph sanity)
4. Downstream awareness (flag `ai: human`, `risk: critical`, heavy cross-capability deps as informational — `ido4specs` is methodology-neutral and does not enforce governance)
5. Validation discipline (classify issues as Error / Warning / Suggestion, independently verify each issue before reporting, false positives erode trust)
6. Output format (Spec Review Report with summary, errors, warnings, suggestions, downstream notes, dependency graph)

You (main Claude) perform the review directly on Sonnet's equivalent — the agent's `model: sonnet` frontmatter sets the expectation, and the skill's `allowed-tools` (Read, Glob, Grep, no Bash) reflects that no bundled-validator call happens here. Structural validation is `validate-spec`'s job; this skill handles content quality.

### Stage 1a: Read the technical spec

Read the technical spec file at `$ARGUMENTS`. Optional: glob the surrounding `specs/` directory for a sibling `*-tech-canvas.md` — if one exists, it's useful grounding for checking stakeholder-attribution preservation (T6 in validate-spec's Pass 2 vocabulary). Do not require the canvas — some specs may be reviewed standalone.

### Stage 1b: Format compliance review

Systematically check every structural element against the parser's exact expectations (from `agents/spec-reviewer.md` Stage 1):

- Project header: exactly one `#` heading, followed by a `> format: tech-spec | version: 1.0` marker and a `>` description line
- Capability headings: `## Capability: Name` format, followed by `>` metadata line with `size` and `risk`
- Task headings: `### REF: Title` where REF matches `[A-Z]{2,5}-\d{2,3}[A-Z]?` (letters + optional single-letter suffix)
- Task prefix matches parent capability prefix (e.g., `NCO-` tasks under "Notification Core")
- Metadata keys (exact, lowercase): `effort`, `risk`, `type`, `ai`, `depends_on`
- Metadata values from allowed sets: `effort` (S/M/L/XL), `risk` (low/medium/high/critical), `type` (feature/bug/research/infrastructure), `ai` (full/assisted/pair/human)
- All `depends_on` references point to existing task IDs in the document
- No circular dependency chains (trace the full graph)

Use `Grep` to verify counts and catch regex violations quickly. Use `Read` with line offsets to spot-check specific sections. Note that the bundled parser catches these same checks deterministically in `/ido4specs:validate-spec` — this stage is for sanity-checking the spec independently and surfacing findings in the same report as the content assessment.

### Stage 1c: Quality assessment

From `agents/spec-reviewer.md` Stage 2. For each task:

- Description ≥ 200 characters with substantive content (not just title restatement)
- Descriptions reference specific code paths, services, or patterns (technical specs should be codebase-grounded)
- Success conditions present, specific, independently verifiable, code-testable
- Effort estimates grounded in code reality
- Risk assessments reflect actual codebase complexity
- `ai` suitability appropriate (external integrations shouldn't be `full`; schema definitions can be `full`)
- Capabilities coherent (2–8 tasks, tasks related to capability purpose)
- Dependency graph sensible (critical path makes sense, minimal cross-capability deps)

### Stage 1d: Downstream awareness check

Flag values with downstream ingestion impact as informational — not as governance enforcement:

- `ai: human` blocks automated start transitions in any governance tooling that consumes the spec — is this intentional and justified?
- `risk: critical` signals elevated attention downstream — does it truly warrant it?
- Cross-capability dependencies create coordination requirements — are they minimized?
- Effort distribution across capabilities — any capability disproportionately heavy?

### Stage 1e: Produce the review report

Classify each issue found as **Error** (will cause ingestion to fail), **Warning** (won't fail but indicates a quality problem), or **Suggestion** (not wrong but could be better). Before reporting any issue, independently verify it — false positives erode trust.

Present the review report to the user in the format from `agents/spec-reviewer.md`:

```markdown
# Spec Review Report

## Summary
- File: [path]
- Capabilities: [N] | Tasks: [N]
- Errors: [N] | Warnings: [N] | Suggestions: [N]
- Verdict: [PASS | PASS WITH WARNINGS | FAIL]

## Errors
[Each error with task ref, line reference, explanation, fix suggestion]

## Warnings
[Each warning with context and recommendation]

## Suggestions
[Each suggestion with reasoning]

## Downstream Notes
[Values that will shape specific downstream behavior — ai: human tasks, critical-risk tasks, heavy cross-capability deps]

## Dependency Graph
- Root tasks: [list]
- Critical path: [chain]
- Cross-capability deps: [list]
- Cycles: [none | details]
```

### Handle the verdict

- **FAIL**: Report the errors clearly. Tell the user: *"The spec has errors that will block ingestion. Run `/ido4specs:refine-spec <spec-path>` to fix them, then re-run `/ido4specs:review-spec`."* Stop.
- **PASS WITH WARNINGS**: Present the warnings. Ask the user: *"Run `/ido4specs:refine-spec <spec-path>` to address these, or proceed with the caveats?"* Stop and wait for the user's explicit choice.
- **PASS**: Proceed to the cross-sell footer.

---

## Cross-sell footer (only on PASS)

Probe for `.ido4/project-info.json` in the workspace:

- **If the marker file exists**:
  > `/ido4dev:ingest-spec <spec-path>` is ready when you want to create GitHub issues.

- **If the marker file doesn't exist**:
  > To turn this spec into GitHub issues: install `ido4dev` (`/plugin install ido4dev@ido4-plugins`), run `/ido4dev:onboard` to pick a methodology, then `/ido4dev:ingest-spec <spec-path>`. Or pipe the file to your own tooling.

The probe is read-only.

---

## Error handling

- **Missing spec path**: stop and ask.
- **Spec file not found**: report the missing path and stop.
- **Wrong file type** (strategic spec instead of technical): warn and suggest `/ido4shape:review-spec`.
- **Review synthesis failure**: if the review report is incomplete or you cannot reach a verdict, report the failure specifically. Do not retry automatically — ask the user if they want to re-run or abort.
