# Changelog

## [0.3.0] — 2026-04-17

Polite-by-default onboarding and opt-in status line

### Added
- Polite-by-default onboarding flow
- Opt-in status line display option
- Auto-updating README skill inventory
- Weekly token health check diagnostics

### Changed
- Updated bundled validators to v0.8.0

## [Unreleased]

**Polite by default.** `ido4specs` now stays out of the way in projects that don't use it, while introducing itself clearly the first time you open a session in any new project. The plugin is invisible when irrelevant, informative when it matters.

### Added
- **First-time-per-project greeting.** First session in a new project now shows a one-line intro: what the plugin is, how to start, where the bundled example lives. Stored marker file prevents repeat — you'll only see it once per project.
- **Opt-in status line.** `scripts/statusline.sh` shows project state at the bottom of the Claude Code UI (`ido4specs · spec ✓ {name}`, `synth {name}`, `plan {name}`, or silent). Wire it into `~/.claude/settings.json` to enable — `/ido4specs:doctor` emits the exact config block with your install path.
- **Doctor Check 8.** `/ido4specs:doctor` now detects whether the status line opt-in is configured and surfaces the config block if not.
- **README polish.** New "What you get" section shows an example tech spec snippet so you can see the artifact, not just read about it.

### Changed
- **SessionStart is now silent in irrelevant projects** after the first-time intro. Previously emitted "no artifacts found" on every session in every project — noisy for users with the plugin installed globally. Artifact-aware messaging in projects that DO use the plugin is unchanged.
- **Skill descriptions tightened.** `/create-spec` and `/synthesize-spec` now lead with "Phase 1 — strategic spec + codebase → technical canvas" / "Phase 2 — technical canvas → technical spec artifact" so the slash menu conveys what each phase does at a glance.
- **T8 capability-coherence assertion** consistently relaxed to "1–8 tasks" across all references (was already shipped in v0.2.0 for `validate-spec` and `spec-reviewer`; this release cleans up the last two stale "2–8" mentions in `review-spec` skill body and `CLAUDE.md`).

### Notes
- Status line is provided as opt-in (not shipped as a plugin default) because Claude Code's plugin `settings.json` does not yet support shipping a `statusLine` directly — only `agent` and `subagentStatusLine` keys, with no `${CLAUDE_PLUGIN_ROOT}` expansion. When that lands upstream, `ido4specs` will ship the `statusLine` config natively.
- CI now installs the Claude Code CLI before running `tests/validate-plugin.sh`, so Test 14 (`claude plugin validate`) actually runs in CI instead of soft-skipping when the runner doesn't have the CLI. The official validator is the source of truth for marketplace acceptance, so we want CI to catch any drift between our custom 148-check suite and the official check.

## [0.2.0] — 2026-04-16

First-time user experience, self-service diagnostics, and quality fixes from the first E2E test round (`reports/e2e-001-ido4shape-cloud.md`).

### Added
- `/ido4specs:doctor` skill — 7-check diagnostic (Node.js, validators, versions, checksums, round-trip, workspace scan) with specific remediation for each failure
- `/ido4specs:help` skill (auto-triggered) — pipeline overview, skills at a glance, getting started, filename conventions, "don't have a strategic spec?" path
- `scripts/session-status.sh` — version echo + artifact scan on every SessionStart. Every session opens with contextual pipeline guidance ("canvas exists, run synthesize-spec" or "no artifacts, run create-spec")
- `references/example-strategic-spec.md` — try the pipeline without ido4shape: `/ido4specs:create-spec references/example-strategic-spec.md`
- `CONTRIBUTING.md` — authoring constraints, testing workflow, release process
- `reports/e2e-001-ido4shape-cloud.md` — full E2E test report (25-capability spec, all 5 skills, 40 min, pipeline verdict PASS)

### Changed
- Duration advisory added before long synthesis in `create-spec` (Stage 1c) and `synthesize-spec` (Stage 1b) — tells users expected wait time so they don't interrupt active synthesis
- T8 capability-coherence assertion relaxed from "2–8 tasks" to "1–8 tasks" in both `validate-spec` and `spec-reviewer` — single-task capabilities are fine when the task is M-effort or larger
- `SECURITY.md` updated to document the new session-status.sh hook (read-only artifact scan, no file contents read, no network, no modifications)
- `README.md` — added doctor to skills list, "Don't have a strategic spec?" section, expected duration and compute table, CONTRIBUTING.md link
- `CLAUDE.md` — added doctor and help to skills table
- `tests/validate-plugin.sh` — now 144 checks (was 130), includes doctor and help skills

## [0.1.0] — 2026-04-15

Initial plugin release, extracted from `ido4dev` during Phase 9 of `ido4-suite/PLAN.md`. Full extraction plan in `docs/extraction-plan.md` and Phase 2 execution plan in `docs/phase-2-execution-plan.md`.

Published as a public GitHub repo (`ido4-dev/ido4specs`) and listed in the `ido4-dev/ido4-plugins` Claude Code marketplace. Both bundled validators (`dist/tech-spec-validator.js` and `dist/spec-validator.js`) are auto-updated from `@ido4/tech-spec-format` and `@ido4/spec-format` via `repository_dispatch` from `ido4/.github/workflows/publish.yml`. Both bundles refreshed to `0.8.0` by the ido4 v0.8.0 release on the same day.

### Added
- Five skills: `create-spec`, `synthesize-spec`, `review-spec`, `validate-spec`, `refine-spec`
- Three agents: `code-analyzer`, `technical-spec-writer`, `spec-reviewer`
- Bundled `@ido4/tech-spec-format@0.8.0` technical-spec validator (zero-dependency CLI bundle in `dist/tech-spec-validator.js`)
- Bundled `@ido4/spec-format@0.8.0` strategic-spec validator (for `create-spec` Stage 0 parsing)
- `SessionStart` hook that copies both bundles into `${CLAUDE_PLUGIN_DATA}` for skill invocation
- `references/technical-spec-format.md` — canonical format reference (moved from `ido4/architecture/spec-artifact-format.md`)
- `references/example-technical-spec.md` — round-trip test fixture and authoring reference
- Canonical filename scheme: `{name}-strategic-spec.md` + `{name}-tech-canvas.md` + `{name}-tech-spec.md` for clean pipeline disambiguation
- Release pipeline (`scripts/release.sh`), validation suite (`tests/validate-plugin.sh`), and CI workflows adapted from `ido4shape`'s reference pattern
- Dual auto-update workflows (`update-spec-validator.yml` + `update-tech-spec-validator.yml`) wired to `ido4/publish.yml` dispatches
- `sync-marketplace.yml` gate flipped on 2026-04-15 after the marketplace entry was added
