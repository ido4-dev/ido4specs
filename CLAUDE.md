# CLAUDE.md — ido4specs Plugin

## What This Is

A Claude Code plugin that turns a strategic spec into a structurally-validated technical spec on disk. Companion to [ido4shape](https://github.com/ido4-dev/ido4shape) for engineers planning implementation work. Reads a strategic spec, explores your codebase via parallel `Explore` subagents, produces an intermediate technical canvas, then synthesizes a methodology-neutral technical spec with capability decomposition, task metadata (effort/risk/type/ai), and a dependency graph. Any downstream tool — or `/ido4dev:ingest-spec` — can turn the file into GitHub issues.

Pipeline: `ido4shape → strategic spec → ido4specs → technical spec → ido4dev:ingest-spec → GitHub issues`

## Skills

| Skill | Phase | Purpose |
|---|---|---|
| `/ido4specs:create-spec` | 1 | Strategic spec + codebase → technical canvas. Parses the strategic spec via the bundled `@ido4/spec-format` validator, detects project mode (existing / greenfield-with-context / greenfield-standalone), spawns parallel `Explore` subagents for codebase analysis, synthesizes the canvas inline using the `code-analyzer` agent as a template reference. |
| `/ido4specs:synthesize-spec` | 2 | Canvas → technical spec. Pure transform, no codebase exploration. Inline synthesis using the `technical-spec-writer` agent as a template reference. Auto-runs structural validation at the end. |
| `/ido4specs:review-spec` | 3a | Qualitative review of a technical spec via the `spec-reviewer` agent on Sonnet. Layer 2 of the two-layer validation pattern. |
| `/ido4specs:validate-spec` | 3b | Structural validation via the bundled `@ido4/tech-spec-format` parser, plus 8 content assertions. Layer 1 of the two-layer pattern. |
| `/ido4specs:refine-spec` | — | Edit an existing technical spec via natural-language instructions. Re-validates after every edit pass. |
| `/ido4specs:doctor` | — | Plugin health diagnostics. Checks bundled validators, versions, checksums, round-trip test. Run when something seems broken. |
| `help` (auto-triggered) | — | Explains what ido4specs does, the pipeline, available skills, getting started. Activates when the user asks for help or seems confused about the plugin. |

## Agents

| Agent | Model | Role |
|---|---|---|
| `code-analyzer` | opus | Canvas template and rules reference for `create-spec`. Defines the canvas structure, mode-specific guidance, and the context-preservation discipline. |
| `technical-spec-writer` | opus | Template and rules reference for `synthesize-spec`. Defines the technical spec output format, the Goldilocks principle, metadata assessment, and shared-infrastructure rules. |
| `spec-reviewer` | sonnet | Review protocol and rules reference for `review-spec`. Defines the two-stage review and structured Spec Review Report output. |

All three agents are read **inline** by the skills that use them — they are not spawned as plugin-defined subagents. Inline execution preserves full conversation context and avoids a Claude Code constraint where plugin-defined subagents hang at ~25–30 tool uses (documented in `ido4dev/reports/e2e-003-ido4shape-cloud.md`). Only built-in `Explore` subagents (used in `create-spec`'s Stage 1a for codebase exploration) are spawned.

## Typical layout and filenames

`ido4specs` recommends placing all spec-related artifacts in a single `specs/` directory at the project root. The recommendation is just that — `ido4specs` accepts the strategic spec from any path the user points at, and discovers or creates the technical work area automatically (`specs/` → `docs/specs/` → creates one). The filename suffixes carry the disambiguation, so co-location is preferred but not required.

```
project/
└── specs/
    ├── notification-system-strategic-spec.md   ← from ido4shape (user-placed)
    ├── notification-system-tech-canvas.md      ← /ido4specs:create-spec output
    └── notification-system-tech-spec.md        ← /ido4specs:synthesize-spec output
```

The `-tech-*` prefix groups every `ido4specs` output, so `specs/*-tech-*.md` is a clean glob for everything the plugin produced. Strategic specs use `-strategic-spec` as the recommended suffix to disambiguate from technical artifacts; the raw `-spec.md` filename that `ido4shape` produces is also accepted as a backward-compatibility fallback (`create-spec`'s spec-name derivation strips both).

The format marker inside each file (`> format: strategic-spec | version: 1.0` or `> format: tech-spec | version: 1.0`) is authoritative — filenames are hints. If a user mislabels a file, the parser catches it and warns.

## Bundled validators

The plugin ships two zero-dependency parser bundles in `dist/`, both auto-copied to `${CLAUDE_PLUGIN_DATA}` by the `SessionStart` hook so skills can invoke them via `node "${CLAUDE_PLUGIN_DATA}/<bundle>" <path>`:

- `tech-spec-validator.js` — `@ido4/tech-spec-format` (~15 KB). Validates the technical specs `ido4specs` produces. Used by `validate-spec`, `refine-spec`, and `synthesize-spec`'s Stage 1d auto-validation.
- `spec-validator.js` — `@ido4/spec-format` (~9 KB). Parses the upstream strategic specs from `ido4shape`. Used by `create-spec`'s Stage 0.

Both bundles have version markers (`dist/.tech-spec-format-version`, `dist/.spec-format-version`) and SHA-256 checksums (`dist/.tech-spec-format-checksum`, `dist/.spec-format-checksum`). Update via `scripts/update-tech-spec-validator.sh <version>` or `scripts/update-spec-validator.sh <version>`.

## Development

```bash
# Run validation suite (130 checks)
bash tests/validate-plugin.sh

# Local plugin test
claude --plugin-dir /path/to/this/repo

# After skill/agent changes in an existing session
/reload-plugins

# Release (bumps version, regenerates CHANGELOG, commits, pushes)
bash scripts/release.sh [patch|minor|major] "Release message"
bash scripts/release.sh --yes [patch|minor|major] "Release message"   # non-interactive
bash scripts/release.sh --dry-run                                      # pre-flight only

# Update bundled validators
bash scripts/update-tech-spec-validator.sh <version>     # @ido4/tech-spec-format
bash scripts/update-spec-validator.sh <version>          # @ido4/spec-format
```

CI runs `tests/validate-plugin.sh` on every push/PR. The marketplace sync workflow (`.github/workflows/sync-marketplace.yml`) is active as of 2026-04-15 (Phase 9.5.6); every successful CI run on main pushes the plugin source to `ido4-plugins/plugins/ido4specs/`.

## E2E Testing Protocol

When monitoring a live `ido4specs` session (the user running skills in a separate terminal against a real project), follow this protocol. Reports live in `reports/e2e-NNN-{project-name}.md`. Before starting a new round, read the most recent report for continuity.

### Setup

Two sessions in parallel:
- **Test session:** A project folder with the `ido4specs` plugin loaded (`claude --plugin-dir ~/dev-projects/ido4specs` or installed from marketplace). The user runs skills and pastes output to the monitor.
- **Monitor session:** This repo. Evaluates behavior against the skill and agent definitions in `skills/` and `agents/`. Logs observations in real time.

### Architectural invariants (check throughout, every skill)

These are the four bets from the extraction. Any violation is a **Critical** observation:

| Invariant | What to watch for |
|---|---|
| **Parser-as-seam** | Every structural validation goes through the bundled `node "${CLAUDE_PLUGIN_DATA}/tech-spec-validator.js"` or `spec-validator.js`. No back-channel parser calls, no reimplemented checks, no "let me just verify the format manually." |
| **Methodology neutrality** | No references to Scrum, Shape-Up, Hydro, BRE, methodology profiles, container types, sprints, waves, or cycles in any skill output. The technical spec is methodology-neutral. |
| **Inline execution** | `code-analyzer.md`, `technical-spec-writer.md`, `spec-reviewer.md` are read as templates/references by main Claude — never spawned via the `Agent` tool as plugin-defined subagents. Only built-in `Explore` subagents (in `create-spec` Stage 1a) are spawned. If you see "`Agent(code-analyzer)`" or similar, the inline-execution pattern has regressed and it will likely hang at ~25–30 tool uses. |
| **Zero runtime coupling** | No `mcp__` tool calls, no `parse_strategic_spec`, no `ingest_spec`, no `@ido4/mcp` references. The only cross-plugin signal is the filesystem probe for `.ido4/project-info.json` in the cross-sell footer. |

### Pipeline-specific checkpoints

The `ido4specs` pipeline is linear: `create-spec → synthesize-spec → review-spec / validate-spec → refine-spec`. Each skill has specific things to verify beyond the architectural invariants.

**`/ido4specs:create-spec <strategic-spec-path>`**

| Stage | Checkpoint |
|---|---|
| 0 | Calls bundled `spec-validator.js` (not `parse_strategic_spec`). Presents parsed summary with group/capability counts and dependency structure. |
| 0 | Derives `{spec-name}` correctly via the §5.3 derivation rule (strips `-spec` or `-strategic-spec` suffix). |
| 0.5 | Discovers artifact directory (finds existing `specs/` or creates one). States the mode (`existing` / `greenfield-with-context` / `greenfield-standalone`) with justification. |
| 0.5 | If strategic spec is outside the artifact directory: emits the **co-location nudge** (one-time informational, not blocking). |
| 0.5 | Reports both the input path and the planned output paths (`{spec-name}-tech-canvas.md`, `{spec-name}-tech-spec.md`). |
| 1a | Spawns **built-in `Explore` subagents** (not plugin-defined). Brief per target is under ~300 tokens. Subagents run in parallel in a single message with multiple tool uses. |
| 1b | Reads the raw strategic-spec text for verbatim context preservation. |
| 1c | Synthesizes the canvas **inline** following `agents/code-analyzer.md` template. Every strategic capability gets its own `## Capability:` section — no summary tables, no collapsing. |
| 1d | Verifies `## Capability:` count in the written canvas matches the parsed capability count from Stage 0. Mismatch = incomplete canvas. |
| End | Writes to `{artifact-dir}/{spec-name}-tech-canvas.md`. End message points at `/ido4specs:synthesize-spec`. Stops — does not auto-invoke the next skill. |

**`/ido4specs:synthesize-spec <canvas-path>`**

| Stage | Checkpoint |
|---|---|
| 0 | Derives `{spec-name}` from the canvas path (strips `-tech-canvas`). |
| 1a | Validates canvas has per-capability sections, strategic context, cross-cutting concerns. Refuses to proceed on an incomplete canvas. |
| 1b | Decomposes inline following `agents/technical-spec-writer.md` template. Output includes `> format: tech-spec \| version: 1.0` marker. Task refs use the `[A-Z]{2,5}-\d{2,3}[A-Z]?` pattern. |
| 1c | Reports capability + task counts. |
| 1d | **Auto-runs `node tech-spec-validator.js`** on the written spec. Reports PASS or first 3 errors. This is the critical smoke test for the parser-as-seam bet. |
| End | Writes to `{artifact-dir}/{spec-name}-tech-spec.md`. Cross-sell footer checks for `.ido4/project-info.json` and emits the appropriate variant. |

**`/ido4specs:validate-spec <tech-spec-path>`**

| Pass | Checkpoint |
|---|---|
| 1 | Runs bundled `tech-spec-validator.js`. Interprets errors intelligently (broken deps → suggests correct target, cycles → identifies which edge to reverse, invalid metadata → shows allowed values). Does not just relay raw parser output. |
| 2 | Applies the 8 content assertions (T0–T8). Each classified as FAIL or WARNING with specific per-task or per-capability references. |
| Verdict | PASS / PASS WITH WARNINGS / FAIL. Next-step guidance matches the verdict (refine-spec for fixes, review-spec or ingest-spec for clean pass). Cross-sell footer present on PASS. |

**`/ido4specs:review-spec <tech-spec-path>`**

| Stage | Checkpoint |
|---|---|
| 1b | Format compliance check against the parser contract (same checks as validate-spec Pass 1, but this is the independent LLM-driven review, not the bundled validator). |
| 1c | Quality assessment — descriptions code-grounded, success conditions verifiable, metadata calibrated, capabilities coherent (2–8 tasks each). |
| 1d | Downstream awareness section — flags `ai: human`, `risk: critical`, heavy cross-capability deps as informational, not as governance enforcement. |
| 1e | Produces the **Spec Review Report** in the structured format from `agents/spec-reviewer.md`: Summary, Errors, Warnings, Suggestions, Downstream Notes, Dependency Graph. |

**`/ido4specs:refine-spec <tech-spec-path>`**

| Check | Checkpoint |
|---|---|
| Scope | Refuses to operate on strategic specs (filename + format-marker check → redirects to ido4shape). |
| Edit | Surfaces ripple effects before making changes ("if we split this capability, these 3 tasks need new prefixes..."). |
| Re-validate | Runs bundled `tech-spec-validator.js` **after every edit pass**. If the edit introduced a structural regression, reports it immediately rather than leaving it for the next validate-spec run. |

### Observation format

Log every deviation immediately — don't batch. Each observation gets:

- **ID:** Sequential within the test (OBS-01, OBS-02, ...)
- **Type:** `bug` | `design-gap` | `behavioral-drift` | `quality-issue` | `architectural-violation` | `ux-issue`
- **Severity:** `low` | `medium` | `high` | `critical`
- **When:** Skill name + stage (e.g., "create-spec Stage 1a")
- **What happened:** Actual behavior (quote the output)
- **What was expected:** Traced to the specific skill/agent definition (file + section)
- **Evidence:** The pasted interaction or output
- **Fix candidate:** File and section where the fix would go

Also log **positive observations** when behavior exceeds expectations — these calibrate quality and inform which design choices are working well.

### Report format

File: `reports/e2e-NNN-{project-name}.md`

Sections:
1. **Test Setup** — project, strategic spec, plugin version, date, which skills were exercised
2. **Pipeline Summary** — which stages ran, what artifacts were produced, what filenames were used
3. **Observations** — all OBS entries in chronological order
4. **Positives** — what worked well, especially architectural invariants that held
5. **Assessment** — overall verdict on skill quality, pipeline coherence, and readiness
6. **Next Steps** — fixes to make, skills to re-test, design gaps to address

### What to watch for (cross-cutting, any skill)

- Does the skill read what it claims to read? (canvas, spec, codebase via Explore)
- Does the output match the defined format? (sections, metadata, file naming)
- Are intermediate review points honored? (skill stops at its boundary, doesn't auto-invoke the next skill)
- Is strategic context preserved through the pipeline? (stakeholder attributions, success conditions, group context — nothing silently dropped between create-spec and synthesize-spec)
- Does the cross-sell footer emit the correct variant? (probe `.ido4/project-info.json`, not hardcoded)
- Are filename conventions honored? (`-tech-canvas.md`, `-tech-spec.md`, never `-canvas.md` or `-technical.md`)
- Does task tracking use `TaskCreate`/`TaskUpdate` (not `TodoWrite`)?

## Reference Repositories

- [`~/dev-projects/ido4shape/`](https://github.com/ido4-dev/ido4shape) — packaging reference. The `ido4specs` plugin layout (plugin.json, scripts/release.sh, tests/validate-plugin.sh, .github/workflows/, hooks plumbing) was adapted from `ido4shape`'s canonical implementation. Skill internals are NOT borrowed — `ido4shape` targets Claude Cowork / Desktop and uses plugin-defined subagents that don't work reliably in Claude Code. Do not edit `ido4shape` as part of `ido4specs` work.
- [`~/dev-projects/ido4dev/`](https://github.com/ido4-dev/ido4dev) — content reference. The `decompose`, `decompose-tasks`, `decompose-validate` skills and the `code-analyzer` / `technical-spec-writer` / `spec-reviewer` agents were ported here with a language pass and renamed during Phase 2 of the extraction. Phase 3 slimmed `ido4dev` to a governance-only plugin; it was released as `v0.8.0` on 2026-04-15.
- [`~/dev-projects/ido4/`](https://github.com/ido4-dev/ido4) — monorepo with the npm packages. The technical-spec validator bundle lives at `packages/tech-spec-format/dist/tech-spec-validator.bundle.js` and the strategic-spec validator bundle at `packages/spec-format/dist/spec-validator.bundle.js`. Both are pulled into this plugin's `dist/` via the update scripts.
- [`~/dev-projects/ido4-suite/`](https://github.com/ido4-dev/ido4-suite) — meta-repo. Canonical docs for release architecture, prompt strategy, interface contracts, cross-repo connections. See the Suite Coordination section below.

## Skill / Agent Conventions

- Skills live in `skills/{name}/SKILL.md` with YAML frontmatter (Agent Skills standard)
- Agents live in `agents/{name}.md`
- Skill cross-references use `/ido4specs:{name}` format
- Bundled validators invoked via Bash: `node "${CLAUDE_PLUGIN_DATA}/tech-spec-validator.js" <path>` (or `spec-validator.js` for strategic)
- `${CLAUDE_PLUGIN_ROOT}` is hooks/mcp config only — skill bodies use `${CLAUDE_SKILL_DIR}` for within-skill references
- Skills use `TaskCreate` / `TaskUpdate` for stage tracking (the current Claude Code task tools, not the older `TodoWrite`)
- All three plugin-defined agents are read inline by skills, not spawned as subagents — see the Agents section above for the why

## ido4 Suite Coordination

This repo is part of the ido4 suite. Cross-repo release patterns, audit tooling, and coordination docs live in `~/dev-projects/ido4-suite/`:

- `docs/release-architecture.md` — the canonical 4-layer release pattern this repo follows (CI gating, marketplace sync, sync auto-PR pattern)
- `docs/prompt-strategy.md` — degrees of freedom, rules vs principles, Opus 4.5/4.6 language guidance, skill architecture patterns, two-layer validation pattern. Read this first before writing or auditing skills, agents, or prompts.
- `docs/interface-contracts.md` — cross-repo contract index. Contract #6 (Technical Spec Format) is the `ido4specs → @ido4/core ingestion` trust boundary.
- `docs/cross-repo-connections.md` — dispatch map, shared secrets, trust boundaries
- `scripts/audit-suite.sh` — verifies all repos against the canonical pattern. Run after any release/CI changes: `bash ~/dev-projects/ido4-suite/scripts/audit-suite.sh`
- `PLAN.md` — master plan tracking cross-repo work. The `ido4specs` extraction was Phase 9; completed 2026-04-15.
- `suite.yml` — machine-readable suite manifest. `ido4specs` is listed as a Tier 1 plugin.

Before changing release scripts, CI workflows, or cross-repo dispatch: read `release-architecture.md` first. After changes: run the audit script.

## Authoring Conventions

`ido4specs` targets Claude Code (terminal), not Claude Cowork / Desktop. Cowork-specific injection-defense rules don't apply here. However, the craft rules carry over as good prompt hygiene:

- No XML tags in skill bodies — use markdown headers
- No directive language ("YOU MUST", "NEVER EVER") — use principles + WHYs
- Describe intent for paths instead of literal relative paths in skill bodies; use `${CLAUDE_SKILL_DIR}` for within-skill references
- `${CLAUDE_PLUGIN_ROOT}` works only in hooks.json and .mcp.json, not in skill bodies
- Keep skills lean — under 500 lines each per `prompt-strategy.md`; agents under 300 lines

The `validate-plugin.sh` suite enforces the language hygiene, MCP-leak, methodology-neutrality, and filename-convention guards automatically. Run it before any commit.

## Working Style

Make the call. Reserve (a)/(b)/(c) for genuinely different paths, not flavors of a recommendation already made. A short answer the user can redirect beats a long one that preempts every objection.

## Related

- [ido4](https://github.com/ido4-dev/ido4) — monorepo with `@ido4/spec-format`, `@ido4/tech-spec-format`, `@ido4/core`, `@ido4/mcp` (the parsers this plugin bundles live here)
- [ido4shape](https://github.com/ido4-dev/ido4shape) — strategic spec authoring plugin (upstream producer in the pipeline)
- [ido4dev](https://github.com/ido4-dev/ido4dev) — governance plugin and downstream ingestion target for the technical specs ido4specs produces
- [ido4-plugins](https://github.com/ido4-dev/ido4-plugins) — Claude Code marketplace mirror
- [ido4-suite](https://github.com/ido4-dev/ido4-suite) — meta-repo with the canonical patterns and audit tooling
