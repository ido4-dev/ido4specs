# Phase 2 Completion Record — ido4specs plugin scaffold

**Completed:** 2026-04-14
**Status:** ✓ Done on local `main`, not pushed (GitHub repo creation is Phase 5)
**Plan:** [`docs/phase-2-execution-plan.md`](phase-2-execution-plan.md)
**Validation:** `bash tests/validate-plugin.sh` → **130 passed, 0 failed, 0 warnings, STATUS: PASS**

---

## Summary

Phase 2 of the `ido4specs` extraction created the plugin scaffold from `ido4dev`'s decompose pipeline. Five skills and three agents ported with a language pass per `ido4-suite/docs/prompt-strategy.md`. Two bundled validators committed (`@ido4/tech-spec-format@0.1.0` and `@ido4/spec-format@0.7.2`). Packaging adapted from `ido4shape`'s canonical pattern. All four architectural bets from the execution plan §1 — parser-as-seam, methodology neutrality, inline-execution reliability, zero runtime coupling — verified intact and grep-enforced by `tests/validate-plugin.sh`.

## Commit history (local main, head `b8be1ab`)

| Commit | Stage | What landed |
|---|---|---|
| `65de6c6` | Plan | `docs/phase-2-execution-plan.md` (1120 lines, 15 sections) |
| `1fe88dc` | A + B | Packaging scaffolding + references (20 files, 2278 insertions) |
| `350ab4a` | C | 3 agents ported with language pass (3 files, 581 insertions) |
| `c8d4224` | D | 5 skills created with new conventions (5 files, 872 insertions) |
| `b8be1ab` | E | CLAUDE.md and README rewritten for shipped state (2 files, 151 insertions / 49 deletions) |

## What was built

### Skills (5)

| Skill | Source | Role |
|---|---|---|
| `create-spec` | `ido4dev/skills/decompose/SKILL.md` | Phase 1 — strategic spec + codebase → technical canvas. Stage 0 calls bundled `spec-validator.js` instead of `parse_strategic_spec` MCP tool. Stage 0.5 emits path-reporting + optional co-location nudge. |
| `synthesize-spec` | `ido4dev/skills/decompose-tasks/SKILL.md` | Phase 2 — canvas → technical spec. New Stage 1d auto-runs the bundled tech-spec validator. Cross-sell footer probes `.ido4/project-info.json` read-only. |
| `review-spec` | `ido4dev/skills/decompose-validate/SKILL.md` Stage 1 only | Phase 3a — qualitative review via `spec-reviewer` agent on Sonnet. Slim split: Stages 2 (preview) and 3 (ingest) dropped — those move to `ido4dev:ingest-spec` in Phase 3. |
| `validate-spec` | (new) | Phase 3b — Pass 1 wraps the bundled tech-spec validator with intelligent error interpretation. Pass 2 applies 8 content assertions (T0–T8) targeting downstream ingestion fitness. |
| `refine-spec` | (new, structure from ido4shape:refine-spec technical half) | Edit existing technical specs. Refuses to operate on strategic specs (filename + format-marker check, redirects to ido4shape). Re-validates after every edit pass. |

All five under 500 lines per `prompt-strategy.md`. All cite the canonical `-tech-canvas.md` / `-tech-spec.md` filenames and the §5.3 derivation rule.

### Agents (3)

| Agent | Source | Model | Lines | Role |
|---|---|---|---|---|
| `code-analyzer` | `ido4dev/agents/code-analyzer.md` | opus | ~250 | Canvas template and rules reference for `create-spec`. **Stale `parse_strategic_spec` MCP call in Step 1 rewritten** to consume parsed strategic-spec data from the skill's Stage 0. |
| `technical-spec-writer` | `ido4dev/agents/technical-spec-writer.md` | opus | ~210 | Template and rules reference for `synthesize-spec`. Goldilocks principle, metadata assessment, technical-only capabilities. |
| `spec-reviewer` | `ido4dev/agents/spec-reviewer.md` | sonnet | ~85 | Review protocol for `review-spec`. Two-stage protocol (format compliance + content quality). Governance-implications section reframed as "downstream awareness" — informational, not enforcement. |

All three under 300 lines per `prompt-strategy.md`. All `tools` fields cleaned (no `mcp`, no `Bash`, no `WebFetch`/`WebSearch`). All read inline by skills, never spawned as plugin-defined subagents — preserves the round-3 inline-execution pattern.

### Bundled validators (2)

| Bundle | Package | Version | Size | Role |
|---|---|---|---|---|
| `dist/tech-spec-validator.js` | `@ido4/tech-spec-format` | `0.1.0` | 15 KB | Validates technical specs. Used by `validate-spec`, `refine-spec`, and `synthesize-spec`'s auto-validation Stage 1d. |
| `dist/spec-validator.js` | `@ido4/spec-format` | `0.7.2` | 9 KB | Parses upstream strategic specs. Used by `create-spec`'s Stage 0 — replaces the old `parse_strategic_spec` MCP call and is the architectural mechanism for zero MCP coupling. |

Both with version markers (`dist/.tech-spec-format-version`, `dist/.spec-format-version`) and SHA-256 checksums (`dist/.tech-spec-format-checksum`, `dist/.spec-format-checksum`). `SessionStart` hook copies both to `${CLAUDE_PLUGIN_DATA}` so skills can invoke them via `node` without needing the plugin root path.

### Scripts (3)

- `scripts/release.sh` — version bump + CHANGELOG generation + commit + push, with **dual-bundle pre-flight** (checks both bundles against npm), `--yes` flag for non-interactive use, `--dry-run` flag for pre-flight only. Adapted from `ido4shape/scripts/release.sh`.
- `scripts/update-tech-spec-validator.sh` — fetch `@ido4/tech-spec-format` from npm or local ido4 build, smoke-test against `references/example-technical-spec.md`, write checksum.
- `scripts/update-spec-validator.sh` — fetch `@ido4/spec-format` from npm or local ido4 build, smoke-test against `tests/fixtures/example-strategic-spec.md`, write checksum.

All three pass shellcheck at error severity.

### Validation suite (`tests/validate-plugin.sh`)

14 test groups, 130 individual checks, 0 failures, 0 warnings. Improvements over the `ido4shape` baseline:

- **Test 9 — Language hygiene**: all-caps directive ceiling (`MUST|NEVER|ALWAYS|IMPORTANT|CRITICAL`) ≤ 10, `TodoWrite` leak grep, XML tag grep
- **Test 10 — Zero runtime coupling**: MCP tool reference grep, ido4dev skill reference grep
- **Test 11 — Methodology neutrality**: `Scrum|Shape-Up|Hydro|BRE|methodology profile|container-bound` grep
- **Test 12 — Filename conventions**: stale `-canvas.md`/`-technical.md` grep with `[^-]` guard against false positives, canonical `-tech-canvas.md`/`-tech-spec.md` presence check
- **Test 4 — Dual-bundle round-trip**: both validators must execute and round-trip their respective example fixtures

The four architectural bets from the execution plan are guarded by these checks automatically on every run.

### Workflows (3)

- `.github/workflows/ci.yml` — runs `validate-plugin.sh` on push and PR
- `.github/workflows/update-tech-spec-validator.yml` — `repository_dispatch` from `@ido4/tech-spec-format`'s publish workflow + weekly cron + manual `workflow_dispatch`. Auto-PR for patch/minor, review-required for major
- `.github/workflows/sync-marketplace.yml` — **gated off** with `if: false &&` until Phase 5. Reason: the marketplace entry and `MARKETPLACE_TOKEN` secret don't exist during Phases 2–4, so running the workflow unconditionally would generate noise rather than signal. Activation procedure documented inline in the workflow file.

### Top-level docs

- `LICENSE` — MIT
- `SECURITY.md` — bundled-validator architecture, hook surface, sub-agent constraints, runtime-coupling claim, cleanup procedure
- `CHANGELOG.md` — initialized with the `0.1.0 — unreleased` entry
- `README.md` — full pipeline diagram, getting started example, bundled validators section, documentation pointers
- `CLAUDE.md` — Skills, Agents, Typical layout, Bundled validators, Development, Reference Repositories (with packaging-vs-content distinction), Suite Coordination, Authoring Conventions, Working Style sections

### References

- `references/technical-spec-format.md` — copied from `ido4/architecture/spec-artifact-format.md` with provenance header. Monorepo deletion deferred to Phase 4.
- `references/example-technical-spec.md` — copied from `ido4/tests/fixtures/technical-spec-sample.md` with provenance header. Round-trip-tested under the bundled tech-spec validator.

### Test fixtures

- `tests/fixtures/example-strategic-spec.md` — copied from `ido4/tests/fixtures/strategic-spec-context-pipeline.md`. Used by `update-spec-validator.sh` for round-trip smoke testing of the strategic-spec validator bundle.

## Architectural decisions worth preserving

These are the calls made during Phase 2 that future work should not reverse without explicit cause:

1. **Inline execution, not subagent spawn.** All three plugin-defined agents are read by skills inline as templates and rules references. They are never spawned via the `Agent` tool. This preserves the round-3 fix from `ido4dev/reports/e2e-003-ido4shape-cloud.md` OBS-04b — plugin-defined subagents hang at ~25–30 tool uses in the current Claude Code environment, while inline execution with full conversation context is reliable and produces stronger synthesis.

2. **Dual bundled validators, both committed.** `dist/spec-validator.js` is just as load-bearing as `dist/tech-spec-validator.js`. The strategic validator is the architectural mechanism for zero MCP coupling — without it, `create-spec`'s Stage 0 would need to call `parse_strategic_spec` via MCP, breaking the bet. Two bundles, two version markers, two checksums, two update scripts.

3. **synthesize-spec inlines its validator call.** Stage 1d runs `node dist/tech-spec-validator.js` directly rather than trying to chain-invoke `/ido4specs:validate-spec`. Skills aren't programmatically callable from other skills in Claude Code; inlining the node call is the clean pattern. `validate-spec` remains the user's tool for deeper interpretation.

4. **Filename scheme `-strategic-spec` / `-tech-canvas` / `-tech-spec`.** Three distinct suffixes with zero collision risk. `specs/*-tech-*.md` is a single glob for everything `ido4specs` produced. Spec-name derivation has a four-suffix priority list with backward-compat for the raw `-spec.md` filename `ido4shape` produces (so users who don't rename at copy time still work). Documented in §5 of the execution plan and enforced by `validate-plugin.sh` Test 12.

5. **Cross-sell footer is consistent across four skills.** `synthesize-spec`, `review-spec`, `validate-spec`, and `refine-spec` all probe `.ido4/project-info.json` read-only and emit the same two message variants. Future drift between the four would be a real risk — the canonical wording lives in each skill body and should be kept in sync.

6. **`refine-spec` refuses to operate on strategic specs.** Filename + format-marker check, redirects to `/ido4shape:refine-spec`. Prevents users from accidentally running technical-spec edits on the wrong file type.

7. **`sync-marketplace.yml` is gated off until Phase 5.** `if: false &&` guard with activation procedure documented inline. Avoids a Phase 2–4 window of CI failures from a workflow that legitimately can't succeed yet.

## What's intentionally not in Phase 2

| Item | Why deferred | Unblocked by |
|---|---|---|
| `repair-spec` skill | Designed against speculation has no value. Held until real failure data from live use exists. | Phase 5 + actual user runs |
| Live smoke test in fresh `claude --plugin-dir` session | Cannot be done from inside an active Claude Code session — needs a separate process | User-driven manual test |
| `ido4dev` slimming | Different repo, different release cycle | Phase 3 |
| `ido4/architecture/spec-artifact-format.md` deletion from monorepo | `ido4dev` still references it during Phases 2–3; deleting now would break cross-references | Phase 4 (bundled with `interface-contracts.md` contract #6) |
| `interface-contracts.md` contract #6, `cross-repo-connections.md` entry, `suite.yml` tier-1 entry | Cross-repo coordination — belongs in suite repo commits | Phase 4 |
| `@ido4/tech-spec-format` npm release | Externally visible, irreversible — held until everything coherent | Phase 5 |
| `ido4-dev/ido4specs` GitHub repo creation | Public face of the project, held until everything else aligns | Phase 5 |
| Marketplace registration + `MARKETPLACE_TOKEN` secret | Phase 5 release moment | Phase 5 |
| Full E2E pipeline smoke test | Needs an interactive Claude Code session | Phase 5 user-driven test |

## Validation summary

```
$ bash tests/validate-plugin.sh
=========================================
ido4specs Plugin Validation
=========================================

--- Test 1: Plugin Manifest ---           ✓ 11 checks
--- Test 2: Directory Structure ---       ✓ 8 checks
--- Test 3: Documentation Files ---       ✓ 6 checks
--- Test 4: Bundled Validators ---        ✓ 13 checks (dual-bundle round-trip clean)
--- Test 5: SKILL.md Files ---            ✓ 25 checks (5 skills × 5 sub-checks)
--- Test 6: Agent Files ---               ✓ 27 checks (3 agents × 9 sub-checks)
--- Test 7: Hooks ---                     ✓ 6 checks
--- Test 8: References ---                ✓ 9 checks (example parses + has metadata)
--- Test 9: Language Hygiene ---          ✓ 3 checks (no all-caps, no TodoWrite, no XML)
--- Test 10: Zero Runtime Coupling ---    ✓ 2 checks (no MCP, no stale ido4dev refs)
--- Test 11: Methodology Neutrality ---   ✓ 1 check
--- Test 12: Filename Conventions ---     ✓ 4 checks
--- Test 13: Shell Script Quality ---     ✓ 11 checks (executable + bash -n + shellcheck)
--- Test 14: claude plugin validate ---   ✓ 1 check

=========================================
RESULTS: 130 passed, 0 failed, 0 warnings
=========================================
STATUS: PASS
```

## Next: Phase 3

`ido4dev` slimming. Delete `skills/decompose/`, `skills/decompose-tasks/`, and the three agents that moved (`code-analyzer.md`, `technical-spec-writer.md`, `spec-reviewer.md`). Rename `decompose-validate` → `ingest-spec` and slim it to Stages 2 (preview) and 3 (ingest) only. Update `ido4dev/CLAUDE.md` and `ido4dev/.claude-plugin/plugin.json` to reflect the governance-only positioning. Verify `tests/validate-plugin.sh` and `tests/compatibility.mjs` still pass. Optional UX win: `ingest-spec` should default to globbing `specs/*-tech-spec.md` when invoked without arguments.

Estimated effort: 1–2 hours for a focused session. Reversible (revert the commit, ido4specs continues to exist in its own directory with no dependency on ido4dev's state).
