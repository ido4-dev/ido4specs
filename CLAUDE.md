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

CI runs `tests/validate-plugin.sh` on every push/PR. The marketplace sync workflow (`.github/workflows/sync-marketplace.yml`) ships gated off until Phase 5 of the extraction lands the marketplace entry and `MARKETPLACE_TOKEN` secret.

## Reference Repositories

- [`~/dev-projects/ido4shape/`](https://github.com/ido4-dev/ido4shape) — packaging reference. The `ido4specs` plugin layout (plugin.json, scripts/release.sh, tests/validate-plugin.sh, .github/workflows/, hooks plumbing) was adapted from `ido4shape`'s canonical implementation. Skill internals are NOT borrowed — `ido4shape` targets Claude Cowork / Desktop and uses plugin-defined subagents that don't work reliably in Claude Code. Do not edit `ido4shape` as part of `ido4specs` work.
- [`~/dev-projects/ido4dev/`](https://github.com/ido4-dev/ido4dev) — content reference. The `decompose`, `decompose-tasks`, `decompose-validate` skills and the `code-analyzer` / `technical-spec-writer` / `spec-reviewer` agents were ported here with a language pass and renamed (Phase 2 of the extraction). Phase 3 will slim `ido4dev` to a governance-only plugin by deleting the moved skills.
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
- `docs/interface-contracts.md` — cross-repo contract index. Contract #6 (Technical Spec Format) lands during Phase 4 of the extraction.
- `docs/cross-repo-connections.md` — dispatch map, shared secrets, trust boundaries
- `scripts/audit-suite.sh` — verifies all repos against the canonical pattern. Run after any release/CI changes: `bash ~/dev-projects/ido4-suite/scripts/audit-suite.sh`
- `PLAN.md` — master plan tracking in-progress cross-repo work. The ido4specs extraction is Phase 9.
- `suite.yml` — machine-readable suite manifest. `ido4specs` is added as a Tier 1 plugin during Phase 4.

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
