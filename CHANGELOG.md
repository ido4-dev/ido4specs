# Changelog

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
