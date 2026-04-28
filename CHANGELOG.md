# Changelog

## [0.4.3] — 2026-04-28

**Doctor UX refactor.** Round-4 and round-5 retest sessions surfaced two `/ido4specs:doctor` UX gaps: (1) doctor was running 8 separate Bash tool calls, each producing intermediate raw output users had to filter through to reach the 8-line summary, and (2) doctor reported validator versions but not the plugin version itself — both retest rounds had the user asking "wait, am I on the right plugin version?" because doctor doesn't answer that. This patch consolidates the diagnostic into a single shell script invocation, surfaces the plugin version in the report header, and adds a workspace-aware pipeline next-action hint at the workspace-state line.

### Added
- **`scripts/doctor.sh`** (~175 lines, shellcheck-clean). Self-contained diagnostic: runs all 8 health checks in one shell invocation; reads plugin version from `.claude-plugin/plugin.json`; computes pipeline next-action from workspace artifacts (strategic spec → `/ido4specs:create-spec`, canvas → `/ido4specs:synthesize-spec`, tech spec → `/ido4specs:review-spec`); resolves its own paths via `BASH_SOURCE` so it works from any cwd; falls back to the conventional `CLAUDE_PLUGIN_DATA` path when run outside Claude Code. Exit 0 on all-pass, 1 on any-fail.

### Changed
- **`skills/doctor/SKILL.md`** slimmed from 143 lines to 33 lines (−75%). Skill body becomes: invoke the script via `${CLAUDE_SKILL_DIR}/../../scripts/doctor.sh`, relay output, surface remediation hints conversationally if a check failed. Status-line config-block helper retained for the `not configured` case. Diagnostic logic now lives in versioned shell — easier to evolve, shellcheck-validated alongside the other plugin scripts.
- **Doctor report header now shows plugin version.** New line: `Plugin version: 0.4.3` (read from `.claude-plugin/plugin.json`). Closes the round-4/5 uncertainty about which plugin version is loaded.
- **Doctor Check 7 (workspace state) now includes a pipeline next-action.** When the script finds a strategic spec without artifacts: `→ next: /ido4specs:create-spec <path>`. When a canvas exists: `→ next: /ido4specs:synthesize-spec <canvas>`. When a tech spec exists: `→ next: /ido4specs:review-spec <spec> or /ido4specs:validate-spec <spec>`.

### Notes
- **TEST 13 picks up the new script automatically** via `scripts/*.sh` glob. Three new passes added to the validation suite (executable, valid bash syntax, shellcheck error-level clean) — total 169 PASS / 0 FAIL (was 166).
- **Trade-off:** less verbose intermediate output on failure. The formatted line message + remediation hint covers most cases. If a debug case needs raw bash output, a `--verbose` flag on the script would address it; not added in this patch since no failure case has needed it yet.
- **Out of scope for this patch (deferred to v0.5+):** cross-skill integrity check (catches partial-install issues), bundle freshness vs npm (proactive drift detection), auto-fix offers per failed check, plugin install source detection (local-dev vs marketplace).

## [0.4.2] — 2026-04-28

**Authoring discipline patch.** Round-4 E2E (`reports/e2e-004-PS-metabase-connector.md`) showed v0.4.1's OBS-01 fix held in `refine-spec` (where prose was backed by clean tooling fit) but regressed in `create-spec` Stage 0 (5 redundant validator invocations) and `synthesize-spec` Stage 1d (2 calls). Audit against [`ido4-suite/docs/prompt-strategy.md`](https://github.com/ido4-dev/ido4-suite/blob/main/docs/prompt-strategy.md) surfaced the cause: the v0.4.1 wording was a rule-shaped prohibition (`Run **once**`, `Do not pipe… under any circumstances`), but the failure has no enforcement layer (no parser, hook, or schema catches violations). Per the doc's decision test, qualitative instructions without enforcement should be principles, not rules. This patch reframes the affected SKILL.md sections as principles paired with concrete BAD/GOOD examples grounded in observed round-4 behavior.

### Changed

- **`create-spec` Stage 0 — OBS-01 reframe.** Replaced the prohibition (`Run **once**`, `Do not pipe…`) with a principle (*"the structured JSON output is in your conversation context as the Bash tool result — that's your data source"*) and a multi-line BAD/GOOD example pair contrasting the 5-invocation pattern observed in round 4 against single-call in-context reads. Same JSON-shape field reference retained as a medium-freedom template.
- **`create-spec` Stage 1c — new chunked-write principle (OBS-R4-02).** Round 4's canvas synthesis took 57 minutes via chunked Write calls (vs ~20 minutes for the same canvas via a single Write in round 3). Added a principle (*"A 30+ capability greenfield-with-context canvas typically lands at 2,000–3,000 lines. That's normal — write it as a single Write call. The Write tool overwrites rather than appends, so iterative chunked writes either lose prior content or force you to re-encode everything-prior-plus-new on each call. The latter is O(n²) in tokens"*) plus a BAD/GOOD example pair grounded in the round-4 timing.
- **`synthesize-spec` Stage 1d — validator-once principle.** Brief positive statement added (*"the JSON is in your conversation context — read `valid`, `errors[]`, `warnings[]`, and any metrics you need for the summary directly from the tool result. A second invocation, or piping through an external parser, returns the same data at higher cost"*). Round 4 surfaced 2 redundant calls here; addressing it consistently with create-spec.
- **`refine-spec` — prohibition language → positive statements.** Two sites where v0.4.1 said "do not pipe through `python3 -c`" rewritten as "pull `valid` / `errors[]` / `warnings[]` from there directly." Same line count, normal-case imperative. Refine-spec was already holding the discipline in round 4; this aligns the language with the prompt-strategy.md normal-case-imperatives guidance without changing behavior.

### Notes

- **No changes to `review-spec`'s OBS-08 fix.** That fix is held by structural enforcement (Bash is not in `review-spec`'s `allowed-tools`), not prose alone — round 4 showed it working with zero permission prompts and a 53% time reduction vs round 3. Per the prompt-strategy.md "don't fix what isn't broken" rule, leaving it.
- **TEST 15 unchanged.** All 166 plugin-validation checks still pass. The multi-line BAD examples in the new wording keep validator+`python3` tokens on different lines, so the existing anti-pattern regex doesn't trip.
- **The asymmetry uncovered by round 4 is itself the v0.4.1 authoring lesson.** Prose discipline holds where there's structural backing (allowed-tools, parser checks); drifts otherwise. If round 5 shows OBS-01 still regressing under principle+example wording, the next step is hooks (PostToolUse on Bash flagging consecutive validator invocations), not more prose. That's a v0.5+ design decision, not more rule-stacking.

## [0.4.1] — 2026-04-28

**Friction patch from round-3 E2E.** Four observations from `reports/e2e-003-PS-metabase-connector.md` addressed: zero permission prompts in `review-spec`, no more filesystem searches for agent files, faster Stage 0 in `create-spec`, and `validate-spec` finally surfaces in the in-product navigation. No correctness bugs were fixed — these are user-experience and skill-discoverability issues.

### Fixed
- **`review-spec` mechanism redesign (OBS-08).** Skill body now explicitly forbids shell-pipeline metadata extraction (`grep | sort | uniq -c`, `awk` for counting, etc.) — these triggered 4 permission prompts per run because Bash isn't in `review-spec`'s allowed-tools. Effort/risk/type/`ai` distributions, hub tasks, root tasks, success-condition counts, and description char counts are now derived from the in-context spec content directly. Substantive review depth (evidence-backed warnings, sibling-pattern checks, dependency-graph reasoning) preserved — only the mechanism changed.
- **Agent file path anchors (OBS-04).** Eight references to `agents/*.md` across `create-spec`, `synthesize-spec`, and `review-spec` SKILL.md bodies now use the `${CLAUDE_SKILL_DIR}/` prefix. Bare relative paths previously triggered `$HOME`-wide filesystem searches when Claude tried to resolve them.
- **Validator JSON usage in `create-spec` Stage 0 and `refine-spec` revalidation (OBS-01).** Stage 0 of `create-spec` now spells out the `spec-validator.js` JSON shape (`project.name`, `groups[].capabilityCount`, `metrics.dependencyEdgeCount`, `metrics.maxDependencyDepth`, `metrics.crossCuttingConcernCount`) so the field-extraction-via-`python3 -c` loop disappears — previously this added ~3 minutes to every Stage 0 run via 5 redundant validator invocations. Same anti-pattern explicitly forbidden in `refine-spec`'s baseline + post-edit revalidation.
- **`validate-spec` cross-reference surfacing (OBS-09).** End-message templates in `synthesize-spec`, `review-spec` (verdict prompts), and `refine-spec` now mention `/ido4specs:validate-spec` alongside `/ido4specs:review-spec`. The deterministic content-assertion layer (T0–T8) is no longer orphaned in the in-product navigation graph — a user following only the in-skill suggestions will encounter it.

### Added
- **TEST 15 in `tests/validate-plugin.sh` (12 hygiene checks).** Guards all four observations against regression: skill-body refs to `agents/*.md` must use `${CLAUDE_SKILL_DIR}/` prefix; predecessor skills' end-messages must mention `/ido4specs:validate-spec`; `review-spec` must explicitly forbid shell-pipeline metadata extraction and instruct deriving from in-context spec content; no skill body may pipe validator output through `python3 -c`. Total suite: 166 PASS / 0 FAIL / 0 WARN.
- **Round-3 E2E report.** `reports/e2e-003-PS-metabase-connector.md` documents the 5-skill pipeline run on a 43-cap / 59-task strategic spec, all observations + positives, and a "Design questions for v0.5+" section capturing structural conversations that don't fit the per-OBS frame (user-profiling at pipeline entry, two-layer validation framing, pipeline orchestrator pattern, `create-spec`'s internal phasing, cross-sell footer audit).

### Changed
- **Bundled validators updated to v0.9.0** (`spec-validator.js` and `tech-spec-validator.js`). Auto-merged via the cross-repo sync pipeline; rebased into the release commit.

## [0.4.0] — 2026-04-20

add spec-quality skill migrated from ido4dev (methodology-neutral adaptation)

### Added
- `spec-quality` skill for assessing technical spec quality against methodology-neutral standards.
- PRIVACY.md documenting no-collection practices.

### Changed
- Updated bundled validators (spec-format and tech-spec-format) to v0.8.0.

### Fixed
- Improved marketplace onboarding and plugin diagnostics.

## [0.3.0] — 2026-04-17

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
- **Marketplace polish.** Description rewritten as a 50-word value-led elevator pitch. Refined keywords to match audience search behavior (dropped vague `specification` and misleading `spec-writing`; added `implementation-planning`, `engineering-planning`, `github-issues`). Added `author.email` for reviewer contact.

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
