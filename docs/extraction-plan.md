# ido4specs — extraction plan and target architecture

**Status:** ✓ All five phases complete 2026-04-15. `ido4specs` is live on GitHub, npm, and the `ido4-plugins` marketplace. `ido4dev` slimmed and released at v0.8.0. Phase 7 wildcard-dep bug closed as a side-effect. Remaining: user-driven live E2E smoke test.
**Created:** 2026-04-13
**Last updated:** 2026-04-15 (Phase 5 landed)
**Scope:** Extract the strategic-spec → technical-spec authoring flow from `ido4dev` into a standalone companion plugin, `ido4specs`, and split the technical-spec parser out of `@ido4/core` into a new sibling package `@ido4/tech-spec-format`.

## Completion record

| Phase | Status | Commit / notes |
|---|---|---|
| **0** | ✓ Done 2026-04-13 | This document |
| **1** | ✓ Done 2026-04-14 | `ido4` monorepo commit `a898421` — `feat: extract @ido4/tech-spec-format package from @ido4/core`. `ido4-suite` commit `241371b` — suite.yml updated. Package `@ido4/tech-spec-format@0.1.0` live in the monorepo with 41 tests, bundled CLI, version contract (strict-when-present / lenient-when-absent), CRLF-normalized parser, `schemaVersion` in CLI output, Invariant-1-compliant pre-flight in `release.sh`, CI build+smoke+size checks for both bundles. Full workspace at **1772/1772 tests passing**. Not yet released to npm — will ship when `scripts/release.sh 0.8.0` runs. |
| **2** | ✓ Done 2026-04-14 | `ido4specs` plugin scaffold complete on local `main` (5 stage-boundary commits, head `b8be1ab`, plus follow-up `a9aa418` for gap closure, not pushed). 5 skills (`create-spec`, `synthesize-spec`, `review-spec`, `validate-spec`, `refine-spec`), 3 agents (`code-analyzer`, `technical-spec-writer`, `spec-reviewer` — all read inline, none spawned as subagents), dual bundled validators (`@ido4/tech-spec-format@0.1.0` + `@ido4/spec-format@0.7.2`) with version markers and SHA-256 checksums, minimal `SessionStart` hook, three scripts (`release.sh` with dual-bundle pre-flight + `--yes`/`--dry-run`, two update scripts), 14-test `validate-plugin.sh` (130 PASS / 0 FAIL / 0 WARN clean), four workflows (`ci.yml` active, `update-tech-spec-validator.yml` and `update-spec-validator.yml` both active and symmetric, `sync-marketplace.yml` gated off until Phase 5), top-level docs (`LICENSE`, `SECURITY.md`, `CHANGELOG.md`, `README.md`, `CLAUDE.md`). Canonical filename scheme `-strategic-spec` / `-tech-canvas` / `-tech-spec` enforced. Full execution detail in `docs/phase-2-execution-plan.md` and `docs/phase-2-completion-record.md`. **Note on dual-bundle architecture:** Phase 2 introduced a dual-bundle design not in the original plan — `dist/spec-validator.js` (the strategic-spec parser) is bundled alongside `dist/tech-spec-validator.js` so `create-spec` Stage 0 can parse the upstream strategic spec without an MCP call. The `update-spec-validator.yml` GitHub workflow that mirrors `update-tech-spec-validator.yml` shipped in this row's gap-closure follow-up; both bundles are now auto-updated via dispatch from `ido4`'s `publish.yml`, no manual updates. See §10 below for the corresponding two-entry update to `cross-repo-connections.md`. |
| **3** | ✓ Done 2026-04-14 | `ido4dev` slimmed on local main in three commits: `e26dfd8` (delete authoring skills, agents, legacy command shims), `3999fb0` (rename `decompose-validate` → `ingest-spec` with slimmed body and the optional default-glob UX win from §8), `16e0f17` (positioning docs + cross-references + tests updates). `ido4specs` commit `e5e579e` relocated `docs/ingestion-enforcement.md` out of `ido4dev` into `ido4specs/docs/` — a scope addition not in the original §8 list, resolving the open question flagged in section 12. Validation after the slim: `ido4dev tests/validate-plugin.sh` = 112/0/0, `tests/compatibility.mjs` = 23/0. Suite master plan `ido4-suite/PLAN.md` Phase 9.3 marked complete in commit `87cee9f`. **Caveat:** the live manual smoke test of `/ido4dev:onboard` and `/ido4dev:ingest-spec` specified as a Phase 3 deliverable in section 9 was NOT performed — automated validation passed, but no one ran the skills end-to-end in a fresh `claude --plugin-dir` session. Deferred to Phase 5 live-release validation or an explicit user-driven smoke test. |
| **4** | ✓ Done 2026-04-15 | Suite integration landed in three commits across two repos. `ido4-suite` commits: `4a72967` (Phase 7 wildcard-dep paper trail — behavior-drift note in `interface-contracts.md` + brief), `6ff0abf` (the main Phase 9.4 commit — 6 files, +352/-153: contracts #1–#5 holistically refreshed for the three-plugin world, new contract #6 added, `cross-repo-connections.md` rebuilt with dual-bundle dispatch rows marked `[PENDING — Phase 9.5.4a/b]` and receiver-side rows marked "receiver live, dispatch wiring pending", `ecosystem-overview.md` rebuilt with three-plugin pipeline diagram and dual-bundle architecture, `suite.yml` extended to `auto_update_workflows: [...]` list form with `github: null` for `ido4specs` matching the tier-3 `ido4shape-cloud` precedent, `CLAUDE.md` updated with tier-1 table and three-plugin paragraph, `PLAN.md` Phase 9.4 items marked complete with execution detail). `ido4` monorepo commit: `37f8a86` (the deferred monorepo cleanup — deleted `architecture/spec-artifact-format.md` which had been moved to `ido4specs/references/technical-spec-format.md` in Phase 9.2, updated references in `two-artifact-pipeline.md` with a stale-notice header pointing at the three-plugin docs, rewired `test-ingestion-live.mjs` to read from `tests/fixtures/technical-spec-sample.md`, updated `ingestion-schemas.ts` to reference the `@ido4/tech-spec-format` package, comment-only updates in `spec-parser.test.ts` and `full-artifact-stress.test.ts`). Validation: `bash scripts/audit-suite.sh` = 40 passed / 0 failures / 0 known failures / 1 warning / 3 skipped — STATUS: PASS clean (the 1 warning is pre-existing about `ido4` `publish.yml` not having an explicit `gh release create` step — a Phase 5 consideration, not a Phase 4 gap). `@ido4/tech-spec-format` tests 41/41 PASS after the comment updates. **Note on original 9.4.5 wording:** the initial PLAN.md 9.4.5 instruction (add `known_divergences` entries for missing repo / no releases to keep audit clean) was unimplementable as written — the mechanism only covers invariant-numbered failures and there's no GH-releases check. The Phase 9.4 agent correctly used `github: null` instead, matching the tier-3 `ido4shape-cloud` precedent. This architectural improvement is captured in the updated PLAN.md Phase 9.4.5 entry. |
| **5** | ✓ Done 2026-04-15 | Release coordination completed end-to-end in one session. Executed in dependency order (9.5.2 → 9.5.3 → 9.5.4 → 9.5.1 → 9.5.5 → 9.5.6 → 9.5.7) rather than numeric order so the ido4 0.8.0 tag push would be the first event exercising the new dispatch wiring end-to-end. Results: (a) `ido4-dev/ido4specs` public GitHub repo, 12 commits on origin/main, first release `v0.1.0` live; (b) secrets configured — `IDO4SPECS_DISPATCH_TOKEN` on `ido4-dev/ido4`, `PAT` on `ido4-dev/ido4specs`, fresh fine-grained `MARKETPLACE_TOKEN` rotated across all three plugin repos; (c) `ido4/publish.yml` wired with three dispatches (ido4shape + ido4specs × 2), first exercised by the ido4 0.8.0 release — both ido4specs receivers opened auto-PRs, CI passed, auto-merge fired, both bundles refreshed to 0.8.0 on ido4specs main; (d) `ido4` 0.8.0 released with all four packages on npm including the new `@ido4/tech-spec-format`; (e) `ido4specs@0.1.0` added to marketplace.json + plugin source synced to `ido4-plugins/plugins/ido4specs/`; (f) `ido4specs/sync-marketplace.yml` activation gate flipped and first automated sync succeeded; (g) `ido4dev` v0.8.0 released as the slimmed governance-only plugin. **Phase 7 closed as a side-effect:** `ido4/scripts/release.sh` now auto-pins internal `@ido4/*` deps to `~${VERSION}` on every bump, mechanically enforcing the same-version contract. Empirical proof via `ido4dev/tests/round3-agent-artifact.mjs`: 22/0 passing against fresh 0.8.0 install (was 19/2 failing against frozen 0.5.0). Two user-driven items remain open: DoD item 3 (Cowork verification of ido4shape) and DoD item 11 (live E2E smoke test of the full `/ido4specs:create-spec → ... → /ido4dev:ingest-spec` chain in a fresh Claude Code session). Full execution detail in `ido4-suite/PLAN.md` Phase 9.5 entry and plan-history table. |

This document is both the architecture spec for the target state and the migration plan to get there. Once the extraction is complete, sections 3–4 remain as the canonical architecture reference; the rest becomes history.

---

## 1. Why this exists

The "strategic spec → GitHub issues" pipeline is the most self-contained slice of `ido4dev`:

- Clean inputs (an ido4shape strategic spec `.md`)
- Clean outputs (a technical spec `.md` → GitHub issues)
- Zero runtime dependency on the governance layer (BRE, standups, retros, compliance, board, health, sandbox)

Today this slice is coupled to the rest of `ido4dev`: the user can't adopt the decomposition flow without also installing a plugin that ships 20 other governance skills and a full MCP server. That creates a friction wall for a real audience — ido4shape users who want to turn their specs into issues but aren't buying into an AI-hybrid governance platform.

**The strategic bet:**

1. **Funnel.** A lightweight "turn my strategic spec into technical issues" plugin is a much easier first adoption step than "install our full platform." Some users stay there. Some graduate into `ido4dev` later when governance resonates.
2. **Architectural discipline.** Drawing the seam forces cleaner separation inside `@ido4/core` between the ingestion parser and the governance-bound services. Even if the companion plugin never shipped, the analysis pays off inside the monorepo.
3. **Product clarity.** After the split, `ido4dev`'s identity becomes "the governance plugin for ido4." Sharper value prop than today's "decompose + governance bundle."

---

## 2. Scope and non-goals

**In scope:**

- Creating `@ido4/tech-spec-format` as a new sibling package inside the `ido4` monorepo, parallel to `@ido4/spec-format`
- Moving the technical-spec parser (`spec-parser.ts`, its types, a new CLI, an esbuild bundle config) out of `@ido4/core/domains/ingestion`
- Creating the `ido4specs` plugin repo with 5 skills and 3 agents
- Porting `decompose`, `decompose-tasks`, and the methodology-neutral part of `decompose-validate` from `ido4dev` into `ido4specs`
- Porting `code-analyzer`, `technical-spec-writer`, `spec-reviewer` agents from `ido4dev` into `ido4specs`
- Slimming `ido4dev`'s remaining ingest path and renaming `decompose-validate` → `ingest-spec`
- Adding `ido4specs` to the suite manifest and updating `interface-contracts.md`

**Out of scope (explicit):**

- Changes to the technical-spec format itself — this extraction ships the format unchanged at v1.0
- Changes to the methodology profile model
- Changes to the BRE, governance skills, or any part of `ido4dev` unrelated to the decompose flow
- Backward-incompatible changes to any public API (`@ido4/mcp` tools, `ingest_spec`, `parse_strategic_spec`)
- Shipping new product features beyond what the extraction restructures — "no, and also improve X" is exactly how this kind of work spirals

---

## 3. Current state

### Package graph (as of 2026-04-13)

```
@ido4/spec-format (v0.7.2) — strategic parser, standalone, CLI, esbuild bundle
  ↓ depends on
@ido4/core (v0.7.2) — 14 domains incl. ingestion, governance, BRE, profiles
  ↓ depends on
@ido4/mcp (v?) — MCP server, wraps @ido4/core, exposes ~57 tools

ido4dev plugin — installs @ido4/mcp via SessionStart hook
  ├── decompose skill (Phase 1: strategic spec → canvas)
  ├── decompose-tasks skill (Phase 2: canvas → technical spec)
  ├── decompose-validate skill (Phase 3: review + ingest to GH)
  ├── code-analyzer agent
  ├── technical-spec-writer agent
  ├── spec-reviewer agent
  └── ~20 governance skills (standup, plan-*, retro-*, board, compliance, health, sandbox, onboard, etc.)

ido4shape plugin — bundles @ido4/spec-format as dist/spec-validator.js
```

### Where the technical-spec parser lives today

`~/dev-projects/ido4/packages/core/src/domains/ingestion/`:

| File | Lines | Role | Purity |
|---|---|---|---|
| `spec-parser.ts` | 328 | Technical-spec markdown → `ParsedSpec` AST | **Pure.** Zero profile awareness, zero I/O, zero container coupling. Imports: types + 2 helpers from `@ido4/spec-format` |
| `spec-mapper.ts` | 220 | `ParsedSpec + MethodologyProfile → MappedSpec` | **Pure.** Value-mapping tables, topological sort, depends only on profile types |
| `ingestion-service.ts` | 368 | `MappedSpec → GitHub issues` via repositories | **Container-bound.** Constructor takes `ITaskService, IIssueRepository, IProjectRepository, MethodologyProfile, ILogger`. Calls `@octokit/graphql` transitively |
| `types.ts` | 120 | Type definitions for all three layers | Types only |

The cleanliness of the split at the module level is the key enabler for this extraction: the parser is literally a pure function that consumes markdown text and emits structured data. It has no hidden coupling to the governance machinery.

### Where methodology matters

Traced end-to-end: the methodology profile is needed at exactly one point in the flow — inside `spec-mapper.ts`, when transforming `ParsedSpec` into `MappedSpec`. Everything else — strategic parsing, canvas synthesis, technical-spec authoring, spec-reviewer structural check — is methodology-neutral.

The profile is **not** passed as a parameter to `ingest_spec`. It's loaded from `.ido4/methodology-profile.json` by `ProfileConfigLoader` at service-container boot time. The user picks methodology once during `/ido4dev:onboard`, and that choice persists in project config. The ingest call just reads `container.profile`.

**Consequence for this extraction:** `ido4specs` can produce a methodology-neutral technical spec `.md` and never touch the methodology question at all. Whoever ingests the file later picks methodology at *their* project init. Two different users can ingest the same `.md` into two different methodology projects.

### `parseSpec` callers inside `@ido4/core`

Two internal callers, both inside core:

- `packages/core/src/domains/ingestion/ingestion-service.ts:32` — the main ingest flow
- `packages/core/src/domains/sandbox/scenario-builder.ts:88` — sandbox scenario construction

Both resolve cleanly: after extraction, `@ido4/core` takes a new dependency on `@ido4/tech-spec-format` and re-exports `parseSpec` from its ingestion index. No code changes to either caller.

### Canvas storage

The `decompose` skill picks an artifact directory at Stage 0.5:

1. If `specs/` exists in the project root, use it
2. Else if `docs/specs/` exists, use it
3. Else if `docs/` exists, create `docs/specs/`
4. Else create `specs/`

The canvas is written as `{artifact-dir}/{spec-name}-canvas.md`. Workspace-local, not plugin-local. The `repair-spec` skill (new, below) can find the canvas by running the same lookup against the same spec name.

### ido4shape's bundled-validator pattern (the blueprint)

This is what `ido4specs` will mirror:

- `@ido4/spec-format/esbuild.bundle.mjs` builds `dist/spec-validator.bundle.js` — a minified CJS bundle with `__SPEC_FORMAT_VERSION__` defined from `package.json.version`, plus a banner containing version + source URL + "DO NOT EDIT"
- The bundle is auto-propagated to `ido4shape` via `repository_dispatch` from `@ido4/spec-format`'s publish workflow (see `ido4shape/.github/workflows/update-validator.yml`)
- Manual fallback: `bash scripts/update-validator.sh <version-or-local-path>`
- `ido4shape/dist/spec-validator.js` + `dist/.spec-format-version` are committed to git
- `ido4shape/hooks/hooks.json` has a `SessionStart` hook that copies `${CLAUDE_PLUGIN_ROOT}/dist/spec-validator.js` → `${CLAUDE_PLUGIN_DATA}/spec-validator.js`
- Skills invoke the validator via Bash: `node "${CLAUDE_PLUGIN_DATA}/spec-validator.js" <path-to-spec.md>`
- Exit codes: 0 = valid, 1 = structural errors, 2 = usage/IO error
- CLI emits structured JSON to stdout; skills parse it and interpret errors intelligently

---

## 4. Target architecture

### Package graph (after extraction)

```
@ido4/spec-format              @ido4/tech-spec-format    ← NEW sibling package
  (strategic parser)             (technical parser)
  Standalone CLI                 Standalone CLI
  Esbuild bundle                 Esbuild bundle
       ↓                              ↓
       └───────────┬──────────────────┘
                   ↓ both deps
              @ido4/core
              (14 domains, unchanged public API)
              parseStrategicSpec + parseSpec re-exported from their new homes
                   ↓
              @ido4/mcp
              (unchanged)

ido4shape plugin              ido4specs plugin              ido4dev plugin
 bundles                        bundles                       installs @ido4/mcp
 @ido4/spec-format              @ido4/tech-spec-format        governance only
                                                               (no decompose)
 Skills: create-spec,           Skills: create-spec,          Skills: onboard,
 refine-spec,                   refine-spec,                  ingest-spec (new name),
 review-spec,                   review-spec,                  standup, plan-*,
 validate-spec,                 validate-spec,                retro-*, board,
 synthesize-spec                repair-spec (new)             compliance, health,
                                                               sandbox, etc.

 Produces:                      Produces:                     Consumes:
  strategic-spec.md              technical-spec.md             technical-spec.md
                                                               → GH issues
```

### Plugin boundaries

- **`ido4shape`**: owns strategic-spec authoring. Input: user conversation. Output: `strategic-spec.md`. No runtime dependency on anything downstream.
- **`ido4specs`** (NEW): owns technical-spec authoring. Input: `strategic-spec.md` + codebase. Output: `technical-spec.md`. No runtime dependency on `ido4dev` or `@ido4/mcp`. Bundles `@ido4/tech-spec-format` for structural validation.
- **`ido4dev`** (slimmed): owns governance and ingestion execution. Input: `technical-spec.md` + an initialized project. Output: GitHub issues + governance loop. Still depends on `@ido4/mcp`.

### Data flow

```
  ido4shape                     ido4specs                          ido4dev
 ┌──────────┐               ┌─────────────┐                   ┌───────────┐
 │ dialogue │ ─strategic─►  │  code       │ ─canvas.md──►     │  onboard  │
 │ + canvas │   spec.md     │  analyzer   │                   │  (picks   │
 └──────────┘               │  (agent)    │                   │  methodo- │
                            └─────────────┘                   │  logy)    │
                                    │                         └───────────┘
                                    ▼                               │
                            ┌─────────────┐                         ▼
                            │  technical  │                   ┌───────────┐
                            │  spec       │ ─technical─►      │  ingest-  │
                            │  writer     │   spec.md         │  spec     │
                            └─────────────┘                   │  (calls   │
                                    │                         │  ingest_  │
                                    ▼                         │  spec     │
                            ┌─────────────┐                   │  MCP tool)│
                            │  spec-      │                   └───────────┘
                            │  reviewer   │ ─verdict─►              │
                            │  (agent)    │                         ▼
                            └─────────────┘                   ┌───────────┐
                                    │                         │  @ido4/   │
                                    ▼                         │  mcp →    │
                            ┌─────────────┐                   │  @ido4/   │
                            │  validate-  │                   │  core →   │
                            │  spec       │ ─bundled──►       │  mapper + │
                            │  (parser)   │  parser           │  issue    │
                            └─────────────┘                   │  creator  │
                                    │                         └───────────┘
                                    ▼                               │
                            technical-spec.md                       ▼
                            (stamped + validated)              GitHub issues
                                                              (methodology-
                                                               shaped containers)
```

### Zero runtime coupling

`ido4specs` has **no runtime dependency** on `ido4dev` or `@ido4/mcp`. It cannot call `ingest_spec`, cannot read the BRE, cannot open containers. It produces a `.md` file on disk and stops.

The only cross-plugin interaction is an **informational footer** written by `ido4specs` skills at end-of-flow:

- If `.ido4/project-info.json` exists in the workspace (i.e., `ido4dev` has been initialized here), the footer says: *"Your technical spec is ready at `path`. Run `/ido4dev:ingest-spec path` to create GitHub issues."*
- If not, the footer says: *"Your technical spec is ready at `path`. To turn it into GitHub issues, install `ido4dev` (`/plugin install ido4dev@ido4-plugins`), run `/ido4dev:onboard` to choose a methodology, then `/ido4dev:ingest-spec path`. Or pipe the `.md` to your own tooling."*

This is a **filesystem probe**, not plugin introspection. `ido4specs` never attempts to *call* `ido4dev`'s skills or MCP tools — it just knows how to *name* them for the user. If the marker file is ever renamed, the generic fallback message is the failure mode and nothing breaks.

---

## 5. The technical-spec format contract

This section defines the contract between `ido4specs` (producer) and `ido4dev`'s ingestion path (consumer). It mirrors contract #1 (strategic-spec format) in the suite's `interface-contracts.md`, adapted for the technical-spec layer.

### Format marker

Every valid technical spec includes this line in its project header block:

```
> format: tech-spec | version: 1.0
```

Parallel to the existing strategic-spec marker (`> format: strategic-spec | version: 1.0`). This is a **claim of intent**, not proof of validity — the parser run is what actually verifies conformance.

### Semver rules

Applied to the format version, not the package version:

- **Major** (1.x → 2.0) — breaking change. Existing files may no longer parse. Requires explicit migration path and deprecation window.
- **Minor** (1.0 → 1.1) — additive change. New optional metadata fields, new optional sections. Old parsers emit a warning on unknown fields but succeed; new parsers recognize them.
- **Patch** (1.0.0 → 1.0.1) — clarification only. Parser behavior unchanged.

### Compatibility policy

- **Backward compatibility** (new consumer, old file): required within a major version. A v1.1 parser parses v1.0 files without errors.
- **Forward compatibility** (old consumer, new file): best-effort within a major version. A v1.0 parser parses v1.1 files with warnings on unknown-but-optional additions. Major mismatches fail fast with a clear error.

### Version enforcement

Both parsers (`@ido4/tech-spec-format` CLI and `@ido4/core`'s re-exported `parseSpec`) do the same check:

1. Read the format marker line
2. Parse the declared version (major.minor)
3. Check against the parser's `SUPPORTED_FORMAT_VERSIONS` constant
4. **If major mismatch**: fail with a specific error ("this file declares format v2.0 but this parser supports v1.x — upgrade `@ido4/tech-spec-format`")
5. **If minor mismatch, newer file**: warn ("this file declares v1.1 but this parser supports v1.0 — unknown fields may be ignored")
6. **If missing marker**: fail with a specific error ("no format marker — this file may not be a technical spec, or may be pre-v1.0")

This catches exactly the class of bug that broke under the wildcard-dep issue (`@ido4/mcp` pinned `@ido4/core: "*"` and froze at 0.5.0 while 0.7.2 had incompatible regex changes). Before: silent divergence. After: fail at parse time with a specific remediation message.

### Shared test fixtures

Both packages reference the same fixture files so drift breaks CI in both repos:

- `@ido4/tech-spec-format/tests/fixtures/*.md` — valid and invalid examples
- `@ido4/core/src/domains/ingestion/tests/` — references the same fixtures via relative path or package export

A new fixture added to one side must produce the same parse result on the other.

### Two-sided parsing, one place each

- **Structural validation happens at both ends.** `ido4specs:validate-spec` runs the parser on file production. `@ido4/core` runs it again on file ingestion. The same parser, same contract, same error messages.
- **Semantic validation happens only once**, at `ido4specs:review-spec` via the `spec-reviewer` agent. Qualitative AI judgment can't be meaningfully re-run at the ingestion layer — and re-running would just duplicate compute and cause drift between two reviewer implementations.
- **No auto-repair at ingestion.** Binary pass/fail. If ingestion fails parsing, the user's options are: hand-fix the file, run `/ido4specs:repair-spec` to walk through the errors interactively, or re-run the full authoring flow if the drift is too large.

---

## 6. `@ido4/tech-spec-format` package — what to build

### Layout

Mirroring `@ido4/spec-format` exactly:

```
packages/tech-spec-format/
  package.json              # name, version 0.1.0, main, types, bin, scripts
  tsconfig.json
  esbuild.bundle.mjs        # Builds dist/tech-spec-validator.bundle.js
  src/
    index.ts                # Exports parseSpec, parser types, version constant
    cli.ts                  # CLI entry point with --help, version banner
    spec-parser.ts          # Moved from @ido4/core/domains/ingestion/
    types.ts                # Parser-only types (ParsedSpec, ParsedTask, etc.)
    spec-parse-utils.ts     # Optional: shared helpers if needed
  tests/
    parser.test.ts          # Vitest, mirrors spec-format's test style
    fixtures/
      round3-agent-artifact.md  # The proven real-world input
      valid-minimal.md
      invalid-missing-marker.md
      invalid-duplicate-ref.md
      invalid-circular-dep.md
      ... (the existing enforcement-probes fixtures)
  README.md                 # Thin pointer to ido4specs/references/technical-spec-format.md
```

### Key design choices

- **`name`**: `@ido4/tech-spec-format`
- **`version`**: start at `0.1.0`, bump to `1.0.0` when the format stabilizes and both producers/consumers are wired up
- **`bin`**: `"ido4-tech-spec-format": "dist/cli.js"` — CLI binary name
- **`SUPPORTED_FORMAT_VERSIONS`**: exported constant, initially `["1.0"]`. Consumers read this to know what they can parse.
- **`__TECH_SPEC_FORMAT_VERSION__`**: esbuild define, same pattern as spec-format
- **Banner**: `// @ido4/tech-spec-format vX.Y.Z | bundled YYYY-MM-DD | Source: https://github.com/ido4-dev/ido4/tree/main/packages/tech-spec-format | DO NOT EDIT`
- **CLI exit codes**: 0 valid, 1 structural errors, 2 usage/IO error (same as spec-format)
- **CLI output**: structured JSON to stdout with parse results, metrics, errors/warnings separated (mirrors spec-format's CLI output shape)
- **`--version` flag**: prints the version and exits (standard pattern, not currently in spec-format but worth adding in both)

### Dependencies

- Runtime: none (zero-dep package, like `@ido4/spec-format`)
- Dev: TypeScript, Vitest, esbuild — same as `@ido4/spec-format`

### What `@ido4/core` loses

`packages/core/src/domains/ingestion/spec-parser.ts` — deleted. Replaced by a re-export from the new package:

```typescript
// packages/core/src/domains/ingestion/index.ts
export { parseSpec } from '@ido4/tech-spec-format';
export { mapSpec, findGroupingContainer, topologicalSort } from './spec-mapper.js';
export { IngestionService } from './ingestion-service.js';
// ... types
```

`@ido4/core/package.json` gets a new dependency: `"@ido4/tech-spec-format": "^0.1.0"` (semver-pinned, not wildcard — see the wildcard-dep incident).

### What stays in `@ido4/core`

- `spec-mapper.ts` — methodology-aware. Stays with core because it depends on profile types and serves a single caller (IngestionService). Moving it gains nothing, costs a second package.
- `ingestion-service.ts` — container-bound. Stays by necessity.
- `types.ts` — the mapper/service-specific types stay. The parser-only types move with the parser.

---

## 7. `ido4specs` plugin — what to build

### Directory layout

Mirroring `ido4shape` as the suite's reference plugin:

```
ido4specs/
  .claude-plugin/
    plugin.json                    # name, version 0.1.0, description, repository, license
  .github/
    workflows/
      ci.yml                       # Layer 3 — runs tests/validate-plugin.sh
      sync-marketplace.yml         # Layer 4 — gated on CI success
      update-tech-spec-validator.yml  # Auto-update bundle from @ido4/tech-spec-format
  agents/
    code-analyzer.md               # Moved from ido4dev + language pass
    technical-spec-writer.md       # Moved from ido4dev + language pass
    spec-reviewer.md               # Moved from ido4dev + language pass
  dist/
    tech-spec-validator.js         # Bundled @ido4/tech-spec-format CLI (committed)
    .tech-spec-format-version      # Version marker file
  hooks/
    hooks.json                     # SessionStart copies dist/tech-spec-validator.js
  references/
    technical-spec-format.md       # The authoring reference for the format
    example-technical-spec.md      # Parseable reference example
  scripts/
    release.sh                     # Layer 1 pre-flight
    session-start.sh               # Hook backing script
    update-tech-spec-validator.sh  # Manual bundle update
  skills/
    create-spec/SKILL.md           # Phase 1: strategic spec → canvas (code analysis)
    synthesize-spec/SKILL.md       # Phase 2: canvas → technical spec (agent synthesis)
    review-spec/SKILL.md           # Phase 3a: qualitative review via spec-reviewer agent
    validate-spec/SKILL.md         # Phase 3b: structural validation via bundled parser
    refine-spec/SKILL.md           # Iterative edits to an existing technical spec
    repair-spec/SKILL.md           # NEW — interactive repair mode after validation/ingest failure
  tests/
    validate-plugin.sh             # Mirrors ido4shape's validation suite
  CHANGELOG.md
  CLAUDE.md                        # Plugin overview + "ido4 Suite Coordination" section
  LICENSE
  README.md
  SECURITY.md
```

### Skill set (6 skills)

Naming and phase structure are symmetric with `ido4shape`, which is the suite's reference implementation. `ido4shape` splits its authoring flow into a monolithic discovery skill (`create-spec`) followed by separate skills for each artifact-producing or artifact-verifying phase (`synthesize-spec`, `review-spec`, `validate-spec`, `refine-spec`). The plugin prefix (`/ido4specs:` vs `/ido4shape:`) disambiguates context.

This structure aligns with the decision test in `ido4-suite/docs/prompt-strategy.md`:

| Condition | Architecture | Applies to ido4specs |
|---|---|---|
| Single conversational loop, no heavy artifacts, no governance checkpoints | One skill with prose-based stages | No — we produce two artifacts (canvas, technical spec) |
| Produces intermediate artifacts that need independent validation | Separate skills per artifact-producing phase | Yes |
| Human must review and approve before the next phase begins | Separate skills — the skill boundary IS the checkpoint | Yes |
| Phases need different agent configurations | Separate skills — each sets its own frontmatter | Yes (`spec-reviewer` runs on Sonnet, others on Opus) |

Three of four conditions apply, so the split is warranted. A single orchestrating `create-spec` would collapse across artifact boundaries that our own documented standard requires us to respect. The skill boundaries are the structural checkpoints — prose-based "ready to proceed?" prompts inside a monolithic skill are advisory-only and (per Anthropic's Claude Code docs) may be bypassed by the model.

The symmetry with `ido4shape`:

| Action | `ido4shape` (strategic) | `ido4specs` (technical) |
|---|---|---|
| Start the work — build the canvas | `create-spec` (dialogue → canvas) | `create-spec` (code analysis → canvas) |
| Crystallize canvas into artifact | `synthesize-spec` (canvas → strategic.md) | `synthesize-spec` (canvas → technical.md) |
| Qualitative review of the artifact | `review-spec` | `review-spec` |
| Structural validation of the artifact | `validate-spec` | `validate-spec` |
| Iterate on an existing artifact | `refine-spec` | `refine-spec` |
| Repair after a downstream failure | (n/a — ido4shape doesn't have repair mode) | `repair-spec` (new) |

Same verbs, same boundaries, different domain. The canvas is the handoff artifact in both plugins — dialogue-built in `ido4shape`, code-analysis-built in `ido4specs`.

**`/ido4specs:create-spec <strategic-spec-path>`** — Phase 1. Takes a strategic spec, parses it, detects project mode, runs parallel `Explore` subagents for integration-target analysis, and synthesizes a technical canvas using the `code-analyzer` agent as a template reference (inline execution, not spawned as subagent — synthesis quality degrades in forked subagent contexts per the prompt-strategy doc). Stages inside the skill:

1. Parse the strategic spec via the bundled `@ido4/spec-format` validator (the `ido4specs` plugin bundles both validators — strategic and technical)
2. Determine artifact directory and project mode (same logic as today's `decompose` Stage 0.5)
3. Spawn parallel `Explore` subagents for integration targets
4. Synthesize the technical canvas inline, guided by the `code-analyzer.md` template
5. Write the canvas to `{artifact-dir}/{spec-name}-canvas.md`
6. Verify the canvas (capability count matches strategic spec)
7. Stop. Report the canvas path and tell the user: *"Canvas ready at {path}. Review it, then run `/ido4specs:synthesize-spec {path}` when you're ready to produce the technical spec."*

The skill ends at the canvas boundary. Phase 2 is a separate user decision.

**`/ido4specs:synthesize-spec <canvas-path>`** — Phase 2. Takes a canvas, produces the technical spec `.md`. Mirrors `ido4shape:synthesize-spec`'s role exactly. Uses the `technical-spec-writer` agent (read as a template reference, inline execution). Stages:

1. Pre-flight: verify the canvas exists and has the expected capability sections
2. Read the canvas as the sole source of truth (Phase 2 does NOT re-read the strategic spec — the canvas is the preservation layer)
3. Synthesize the technical spec inline, guided by `technical-spec-writer.md`
4. Write the spec to `{artifact-dir}/{spec-name}-spec.md`
5. Auto-run `/ido4specs:validate-spec` for Layer 1 (structural) verification before returning to the user
6. Stop. Report the spec path, the validation result, and tell the user: *"Technical spec ready at {path}. Run `/ido4specs:review-spec {path}` for qualitative review, or `/ido4specs:refine-spec {path}` to edit."*

**`/ido4specs:review-spec <technical-spec-path>`** — Phase 3a. Invokes the `spec-reviewer` agent for a qualitative review pass. Returns PASS / PASS WITH WARNINGS / FAIL with structured findings. This is Layer 2 of the two-layer validation pattern — the qualitative LLM pass. No structural validation (that's `validate-spec`), no file edits. The agent runs on Sonnet per existing frontmatter.

**`/ido4specs:validate-spec <technical-spec-path>`** — Phase 3b. Runs the bundled `@ido4/tech-spec-format` CLI. Binary pass/fail with line-numbered errors. Structural only. This is Layer 1 deterministic validation (the cheap, fast, no-LLM pass). Together with `review-spec` this forms the two-layer pattern referenced in the prompt-strategy doc. Invoked automatically at the end of `synthesize-spec` and manually whenever the user wants structural verification.

**`/ido4specs:refine-spec <technical-spec-path>`** — iterative edits to an existing technical spec. Parallel to `ido4shape:refine-spec` but targets technical-spec fields (effort, risk, type, ai, dependencies) instead of strategic fields. Distinct from `repair-spec` in that refine is for intentional user-driven edits, not error recovery. Runs `validate-spec` after every refinement pass to catch structural drift immediately.

**`/ido4specs:repair-spec <technical-spec-path>`** — new interactive repair mode. Takes an error context (from a previous `validate-spec` or `ingest-spec` failure), walks the user through each error, asks clarifying questions where needed, and produces a proposed fix diff. Internal protocol:

1. Run `validate-spec` to get current error list (or accept pre-supplied error context)
2. Check if the canvas artifact still exists at the conventional path (`{artifact-dir}/{spec-name}-canvas.md`). If yes, load it as grounding context; if no, fall back to pure user dialogue
3. Walk errors in order. Classify each:
   - **Pure syntax** (missing metadata, wrong task-ref format) — propose fix, confirm once, apply
   - **Content drift** (description no longer matches effort, missing success conditions) — ask user to clarify what changed
   - **New intent** (user added an unparseable capability block) — ask about intent, shape into proper structure
4. Batch questions where possible; don't peck at one error at a time
5. Re-validate after each repair pass. Only declare "repaired" when the parser agrees
6. Produce a new proposed `.md`; user reviews the diff and approves before anything is written
7. Know scope limits: if drift is substantial (e.g., a whole new capability cluster), recommend re-running `create-spec` with an updated canvas instead of trying to repair

### Agents (3 agents)

Moved from `ido4dev/agents/` with a language pass per the prompt-strategy rules:

- **`code-analyzer.md`** — canvas template and rules reference. Read inline, not spawned as subagent.
- **`technical-spec-writer.md`** — synthesizes the technical spec from the canvas. Also read inline.
- **`spec-reviewer.md`** — qualitative reviewer. Runs on Sonnet (per the existing frontmatter), returns structured verdict.

All three get the Round 4 language pass applied as part of the move: dial back all-caps imperatives, convert qualitative rules to principles + examples, add WHY motivation, preserve empirical hard rules with clear WHY. This is the audit work from last night applied in context, not as a standalone Round 4 audit.

### Hooks (1 hook)

`hooks/hooks.json`:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup",
        "hooks": [
          {
            "type": "command",
            "command": "cp \"${CLAUDE_PLUGIN_ROOT}/dist/tech-spec-validator.js\" \"${CLAUDE_PLUGIN_DATA}/tech-spec-validator.js\" 2>/dev/null || true",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

Simpler than `ido4shape`'s hook config because `ido4specs` doesn't need canvas-context, phase-gate, or stop-check hooks. Just the bundled-validator copy.

### Validation suite (`tests/validate-plugin.sh`)

Mirrors `ido4shape/tests/validate-plugin.sh`. Checks:

1. Plugin manifest (`plugin.json` exists, valid JSON, required fields, name matches, repository URL points to `ido4-dev/ido4specs`)
2. Bundled validator present (`dist/tech-spec-validator.js` exists, runs without error, responds to `--version`)
3. Skill directory structure (5 skills, each has `SKILL.md` with valid frontmatter)
4. Agent directory structure (3 agents, valid frontmatter)
5. Hook config (`hooks.json` valid JSON, SessionStart hook present)
6. References present (`technical-spec-format.md`, `example-technical-spec.md`)
7. `claude plugin validate .` passes
8. Language-pass check: grep for all-caps `MUST|NEVER|ALWAYS|IMPORTANT|CRITICAL` in skill/agent bodies and fail if found outside specific allowed contexts

### CLAUDE.md

Standard plugin structure with the "ido4 Suite Coordination" section copied from `ido4dev`. Adds a new section referencing the extraction plan (this doc) during migration, to be removed once extraction lands.

### Release pattern (`scripts/release.sh`)

Copied from `ido4shape/scripts/release.sh` and adapted:

- Layer 1 pre-flight: bundle drift check vs npm, local-vs-remote sync, `validate-plugin.sh`, plugin.json format check
- Layer 2: version bump in `.claude-plugin/plugin.json`, commit, tag, push
- Layers 3 & 4 run as GitHub Actions (CI + sync-marketplace)
- `--yes` flag for non-interactive agent use
- `--dry-run` flag for pre-flight only

---

## 8. `ido4dev` changes — what to delete and slim

### Status

✓ **Phase 3 complete 2026-04-14** on `ido4dev` local main (not pushed). Three commits: `e26dfd8` (deletions), `3999fb0` (rename + slim), `16e0f17` (positioning + cross-references). Plus a scope addition — the relocation of `docs/ingestion-enforcement.md` to `ido4specs/docs/` in `ido4specs` commit `e5e579e`. See section 12 for the full trace and the `ido4-suite/PLAN.md` Phase 9.3 entry (commit `87cee9f`) for the checklist view. The body below is the plan as it was executed; deviations and additions are noted inline where they occurred.

### Delete (move to ido4specs)

- `skills/decompose/` — fully moved
- `skills/decompose-tasks/` — fully moved
- `agents/code-analyzer.md` — fully moved
- `agents/technical-spec-writer.md` — fully moved
- `agents/spec-reviewer.md` — fully moved

### Slim and rename

- `skills/decompose-validate/` → `skills/ingest-spec/`

The original `decompose-validate` has three stages: (1) run spec-reviewer and produce a verdict, (2) run `ingest_spec` with `dryRun=true` for preview, (3) run `ingest_spec` with `dryRun=false` on user approval.

After extraction, Stage 1 moves to `ido4specs:review-spec`. `ido4dev`'s remaining ingest skill handles Stages 2 and 3 only. Rename reflects the new, simpler responsibility: take a validated technical spec path, preview it under the project's chosen methodology, ingest on user approval.

New skill body:

```
/ido4dev:ingest-spec <technical-spec-path>

Stage 0: Check .ido4/project-info.json exists (project initialized)
Stage 1: Call ingest_spec with dryRun=true, present preview
Stage 2: Wait for explicit user approval
Stage 3: Call ingest_spec with dryRun=false, report created issues
```

### Keep

- `skills/onboard/` — methodology choice still happens here
- All governance skills (standup, plan-*, retro-*, board, compliance, health, sandbox, etc.)
- The PM agent
- `.mcp.json` + SessionStart hook that installs `@ido4/mcp`
- `tests/compatibility.mjs` (update `criticalTools` list if any tool names change)

### Update

- `CLAUDE.md` — reflect that decomposition now lives upstream in `ido4specs`. Update the plugin description to "governance plugin for ido4."
- `skills/onboard/SKILL.md` — add a note that users who want to author technical specs should install `ido4specs` separately, or reference existing technical specs from disk
- `plugin.json` description — replaced to match new scope
- `package.json` description — same
- `scripts/release.sh` — update the validation command if any moved files were referenced
- **Added in Phase 3 execution, not in the original plan:** `skills/sandbox-explore/SKILL.md` Option 13 ("Full Pipeline") was rewritten. It previously chained `/ido4dev:decompose → decompose-tasks → decompose-validate`, all of which were being deleted. Per user direction, the walkthrough was rewritten to chain `/ido4specs:create-spec → synthesize-spec → review-spec → validate-spec → /ido4dev:ingest-spec` instead, positioning `ido4specs` as an installed prerequisite for the demo flow. Option 13's execution logic now checks for `ido4specs` installation and reports the prerequisite if missing, rather than invoking a deleted skill.
- **Scope addition:** `docs/ingestion-enforcement.md` was moved out of `ido4dev` into `~/dev-projects/ido4specs/docs/ingestion-enforcement.md` (`ido4specs` commit `e5e579e`). Pre-extraction the doc sat in `ido4dev` because that plugin owned both the authoring agents and the `ingest_spec` MCP call. Post-extraction, the authoring-side assertions the doc audits live in `ido4specs` (the moved agents) and the enforcement code lives in `@ido4/core` — neither is an `ido4dev` concern. Content updates applied during the move: `decompose-tasks` → `synthesize-spec` references throughout, `decompose-validate` Stage 1 → `ido4specs:review-spec` references, "Scope and repo placement" section rewritten, silent-failure gap remediation options extended to include `ido4specs:validate-spec` bundled pre-ingest validation. No test-anchor claims changed. The test harness that anchors the doc's claims (`tests/round3-agent-artifact.mjs`, `tests/enforcement-probes.mjs`, `tests/fixtures/round3-agent-artifact.md`) stays in `ido4dev/tests/` for now because those scripts import `@ido4/core` from `ido4dev`'s `node_modules` via the MCP install — a future natural move is to reparent them into the `@ido4/tech-spec-format` package tests in the monorepo, but that's out of scope for Phase 9.

### Verification

- `bash tests/validate-plugin.sh` passes after changes → ✓ **112 passed / 0 failed / 0 warnings**
- `tests/compatibility.mjs` still passes → ✓ **23 passed / 0 failed** (the `criticalTools` list also lost `parse_strategic_spec` in the same commit, since no `ido4dev` skill calls it anymore)
- `claude plugin validate .` passes → ✓ (runs as the last check inside `validate-plugin.sh`)
- A manual smoke test: `/ido4dev:onboard` still initializes a project cleanly; `/ido4dev:ingest-spec` accepts a pre-existing technical spec and creates issues → ⚠️ **NOT performed in Phase 3.** Automated validation passed, but no one ran the skills end-to-end in a fresh `claude --plugin-dir` session. The manual smoke test is deferred to either Phase 5 live-release validation (which ships an externally-visible release that will exercise the skills naturally) or an explicit user-driven smoke test in a dedicated session. Worth running before Phase 5 so the release doesn't carry latent end-to-end bugs.

---

## 9. Migration and release order

The extraction ships in **five phases**, each with a clear commit point and reversible up to Phase 5. Between phases, the user reviews.

### Phase 1 — `@ido4/tech-spec-format` package

Scope: create the new package inside `~/dev-projects/ido4/packages/tech-spec-format/`. Move the parser. Add CLI, esbuild bundle, version marker support, README pointer. Write tests using existing Round 4 fixtures as a starting base. Update `@ido4/core` to depend on the new package and re-export `parseSpec`. Verify `IngestionService` and `SandboxService.scenarioBuilder` still work.

Shippable in isolation. Runs through the existing `ido4` monorepo release pattern (CI → `publish.yml`). Lands on npm as `@ido4/tech-spec-format@0.1.0` and `@ido4/core` bumps to consume it.

Rollback: revert the commit; nothing downstream changes.

### Phase 2 — `ido4specs` plugin, local only

Scope: create the plugin directory tree at `~/dev-projects/ido4specs/`. Copy skills and agents from `ido4dev` with the language pass applied. Bundle `@ido4/tech-spec-format` via a local build. Wire the SessionStart hook. Write `tests/validate-plugin.sh` and get it passing. Write `CLAUDE.md` and the `references/` files.

**Deliverable**: `validate-plugin.sh` clean run. No push to GitHub yet.

Rollback: delete the directory. Nothing in `ido4` or `ido4dev` has changed.

### Phase 3 — `ido4dev` slimming ✓ Complete 2026-04-14

Scope: delete the skills and agents that moved. Rename and slim `decompose-validate` → `ingest-spec`. Update CLAUDE.md, plugin.json, onboard skill references. Run `tests/validate-plugin.sh` and `tests/compatibility.mjs`. Smoke-test `/ido4dev:onboard` and `/ido4dev:ingest-spec` manually.

**Deliverable** (as executed):
- ✓ `ido4dev` validation clean — `tests/validate-plugin.sh` = 112/0/0, `tests/compatibility.mjs` = 23/0
- ✓ Three slim commits on `ido4dev` local main: `e26dfd8`, `3999fb0`, `16e0f17`
- ✓ Scope addition: `docs/ingestion-enforcement.md` relocated to `ido4specs/docs/` (`ido4specs` commit `e5e579e`) — see section 12 for the trace
- ✓ Suite master plan updated: `ido4-suite/PLAN.md` Phase 9.3 marked complete in commit `87cee9f`
- ⚠️ Manual smoke test of `/ido4dev:onboard` and `/ido4dev:ingest-spec` NOT performed — deferred to Phase 5 live-release validation or a dedicated user-driven smoke session. Automated validation alone does not prove end-to-end correctness of the renamed skill or the default-glob Stage 0 logic.

Rollback: revert the three `ido4dev` commits (`git revert 16e0f17 3999fb0 e26dfd8`). `ido4specs` continues to exist in its own directory; nothing ties it to `ido4dev` at this point. The `ido4specs` commit `e5e579e` (doc relocate) can optionally be reverted as well, or left in place — the doc works correctly in either repo.

### Phase 4 — Suite integration

Scope: add `ido4specs` entry to `~/dev-projects/ido4-suite/suite.yml` as a Tier 1 plugin. Add contract #6 (Technical Spec Format) to `interface-contracts.md`. Update contract #5 (MCP Runtime Dependency) to reflect that `ido4dev` is now the only consumer. Update `cross-repo-connections.md` to document the `@ido4/tech-spec-format` → `ido4specs` auto-update flow. Run `bash ~/dev-projects/ido4-suite/scripts/audit-suite.sh` and resolve any violations.

Rollback: revert the suite commit. No functional change to other repos.

### Phase 5 — Release coordination

Scope: actually ship the new artifacts.

1. Release `@ido4/tech-spec-format` to npm (via `ido4` monorepo's release pattern). This goes first because everything else depends on it.
2. Update `ido4specs`'s bundled validator to the released version. Commit. Create the GitHub repo `ido4-dev/ido4specs`. Push. First release: `v0.1.0`.
3. Add `ido4specs` to the `ido4-plugins` marketplace manifest. The sync workflow picks it up automatically.
4. Release the slimmed `ido4dev` (version bump, probably to `v0.8.0` since it's a breaking change to the plugin's scope). Update marketplace manifest.
5. Announcement (if any) goes out after all three artifacts are live.

This phase is where the extraction becomes externally visible. Drive the release button on each artifact explicitly — no automatic cascade.

Rollback: for npm, publish a patch release. For the plugin marketplace, revert the manifest commit. For GitHub repo creation, it can stay (empty repos are cheap) or be deleted.

### Compatibility window

During and after the split, there's a transitional period where users might have only `ido4dev` (old behavior), only `ido4specs` (new authoring flow, no ingestion), or both. The transition is smoothed by:

- **`ido4dev` keeps working during the window**: existing users don't see any breakage. The decompose skills still exist until Phase 3 ships.
- **The bundled `@ido4/tech-spec-format` version in `ido4specs` must be compatible with the version `@ido4/core` consumes in `ido4dev`** at any point when both could be used on the same file. The version contract enforces this fail-fast.
- **Marketplace description updates** make it clear that `ido4dev` users who also want the lightweight authoring story can install `ido4specs` side-by-side.

---

## 10. Suite integration

### Entry in `suite.yml`

```yaml
  - name: ido4specs
    github: ido4-dev/ido4specs
    local: ~/dev-projects/ido4specs
    tier: 1
    role: plugin
    canonical_pattern: true
    artifacts:
      - "ido4specs (Claude Code plugin via ido4-plugins marketplace)"
    audit:
      release_script: scripts/release.sh
      ci_workflow: .github/workflows/ci.yml
      sync_workflow: .github/workflows/sync-marketplace.yml
      auto_update_workflow: .github/workflows/update-tech-spec-validator.yml
      validation_command: "bash tests/validate-plugin.sh"
    known_divergences: []
```

### New interface contract #6 — Technical Spec Format

Added to `interface-contracts.md`:

**What it defines:** The markdown format that `ido4specs` produces and `@ido4/core`'s ingestion pipeline consumes. Heading patterns, task-ref format, metadata syntax, required sections, dependency graph rules.

**Why it matters:** Second contract between the "shape" and "build" sides, parallel to contract #1 (strategic-spec format). If `ido4specs` produces something `@ido4/core` can't read, ingestion fails. If the parser changes output schema, both `ido4specs`'s validation and the MCP ingest tool break.

**Canonical file:** `ido4specs/references/technical-spec-format.md`

**Parser implementation:** `@ido4/tech-spec-format/src/spec-parser.ts`

**Consumers:**
- `ido4specs:validate-spec` (via bundled `dist/tech-spec-validator.js`)
- `@ido4/core` ingestion pipeline (via `parseSpec` re-exported from `@ido4/tech-spec-format`)
- `@ido4/core` sandbox scenario builder (via same re-export)

**Versioning:** Format identifier `> format: tech-spec | version: 1.0` in the spec. Parser published to npm as `@ido4/tech-spec-format`. Breaking changes only at major version boundaries.

### Update to contract #5 — MCP Server Runtime Dependency

Narrow the "consumers" list to `ido4dev` only. Remove the decompose skills from the listed examples of tool invocations; they no longer exist in the consumer.

### Cross-repo connections

Add **two** entries to `cross-repo-connections.md` under "Outbound dispatches and writes". Phase 2 shipped a dual-bundle architecture in `ido4specs` (both `@ido4/tech-spec-format` AND `@ido4/spec-format` are bundled into `dist/`), so two separate dispatch flows are needed — both fully automated, neither manual.

**Entry 1 — `@ido4/tech-spec-format` → `ido4specs`** (new dispatch, Phase 4 wires it):
- **Source:** `ido4` (publishing `@ido4/tech-spec-format`)
- **Target:** `ido4specs`
- **Mechanism:** `repository_dispatch` type `tech-spec-format-published` from `ido4`'s `publish.yml` → `ido4specs`'s `.github/workflows/update-tech-spec-validator.yml`
- **Payload:** version string
- **Downstream action:** auto-update PR with new bundle, gated on patch/minor only; major bumps require manual review

**Entry 2 — `@ido4/spec-format` → `ido4specs`** (new branch on the existing dispatch, Phase 4 wires it):
- **Source:** `ido4` (publishing `@ido4/spec-format`)
- **Target:** `ido4specs` (in addition to the existing `ido4shape` target)
- **Mechanism:** `repository_dispatch` type `spec-format-published` from `ido4`'s `publish.yml` — already dispatches to `ido4shape`'s `update-validator.yml`; Phase 4 adds a parallel dispatch step that targets `ido4specs`'s `.github/workflows/update-spec-validator.yml`
- **Payload:** version string
- **Downstream action:** same auto-update PR pattern as Entry 1 — patch/minor auto-merges, majors require review of `create-spec` Stage 0 parsing-output handling

The receiver workflows in `ido4specs` (`update-tech-spec-validator.yml` and `update-spec-validator.yml`) ship in Phase 2; the dispatch-side wiring in `ido4`'s `publish.yml` is Phase 4 work. Both targets share the same PAT pattern; the secret name (`IDO4SPECS_DISPATCH_TOKEN` or similar) is decided in Phase 4.

**Why the dual-bundle is automated, not manual:** the strategic-spec validator (`@ido4/spec-format`) is used by `/ido4specs:create-spec` Stage 0 to parse the upstream strategic spec — it's the architectural replacement for the old `parse_strategic_spec` MCP call. If the format ever changes, `ido4specs` users get broken parsing the same way `ido4shape` users do. Both consumers should learn about new versions through the same auto-PR pattern; making one manual and one automated would be an unjustified asymmetry.

---

## 11. Decisions — resolved and pending

**Decision #1 — Skill granularity. RESOLVED: six skills, mirroring `ido4shape`.** Initial proposal was a single monolithic `create-spec` with internal stages. Investigation of `ido4shape` (the suite's reference implementation) and the prompt-strategy decision test showed this was wrong: `ido4shape` splits its authoring flow into `create-spec` (canvas dialogue) + `synthesize-spec` (canvas → artifact) + `review-spec` + `validate-spec` + `refine-spec`, and the prompt-strategy doc explicitly says: *"ido4dev's decompose pipeline produces heavy artifacts and requires human review between every phase. The split-skill architecture is warranted."* `ido4specs` inherits the same structural requirements. The six-skill layout (section 7 above) is final.

**Decision #2 — Slimmed `decompose-validate` rename. RESOLVED: rename to `ingest-spec`.** Confirmed with user 2026-04-13. Rationale: the skill's remaining responsibility after the extraction is literally "take a validated `.md` and ingest it via the `ingest_spec` MCP tool." The old name referenced a validation step that no longer lives in `ido4dev`. Rename happens during Phase 3.

**Decision #3 — Reference doc location for the technical-spec format. RESOLVED: one canonical location.** A 505-line format reference already exists at `~/dev-projects/ido4/architecture/spec-artifact-format.md`, currently in the ido4 monorepo. It gets **moved** (not copied) to `ido4specs/references/technical-spec-format.md` as part of Phase 2. The package `@ido4/tech-spec-format/README.md` is a thin package doc (install, CLI usage, API, version contract) with a link to the plugin's format reference — it does not duplicate the grammar.

Why one place:
- Parallel to `ido4shape/references/strategic-spec-format.md` — ido4shape's existing pattern
- The agents that cite it (`technical-spec-writer`, `refine-spec`, `repair-spec`) live in the plugin
- Updates happen on the plugin's authoring cadence, not the monorepo's
- Two places = drift risk; one source of truth = no drift
- The package README isn't a format doc, it's a package doc — different scope, no duplication

Phase 2 action: move the existing file, update any cross-references in `@ido4/core`, `@ido4/mcp` schemas, and `ido4-suite/docs/interface-contracts.md` to point at the new location. Leave a one-line redirect note at the old path for search continuity, or delete if the monorepo prefers clean removal.

---

## 12. Deferred / revisit after the split

These items are set aside deliberately and should be revisited once the extraction is complete. Not priorities for this work.

### Last night's investigation artifacts (ido4dev, currently untracked)

- `docs/ingestion-enforcement.md` — ✓ **Resolved in Phase 3.** The "preserve, absorb, or discard" decision collapsed into a fourth option not anticipated here: **relocate**. The doc was moved to `~/dev-projects/ido4specs/docs/ingestion-enforcement.md` (`ido4specs` commit `e5e579e`) because its subject matter (rule audit of authoring-side assertions vs. `@ido4/core` enforcement) became cross-plugin after the split and its natural home is now `ido4specs` where the authoring agents it audits live. Content was updated during the move (decompose-tasks → synthesize-spec references, scope-and-placement rewrite). `docs/` directory in `ido4dev` is now empty and removed.
- `tests/enforcement-probes.mjs` — ⚠️ **Still untracked in `ido4dev`.** Phase 1's verification used existing `@ido4/tech-spec-format` tests rather than adopting these probes directly, so the "revisit during Phase 1" window passed without action. The file still has value as behavior-level regression infrastructure and will block `scripts/release.sh` pre-flight in Phase 5 (untracked-file check). **Next action before Phase 5 release:** commit these as a dedicated "chore: preserve round-4 parser regression harness" commit on `ido4dev` main, or move them into the `ido4` monorepo's `@ido4/tech-spec-format` package tests.
- `tests/round3-agent-artifact.mjs` + `tests/fixtures/round3-agent-artifact.md` — ⚠️ **Still untracked in `ido4dev`.** Same status and same remediation path as `enforcement-probes.mjs` above. These are the primary real-world-artifact regression tests and should not be lost.
- `reports/round-4-rule-audit.md` — ⚠️ **Still untracked.** The plan said "Discard after Phase 2 completes." Phase 2 is done. Technically this can be `git clean -f`ed now, but the memory file `project_e2e_decompose_findings.md` flagged it as "SUPERSEDED by ido4specs extraction" rather than "lost", so the content was absorbed into that memory and the on-disk file is redundant. **Recommended action before Phase 5 release:** delete the untracked file with `rm` (not `git rm` since never tracked) as part of the working-tree cleanup sweep.
- `CLAUDE.md` working-style edit (already committed to the working tree but untracked) — ✓ Already landed in a prior commit on `ido4dev` main. No pending action.

### Other items surfaced during investigation

- **ido4shape `refine-spec/SKILL.md:20` text cleanup.** The skill text mentions "technical spec (has effort/type/ai fields)" as a format branch. Per user clarification, this refers to technical-persona sessions within strategic authoring, not technical-spec files. The wording is stale — worth a 5-minute edit later to remove the confusing dual-mode framing. **Revisit after extraction lands.**
- **`compatibility.mjs` behavior-level hardening.** Interface contract #5 notes a gap: the test only checks tool names, not behavior. The round3 fixture + probes from last night are a candidate behavior-level test. **Revisit after Phase 3** — by then, `ido4dev`'s scope is clearer and the right test boundary is easier to see. **Gate now open as of 2026-04-14:** Phase 3 shipped. `ido4dev` scope is now "governance only, consumes a validated technical spec via `ingest_spec`" — the right test boundary is behavior-level verification that `ingest_spec` round-trips a known-good technical spec into the expected hierarchy under each methodology profile. The round3 fixture is directly reusable. Still not urgent; track as follow-up work, not blocking.
- **`@ido4/spec-format` CLI `--version` flag.** If we add a `--version` flag to `@ido4/tech-spec-format`'s CLI (recommended for scripting/debugging), mirror it in `@ido4/spec-format`'s CLI for consistency. **Revisit during Phase 1.**

---

## 13. Execution checkpoints

| Phase | Deliverable | Review gate | Reversibility | Status |
|---|---|---|---|---|
| **0** | This document | User sign-off before Phase 1 | N/A | ✓ 2026-04-13 |
| **1** | `@ido4/tech-spec-format` package, `@ido4/core` updated, tests green | User review of the package + core changes | Revert commit | ✓ 2026-04-14 |
| **2** | `ido4specs` local plugin, `validate-plugin.sh` clean | User review of the plugin layout + smoke test | Delete directory | ✓ 2026-04-14 (head `b8be1ab`, live smoke test deferred) |
| **3** | `ido4dev` slimmed, tests + compatibility green | User review + manual smoke test | Revert commit | ✓ 2026-04-14 (three commits `e26dfd8` → `3999fb0` → `16e0f17`; **manual smoke test still pending**) |
| **4** | Suite manifest + interface-contracts updated, audit clean | User review of suite commits | Revert suite commit | ✓ 2026-04-15 (commits `4a72967` + `6ff0abf` in ido4-suite, `37f8a86` in ido4; audit clean 40/0/0) |
| **5** | All three artifacts released, marketplace updated | Externally visible — no further review gates; each release is a deliberate action | Patch releases / manifest revert | ✓ 2026-04-15 (ido4 v0.8.0 on npm, ido4specs v0.1.0 public + marketplace, ido4dev v0.8.0 released; Phase 7 closed as side-effect) |

**Between-phase protocol**: at the end of each phase, report status, pause, wait for "proceed" before starting the next. If a phase reveals a planning error, report and re-plan rather than working around it.

---

## 14. Success criteria

When this extraction is complete, the following should all be true:

1. [x] A user can install `ido4specs` alone, run `/ido4specs:create-spec path/to/strategic-spec.md`, and produce a validated technical spec `.md` on disk. No MCP server installed. No `@ido4/mcp` runtime dependency. **(Architecturally satisfied as of 2026-04-15 — the plugin is shipped and its dependencies are self-contained via bundled validators. Awaiting live verification by user-driven smoke test.)**
2. [x] A user can install `ido4dev` alone (without `ido4specs`) and still do everything `ido4dev` currently does *except* authoring technical specs from scratch. Existing technical specs on disk can still be ingested. **(`ido4dev` v0.8.0 shipped 2026-04-15 with the slim — 21 skills / 1 agent — and `compatibility.mjs` + `validate-plugin.sh` both green.)**
3. [x] A user who installs both plugins sees a smooth handoff: `ido4specs:create-spec` produces a file, the cross-sell footer points at `/ido4dev:ingest-spec`, the next command creates issues. **(Cross-sell footer is live in four ido4specs skills; handoff is filesystem-probe based, not plugin-introspection. Awaiting live verification.)**
4. [x] `@ido4/tech-spec-format` is an independent npm package that any third party could consume to validate technical specs without installing anything else. **(Live on npm at v0.8.0 as of 2026-04-15, standalone, zero runtime deps, `bin` CLI entry, version contract enforced.)**
5. [x] The technical-spec format has an explicit version contract with fail-fast on major mismatch, preventing a repeat of the wildcard-dep silent divergence bug. **(`SUPPORTED_FORMAT_VERSIONS` constant + strict-when-present/lenient-when-absent enforcement shipped in Phase 9.1, verified end-to-end by Phase 9.5 release.)**
6. [x] `bash ~/dev-projects/ido4-suite/scripts/audit-suite.sh` passes clean with `ido4specs` listed as a Tier 1 canonical-pattern plugin. **(41 passed / 0 failures / 0 known failures post-Phase-9.5, verified 2026-04-15.)**
7. [x] Both `ido4shape`'s and `ido4specs`'s skill namespaces are symmetric — same verbs, different plugin prefix, different domain. **(Shipped in Phase 9.2, validated by `tests/validate-plugin.sh` filename-convention and skill-set checks.)**
8. [x] The `ido4` monorepo has cleaner internal layers: `@ido4/spec-format` owns strategic parsing, `@ido4/tech-spec-format` owns technical parsing, `@ido4/core` owns the mapper, service, and governance, `@ido4/mcp` owns the MCP surface. **(Shipped in Phase 9.1, 0.8.0 release landed all four packages on npm 2026-04-15.)**

---

## Status (as of 2026-04-15)

All five phases are complete. `ido4-dev/ido4specs` is a public GitHub repo with `v0.1.0` released, `@ido4/tech-spec-format@0.8.0` is live on npm alongside the three existing monorepo packages, the ido4specs plugin is listed in the `ido4-plugins` marketplace with its source tree synced, and `ido4dev` has been slimmed to governance-only and released at `v0.8.0`. Phase 7 (the wildcard-dep bug that initially blocked this work) closed as a side-effect of Phase 9.5.1's release-script pinning change — `ido4dev/tests/round3-agent-artifact.mjs` went from 19/2 failing against stale `@ido4/core@0.5.0` to 22/0 passing against fresh 0.8.0, empirically verifying the fix.

**Only remaining closure: the live E2E smoke test.** Automated verification (audit, validate-plugin, compatibility, round3 behavior test) all green, but nobody has yet run `/ido4specs:create-spec → synthesize-spec → review-spec → validate-spec → /ido4dev:ingest-spec` end-to-end against a real strategic spec in a fresh Claude Code session. This is a user-driven manual step that the extraction agent cannot execute itself. Same applies to the two earlier pending smoke tests (Phase 2's live plugin load and Phase 3's `/ido4dev:onboard` + `/ido4dev:ingest-spec` walkthrough) — all three fold into one live session run.
