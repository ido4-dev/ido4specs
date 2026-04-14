# CLAUDE.md — ido4specs Plugin (under construction)

## What This Is

The Claude Code plugin being extracted from `ido4dev` as a lightweight companion for `ido4shape` users who want to turn a strategic spec into a structurally-validated technical spec on disk. Never creates GitHub issues — that's `ido4dev:ingest-spec`'s job. The output is a methodology-neutral `.md` file.

Pipeline: `ido4shape → strategic spec (.md) → ido4specs → technical spec (.md) → ido4dev:ingest-spec → GitHub issues`

## Current State

**Phase 1 complete 2026-04-14.** `@ido4/tech-spec-format@0.1.0` extracted from `@ido4/core` inside the `ido4` monorepo (commits `a898421`, `294b92d`). The new package has its own parser, types, CLI, esbuild bundle, version contract, and 41 tests.

**Phases 2–5 pending.** This directory currently holds only `docs/extraction-plan.md` and this orientation file. The plugin scaffold (skills, agents, hooks, bundled validator, workflows) has not been created yet — that is Phase 2's work.

**Authoritative plan:** `docs/extraction-plan.md` — read this first, in full, before starting any Phase 2+ work. The plan has the target architecture, the version contract, the five-phase execution sequence, review gates, and success criteria.

## Where to Start (Cold Session)

1. Read `docs/extraction-plan.md` — full plan, Phase 1 completion record, Phase 2 deliverables
2. Check `~/dev-projects/ido4-suite/PLAN.md` Phase 9 for per-sub-phase checkbox state
3. Check session memory at `~/.claude/projects/-Users-bogdanionutcoman-dev-projects-ido4specs/memory/project_ido4specs_extraction.md` for cross-session workstream context

## Reference Repositories

- `~/dev-projects/ido4shape/` — **the reference plugin**. Mirror its layout for ido4specs: skill naming (`create-spec`/`synthesize-spec`/`review-spec`/`validate-spec`/`refine-spec`), hooks pattern (`SessionStart` copies bundled validator to `${CLAUDE_PLUGIN_DATA}`), `.claude-plugin/plugin.json` shape, `scripts/release.sh` structure, `tests/validate-plugin.sh` checks, `.github/workflows/` layout.
- `~/dev-projects/ido4dev/` — where the decompose skills and agents currently live. Phase 2 ports `code-analyzer`, `technical-spec-writer`, `spec-reviewer` here with a language pass. Phase 3 slims ido4dev to a governance-only plugin.
- `~/dev-projects/ido4/` — monorepo with the npm packages. The technical-spec validator bundle lives at `packages/tech-spec-format/dist/tech-spec-validator.bundle.js` — ido4specs copies it to its own `dist/` via `scripts/update-tech-spec-validator.sh` (following ido4shape's `update-validator.sh` pattern). The strategic-spec parser is bundled similarly from `@ido4/spec-format`.
- `~/dev-projects/ido4-suite/` — meta-repo. Canonical docs for release architecture, prompt strategy, interface contracts, cross-repo connections. See the Suite Coordination section below.

## Skill / Agent Conventions

- Skills live in `skills/{name}/SKILL.md` with YAML frontmatter (Agent Skills standard)
- Agents live in `agents/{name}.md` (or `agents/{name}/AGENT.md` when they grow references)
- Skill cross-references use `/ido4specs:{name}` format
- Tool references use the appropriate MCP prefix when skills invoke MCP tools (ido4specs bundles its validators locally; it does NOT require an MCP server)
- Bundled validators invoked via Bash: `node "${CLAUDE_PLUGIN_DATA}/tech-spec-validator.js" <path>`

## Development

This section will expand as Phase 2 creates the scaffold. For now:

```bash
# Local testing (once the plugin exists)
claude --plugin-dir /path/to/this/repo

# After skill/agent changes
/reload-plugins
```

Release commands, `validate-plugin.sh`, hooks, and CI workflows will land in Phase 2.

## ido4 Suite Coordination

This repo is part of the ido4 suite. Cross-repo release patterns, audit tooling, and coordination docs live in `~/dev-projects/ido4-suite/`:

- `docs/release-architecture.md` — the canonical 4-layer release pattern this repo will follow once Phase 2 creates its CI/release automation
- `docs/prompt-strategy.md` — degrees of freedom, rules vs principles, Opus 4.5/4.6 language guidance, skill architecture patterns, two-layer validation pattern
- `docs/interface-contracts.md` — cross-repo contract index. Contract #6 (Technical Spec Format) will land during Phase 4 of the extraction
- `docs/cross-repo-connections.md` — dispatch map, shared secrets, trust boundaries
- `scripts/audit-suite.sh` — verifies all repos against the canonical pattern. Run after any release/CI changes: `bash ~/dev-projects/ido4-suite/scripts/audit-suite.sh`
- `PLAN.md` — master plan tracking in-progress cross-repo work. The ido4specs extraction is Phase 9.
- `suite.yml` — machine-readable suite manifest. ido4specs will be added as a Tier 1 plugin during Phase 4.

Before changing release scripts, CI workflows, or cross-repo dispatch: read `release-architecture.md` first. After changes: run the audit script.

Before writing or auditing skills, agents, or prompts: read `docs/prompt-strategy.md` first. It defines degrees of freedom, rules vs principles, language guidance for Opus 4.5/4.6, skill architecture patterns, and the two-layer validation pattern.

## Cowork Compatibility Rules

ido4specs will eventually ship to the same marketplace as ido4shape. Skill authoring inherits ido4shape's Cowork compatibility rules — see `~/dev-projects/ido4shape/CLAUDE.md` "Cowork Compatibility Rules" section. Key points to remember when writing skills: no XML tags (triggers injection defense), no directive language, describe intent instead of literal relative paths, `${CLAUDE_SKILL_DIR}` for within-skill refs, `${CLAUDE_PLUGIN_ROOT}` only in hooks/mcp config, keep skills lean.

## Working Style

Make the call. Reserve (a)/(b)/(c) for genuinely different paths, not flavors of a recommendation already made. A short answer the user can redirect beats a long one that preempts every objection.

## Related

- [ido4](https://github.com/ido4-dev/ido4) — monorepo with `@ido4/spec-format`, `@ido4/tech-spec-format`, `@ido4/core`, `@ido4/mcp` (the parser that ido4specs bundles lives here)
- [ido4shape](https://github.com/ido4-dev/ido4shape) — strategic spec authoring plugin (upstream producer in the pipeline)
- [ido4dev](https://github.com/ido4-dev/ido4dev) — governance plugin and downstream ingestion target for the technical specs ido4specs produces
- [ido4-plugins](https://github.com/ido4-dev/ido4-plugins) — Claude Code marketplace mirror
- [ido4-suite](https://github.com/ido4-dev/ido4-suite) — meta-repo with the canonical patterns and audit tooling
