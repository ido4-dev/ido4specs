# Ingestion pipeline enforcement — ground truth

This document records what the `@ido4/core` technical-spec ingestion pipeline **actually** enforces when it consumes artifacts produced by this plugin's `synthesize-spec` skill. It's the authoritative reference for any rule audit in this repo that needs to know "does downstream code catch violations of rule X?"

Every claim below is backed by an executable test. When the installed `@ido4/core` changes behavior, the tests break. When the tests pass, this document is accurate.

## Scope and repo placement

This document lives in `ido4specs` because it audits the rules asserted by this plugin's authoring agents (`code-analyzer`, `technical-spec-writer`, `spec-reviewer`). The behavior it describes lives in `@ido4/core` (the ido4 monorepo), which is not a runtime dependency of this plugin — the parser logic moved into bundled `dist/tech-spec-validator.js` via the `@ido4/tech-spec-format` extraction, so `ido4specs` exercises the same parser at spec-production time that `@ido4/core` exercises at spec-ingestion time.

The test harness that anchors every claim below (`round3-agent-artifact.mjs`, `enforcement-probes.mjs`, and the `round3-agent-artifact.md` fixture) currently lives in `~/dev-projects/ido4dev/tests/` because those scripts import `@ido4/core` directly from `ido4dev`'s `node_modules` (installed transitively via `@ido4/mcp` at session start). This is a historical artifact of the pre-extraction layout: before `ido4specs` existed, both the authoring agents and the consuming runtime lived in `ido4dev`. Post-extraction, a natural future move is to reparent these parser regression tests into the `ido4 monorepo`'s `@ido4/tech-spec-format` package where they'd sit next to the parser source. That move is not urgent — the tests still run correctly from `ido4dev` and still fail fast on drift.

**Known skew as of 2026-04-12.** The matrix below describes `@ido4/core` 0.7.2 source behavior. The installed `@ido4/core` in `ido4dev`'s `node_modules` is currently 0.5.0 due to a wildcard-dep bug in `@ido4/mcp`'s manifest. The two versions differ in at least one user-visible way: the 0.5.0 parser rejects suffixed task refs (`NCO-01A`, `STOR-01B`, etc.) while 0.7.2 accepts them. See `~/dev-projects/ido4-suite/briefs/fix-ido4-mcp-core-wildcard-dep.md` for the fix. Until that fix lands, this document's claims are aspirational for installed behavior but accurate for the target behavior (what users will get once the wildcard is pinned and installs refresh).

## Why this document exists

Prior to the Round 4 rule audit, the rule set in the decomposition agents and skills was growing under the assumption that "the parser" or "the reviewer" would catch format mistakes. That assumption had never been tested end-to-end: until Round 3, the ingestion pipeline had only been exercised on hand-written fixtures written by the same person who wrote the parser, and Round 3's Phase 3 was blocked by the project-initialization gate before `ingest_spec` ever ran on the real agent-produced artifact.

This document closes that gap. It is the first empirical ground truth for what the pipeline catches. The Round 4 rule audit used it as the authoritative reference: no rule was classified as "safe to delete because downstream catches it" unless this document — and the tests backing it — confirmed the claim.

## How to use this document

1. When auditing a rule in any agent or skill definition, find the rule's claim in the **enforcement matrix** below.
2. If the matrix says the claim is **structurally enforced** (fatal at parse or map), the prose rule can be trimmed to a short WHY explanation — the code is the enforcer.
3. If the matrix says the claim is **advisory-only** or **unenforced**, the prose rule is load-bearing. Reshape its language (language pass, principles + examples) but do not delete it.
4. If the matrix says the claim is **silently accepted**, the pipeline will not catch violations. This is an enforcement gap — consider whether the rule should be promoted to a hook, a reviewer check, or a parser fix (a separate issue, not a rule deletion).

## Enforcement layers (reference)

| Layer | Code | What it does |
|---|---|---|
| **Parser** | `@ido4/core` → `domains/ingestion/spec-parser.ts` (re-exported from `@ido4/tech-spec-format`) | Line-by-line state machine. Regex-based heading recognition. Extracts metadata into typed structures. |
| **Mapper** | `@ido4/core` → `domains/ingestion/spec-mapper.ts` | Translates parsed values into methodology-profile types (effort, risk, type, ai). Validates dep refs. Topological sort detects cycles. |
| **IngestionService** | `@ido4/core` → `domains/ingestion/ingestion-service.ts` | Orchestrates parse → map → (dry-run or create issues). Treats some mapper errors as fatal (halt ingestion) and others as non-fatal (continue with warnings). |
| **spec-reviewer agent** | `agents/spec-reviewer.md` (this repo) | Advisory. Runs inline during `ido4specs:review-spec`. Returns PASS / PASS WITH WARNINGS / FAIL. User can ignore warnings and ingest anyway via `ido4dev:ingest-spec`. |
| **BRE** | `@ido4/core` → `domains/...` | Runtime governance on already-ingested GitHub issues. **Plays no role in spec-authoring enforcement.** |

## Severity semantics

- **Fatal** — pipeline halts. No issues are created.
- **Non-fatal error** — logged, ingestion proceeds. May produce incomplete output.
- **Warning** — logged, ingestion proceeds with the offending field set to `undefined` or a sensible fallback.
- **Silently accepted** — no signal at all. Output may differ from input without any detection.

## The enforcement matrix

Each row is a rule-shaped claim that appears in this repo's agents or skills. The columns answer: is the claim enforced, by which layer, and at what severity.

### Structural / format rules

| Claim | Parser | Mapper | Service | Reviewer | Test anchor |
|---|---|---|---|---|---|
| `# Project Name` heading present | Required to enter `PROJECT` state. If missing, project name stays empty. | — | — | Stage 1 format check | `round3-agent-artifact.mjs` |
| `## Capability: Name` heading recognizes a capability | **Strict regex match**. `## Group:` and other variants are silently unrecognized — any tasks beneath them become orphans. | — | — | Stage 1 format check | `enforcement-probes.mjs` "## Group: instead of ## Capability:" probe |
| Task ref format `[A-Z]{2,5}-\d{2,3}[A-Z]?` | **Strict regex match** (0.7.2; 0.5.0 lacks the `[A-Z]?` suffix). Non-matching `### ...` lines are absorbed into the preceding task body. **No error, no warning — silent data loss.** | — | — | Stage 1 format check | `enforcement-probes.mjs` lowercase + too-long-prefix probes |
| Duplicate task refs | **Error (severity=error)** — non-fatal in the parser sense but `IngestionService` halts on any parse error. | — | Halts if `fatalParseErrors > 0` | Stage 1 check | `enforcement-probes.mjs` duplicate-ref probe |
| Known metadata keys only | **Unknown key → warning (severity=warning)**. Known values still captured. | — | — | Stage 1 check | `enforcement-probes.mjs` unknown-key probe |
| Required metadata keys present | **Silently accepted** — parser stores whatever is present, missing keys become `undefined`. | Missing values map to `undefined` silently. | — | Stage 1 check | `round3-agent-artifact.mjs` baseline |
| Blockquote metadata syntax | Parser requires metadata on a blockquote line (`> key: value`). If not a blockquote, the line becomes body. Silent. | — | — | — | (not probed — structurally enforced by the state machine) |

### Metadata value rules

| Claim | Parser | Mapper | Service | Reviewer | Test anchor |
|---|---|---|---|---|---|
| `effort` ∈ {S, M, L, XL} | Stores any string. | **Unknown value → warning + `effort: undefined` in mapped output.** | Ingestion proceeds with undefined effort. | Stage 1 check | `enforcement-probes.mjs` unknown-effort probe |
| `risk` ∈ {low, medium, high, critical} | Stores any string. | **Unknown value → warning + `riskLevel: undefined`.** `critical` → warning + downgraded to `High`. | Ingestion proceeds. | Stage 1 check | `enforcement-probes.mjs` unknown-risk + critical-risk probes |
| `type` ∈ {feature, bug, research, infrastructure} | Stores any string. | **Unknown value → warning + `taskType: undefined`.** | Ingestion proceeds. | Stage 1 check | `enforcement-probes.mjs` unknown-type probe |
| `ai` ∈ {full, assisted, pair, human} | Stores any string. | **Unknown value → warning + `aiSuitability: undefined`.** | Ingestion proceeds. | Stage 1 check | `enforcement-probes.mjs` unknown-ai probe |
| Case-sensitivity of values | Stores raw string. | **Case-insensitive lookup** — `CRITICAL`, `critical`, `Critical` all resolve identically. | — | — | `enforcement-probes.mjs` case-insensitive probe |
| XL effort distinct from L | Stores `XL`. | **Silent information loss** — `XL` and `L` both map to `Large`. No warning. | Ingestion proceeds. | — (reviewer can't see it) | `enforcement-probes.mjs` XL-effort probe |

### Dependency rules

| Claim | Parser | Mapper | Service | Reviewer | Test anchor |
|---|---|---|---|---|---|
| `depends_on` refs resolve to existing tasks | Stores raw strings. | **Unresolved ref → mapping error (non-fatal) + ref silently dropped from `validDeps`**. | Ingestion proceeds; task is created with no dependency. | Stage 1 check | `enforcement-probes.mjs` unresolved-dep probe |
| No circular dependency chains | — (parser not aware of semantics) | **Kahn-algorithm topological sort detects cycles → mapping error with "Circular dependency" message.** | **Halts ingestion** on circular-dependency mapping errors. | Stage 1 check | `enforcement-probes.mjs` circular-dep probe |
| Topological order is deterministic | — | Mapper emits tasks in topological order. | Tasks are created in this order. | — | (covered by `full-artifact-stress.test.ts` in `@ido4/core`'s own tests) |

### Content quality rules

| Claim | Parser | Mapper | Service | Reviewer | Test anchor |
|---|---|---|---|---|---|
| Task description ≥200 characters | **Unenforced** — parser captures any length. | — | — | Stage 2 quality check (advisory) | `round3-agent-artifact.mjs` baseline (1/94 at 187 chars) |
| ≥2 success conditions per task | **Unenforced** — parser captures any count, including zero. | — | — | Stage 2 quality check (advisory) | `round3-agent-artifact.mjs` baseline (0/94 violations) |
| Descriptions reference specific code paths | **Unenforced**. | — | — | Stage 2 quality check (advisory, qualitative) | — |
| Stakeholder attribution preserved verbatim | **Unenforced**. | — | — | **Unenforced** (spec-reviewer does not check this) | — |
| Capability description includes group context | **Unenforced**. | — | — | **Unenforced** | — |
| Strategic context preserved verbatim from strategic spec to canvas | **Unenforced** — prose only. No parser, hook, or reviewer verifies verbatim preservation. | — | — | — | — |
| Effort/risk grounded in canvas complexity | **Unenforced** — no code can verify grounding. | — | — | Stage 2 quality check (advisory, qualitative) | — |
| Methodology-neutral vocabulary during decomposition | **Unenforced** — no check for wave/sprint/cycle terminology in agent prose or output. | — | — | **Unenforced** | — |

### Structural coherence rules

| Claim | Parser | Mapper | Service | Reviewer | Test anchor |
|---|---|---|---|---|---|
| Each strategic capability has its own `## Capability:` section in the canvas | — (canvas is outside the ingestion pipeline — it's an intermediate artifact read only by `synthesize-spec`) | — | — | **Unenforced** — spec-reviewer operates on the technical spec, not the canvas | — |
| Capability count in the technical spec matches the strategic-spec capability count | — | — | — | **Unenforced** | — |
| Task prefix matches parent capability prefix (e.g., `NCO-` tasks under "Notification Core") | — | — | — | Stage 1 check (advisory) | — |

## Round 3 empirical baseline

Fixture: `~/dev-projects/ido4dev/tests/fixtures/round3-agent-artifact.md` — the technical spec produced by this plugin's `synthesize-spec` skill (then called `decompose-tasks` in `ido4dev`, pre-extraction) in Round 3 on the `ido4shape-enterprise-cloud-spec.md` input. 1318 lines, 119,746 chars.

Results were captured against `@ido4/core` **0.7.2 source** (not the stale 0.5.0 currently installed in `ido4dev`'s `node_modules`):

| Metric | Value |
|---|---|
| Capabilities | 29 |
| Tasks | 94 |
| Parse errors | 0 |
| Parse warnings | 0 |
| Orphan tasks | 0 |
| Duplicate refs | 0 |
| Tasks missing any metadata field | 0 / 94 |
| Tasks with body <200 chars | **1 / 94** (PROJ-02B at 187 chars) |
| Tasks with <2 success conditions | **0 / 94** |
| Silent heading-in-body lines | 0 |
| Effort distribution | 52 M, 38 S, 4 L, **0 XL** |
| Risk distribution | 42 low, 36 medium, 16 high, **0 critical** |
| Type distribution | 34 infrastructure, 11 research, 49 feature, 0 bug |
| AI distribution | 25 full, 24 assisted, 45 pair, 0 human |
| Mapping errors (all 3 profiles) | 0 |
| Mapping warnings (all 3 profiles) | 0 |
| Silent metadata loss (→ undefined) | 0 |

**Interpretation.** The Round 3 agent — without hook or validator enforcement — produced an artifact that parses and maps cleanly on every profile **when run through 0.7.2**. The prose rules in `agents/technical-spec-writer.md` are doing their job: the 94 tasks comply with the ≥200-char body, ≥2 success conditions, known metadata values, and dep-graph integrity rules even though none of those are structurally enforced below the agent.

**Implication for rule audits.** Deleting the prose rules that the agent is currently following would likely degrade this compliance. The prose is not redundant with downstream enforcement — it *is* the enforcement for content-quality rules. Language dial-back and restructuring (principles + examples) are safe; rule deletion based on "downstream catches it" is not, for any rule in the "Content quality" table above.

## Unexercised paths

Paths the Round 3 artifact did not exercise (all now covered by synthetic probes in `~/dev-projects/ido4dev/tests/enforcement-probes.mjs`):

- Duplicate task refs
- Circular dependencies
- Unresolved `depends_on`
- Unknown values for effort / risk / type / ai
- `critical` risk (downgrade path)
- `XL` effort (silent conflation with L)
- Case variations in metadata values
- Malformed task ref prefix
- Wrong capability heading (`## Group:`)

Paths still unexercised by any test:

- **Large-scale parsing performance.** Round 3's 1318 lines is the biggest real fixture. No stress test at 10x scale.
- **Partial GitHub API failures during ingestion** (e.g., rate-limit, sub-issue wiring race conditions). `SUB_ISSUE_DELAY_MS` is hardcoded; failure modes not tested.
- **Methodology profile edge cases** beyond the three current profiles.
- **Technical-only capabilities** (`PLAT-`, `INFRA-`, `TECH-` prefixes that don't trace to a strategic capability). Round 3 has INFRA-01, INFRA-02, PLAT-01, PLAT-02 and they parse cleanly, but they're tested as generic capabilities — the "technical capability" semantic layer doesn't exist in code.

## Silent-failure gaps (findings)

Three cases where the pipeline accepts invalid input with no signal at all. None is currently covered by any rule in this plugin's agents or skills — they represent **new** enforcement gaps discovered by this investigation, not existing rules being audited.

1. **XL effort silently conflated with L.** Both map to the `Large` methodology bucket. A user who distinguishes "a 1500-line task" (L) from "a multi-week architectural change" (XL) in the writer's prompt will see the distinction erased at ingestion. No warning. Mapper code: `EFFORT_MAP: { ..., l: 'Large', xl: 'Large' }`.

2. **Wrong capability heading produces silent data loss.** `## Group:` (instead of the required `## Capability:`) is silently unrecognized — the capability disappears and any tasks beneath it become orphans. Zero errors or warnings. An agent that uses the wrong heading ships a broken spec that looks clean to the reviewer.

3. **Malformed task refs are silently absorbed into the preceding task's body.** Lowercase refs (`test-01`), 6+ letter prefixes (`TOOLONG-01`), or any format outside `[A-Z]{2,5}-\d{2,3}[A-Z]?` are silently dropped. No error, no warning. An agent that produces these ships a spec where entire tasks vanish.

All three are candidates for either:
- **Parser upgrade** — convert silent drops to warnings or errors. Requires a new `@ido4/tech-spec-format` release, which flows into `@ido4/core` via the re-export, and into this plugin's bundled `dist/tech-spec-validator.js` via the update workflow.
- **spec-reviewer strengthening** — add Layer-2 checks for these specific failure modes so they produce review warnings.
- **`validate-spec` strengthening** — the bundled validator can do pre-ingest structural checks that short-circuit the pipeline before `ingest_spec` runs downstream.

These gaps should be addressed as dedicated work items — not folded into unrelated audits.

## Reproducing

The test harness currently lives in `ido4dev` because the scripts import `@ido4/core` from `ido4dev`'s `node_modules` (the runtime dep comes in via `@ido4/mcp` at session start):

```bash
cd ~/dev-projects/ido4dev
node tests/round3-agent-artifact.mjs
node tests/enforcement-probes.mjs
```

Expected when the wildcard-dep bug is fixed: all tests pass. **Currently:** `round3-agent-artifact.mjs` fails some assertions because the installed `@ido4/core` is the stale 0.5.0 that doesn't recognize suffixed task refs. That's the forcing function for `~/dev-projects/ido4-suite/briefs/fix-ido4-mcp-core-wildcard-dep.md`.

If the test behavior diverges from what this document describes, **this document is out of date**. Update the matrix to match, or find the code change that caused the drift.

## Cross-references

- `~/dev-projects/ido4-suite/docs/prompt-strategy.md` — the authoring standard this document serves
- `~/dev-projects/ido4-suite/docs/interface-contracts.md` — cross-repo contract index; MCP runtime dependency (#5) is where the ingestion API contract lives, and contract #6 (Technical Spec Format) is where the parser-as-boundary claim lives post-extraction
- `~/dev-projects/ido4-suite/briefs/fix-ido4-mcp-core-wildcard-dep.md` — the brief that tracks the wildcard-dep fix
- `agents/technical-spec-writer.md` — the agent whose rules this document classifies
- `agents/code-analyzer.md` — produces the canvas, which is upstream of the ingestion pipeline
- `agents/spec-reviewer.md` — the advisory Layer 2 reviewer
- `~/dev-projects/ido4dev/reports/e2e-003-ido4shape-cloud.md` — the E2E round that produced the Round 3 fixture (OBS-09 being audited in Round 4)
- `~/dev-projects/ido4dev/tests/round3-agent-artifact.mjs`, `~/dev-projects/ido4dev/tests/enforcement-probes.mjs`, `~/dev-projects/ido4dev/tests/fixtures/round3-agent-artifact.md` — the tests and fixture that anchor every claim in this document
