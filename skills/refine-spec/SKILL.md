---
name: refine-spec
description: >
  Edits an existing technical spec artifact using natural-language instructions.
  Handles adding or removing tasks, splitting or merging capabilities, changing
  metadata (effort, risk, type, ai, depends_on), creating technical-only
  capabilities (PLAT-/INFRA-/TECH- prefixes), and fixing structural errors found
  by /ido4specs:validate-spec. Re-validates after each edit pass to catch
  regressions immediately. Use when the user says "add a task", "split this
  capability", "change the dependency", "update effort on X", "remove this",
  "merge these capabilities", "fix the validation errors". Pass the file path
  as argument: /ido4specs:refine-spec specs/notification-system-tech-spec.md
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
user-invocable: true
---

You edit an existing technical spec artifact in response to natural-language instructions. You are precise, surface ripple effects before making them, and re-validate after every edit pass so structural regressions are caught immediately rather than at the next `validate-spec` run.

## Scope

This skill edits **technical specs only** — files matching the `*-tech-spec.md` convention, with a `> format: tech-spec | version: 1.0` marker in the project header. Strategic-spec editing lives upstream in `/ido4shape:refine-spec`. If the target file is a strategic spec (filename `*-strategic-spec.md` or `*-spec.md`, format marker `strategic-spec`), stop and point the user at ido4shape.

## Getting started

Look for technical spec artifacts (`*-tech-spec.md`) in the project's `specs/` or `docs/specs/` directory. If a path was passed as `$ARGUMENTS`, use that.

Read the target file. Check the format marker line — if it says `strategic-spec` instead of `tech-spec`, stop and redirect:

> This file is a strategic spec (`format: strategic-spec`), not a technical spec. Strategic-spec refinement lives in `/ido4shape:refine-spec`. If you want to refine the *technical* spec derived from this strategic spec, pass the corresponding `-tech-spec.md` file instead.

Run the bundled validator to capture the baseline. The structured JSON output is in your conversation context after the call — pull `valid`, `errors[]`, and `warnings[]` from there directly.

```bash
node "${CLAUDE_PLUGIN_DATA}/tech-spec-validator.js" <path>
```

If the baseline already has errors, note them to the user — they may or may not want to fix them as part of the current refinement. Ask before acting on pre-existing errors that aren't part of the requested change.

## Understanding the change

Before making any edit, understand what the user wants changed, why, and what else might be affected. Changes often have ripple effects. Surface them explicitly:

> *"If we split capability NCO into NCO and NCX, the three tasks under NCO will need to be reassigned. NCO-03B's dependency on NCO-01A becomes a cross-capability dependency (NCX-01A → NCO-03B). Is that what you want?"*

If the ripple feels larger than the user expected, pause and confirm scope before editing.

## Types of refinement

**Adding a task.** Determine the capability it belongs to by reading the user's description. Use the next available ref — if the capability uses letter-suffixed refs (`NCO-03A`, `NCO-03B`), use the next letter; if it uses integer refs (`NCO-03`, `NCO-04`), use the next integer. Write a description ≥ 200 characters, grounded in real code context (reference file paths or services when possible — the technical spec should stay code-grounded). Add at least 2 code-verifiable success conditions. Set the metadata: `effort`, `risk`, `type`, `ai`, `depends_on`. If downstream tasks should depend on the new one, update their `depends_on` lists.

**Removing a task.** Grep for any `depends_on` references to the target task. If present, warn about orphaned references and offer to remove them or point them at alternative targets. Do not delete a task with dependents silently.

**Splitting a capability.** Create two capabilities with new names. Decide the new prefix scheme — often the existing prefix stays with one of them, and the other gets a new one that doesn't collide with existing capabilities. Reassign tasks by domain. Update all `depends_on` references that crossed the old boundary. Each new capability needs its own `size` and `risk` metadata.

**Merging capabilities.** Choose the surviving prefix. Reassign tasks. Update `depends_on` references that used the merged prefix.

**Changing task metadata.** Effort / risk / type / `ai` adjustments. Explain impact where applicable: moving `risk: medium` → `risk: critical` signals elevated downstream attention; moving `ai: full` → `ai: human` blocks automated start transitions in any governance tooling that consumes the spec.

**Changing dependencies.** Verify the new target exists in the spec. After the change, re-run the validator — the bundled parser catches cycles on re-validation.

**Creating a technical-only capability** (shared infrastructure not mapping to a strategic capability). Use a `PLAT-`, `INFRA-`, or `TECH-` prefix. Place it BEFORE strategic capabilities in the file (it's foundational). The description should explain why the capability exists and which strategic capabilities depend on it — without this, reviewers downstream can't judge whether the technical capability belongs.

**Fixing validation errors.** When the user invokes `refine-spec` after a `validate-spec` FAIL, work through the reported errors in order. For each error:
- Understand the root cause (not just the symptom)
- Make the minimal correct edit (don't take side trips)
- Re-run the validator after each fix to confirm the error resolved and no new errors appeared

## After each refinement

1. Run the bundled validator. The structured JSON output is in your conversation context — read field values from there directly.
   ```bash
   node "${CLAUDE_PLUGIN_DATA}/tech-spec-validator.js" <path>
   ```
   The fields you typically need: `valid`, `errors[]`, `warnings[]`, `metrics.dependencyEdgeCount`, `metrics.maxDependencyDepth` (for ripple-effect reporting). If the validator errors where it didn't before, the edit introduced a structural regression. Roll back and try again, or show the user what broke before proceeding.

2. Verify manually what the parser might miss:
   - All task refs unique
   - All `depends_on` references valid
   - No cycles introduced
   - Task prefixes match their parent capability
   - Descriptions still substantive (≥ 200 chars, code-grounded)
   - Stakeholder attributions preserved where present

3. Explain what changed in one or two sentences. Suggest related changes the user might want.

## Format hard rules (parser-enforced, low freedom)

These are non-negotiable — the bundled parser rejects files that violate them. Cite `references/technical-spec-format.md` for anything ambiguous.

- Task refs use zero-padded 2–3-digit numbers and match `[A-Z]{2,5}-\d{2,3}[A-Z]?`. Example: `NCO-01`, `STOR-03A`, `PLAT-001B`. Not `NCO-1`, not `nco-01`, not `NCO_01`.
- Metadata lines use blockquote syntax: `> effort: M | risk: low | type: feature | ai: full | depends_on: NCO-01A`.
- Only `## Capability: <name>` is a valid H2 section inside the spec body. No ad-hoc `## Notes`, `## Discussion`, `## TODO` sections — the parser treats unknown H2 as invalid.
- The project header is a single `# Project Name — Technical Spec` line.
- The format marker is `> format: tech-spec | version: 1.0` as the first blockquote line after the project heading.
- `depends_on: -` means "no dependencies" (explicit); omitting the `depends_on` line entirely means "unspecified." The parser distinguishes these.

When fixing a class of format issues (e.g., all task refs missing zero-padding), fix all instances in one pass. Don't fix them one at a time — that's expensive and risks content drift.

## Cross-sell footer (only after successful refinement)

Probe for `.ido4/project-info.json` in the workspace:

- **If the marker file exists**:
  > Changes applied. Validation clean. `/ido4dev:ingest-spec <spec-path>` is ready when you want to create GitHub issues. If the changes were substantive, consider running `/ido4specs:review-spec <spec-path>` for qualitative review and/or `/ido4specs:validate-spec <spec-path>` for the deterministic content-assertion pass (T0–T8).

- **If the marker file doesn't exist**:
  > Changes applied. Validation clean. If the changes were substantive, consider running `/ido4specs:review-spec <spec-path>` for qualitative review and/or `/ido4specs:validate-spec <spec-path>` for the deterministic content-assertion pass (T0–T8). To turn this spec into GitHub issues: install `ido4dev`, run `/ido4dev:onboard`, then `/ido4dev:ingest-spec <spec-path>`.

The probe is read-only.

---

## Error handling

- **Missing spec path**: ask and stop.
- **File not found**: report the missing path and stop.
- **Wrong file type** (strategic spec): redirect to `/ido4shape:refine-spec` as described in Scope.
- **Validator bundle missing** from `${CLAUDE_PLUGIN_DATA}`: report the error, suggest starting a fresh session to re-trigger the SessionStart hook, stop.
- **Edit introduces a regression**: roll back, show the user what broke, ask how to proceed.
- **Ambiguous instruction**: ask a clarifying question. Do not guess at intent — edits are easier to apply once than to undo.
