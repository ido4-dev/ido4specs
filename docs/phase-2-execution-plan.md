# Phase 2 Execution Plan — ido4specs plugin creation

**Created:** 2026-04-14
**Prerequisite:** `docs/extraction-plan.md` Phase 1 complete
**Goal:** Produce a locally-validated `ido4specs` plugin scaffold — 5 skills, 3 agents, bundled validators, packaging — ready for Phase 3 (ido4dev slimming).

---

## 1. What Phase 2 is actually testing

Phase 2 is not a file-shuffling exercise. It's where four architectural bets from the extraction plan meet real code. Every decision in this plan is oriented around keeping these bets intact.

**Bet 1 — Parser-as-seam.** The bundled technical-spec validator lets `ido4specs` produce files and `@ido4/core` consume them without sharing a runtime dependency. Same binary at both ends, version contract fails fast on major mismatch. The test: does every spec touchpoint go through the bundled validator, with no back-channel path to the monorepo parser?

**Bet 2 — Methodology neutrality.** `ido4specs` produces a `.md` file and stops. No Scrum, no Shape-Up, no BRE, no profile config, no container types. Methodology lives downstream in `@ido4/core/spec-mapper.ts`, applied at ingestion. The test: does any ported skill or agent secretly reach for a methodology concept? Any leak is a Phase 2 bug.

**Bet 3 — Inline-execution reliability.** Round 3 of `ido4dev`'s E2E tests (see `ido4dev/reports/e2e-003-ido4shape-cloud.md` OBS-04b) proved that plugin-defined subagents hang at ~25–30 tool uses in Claude Code, and that the fix is inline execution with built-in `Explore` subagents. `ido4dev`'s current decompose skills already implement this pattern correctly. Phase 2's job is to preserve it faithfully — **not** "clean it up" into a more elegant subagent delegation that breaks.

**Bet 4 — Zero runtime coupling.** `ido4specs` has no MCP server, no `ingest_spec` call, no access to `@ido4/mcp`. The only cross-plugin signal is a filesystem probe for `.ido4/project-info.json` to vary an end-of-flow cross-sell message. If Phase 2 accidentally reintroduces an MCP call anywhere, the seam is broken and the whole case for this extraction weakens.

If Phase 2 clears all four, `ido4specs` is a real standalone plugin. If any wobble, Phases 3–5 compound the problem.

---

## 2. Reference-model clarification (important)

Two reference repos, two different roles. Keep them straight.

- **`ido4shape` = packaging reference only.** `.claude-plugin/plugin.json` shape, `scripts/release.sh` structure, `tests/validate-plugin.sh` pattern, `.github/workflows/*.yml` layout, `hooks/hooks.json` plumbing, SessionStart `cp` hook pattern. These are Claude Code plugin packaging concerns, and `ido4shape` is the cleanest canonical implementation of the suite's 4-layer release pattern. Mirror the shape. **Do not mirror skill internals** — `ido4shape` targets Claude Cowork / Desktop, uses plugin-defined subagents via the `Agent` tool for composition and parallel review, and those patterns don't work reliably in Claude Code. `ido4shape` is also tested and in production — do not edit it as part of this work.

- **`ido4dev` = content reference.** The `decompose`, `decompose-tasks`, `decompose-validate` skills and the `code-analyzer`, `technical-spec-writer`, `spec-reviewer` agents are the direct ancestors of what `ido4specs` ships. They already implement the inline-execution + built-in-`Explore` pattern that round 3 proved reliable. Port them with a language pass and a rename; don't invent new structure.

---

## 3. Pre-flight

Verify before starting any stage:

- `~/dev-projects/ido4/packages/tech-spec-format/dist/tech-spec-validator.bundle.js` exists (Phase 1 artifact, ~15 KB)
- `~/dev-projects/ido4/packages/spec-format/dist/spec-validator.bundle.js` exists (~8.6 KB)
- `~/dev-projects/ido4dev/skills/{decompose,decompose-tasks,decompose-validate}/SKILL.md` present
- `~/dev-projects/ido4dev/agents/{code-analyzer,technical-spec-writer,spec-reviewer}.md` present
- `~/dev-projects/ido4/architecture/spec-artifact-format.md` present (the doc to move)
- `~/dev-projects/ido4/tests/fixtures/technical-spec-sample.md` present (the example to copy)
- `~/dev-projects/ido4shape/` packaging files present (plugin.json, scripts/release.sh, scripts/update-validator.sh, tests/validate-plugin.sh, .github/workflows/{ci,sync-marketplace,update-validator}.yml, hooks/hooks.json)
- `~/dev-projects/ido4specs/` contains only `CLAUDE.md`, `README.md`, `.gitignore`, `docs/`, `.git/`

---

## 4. Stage ordering

```
Stage A — Packaging scaffolding   (plugin.json, hooks, scripts, tests, workflows, bundles)
   ↓
Stage B — References              (technical-spec-format.md, example-technical-spec.md)
   ↓
Stage C — Agents                  (3 ports with language pass)
   ↓
Stage D — Skills                  (5 creates, sequenced by internal dependency)
   ↓
Stage E — Local validation + exit (run suite, smoke test, update CLAUDE.md, commit)
```

Within each stage, items are independent unless noted. Commit at stage boundaries, not per-file.

---

## 5. Filename and path conventions (canonical — applies to all stages)

**This section is the single source of truth for artifact paths.** Every skill, agent, validation check, and documentation example in the plan cites these conventions. Do not introduce filename variants elsewhere in the code without updating this section first.

### 5.1 — Directory

`ido4specs` uses a single work area in the target codebase for all spec-related artifacts (strategic and technical). Discovery logic is the same four-tier lookup `ido4dev`'s `decompose` currently uses:

1. If `specs/` exists in the project root → use it
2. Else if `docs/specs/` exists → use it
3. Else if `docs/` exists → create `docs/specs/`
4. Else create `specs/`

The discovered or created directory is referred to as `{artifact-dir}` throughout the plan.

### 5.2 — Filename scheme

All ido4 spec artifacts use distinct, self-documenting suffixes. Each filename carries its layer identity — `ls specs/` is enough to understand the pipeline state.

| Artifact | Filename | Producer |
|---|---|---|
| Strategic spec | `{name}-strategic-spec.md` | `ido4shape` output (user-renamed on copy) |
| Technical canvas | `{name}-tech-canvas.md` | `/ido4specs:create-spec` |
| Technical spec | `{name}-tech-spec.md` | `/ido4specs:synthesize-spec` |

**Why `-strategic-spec.md` and not `-spec.md` for strategic.** `ido4shape` writes its output in its own session workspace, not the target codebase — the user manually copies the file into the codebase. Renaming at copy time costs nothing and gives complete filename symmetry with technical artifacts. Every file in `specs/` carries its layer identity explicitly, with zero asymmetry and zero "which spec is this" moments.

**Why location is recommended not enforced.** `ido4specs` accepts the strategic spec from any path — `specs/`, project root, `docs/`, an absolute path elsewhere. The recommendation lives in docs (CLAUDE.md, README); enforcement does not live in the tool. Users who prefer strategic specs at project root for visibility are accommodated without changes. The filename suffixes carry the disambiguation, so co-location is preferred but not required.

**Example layout:**

```
project/
└── specs/
    ├── notification-system-strategic-spec.md   ← from ido4shape (user-placed)
    ├── notification-system-tech-canvas.md      ← ido4specs phase 1
    └── notification-system-tech-spec.md        ← ido4specs phase 2 → ingest-spec input
```

### 5.3 — Spec-name derivation rule

Every skill that derives a spec-name from an input path uses the same function. Apply in order, first match wins:

```
derive_spec_name(path):
  base = basename(path) with ".md" stripped
  strip trailing suffix if present (first match wins):
    "-strategic-spec"   # strategic spec, recommended name
    "-tech-spec"        # technical spec
    "-tech-canvas"      # technical canvas
    "-spec"             # backward-compat: raw ido4shape output before user rename
  return base
```

Test cases:

| Input path | Derived spec-name |
|---|---|
| `specs/notification-system-strategic-spec.md` | `notification-system` |
| `specs/notification-system-tech-canvas.md` | `notification-system` |
| `specs/notification-system-tech-spec.md` | `notification-system` |
| `./notification-system-spec.md` (raw ido4shape output) | `notification-system` |
| `./product-v2.md` (no spec suffix at all) | `product-v2` |
| `docs/roadmap-2026-strategic-spec.md` | `roadmap-2026` |

Same input name → same base → same derived paths at every hop. Ties the pipeline together.

### 5.4 — Filename is a hint, format marker is the truth

`ido4specs` never trusts filenames alone. Every skill that reads a spec file also checks the format marker in the file content — either `> format: strategic-spec | version: 1.0` or `> format: tech-spec | version: 1.0`. If the filename and the format marker disagree, the format marker wins and a warning surfaces. This means:

- A user who forgets to rename from `-spec.md` to `-strategic-spec.md` gets parsed correctly (backward-compat fallback in the derivation rule + content-authoritative parsing).
- A user who mislabels a file (e.g., renames a strategic spec to `-tech-spec.md` by mistake) sees a warning rather than silent wrong behavior.

### 5.5 — Glob patterns

All non-overlapping, tool-friendly:

- `specs/*-strategic-spec.md` → strategic specs
- `specs/*-tech-*.md` → **everything** `ido4specs` produced
- `specs/*-tech-spec.md` → technical specs only
- `specs/*-tech-canvas.md` → technical canvases only
- Fallback for raw ido4shape output not yet renamed: `./*-spec.md` at project root

---

## 6. Stage A — Packaging scaffolding

**Goal:** get `validate-plugin.sh` able to run end-to-end (even if it reports FAILs about missing skills/agents — the harness itself must work).

### A.1 — `.claude-plugin/plugin.json`

Create new. Mirror `ido4shape`'s shape:

```json
{
  "name": "ido4specs",
  "description": "Turn a strategic spec into a structurally-validated technical spec on disk. Companion to ido4shape for engineers planning implementation work. Reads a strategic spec, explores your codebase, produces a technical canvas (name-tech-canvas.md), then synthesizes a methodology-neutral technical spec (name-tech-spec.md) with capability decomposition, task metadata, and a dependency graph. Any downstream tool — or ido4dev:ingest-spec — can turn the file into GitHub issues.",
  "version": "0.1.0",
  "category": "productivity",
  "author": { "name": "Bogdan Coman", "url": "https://github.com/ido4-dev" },
  "homepage": "https://github.com/ido4-dev/ido4specs",
  "repository": "https://github.com/ido4-dev/ido4specs",
  "license": "MIT",
  "keywords": ["specification", "spec-writing", "technical-spec", "task-decomposition", "code-analysis", "claude-code"]
}
```

Description must be under 1024 chars and assertive (prompt-strategy allows pushy language in discovery metadata). The GitHub repo URL doesn't exist yet — that's Phase 5's creation moment. Declaring it here is intentional.

### A.2 — `dist/` bundled validators

Two bundles, two version markers.

```
cp ~/dev-projects/ido4/packages/tech-spec-format/dist/tech-spec-validator.bundle.js \
   ~/dev-projects/ido4specs/dist/tech-spec-validator.js

cp ~/dev-projects/ido4/packages/spec-format/dist/spec-validator.bundle.js \
   ~/dev-projects/ido4specs/dist/spec-validator.js
```

Version markers:

```
echo "0.1.0" > ~/dev-projects/ido4specs/dist/.tech-spec-format-version
echo "0.7.2" > ~/dev-projects/ido4specs/dist/.spec-format-version
```

Both bundles commit to git. Both version markers commit to git. The pattern is identical to `ido4shape`'s committed `dist/spec-validator.js` + `dist/.spec-format-version`.

**Why two bundles?** `create-spec`'s Stage 0 parses the upstream strategic spec (the same call `ido4dev:decompose` currently makes to `parse_strategic_spec` via MCP). Without an MCP server, the replacement is the bundled strategic-spec validator CLI. `validate-spec` uses the technical-spec bundle to validate the produced artifact. Two validators, two responsibilities, two bundles — symmetric with the two-sided-parsing contract in extraction-plan.md section 5.

### A.3 — `hooks/hooks.json`

Minimal: two `SessionStart` command hooks, one per validator bundle. Nothing else.

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
          },
          {
            "type": "command",
            "command": "cp \"${CLAUDE_PLUGIN_ROOT}/dist/spec-validator.js\" \"${CLAUDE_PLUGIN_DATA}/spec-validator.js\" 2>/dev/null || true",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

No `PreToolUse` phase-gate, no `UserPromptSubmit` canvas-context, no `Stop` check, no `PreCompact` prompt. Those are `ido4shape` conversation-flow hooks that have no analogue here — `ido4specs` is a transform pipeline, not a dialogue tool.

### A.4 — `scripts/`

Three scripts only:

**`scripts/release.sh`** — adapt `ido4shape/scripts/release.sh`. Name substitutions: `ido4shape` → `ido4specs`. Keep `--yes` and `--dry-run` flags. Pre-flight order: Claude CLI presence, clean working tree, remote sync, `validate-plugin.sh`, plugin.json format check, version coherence, validator-bundle-drift check (confirm `dist/tech-spec-validator.js` and `dist/spec-validator.js` match their version markers).

**`scripts/update-tech-spec-validator.sh`** — adapt `ido4shape/scripts/update-validator.sh`. Takes a version string or a local path to the `ido4` monorepo. Two modes:
- Version mode: `npm pack @ido4/tech-spec-format@<version>`, extract `dist/tech-spec-validator.bundle.js`, copy to `dist/tech-spec-validator.js`, write `dist/.tech-spec-format-version`
- Local mode: take path to ido4 checkout, `cd packages/tech-spec-format && npm run build:bundle`, copy result

**`scripts/update-spec-validator.sh`** — same shape as above, for `@ido4/spec-format`. Separate file so each update path is debuggable in isolation. Don't combine them into a polyvariant script.

**Not needed:** `session-start.sh`, `canvas-context.sh`, `phase-gate.sh`, `stop-check.sh`, `find-workspace.sh`, `find-project-dir.sh`, `hook-diagnostic.sh`, `generate-skill-inventory.sh`, `deploy-to-cowork.sh`. All `ido4shape`-specific, none apply here.

### A.5 — `tests/validate-plugin.sh`

Adapt `ido4shape/tests/validate-plugin.sh` (26 KB, 203 checks). Structure reuses cleanly; specific values need substitution. Budget real effort here — it's the one file where skim-porting is a trap.

**Sections to keep (adapted):**

1. **Plugin manifest.** Check `plugin.json` exists, valid JSON, required fields (`name`, `description`, `version`, `repository`, `license`), `name == "ido4specs"`, `repository` URL points to `ido4-dev/ido4specs`.
2. **Bundled validators present.** Check `dist/tech-spec-validator.js` and `dist/spec-validator.js` exist. Run each with no argument — should exit with a usage error (exit 2), not a crash. Run each against the corresponding example and expect exit 0.
3. **Version marker files.** Check `dist/.tech-spec-format-version` and `dist/.spec-format-version` exist and match a semver regex.
4. **Skill directory structure.** For each `skills/*/SKILL.md`: valid YAML frontmatter (`name`, `description`, `allowed-tools` or equivalent), body under 500 lines, no XML tags, no `${CLAUDE_PLUGIN_ROOT}` references in skill body (that env var is hooks/mcp only).
5. **Agent directory structure.** For each `agents/*.md`: valid frontmatter (`name`, `description`, `tools`, `model`), body under 300 lines.
6. **Hook config.** `hooks.json` valid JSON, `SessionStart` entry present with both copy commands, no references to scripts that don't exist.
7. **References present.** `references/technical-spec-format.md` exists. `references/example-technical-spec.md` exists AND parses cleanly under the bundled validator (round-trip test — our own validator parses our own example).
8. **`claude plugin validate .`** — run if CLI available, warn (not fail) if not.
9. **Language-pass guardrail.** `grep -En '\b(MUST|NEVER|ALWAYS|IMPORTANT|CRITICAL)\b' skills/*/SKILL.md agents/*.md | wc -l`. Ceiling: 10 across the whole plugin (allows a few load-bearing hard rules, fails the noisy anti-pattern). This is the regression guard for the Round 4 language audit applied in-context.
10. **No MCP leaks.** `grep -En 'mcp__|parse_strategic_spec|ingest_spec|@ido4/mcp' skills/*/SKILL.md agents/*.md` — must return nothing.
11. **No TodoWrite leaks.** `grep -En '\bTodoWrite\b' skills/*/SKILL.md agents/*.md` — must return nothing (current Claude Code uses `TaskCreate`/`TaskUpdate`).
12. **Filename invariant guard** (per §5.2). `grep -En '\-technical\.md|\-canvas\.md[^-]' skills/*/SKILL.md agents/*.md` — must return nothing. The `[^-]` guard prevents false positives on `-tech-canvas.md`. Old `ido4dev` naming (`-canvas.md`, `-technical.md`) is stale by construction after the port; surviving references are bugs.

**Sections to drop:** any check referencing `.ido4shape/` workspace, `.ido4shape/canvas.md`, `soul.md`, `stakeholder-profiles.md`, Cowork-specific paths.

**Sections to add:**

- **Methodology-neutrality grep.** `grep -En '\b(Scrum|Shape-Up|Hydro|BRE|methodology profile|container-bound)\b' skills/*/SKILL.md agents/*.md references/*.md` — must return nothing except inside `references/technical-spec-format.md` where the format doc may reference methodology as downstream context.
- **Cross-validator round-trip.** Explicitly run `dist/tech-spec-validator.js references/example-technical-spec.md` and expect exit 0.
- **Convention coherence check.** For each `skills/*/SKILL.md` that mentions a concrete filename in an example or usage line, verify it matches one of the §5.2 canonical forms (`*-strategic-spec.md`, `*-tech-canvas.md`, `*-tech-spec.md`). Catches drift where a skill example was written with the old naming.

### A.6 — `.github/workflows/`

Three workflows:

**`ci.yml`** — identical to `ido4shape/.github/workflows/ci.yml`. Checkout + `bash tests/validate-plugin.sh`. One-line substitutions only.

**`sync-marketplace.yml`** — shape identical to `ido4shape/.github/workflows/sync-marketplace.yml`. `workflow_run` gated on CI, pushes plugin files to `ido4-plugins` marketplace repo. Path and token name substitutions:
- `ido4shape` → `ido4specs` throughout
- Dispatch token: `IDO4SPECS_MARKETPLACE_TOKEN` (new secret, Phase 5 creates it)

**Mark as deferred until Phase 5 operationally** — the workflow file exists and is correct, but the marketplace entry and token don't exist until Phase 5, so CI runs of this workflow will fail during the intermediate period. Either (a) leave the workflow file committed and let it fail until Phase 5 (noisy but visible), or (b) commit it with the job commented out and uncomment in Phase 5. **Prefer (b)** — failing CI for weeks is a false-alarm tax.

**`update-tech-spec-validator.yml`** — adapt `ido4shape/.github/workflows/update-validator.yml`. Triggers: `repository_dispatch` type `tech-spec-format-published`, weekly cron (safety net), `workflow_dispatch` manual. Runs `scripts/update-tech-spec-validator.sh`, commits new bundle + version marker, opens auto-PR. The cross-repo `repository_dispatch` from `ido4/.github/workflows/publish.yml` is Phase 4 wiring — for Phase 2, the `workflow_dispatch` path (manual trigger) is enough to exercise the update path once the repo exists.

**Not shipping in Phase 2:** `update-readme.yml`. Optional; defer.

### A.7 — Top-level docs

- `LICENSE` — copy `ido4shape/LICENSE` (MIT)
- `SECURITY.md` — copy `ido4shape/SECURITY.md`, substitute plugin name
- `CHANGELOG.md` — create with one unreleased section: `## [0.1.0] - unreleased\n\n- Initial plugin extraction from ido4dev. See docs/extraction-plan.md and docs/phase-2-execution-plan.md.`
- `README.md` — already exists (1.5 KB). Don't rewrite yet — revisit in Stage E.3 after skill surface is final.
- `CLAUDE.md` — already exists, currently "under construction" phase. Don't touch in Stage A. Rewrite in Stage E.3.

### Stage A exit criteria

- `bash tests/validate-plugin.sh` runs end-to-end without crashing (many FAIL lines expected — no skills/agents yet)
- `claude plugin validate .` runs (if CLI available) and does not hard-fail on structural issues
- Both bundled validators present and `node dist/tech-spec-validator.js --help` or similar works

---

## 7. Stage B — References

Two files. Short stage but important.

### B.1 — Move `technical-spec-format.md`

The plan says "move not copy" but the source is in a different repo. Handle as two sides of one logical move:

**In `~/dev-projects/ido4specs/`:**
```
mkdir -p references
cp ~/dev-projects/ido4/architecture/spec-artifact-format.md references/technical-spec-format.md
```

Prepend a one-line header above the copied content:

```
> Moved from ido4/architecture/spec-artifact-format.md during Phase 2 of the
> ido4specs extraction (2026-04-14). This is the canonical reference for the
> technical-spec format — produced by ido4specs, consumed by @ido4/core's
> ingestion pipeline via the bundled @ido4/tech-spec-format parser.
```

**In `~/dev-projects/ido4/` (deferred to Phase 4):** delete `architecture/spec-artifact-format.md`. Grep the monorepo for references to it (test files, READMEs, code comments, other architecture docs) and update them to point at `ido4specs/references/technical-spec-format.md`. Bundle this change with the Phase 4 `interface-contracts.md` contract #6 addition so the monorepo commit and the suite commit land close together.

**Why not delete the monorepo copy in Phase 2?** Because during Phases 2–3, `ido4dev` still has a decompose flow that cites this doc via CLAUDE.md references. Deleting it now would leave broken doc links in `ido4dev` until Phase 3 slimming completes. Phase 4 is the natural moment for the monorepo cleanup.

### B.2 — Create `example-technical-spec.md`

```
cp ~/dev-projects/ido4/tests/fixtures/technical-spec-sample.md \
   ~/dev-projects/ido4specs/references/example-technical-spec.md
```

**Round-trip verification (mandatory):**

```
node ~/dev-projects/ido4specs/dist/tech-spec-validator.js \
     ~/dev-projects/ido4specs/references/example-technical-spec.md
```

Expected: exit 0, no errors. If the fixture has drifted since `@ido4/tech-spec-format@0.1.0` landed and doesn't parse cleanly, **fix the example, not the parser**. The example is the reference and the round-trip test. It must parse under our own shipped validator.

### Stage B exit criteria

- `references/technical-spec-format.md` exists
- `references/example-technical-spec.md` exists AND `node dist/tech-spec-validator.js references/example-technical-spec.md` → exit 0

---

## 8. Stage C — Agents (3 ports)

Three agents move from `ido4dev/agents/` → `ido4specs/agents/`. Each port is:

1. Read the source file end-to-end before editing
2. Update frontmatter (tools, description, drop `mcp` if present)
3. Apply the language pass per `prompt-strategy.md`
4. Rewrite any stale MCP call references in the body (code-analyzer Step 1 is the one known case)
5. Stay under 300 lines (prompt-strategy agent threshold)
6. Remove any methodology, BRE, or `ido4dev`-specific references

The language pass is creative work, not mechanical. Target: **fewer words, not more**. Each replacement of `MUST` with principle+example must justify its token cost per prompt-strategy's "budget the positive replacements" rule. If the end of the pass lengthens the file, you're probably over-expanding.

### C.1 — `agents/code-analyzer.md`

**Source:** `~/dev-projects/ido4dev/agents/code-analyzer.md` (228 lines, 12.7 KB)

**Frontmatter changes:**

```yaml
---
name: code-analyzer
description: >
  Analyzes a codebase in the context of a strategic spec and produces a technical
  canvas — a markdown artifact mapping each strategic capability to concrete code
  knowledge. Used inline by /ido4specs:create-spec as a canvas template and rules
  reference, not spawned as a subagent.
tools: Read, Write, Glob, Grep
model: opus
---
```

Key changes vs source:
- Drop `mcp` from `tools`
- Rewrite `description` to reference `/ido4specs:create-spec` and explicitly note inline usage (prevents future "clean-up" into subagent delegation)

**Body changes:**

- **Step 1 rewrite (critical).** The source currently says: *"Call `parse_strategic_spec` with the spec content to get structured data."* This is stale from before round 3's inline-execution rewrite. In the new pattern, `create-spec`'s Stage 0 parses the strategic spec via the bundled validator and passes the parsed data to the code-analyzer inline. Rewrite Step 1 to:

  > Review the strategic-spec structured data provided by `create-spec`'s Stage 0. You receive: project name and description, groups with priorities, capabilities with dependency edges, cross-cutting concerns, stakeholders, constraints, non-goals, open questions.

- **Rule 3 (context preservation)** — keep as rule, empirical origin is load-bearing. Current text: *"You MUST carry forward verbatim..."* The WHY is already present (*"if the canvas drops context, everything downstream fails"*). Just dial `MUST` → `always` and let the existing explanation carry the weight.

- **Rule 7 (no cat via Bash)** — empirical, OBS-03 from e2e-001. Keep as rule. Rewrite positive: *"Read files via the `Read` tool, not via shell helpers. Shell reads rely on internal cache paths that are Claude Code internals and break when those internals change."* Note: this rule references `cat` — and `cat` is banned, not Bash entirely. Make that distinction clear.

- **Scan for remaining all-caps.** Expected violations in source: `MUST carry forward` (rule 3), `MUST be to call` (Step 1, being rewritten anyway), `Never use cat` (rule 7), possibly `NEVER` in mode-specific sections. Target: 0 uncovered after the pass (or document each retained instance with inline comment explaining why).

- **Mode-specific instructions** (`existing` / `greenfield-with-context` / `greenfield-standalone`) — keep verbatim. These are load-bearing behavioral guidance.

- **Methodology / BRE references** — scan and remove any. Expected: none, but verify.

**Body size:** currently 228 lines. Target: 180–230 lines after the pass (the stale Step 1 rewrite is the only meaningful shrink; don't try to force more). If it stays close to 300, that's fine — don't split into progressive-disclosure sibling files unless forced to.

### C.2 — `agents/technical-spec-writer.md`

**Source:** `~/dev-projects/ido4dev/agents/technical-spec-writer.md` (~228 lines, 12.8 KB)

**Frontmatter changes:**

```yaml
---
name: technical-spec-writer
description: >
  Reads a technical canvas and produces a technical spec artifact in the format
  consumed by ido4's ingestion pipeline. Decomposes strategic capabilities into
  right-sized tasks with code-grounded effort, risk, type, AI suitability, and
  dependencies. Used inline by /ido4specs:synthesize-spec as a template and
  rules reference, not spawned as a subagent.
tools: Read, Write, Glob, Grep
model: opus
---
```

**Body changes:**

- **Rule 5 ("Respect the contract")** — hard rule with real enforcer (the parser). Keep as rule. Current: *"The output MUST be parseable by `spec-parser.ts`."* Rewrite with explicit WHY: *"The output must parse under `@ido4/tech-spec-format`. `validate-spec` runs the parser on the file after you produce it, and `@ido4/core`'s ingestion runs the same parser downstream. If your output doesn't parse, the file is silently unusable — the downstream pipeline can't read it."* Replace `spec-parser.ts` with `@ido4/tech-spec-format` (the package name in the new world).

- **"Technical Capabilities" section** — *"the capability description MUST explain why it exists"*. Parser doesn't enforce "why" — this is empirical guidance, not a parser rule. Downgrade: `MUST` → `should`, keep as principle with WHY (*"without the why, a PLAT-/INFRA-/TECH- capability looks arbitrary downstream and reviewers can't judge whether it belongs"*).

- **Goldilocks Principle** — already well-written principle + examples. Leave intact.

- **Rule 6 (no cat via Bash)** — same treatment as code-analyzer.

- **Task-ref pattern** — reference the regex `[A-Z]{2,5}-\d{2,3}[A-Z]?`. Explicitly note that suffixed refs (`NCO-01A`) are valid and trace to strategic capability `NCO-01`. This is load-bearing — the source already has it correctly.

- **Methodology references** — scan for any leak. Technical-spec-writer already is methodology-neutral in the source; verify.

**Body size:** ~228 lines source, target similar.

### C.3 — `agents/spec-reviewer.md`

**Source:** `~/dev-projects/ido4dev/agents/spec-reviewer.md` (95 lines, 4.6 KB — the smallest)

**Frontmatter changes:**

```yaml
---
name: spec-reviewer
description: >
  Reviews technical spec artifacts for format compliance and content quality.
  Two-stage review: structural checks against the parser contract, then
  qualitative assessment of descriptions, success conditions, metadata
  calibration, and dependency graph sanity. Used inline by
  /ido4specs:review-spec, not spawned as a subagent. Runs on Sonnet.
tools: Read, Glob, Grep
model: sonnet
---
```

**Body changes:**

- **"Pipeline Context" section** — source lists two invocation contexts: *"Standalone — user invokes `/ido4dev:spec-validate`"* and *"Decomposition Phase 3 — spawned by `/ido4dev:decompose-validate`"*. Round 3 collapsed this into always-inline. Update to: *"Invoked inline by `/ido4specs:review-spec`. Main Claude reads this file as the review protocol and rules reference."* Single context, clean.

- **"Governance Implications Check" section** — source mentions "BRE", "elevated governance attention", "downstream governance impact". `ido4specs` is methodology-neutral and knows nothing about the BRE. Rewrite this section as "Downstream awareness" — the reviewer surfaces values the downstream ingestion pipeline will care about (`ai: human`, `risk: critical`, heavy cross-capability deps) as *information*, not as governance enforcement. Frame: *"These are flags for the user to consider before handing the spec to downstream tooling — they shape attention, not gates."*

- **"For each issue found, independently verify it before reporting. False positives erode trust."** — principle with good WHY in the source. Keep verbatim.

- **Model-tier caveat.** `spec-reviewer` runs on Sonnet. Per prompt-strategy: *"On smaller models (Sonnet, Haiku), principles may underspecify — the model needs more explicit examples."* Do **not** preemptively add examples in Phase 2. Land the port, observe behavior in Phase 5 smoke testing, add calibration examples only if we see verdicts drift shallow.

- **Output format** (Spec Review Report markdown template) — verbatim.

**Body size:** ~95 lines, comfortably under 300.

### Stage C exit criteria

- `agents/code-analyzer.md`, `agents/technical-spec-writer.md`, `agents/spec-reviewer.md` exist
- All three have valid frontmatter (`name`, `description`, `tools`, `model`)
- All three under 300 lines
- `grep -En '\bMUST\b|\bNEVER\b|\bALWAYS\b|\bIMPORTANT\b|\bCRITICAL\b' agents/*.md` returns zero or a tiny documented set
- `grep -En 'mcp__|parse_strategic_spec|ingest_spec|@ido4/mcp|\bBRE\b|methodology profile' agents/*.md` returns nothing
- `grep -En 'ido4dev:|decompose-tasks|decompose-validate' agents/*.md` returns nothing (all skill references point at `ido4specs:*` now)

---

## 9. Stage D — Skills (5 creates)

Five skills. Source-to-target mapping:

| Target | Source | Strategy |
|---|---|---|
| `skills/validate-spec/SKILL.md` | (new) | Thin wrapper around the bundled validator, intelligent error interpretation. Structural reference: `ido4shape/skills/validate-spec/SKILL.md` (strategic-focused but same two-pass shape) |
| `skills/create-spec/SKILL.md` | `ido4dev/skills/decompose/SKILL.md` | Rename, drop MCP, replace `parse_strategic_spec` with bundled CLI, language pass |
| `skills/synthesize-spec/SKILL.md` | `ido4dev/skills/decompose-tasks/SKILL.md` | Rename, drop MCP, add auto-run of bundled tech-spec validator at end, language pass |
| `skills/review-spec/SKILL.md` | `ido4dev/skills/decompose-validate/SKILL.md` Stage 1 only | Slim split — drop Stages 2 (preview) and 3 (ingest), language pass |
| `skills/refine-spec/SKILL.md` | (new) | Structure-borrow from `ido4shape/skills/refine-spec/SKILL.md` strategic half, retarget fields to technical-spec metadata |

**Order within Stage D** (by dependency):

1. `validate-spec` — simplest and unblocks `synthesize-spec`'s auto-run
2. `create-spec` and `synthesize-spec` — independent, can go in parallel
3. `review-spec` — needs `spec-reviewer` agent from Stage C
4. `refine-spec` — most novel work, do last with fresh eyes

### D.1 — `skills/validate-spec/SKILL.md`

**Frontmatter:**

```yaml
---
name: validate-spec
description: >
  Validates a technical spec artifact for format compliance and content quality.
  Two-pass: deterministic structural check via the bundled @ido4/tech-spec-format
  parser, then qualitative content assertions. Returns PASS / PASS WITH WARNINGS
  / FAIL with line-referenced findings. Use when the user says "validate the spec",
  "check the tech spec", "is this ready for ingest", or wants to verify a
  {name}-tech-spec.md before handing it downstream. Pass the file path as argument:
  /ido4specs:validate-spec specs/notification-system-tech-spec.md
allowed-tools: Read, Glob, Grep, Bash
---
```

**Input discovery.** If `$ARGUMENTS` is empty, glob `specs/*-tech-spec.md` (and `docs/specs/*-tech-spec.md` as fallback) and ask the user which to validate. Do not auto-pick when multiple match — ask. The path-argument form remains the primary interface.

**Body structure** (~150–200 lines, modeled on `ido4shape/skills/validate-spec/SKILL.md`):

**Pass 1 — Structural validation (deterministic).** Run:

```bash
node "${CLAUDE_PLUGIN_DATA}/tech-spec-validator.js" <path>
```

Parse the JSON output. Interpret errors intelligently — do not just relay:

- **Broken depends_on** (`depends on "X" which does not exist`): scan the `tasks` array for existing refs, infer intended target from the task's description and prefix, suggest the correct ref.
- **Circular dependencies** (`Circular dependency detected: A → B → A`): trace the cycle, read each task description to identify the natural data/control flow, recommend which edge to reverse.
- **Duplicate task refs** (`Duplicate task ref: X`): suggest renaming the second with the next available suffix or number.
- **Invalid metadata values**: show the allowed set. If close to valid (`"cricital"` vs `"critical"`), propose the fix.
- **Missing format marker**: show expected line `> format: tech-spec | version: 1.0`.
- **Metric anomalies** from `metrics` object: empty capabilities (declared but no tasks), orphan tasks (no capability), unbalanced sizes (one capability has 8 tasks, another has 1), max dependency depth > 4 (consider parallelizing), zero dependency edges across many tasks (suspicious for a real system).

**Pass 2 — Content assertions (LLM judgment).** Eight binary assertions targeting downstream decomposability — what the `@ido4/core` ingestion pipeline and any agent executing these tasks will need.

- **T1** — Task descriptions are code-grounded (reference real file paths, services, or architectural patterns, not vague). **FAIL** when descriptions are pure title restatement; **WARNING** when code-grounding is thin.
- **T2** — Effort estimates are traceable to canvas complexity assessment (S for pattern-follows, M for adapted-pattern, L for new-pattern, XL for architectural). **WARNING** when metadata seems guessed, not grounded.
- **T3** — Risk labels reflect real unknowns (coupling, test coverage, integration surface), not generic "this is hard". **WARNING** on miscalibration.
- **T4** — `ai` suitability calibrated: external integrations shouldn't be `full`, schema work often is, human-only tasks are genuinely human-judgment territory. **WARNING** on pattern mismatches.
- **T5** — Success conditions are code-verifiable (testable, not "works correctly"). **FAIL** on vague conditions; **WARNING** on mixed specific/vague.
- **T6** — Stakeholder attributions preserved from the upstream strategic spec (e.g., "Per Marcus: idempotency key required"). **WARNING** when present upstream but dropped.
- **T7** — No circular cross-capability deps. Minimal cross-capability coordination. **FAIL** on cycles; **WARNING** on excessive cross-deps.
- **T8** — Capability coherence: 2–8 tasks per capability, tasks relate to capability purpose. **WARNING** outside this range.

**Verdict rollup** (mirrors `ido4shape`):
- Any T-assertion at FAIL → **FAIL**
- Only WARNINGs → **PASS WITH WARNINGS**
- All satisfied (and Pass 1 clean after auto-fix) → **PASS**

**Report structure:** Verdict first, What's working paragraph, What needs input (content findings ordered FAIL first), Format issues resolved (if auto-fix applied — one line), Next step, Supporting metrics (last).

**Next step wording** (conditional on verdict and on `.ido4/project-info.json` probe):

- FAIL → *"Run `/ido4specs:refine-spec <path>` to address the errors, then re-run `/ido4specs:validate-spec`."*
- PASS WITH WARNINGS → *"Run `/ido4specs:review-spec <path>` for qualitative review of the warnings, or proceed with caveats."*
- PASS with `.ido4/project-info.json` present → *"Ready for review (`/ido4specs:review-spec <path>`) or direct hand-off to `/ido4dev:ingest-spec <path>`."*
- PASS without the marker file → *"Ready for review (`/ido4specs:review-spec <path>`). To create GitHub issues, install `ido4dev` and run `/ido4dev:onboard` then `/ido4dev:ingest-spec <path>`. Or pipe the file to your own tooling."*

**Do not reference `repair-spec`** — not shipping in Phase 2. When it ships later, the FAIL next-step wording changes to offer repair-spec as the interactive alternative to refine-spec.

### D.2 — `skills/create-spec/SKILL.md`

**Source:** `~/dev-projects/ido4dev/skills/decompose/SKILL.md` (170 lines, 9.7 KB)

**Frontmatter changes:**

```yaml
---
name: create-spec
description: >
  Takes a strategic spec (typically from ido4shape), parses it, detects project
  mode (existing / greenfield-with-context / greenfield-standalone), spawns
  parallel Explore subagents for codebase or integration-target analysis, and
  synthesizes a technical canvas — the intermediate artifact that becomes the
  input to /ido4specs:synthesize-spec. Use when the user has a strategic spec
  and is ready to start technical planning. Pass the strategic-spec path as
  argument: /ido4specs:create-spec path/to/notification-system-strategic-spec.md
allowed-tools: Read, Write, Glob, Grep, Bash
user-invocable: true
---
```

Key vs source:
- `allowed-tools` drops MCP tools, adds `Bash` for the bundled validator CLI call
- `description` updated to reference `ido4shape` upstream and `/ido4specs:synthesize-spec` downstream, and to use the canonical `-strategic-spec.md` filename in the usage example

**Body changes:**

**Stage 0 — Parse the strategic spec (critical rewrite).** Source currently says:

> Your next action MUST be to call `parse_strategic_spec` with the file contents.

Replace with bundled-validator invocation:

```
Run the bundled strategic-spec validator:

  node "${CLAUDE_PLUGIN_DATA}/spec-validator.js" <strategic-spec-path>

Parse the JSON output (same @ido4/spec-format parser that `parse_strategic_spec`
used, different delivery mechanism — an inlined CLI bundle instead of an MCP
tool). Review:

- If there are errors, stop and report them. The strategic spec must be fixed
  before create-spec can proceed.
- If there are warnings, report them but continue.

Present the Stage 0 summary with: project name, capabilities grouped by
ido4shape groups (with count per group), group priorities, dependency structure
summary, number of cross-group dependencies.
```

**Derive spec-name from the strategic spec path using the §5.3 derivation rule.** Strip `.md`, then strip the first matching trailing suffix from the priority list (`-strategic-spec`, `-tech-spec`, `-tech-canvas`, `-spec`). The result is the `{spec-name}` used for all downstream artifact filenames in this pipeline. Do not hard-code any suffix check — cite the rule by reference to §5.3 in the skill body.

**Stage 0.5 — Artifact directory + project mode.** Verbatim from source for discovery logic (four-tier: `specs/` → `docs/specs/` → create `docs/specs/` → create `specs/`) and mode assignment (`existing` → source code present; `greenfield-with-context` → integration targets referenced; `greenfield-standalone` → neither).

**New at the end of Stage 0.5 — path-reporting nudge.** After the artifact directory and project mode are determined, report both the strategic spec path and the work area to the user, and include a co-location hint if the strategic spec is NOT already in the artifact directory:

```
Report to the user:

  Strategic spec: {strategic-spec-path}
  Artifact directory: {artifact-dir} ({existing | created})
  Project mode: {existing | greenfield-with-context | greenfield-standalone}

  Your technical artifacts will land at:
    {artifact-dir}/{spec-name}-tech-canvas.md   (this skill's output)
    {artifact-dir}/{spec-name}-tech-spec.md     (next skill's output)

If the strategic spec's directory is different from {artifact-dir}, append:

  Your strategic spec is outside the work area. If you'd like everything
  co-located under {artifact-dir}/, you can move and rename it for symmetry
  with the technical artifacts:

    mv {strategic-spec-path} {artifact-dir}/{spec-name}-strategic-spec.md

  ido4specs will find it there next time. This is optional — the current path
  is also fine.
```

The nudge is one-time informational. Do not gate any subsequent stage on it. The user may ignore it every invocation.

**Stage 1a — Parallel Explore subagents.** Verbatim. This is the proven inline-execution pattern — sub-300-token briefs, run in a single message with multiple tool uses for true parallelism, return summaries under 2000 words. Do not touch this.

**Stage 1b — Read the strategic spec as raw text.** Verbatim. The WHY (verbatim context preservation) is load-bearing.

**Stage 1c — Synthesize the canvas inline, guided by `agents/code-analyzer.md`.** Verbatim. Update the path reference — agent file is at `agents/code-analyzer.md` in `ido4specs`. The critical guidance stays: *"`agents/code-analyzer.md` is a canvas template and rules reference — read it for the canvas structure, per-capability template, context-preservation rules, and mode-specific guidance. Do NOT spawn it as a subagent; you are the orchestrator AND synthesizer for Stage 1."*

**Canvas output path:** `{artifact-dir}/{spec-name}-tech-canvas.md`. Cite §5.2 (filename scheme). The `-tech-canvas.md` suffix is non-negotiable — no `-canvas.md` fallback.

**Stage 1d — Verify and summarize.** Verbatim. The capability-count match check is load-bearing (caught malformed canvases in round 2 testing). Update path references to use `-tech-canvas.md`.

**End-of-phase message:**

```
✓ Canvas ready at `{artifact-dir}/{spec-name}-tech-canvas.md`. Review it,
  then run `/ido4specs:synthesize-spec {artifact-dir}/{spec-name}-tech-canvas.md`
  when you're ready to produce the technical spec.
```

**Task-tracking language update:** Source says *"create a task list (using `TodoWrite` or your equivalent task-tracking tool)"*. Replace with: *"Use `TaskCreate` at the start of this skill to track stages and `TaskUpdate` to mark progress as you complete each one."*

**Language-pass violations in source:**
- `MUST be to call` in Stage 0 — being rewritten anyway
- `MUST match` in Stage 1d (load-bearing hard check) — downgrade to `must` or keep as rule with explicit WHY
- `Never auto-search` in Behavioral Guardrail — rewrite positive: *"Ask for what's missing — the user knows which spec they want."*

**Body size:** ~170 lines source, target ~180–200 (Stage 0.5 gains the path-reporting nudge).

### D.3 — `skills/synthesize-spec/SKILL.md`

**Source:** `~/dev-projects/ido4dev/skills/decompose-tasks/SKILL.md` (140 lines, 8.9 KB)

**Frontmatter changes:**

```yaml
---
name: synthesize-spec
description: >
  Takes a technical canvas (produced by /ido4specs:create-spec) and produces the
  technical spec artifact — the input to downstream ingestion. Phase 2 of the
  technical-spec pipeline: pure transform, canvas in, spec out. No codebase
  exploration; the canvas is the source of truth. Auto-runs structural
  validation at the end. Use when the user has a canvas file and is ready to
  compose the technical spec. Pass the canvas path as argument:
  /ido4specs:synthesize-spec specs/notification-system-tech-canvas.md
allowed-tools: Read, Write, Glob, Grep, Bash
user-invocable: true
---
```

**Body changes:**

**Stage 0 — validate input.** Verbatim behavior. Canvas file existence check at `$ARGUMENTS`. Derive `{artifact-dir}` as the canvas file's parent directory. Derive `{spec-name}` using the §5.3 derivation rule (strip `.md`, strip trailing `-tech-canvas`). The technical spec will be written to `{artifact-dir}/{spec-name}-tech-spec.md`.

**Stage 1a — read and validate the canvas.** Verbatim.

**Stage 1b — decompose and write the technical spec.** Mostly verbatim, with the canonical path convention from §5.2:

- **Output path:** `{artifact-dir}/{spec-name}-tech-spec.md`. The `-tech-spec.md` suffix is non-negotiable. No `-technical.md` fallback. No `-spec.md` fallback (that would collide with strategic spec naming).
- Everything else in Stage 1b (task decomposition rules, Goldilocks principle, metadata grounding, dependency graph validation) is verbatim from source.

**Stage 1c — verify and summarize.** Verbatim behavior. Update the `grep` counts to read the new `-tech-spec.md` filename.

**Stage 1d — NEW — auto-run structural validation.** Add as the last stage before the End-of-Phase message:

```
Stage 1d — Auto-run structural validation:

Immediately after writing the spec, run the bundled tech-spec validator to
catch structural drift before returning to the user. This is Layer 1 of the
two-layer validation pattern — deterministic, cheap, no LLM involved.

  node "${CLAUDE_PLUGIN_DATA}/tech-spec-validator.js" {spec-path}

Parse the exit code and JSON output:

- Exit 0, no errors → report "Structural validation: PASS (@ido4/tech-spec-format
  {version})" and proceed to the End-of-Phase message.
- Exit 1, structural errors → report the first 3 errors verbatim, suggest
  `/ido4specs:refine-spec {spec-path}` to fix, do NOT claim success.
- Exit 2, usage/IO error → report the issue (bundle not found in
  ${CLAUDE_PLUGIN_DATA}, or file not readable), suggest the user re-trigger
  the SessionStart hook or check the file path.

For deeper error interpretation and content assertions, the user runs
`/ido4specs:validate-spec` separately. synthesize-spec stays focused on the
happy path.
```

**Why inline the validator call instead of invoking `/ido4specs:validate-spec`?** Skills in Claude Code are user-invoked, not programmatically callable from other skills. Inlining the `node` call gives deterministic, fast validation without trying to chain skills. `validate-spec` remains the user's tool for deeper interpretation.

**End-of-phase message:**

```
✓ Technical spec ready at `{artifact-dir}/{spec-name}-tech-spec.md`.
  Structural validation: {PASS | FAILED with N errors}.

  Review it, then run `/ido4specs:review-spec {artifact-dir}/{spec-name}-tech-spec.md`
  for qualitative review, or `/ido4specs:refine-spec {artifact-dir}/{spec-name}-tech-spec.md`
  to edit.
```

**Cross-sell footer** (append after the End-of-Phase message, conditional on Stage 1d verdict):

- If PASS and `.ido4/project-info.json` exists in the workspace:
  > `/ido4dev:ingest-spec {artifact-dir}/{spec-name}-tech-spec.md` is ready when you want to create GitHub issues.
- If PASS and no marker file:
  > To turn this spec into GitHub issues: install `ido4dev` (`/plugin install ido4dev@ido4-plugins`), run `/ido4dev:onboard` to pick a methodology, then `/ido4dev:ingest-spec {artifact-dir}/{spec-name}-tech-spec.md`. Or pipe the file to your own tooling.
- If FAILED: no cross-sell footer.

**Extract the cross-sell footer pattern into `references/cross-sell-footer.md`** and have each skill cite it (rather than duplicate the prose across three skills). Keeps the four conditional cases in one place.

**Language pass:** scan and dial back.

**Body size:** ~150 lines (source 140 + ~15 for Stage 1d).

### D.4 — `skills/review-spec/SKILL.md`

**Source:** `~/dev-projects/ido4dev/skills/decompose-validate/SKILL.md` (180 lines, 9.6 KB)

This is a **slim split**. Take only Stage 1 (structural + quality review via `spec-reviewer` inline). Drop Stages 2 (ingestion preview via MCP) and 3 (actual ingest via MCP) — those stay with `ido4dev` as the new `ingest-spec` skill in Phase 3.

**Frontmatter:**

```yaml
---
name: review-spec
description: >
  Runs a qualitative review of a technical spec artifact — two-stage protocol
  (format compliance then content quality) applied inline via the spec-reviewer
  agent on Sonnet. Returns PASS / PASS WITH WARNINGS / FAIL with structured
  findings. Layer 2 of the two-layer validation pattern — use after
  /ido4specs:validate-spec (Layer 1 — structural) for full coverage. Use when
  the user says "review the spec", "check the quality", "is this ready for
  ingest", "run the reviewer". Pass the spec path as argument:
  /ido4specs:review-spec specs/notification-system-tech-spec.md
allowed-tools: Read, Glob, Grep
user-invocable: true
---
```

No `Bash` — `review-spec` doesn't call the bundled validator. Structural validation is `validate-spec`'s job.

**Input discovery.** Same as `validate-spec`: path argument is primary; if empty, glob `specs/*-tech-spec.md` (and `docs/specs/*-tech-spec.md` as fallback) and ask which to review. Do not auto-pick.

**Body:**

**Stage 0 — validate input.** Verbatim.

**Stage 1 — inline review via spec-reviewer.** Take Stages 1a–1e from source verbatim. Changes:
- Update agent path reference to `agents/spec-reviewer.md` (in `ido4specs`)
- Drop the "Standalone vs Decomposition Phase 3" framing — single invocation context now
- Scan for and remove any `@ido4/mcp` or BRE references
- Scan for methodology leaks — the "governance implications check" section in the source mentions "BRE" and "governance attention"; the ported `spec-reviewer` agent (Stage C.3) already converted this to "downstream awareness" framing. The skill body should match.

**Stages 2 and 3 — DROPPED.** Do not port Stage 2 (`ingest_spec dryRun:true` preview) or Stage 3 (`ingest_spec dryRun:false` ingest). These depend on `@ido4/mcp` and are `ido4dev`'s responsibility post-Phase-3.

**End-of-skill message** — conditional on verdict:

```
Verdict: {PASS | PASS WITH WARNINGS | FAIL}

- FAIL → "Run `/ido4specs:refine-spec {spec-path}` to address the errors, then
  re-run `/ido4specs:review-spec`."
- PASS WITH WARNINGS → "Warnings listed above. Run `/ido4specs:refine-spec`
  to address them, or proceed with the caveats."
- PASS → [cross-sell footer, same conditional pattern as synthesize-spec]
```

**Language pass:** light — source is already fairly neutral.

**Body size:** ~120 lines (shorter than source because Stages 2 and 3 go).

### D.5 — `skills/refine-spec/SKILL.md`

**Source:** No direct `ido4dev` equivalent. Structural reference: `ido4shape/skills/refine-spec/SKILL.md` (54 lines) — specifically the technical-spec half of its dual-mode branch. We read it for shape; we don't edit `ido4shape`.

**Frontmatter:**

```yaml
---
name: refine-spec
description: >
  Edits an existing technical spec artifact using natural-language instructions.
  Handles adding or removing tasks, splitting or merging capabilities, changing
  metadata (effort, risk, type, ai, depends_on), creating technical-only
  capabilities (PLAT-/INFRA-/TECH- prefixes), and fixing structural errors found
  by /ido4specs:validate-spec. Re-validates after each edit pass. Use when the
  user says "add a task", "split this capability", "change the dependency",
  "update effort on X", "remove this", "merge these capabilities", "fix the
  validation errors". Pass the file path as argument:
  /ido4specs:refine-spec specs/notification-system-tech-spec.md
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
user-invocable: true
---
```

**Input discovery.** Primary: explicit path argument. Fallback: glob `specs/*-tech-spec.md` (and `docs/specs/*-tech-spec.md`). Do not operate on a strategic spec — if the input filename or format marker indicates `strategic-spec`, stop and tell the user this skill is for technical specs only, point them at ido4shape for strategic-spec refinement.

**Body structure:**

**Getting started.** Read the target file. Run the bundled validator first to capture the baseline:

```bash
node "${CLAUDE_PLUGIN_DATA}/tech-spec-validator.js" <path>
```

If the baseline already has errors, note them — the user may or may not want to fix them as part of the refinement. Ask.

**Understanding the change.** Before editing, understand what's being changed, why, and what else might ripple. Surface ripples explicitly:

> *"If we split this capability, the three tasks that share prefix `NCO-` will need new prefixes. And `NCO-03`'s dependency on `NCO-01` becomes a cross-capability dependency. Is that what you want?"*

**Types of refinement:**

- **Adding a task.** Determine the capability. Use the next available ref (letter-suffix `NCO-03B` if the parent is `NCO-03`, else next integer). Write a ≥200-char description grounded in real code context (reference file paths or services when possible — the technical spec should stay code-grounded). Add ≥2 code-verifiable success conditions. Set metadata (`effort`, `risk`, `type`, `ai`, `depends_on`). If downstream tasks should depend on the new task, update their `depends_on` lists.

- **Removing a task.** Grep for any `depends_on` references to the target. Warn about orphaned references. Offer to update or remove them.

- **Splitting a capability.** Create two capabilities with new names. Decide the new prefix scheme (often the existing prefix stays with one, and the other gets a new one). Reassign tasks. Update all `depends_on` refs that crossed the old boundary. Each new capability needs its own `size` and `risk` metadata.

- **Merging capabilities.** Choose the surviving prefix. Reassign tasks. Update refs.

- **Changing task metadata.** Effort / risk / type / ai adjustments. Explain impact where applicable (e.g., moving `risk: medium` → `risk: critical` will raise attention downstream; moving `ai: full` → `ai: human` will block auto-start transitions in any governance tooling that consumes the spec).

- **Changing dependencies.** Verify the new target exists in the spec. After the change, check for cycles (the bundled validator catches this on re-validation).

- **Creating a technical-only capability** (shared infrastructure not mapping to a strategic capability). Use a `PLAT-`, `INFRA-`, or `TECH-` prefix. Place it **before** strategic capabilities in the file (it's foundational). Explain in the description why it exists and which strategic capabilities depend on it.

**After each refinement:**

1. Run the bundled validator. If it errors where it didn't before, the edit introduced a structural regression — roll back or fix before continuing.
2. Verify: all task refs unique, all `depends_on` refs valid, no cycles, task prefixes match their parent capability, descriptions still ≥200 chars with substance, stakeholder attributions preserved where present.
3. Explain what changed in one or two sentences. Suggest related changes the user might want.

**Format hard rules** (parser-enforced, low-freedom):

- Task refs use zero-padded 2–3-digit numbers (`NCO-01`, `STOR-03A` — not `NCO-1`).
- Metadata lines use blockquote syntax (`> effort: M | risk: low | type: feature | ai: full`).
- Only `## Capability: <name>` and the project header are valid H2 sections.
- Project header line is `# Project Name — Technical Spec`.
- Format marker line is `> format: tech-spec | version: 1.0`.

Cite the format reference for anything ambiguous: `${CLAUDE_SKILL_DIR}/../../references/technical-spec-format.md` and `${CLAUDE_SKILL_DIR}/../../references/example-technical-spec.md`.

**Language:** written fresh — no `MUST`s or all-caps. Principles with short good/bad examples where helpful.

**Body size:** target 100–130 lines.

### Stage D exit criteria

- All 5 skills exist at `skills/{name}/SKILL.md`
- All 5 have valid frontmatter (`name`, `description`, `allowed-tools`, `user-invocable` where applicable)
- All 5 under 500 lines
- All 5 pass the all-caps grep ceiling
- `create-spec` Stage 0 calls `node dist/spec-validator.js` — NOT `parse_strategic_spec` MCP
- `create-spec` Stage 0.5 emits the path-reporting nudge (co-location hint) when the strategic spec lives outside the artifact directory
- `create-spec` writes the canvas to `{artifact-dir}/{spec-name}-tech-canvas.md` (§5.2) using the derivation rule from §5.3
- `synthesize-spec` has Stage 1d auto-run of `tech-spec-validator.js` after writing
- `synthesize-spec` writes to `{artifact-dir}/{spec-name}-tech-spec.md` — not `-technical.md`, not `-spec.md`
- `validate-spec` wraps the bundled technical-spec validator with intelligent interpretation, two-pass structure
- `validate-spec` discovers inputs by globbing `*-tech-spec.md`
- `review-spec` has single-stage inline review, no ingestion stages; discovers inputs by globbing `*-tech-spec.md`
- `refine-spec` re-validates after each edit pass; refuses to operate on strategic specs (filename or format marker check)
- `grep -En 'mcp__|parse_strategic_spec|ingest_spec|@ido4/mcp' skills/*/SKILL.md` returns nothing
- `grep -En '\bBRE\b|methodology profile|Scrum|Shape-Up|Hydro' skills/*/SKILL.md` returns nothing
- `grep -En 'TodoWrite' skills/*/SKILL.md` returns nothing
- `grep -En 'repair-spec' skills/*/SKILL.md` returns nothing (it doesn't exist yet)
- `grep -En '\-technical\.md|\-canvas\.md[^-]' skills/*/SKILL.md` returns nothing (old naming must be gone — the `[^-]` guard prevents matching `-tech-canvas.md`)

---

## 10. Stage E — Local validation and exit

### E.1 — Run the validation suite

```
cd ~/dev-projects/ido4specs
bash tests/validate-plugin.sh
```

Expected failures on first run and how to fix:

- **Missing frontmatter field** → typo in the SKILL.md YAML, fix
- **Body too long** → prompt-strategy threshold; trim the port rather than splitting into sibling files
- **Example technical spec doesn't parse** → fix the example (not the parser)
- **MCP leak grep hit** → find and remove
- **TodoWrite grep hit** → find and rename to TaskCreate/TaskUpdate
- **All-caps ceiling exceeded** → language pass wasn't aggressive enough; revisit

Iterate until clean.

### E.2 — Manual smoke test

In a fresh shell:

```
claude --plugin-dir ~/dev-projects/ido4specs
```

In the session:

1. Plugin loads cleanly (no red on startup)
2. SessionStart hook executed — verify `${CLAUDE_PLUGIN_DATA}/tech-spec-validator.js` and `${CLAUDE_PLUGIN_DATA}/spec-validator.js` exist
3. Run `/ido4specs:validate-spec references/example-technical-spec.md` — expect **PASS** verdict
4. (Optional) Run `/ido4specs:create-spec` against a known-good strategic spec. A good candidate: copy `ido4shape-enterprise-cloud-spec.md` from `ido4dev/reports/` or any strategic spec the user has lying around, to a scratch directory. Watch for:
   - Stage 0 runs the bundled strategic validator and parses the spec successfully (not a `parse_strategic_spec` MCP call)
   - Stage 1a spawns parallel `Explore` subagents successfully (no hang at 25–30 tool uses — if it hangs, the inline-execution pattern regressed and must be debugged before declaring Phase 2 complete)
   - Stage 1c writes the canvas to the expected path
5. Do **not** run the full pipeline (`create-spec` → `synthesize-spec` → `review-spec` → `validate-spec`). Full-pipeline smoke testing is Phase 5 exit criteria, not Phase 2.

### E.3 — Rewrite top-level docs

**`CLAUDE.md`** — current version says "under construction" and "Phase 2+ pending." Rewrite it as the working plugin's CLAUDE.md:

- Remove "What This Is" → "Current State → Phase 1 complete" framing. Replace with active-plugin framing: *"The `ido4specs` Claude Code plugin — turns a strategic spec into a structurally-validated technical spec on disk. Companion to `ido4shape`; upstream of `ido4dev:ingest-spec`."*
- Keep the **Pipeline** section
- Add a **Skills** section listing the 5 skills with one-line roles
- Add an **Agents** section listing the 3 agents with one-line roles
- **New — add a "Typical layout and filenames" section** that mirrors §5 of this plan:
  ```
  project/
  └── specs/
      ├── notification-system-strategic-spec.md   ← from ido4shape (user-placed)
      ├── notification-system-tech-canvas.md      ← /ido4specs:create-spec output
      └── notification-system-tech-spec.md        ← /ido4specs:synthesize-spec output
  ```
  Followed by: *"ido4specs accepts strategic specs from any path — `specs/` is the recommended default for organizational coherence, but project root, `docs/`, or an absolute path all work. The filename suffixes (`-strategic-spec`, `-tech-canvas`, `-tech-spec`) carry the disambiguation, so co-location is preferred but not required. All ido4specs outputs use the `-tech-*` prefix, making `specs/*-tech-*.md` a clean glob for everything the plugin produced."*
- Keep the **Reference Repositories** section (still accurate, but update tone from "read the plan first" to "reference implementations for packaging")
- Add a **Development** section with test/release/local-load commands, mirroring `ido4shape/CLAUDE.md`
- Keep the **ido4 Suite Coordination** section verbatim (still accurate, and links the canonical prompt-strategy / release-architecture / audit-script docs)
- Keep the **Cowork Compatibility Rules** section but reframe: *"`ido4specs` targets Claude Code, not Cowork, so injection-defense constraints don't apply. However, the craft rules (no XML tags, positive framing over prohibitions, describe intent instead of literal paths) are best practices we inherit from ido4shape's authoring standards."*
- Keep the **Working Style** section

**`README.md`** — current 1.5 KB version is a stub. Update with a short overview: what the plugin does, the pipeline position, install command, five skills, three agents, and a "Getting started" example using `specs/notification-system-strategic-spec.md` → `specs/notification-system-tech-canvas.md` → `specs/notification-system-tech-spec.md`. Target ~100 lines.

**`CHANGELOG.md`** — update the unreleased section with the actual change list.

### E.4 — Phase 2 exit report

Write a short status note (to the conversation, or optionally to `docs/phase-2-completion-record.md` mirroring how extraction-plan.md has a "Completion record" at the top):

- `validate-plugin.sh` result — pass count, any residual warnings, zero FAILs
- Deviations from this execution plan (document why — e.g., "Stage A.5 check 11 relaxed because…")
- Any surfaced issues that should inform Phase 3 (ido4dev slimming)
- Bundle versions committed: `@ido4/tech-spec-format@0.1.0`, `@ido4/spec-format@0.7.2`
- Open questions for the user before Phase 3 starts

### E.5 — Commit

Single commit at Phase 2 exit:

```
feat: extract ido4specs plugin from ido4dev (Phase 2)

Creates the ido4specs plugin scaffold with 5 skills, 3 agents, bundled
strategic and technical spec validators, and packaging adapted from
ido4shape's reference pattern.

Ports decompose / decompose-tasks / decompose-validate from ido4dev with
a language pass per ido4-suite/docs/prompt-strategy.md, and the three
decompose agents (code-analyzer, technical-spec-writer, spec-reviewer).
Skills use inline execution + built-in Explore subagents — the pattern
proved reliable in ido4dev round-3 testing (see
ido4dev/reports/e2e-003-ido4shape-cloud.md OBS-04b).

validate-plugin.sh passes clean locally. Not pushed to a remote —
ido4-dev/ido4specs repo creation is Phase 5.

Phase 3 (ido4dev slimming) and Phase 4 (suite integration) are separate.
See docs/extraction-plan.md and docs/phase-2-execution-plan.md.
```

**Do NOT push to a remote.** The GitHub repo `ido4-dev/ido4specs` doesn't exist yet — that's Phase 5. Phase 2 is strictly local.

---

## 11. Phase 2 gotchas — running list

Watch for these during execution. They're the failure modes that cost time if not caught early.

1. **Stale `parse_strategic_spec` MCP call in `code-analyzer.md` Step 1.** The round-3 inline-execution rewrite moved this call from the agent to the skill's Stage 0. The agent file body may still say "call parse_strategic_spec". Verify and rewrite.

2. **`technical-spec-sample.md` fixture drift.** The monorepo's CI smoke test uses this fixture. If the parser has made any breaking changes since, the fixture may not parse. Test with `node dist/tech-spec-validator.js` before committing. Fix the fixture if it drifted, not the parser.

3. **Version-marker-file format.** `ido4shape/dist/.spec-format-version` is just the version string (`0.7.2`). Check exact newline behavior and mirror it — `validate-plugin.sh` version checks are sensitive to trailing newlines.

4. **Filename invariant — §5 is the single source of truth.** The canonical filenames are `{name}-strategic-spec.md` (strategic), `{name}-tech-canvas.md` (technical canvas), `{name}-tech-spec.md` (technical spec). The `ido4dev` source writes `-canvas.md` and `-technical.md` — both are stale. Every ported skill must update its paths to the `-tech-*` variants. `grep -En '\-technical\.md|\-canvas\.md[^-]' skills/*/SKILL.md agents/*.md` should return nothing after the port (the `[^-]` guard prevents false positives on `-tech-canvas.md`). And the all-ido4specs-outputs glob `specs/*-tech-*.md` is non-overlapping with ido4shape's `*-spec.md` by construction — do not introduce any filename that breaks this property.

5. **`TaskCreate` vs `TodoWrite`.** `ido4dev` skill sources say `TodoWrite`. Current Claude Code uses `TaskCreate`/`TaskUpdate`. Global substitution during the port.

6. **Subagent-hang reintroduction.** `ido4dev`'s decompose skills explicitly say: *"`agents/code-analyzer.md` is a canvas template and rules reference — Do NOT spawn it as a subagent."* This language must survive the port. If any reviewer "cleans up" the skill to use `Agent` tool delegation, the pipeline hangs at 25–30 tool uses.

7. **`@ido4/mcp` SessionStart hook leak.** `ido4dev` has a hook that installs `@ido4/mcp` via npm at session start. `ido4specs` has NO such hook. If any ported skill references MCP startup, it's stale.

8. **Cross-sell footer drift.** The `.ido4/project-info.json` probe and the two message variants must be identical across `synthesize-spec`, `review-spec`, and `validate-spec`. Put the footer logic in `references/cross-sell-footer.md` once, cite from each skill.

9. **`references/example-technical-spec.md` as round-trip test.** This file has to parse clean under `dist/tech-spec-validator.js`. If it doesn't, every `validate-plugin.sh` run fails. Keep it minimal and well-tested.

10. **Scope creep: do not edit `ido4shape`.** Even the "easy 5-minute refine-spec cleanup." Even the stale dual-mode branch. `ido4shape` is in production, tested, not in this scope. Note anything interesting for a future session and move on.

11. **Methodology leaks.** Scan every ported file for `Scrum`, `Shape-Up`, `Hydro`, `BRE`, `methodology profile`, `container-bound`, `epic`, `bet` (where it implies methodology containers — `bet` is a valid word in normal English). `ido4specs` is methodology-neutral. The `references/technical-spec-format.md` may mention methodology as downstream context; nothing else should.

12. **Agent `tools:` field stripping.** The `code-analyzer.md` source has `tools: Read, Write, Glob, Grep, mcp`. The `mcp` value needs to come out. Verify with a grep.

13. **Spec-name derivation — use §5.3 unchanged everywhere.** Any skill that derives a spec-name from a path must apply the full four-suffix priority list (`-strategic-spec`, `-tech-spec`, `-tech-canvas`, `-spec` fallback). Do not implement ad-hoc trimming in individual skills — cite §5.3. Inconsistent derivation across skills is a class of bug that breaks the "same name → same files" invariant.

14. **Strategic spec rename is user action, not tool action.** `ido4specs` never moves or renames files. The Stage 0.5 nudge in `create-spec` is informational only. If any ported skill includes a `mv`, `Edit`, or `Write` against the strategic spec's path, it's a bug.

---

## 12. What's deferred to later phases

- **`repair-spec` skill** — after Phase 2, once real failure data shows what we're building against
- **`ido4dev` slimming** (delete decompose skills, rename decompose-validate → ingest-spec) — Phase 3
- **`ido4/architecture/spec-artifact-format.md` removal from the monorepo** — Phase 4, bundled with `interface-contracts.md` contract #6 addition
- **`interface-contracts.md` contract #6** — Phase 4
- **`cross-repo-connections.md` dispatch entry** — Phase 4
- **`suite.yml` tier-1 entry for `ido4specs`** — Phase 4
- **`@ido4/tech-spec-format` npm release** — Phase 5
- **`ido4-dev/ido4specs` GitHub repo creation** — Phase 5
- **Marketplace registration + `IDO4SPECS_DISPATCH_TOKEN` secret** — Phase 5
- **Full-pipeline end-to-end smoke test against a real strategic spec** — Phase 5
- **`ido4shape` refine-spec stale dual-mode branch cleanup** — out of scope entirely
- **Phase 2 `sync-marketplace.yml` enabling** — commented-out until Phase 5, then uncomment
- **`ido4dev:ingest-spec` default glob** — Phase 3: when `ingest-spec` is invoked without arguments, default to globbing `specs/*-tech-spec.md` (and `docs/specs/*-tech-spec.md`). Mirrors the pattern `ido4shape` uses for `*-spec.md` discovery. Small UX win that completes the file-convention story across the three plugins.

---

## 13. Phase 2 exit criteria (tight form)

1. `bash tests/validate-plugin.sh` → all PASS, zero FAIL
2. `node dist/tech-spec-validator.js references/example-technical-spec.md` → exit 0
3. `node dist/spec-validator.js <a known-good strategic spec>` → exit 0
4. All 5 skills load in `claude --plugin-dir .` without errors
5. `/ido4specs:validate-spec references/example-technical-spec.md` returns PASS in a live session
6. (Optional) `/ido4specs:create-spec` against a known-good strategic spec completes Stage 0 and enters Stage 1 without hanging
7. `CLAUDE.md` reflects the shipped state (not "under construction")
8. Single Phase 2 commit on local `main` (not pushed)
9. No plugin file references `mcp__`, `parse_strategic_spec`, `ingest_spec`, `@ido4/mcp`, the BRE, or a methodology profile
10. No plugin file references `TodoWrite`
11. No plugin file references `repair-spec`
12. All-caps directive count across the plugin is under 10 (each retained instance load-bearing and documented)

When all 12 clear, Phase 2 is done. Phase 3 can begin.

---

## 14. Time budget (rough)

Not a commitment, a sanity check — if any stage is 3× its estimate, pause and investigate.

| Stage | Estimate | Notes |
|---|---|---|
| A — Scaffolding | 60–90 min | validate-plugin.sh adaptation is the slowest item |
| B — References | 10–15 min | Mostly file copying + round-trip test |
| C — Agents (3) | 60–90 min | Language pass is creative; code-analyzer is the biggest item |
| D — Skills (5) | 120–180 min | validate-spec and refine-spec are the most novel |
| E — Validation + docs | 30–60 min | Mostly running the suite, fixing, iterating |
| **Total** | **~5–7 hours** | Single focused session |

---

## 15. One-liner before you start

> `ido4dev` is the content, `ido4shape` is the packaging, `prompt-strategy.md` is the language, the round-3 inline-execution pattern is the architecture, the bundled parser is the seam, and methodology neutrality is the discipline. Keep all six straight and Phase 2 lands clean.
