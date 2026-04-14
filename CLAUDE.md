# CLAUDE.md — ido4specs (under construction)

## What this is

`ido4specs` is the Claude Code plugin being extracted from `ido4dev` as part of a larger architectural restructuring. It will become the lightweight companion plugin for `ido4shape` users — taking a strategic spec produced by ido4shape and turning it into a structurally-validated technical spec `.md` file. Users who want to then create GitHub issues from that file install `ido4dev` separately.

**Scope boundary:** ido4specs STOPS at producing a validated technical spec on disk. It never creates GH issues. The technical spec is methodology-neutral. The handoff to `ido4dev:ingest-spec` is where methodology (Hydro/Scrum/Shape Up) gets applied.

## Current state (2026-04-14)

**Phase 1 complete.** The `@ido4/tech-spec-format` npm package has been extracted from `@ido4/core` inside the `~/dev-projects/ido4/` monorepo. It has its own parser, types, CLI, esbuild bundle, version contract, and 41 tests. Commits: `ido4 a898421 + 294b92d`, `ido4-suite 241371b + 9c364cc + 631dd5e`.

**Phases 2–5 pending.** This directory currently holds only the extraction plan document and this orientation file. The plugin itself has NOT been scaffolded yet — that is Phase 2's job.

## Where to start (for a cold session)

1. **Read `docs/extraction-plan.md` first.** This is the authoritative spec for what ido4specs will be, how it's being extracted, and the phase-by-phase execution plan with review gates. Section 7 has the target plugin layout. Section 9 has the five-phase migration sequence.
2. **Check `~/dev-projects/ido4-suite/PLAN.md` Phase 9** for the per-sub-phase checkbox state. Phase 9.1 is complete; Phase 9.2 (plugin creation) is the next work.
3. **Check the session memory** at `~/.claude/projects/-Users-bogdanionutcoman-dev-projects-ido4specs/memory/project_ido4specs_extraction.md` for cross-session workstream context.

## Reference repositories (read-only unless explicitly touched)

- **`~/dev-projects/ido4shape/`** — reference implementation for plugin structure, skill conventions, bundled-validator pattern (`hooks/hooks.json` SessionStart + `dist/spec-validator.js` + skill Bash invocation). The suite's canonical plugin per `ido4-suite/suite.yml`. Mirror its layout for ido4specs.
- **`~/dev-projects/ido4dev/`** — where the decompose skills and agents currently live. Phase 2 ports them here (with a language pass per `ido4-suite/docs/prompt-strategy.md`). Phase 3 slims ido4dev to a governance-only plugin.
- **`~/dev-projects/ido4/`** — monorepo with `@ido4/tech-spec-format` (Phase 1 artifact to bundle), `@ido4/spec-format` (the strategic parser, also bundled), `@ido4/core`, `@ido4/mcp`. The technical-spec validator bundle lives at `packages/tech-spec-format/dist/tech-spec-validator.bundle.js` — ido4specs will copy it to its own `dist/` via `scripts/update-tech-spec-validator.sh` (following ido4shape's existing `update-validator.sh` pattern).
- **`~/dev-projects/ido4-suite/`** — meta-repo. Read `docs/release-architecture.md` and `docs/prompt-strategy.md` before writing any workflow, release script, skill, or agent definition. Run `bash scripts/audit-suite.sh` after any release/CI changes.

## Development conventions (inherited from the suite)

- Skills and agents follow `~/dev-projects/ido4-suite/docs/prompt-strategy.md` — degrees of freedom, rules vs principles, Opus 4.6 language guidance (no all-caps `MUST`/`NEVER`/`ALWAYS`, motivate with WHY, positive framing)
- Release pipeline follows `~/dev-projects/ido4-suite/docs/release-architecture.md` — 4-layer pattern, 4 invariants. Layer 1 (`scripts/release.sh`) runs the same checks as Layer 3 (`ci.yml`)
- Bundled validator pattern follows `~/dev-projects/ido4shape` — SessionStart hook copies `dist/*.js` to `${CLAUDE_PLUGIN_DATA}`, skills invoke via Bash

## What Phase 2 creates (not yet here)

Per `docs/extraction-plan.md` section 7:

```
ido4specs/
├── .claude-plugin/plugin.json
├── .github/workflows/{ci,sync-marketplace,update-tech-spec-validator}.yml
├── agents/{code-analyzer,technical-spec-writer,spec-reviewer}.md
├── dist/tech-spec-validator.js + .tech-spec-format-version
├── hooks/hooks.json
├── references/{technical-spec-format,example-technical-spec}.md
├── scripts/{release,session-start,update-tech-spec-validator}.sh
├── skills/{create-spec,synthesize-spec,review-spec,validate-spec,refine-spec,repair-spec}/SKILL.md
├── tests/validate-plugin.sh
├── CHANGELOG.md
├── LICENSE
├── README.md
├── SECURITY.md
└── (this file)
```

Six skills, three agents, one hook, two bundled validators (spec-format + tech-spec-format, following ido4shape's pattern for the strategic side and extending it for the technical side).

## Cross-reference index

- **Canonical plan:** `docs/extraction-plan.md`
- **Per-sub-phase tracking:** `~/dev-projects/ido4-suite/PLAN.md` Phase 9
- **Session memory:** `~/.claude/projects/-Users-bogdanionutcoman-dev-projects-ido4specs/memory/project_ido4specs_extraction.md`
- **Sibling monorepo memory:** `~/.claude/projects/-Users-bogdanionutcoman-dev-projects-ido4/memory/tech-spec-format-package.md`
- **Reference plugin:** `~/dev-projects/ido4shape/`
- **Source plugin for moves:** `~/dev-projects/ido4dev/`
