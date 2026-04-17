# ido4specs

**The bridge between a strategic spec and GitHub issues.**

`ido4specs` is a Claude Code plugin that takes a strategic spec — yours or one produced by [ido4shape](https://github.com/ido4-dev/ido4shape) — analyzes your codebase, and produces a structurally-validated technical spec: code-grounded task decomposition with effort, risk, type, and dependency metadata. Methodology-neutral. Any downstream tool — or `/ido4dev:ingest-spec` — can turn the file into GitHub issues.

**Built for** tech leads, staff engineers, and founder-engineers who plan implementation work from high-level specs and want to skip the manual decomposition tax.

Part of the [ido4 ecosystem](https://github.com/ido4-dev/ido4).

## What you get

A technical spec like this — every task grounded in your actual code, every metadata field calibrated against codebase reality, every dependency edge traced through the parser:

```markdown
## Capability: Context Assembly
> size: L | risk: medium

Core logic for assembling a context bundle at task start.

### CAS-01: Upstream Decision Fetcher
> effort: M | risk: low | type: feature | ai: full
> depends_on: -

Fetch decisions from parent issues and upstream capabilities relative to the
current task. Pulls from GitHub issue bodies and comments, filters for
structured decision markers.

**Success conditions:**
- Returns all decisions from the dependency chain above the task
- Handles missing upstream gracefully (returns empty array, not error)
```

`effort` says how big it is. `risk` says how easily it goes wrong. `type` separates feature work from infrastructure. `ai` says whether to hand it to a coding agent (`full`), pair on it (`pair`), or do it yourself (`human`). `depends_on` builds the dependency graph the parser uses to compute critical path. **Every field has a semantic the bundled validator enforces.**

See [`references/example-technical-spec.md`](references/example-technical-spec.md) for a complete parseable example.

## Pipeline

```
strategic spec (ido4shape or hand-written)
       ↓
/ido4specs:create-spec       → technical canvas (code analysis + strategic context)
       ↓
/ido4specs:synthesize-spec   → technical spec (methodology-neutral)
       ↓
/ido4specs:review-spec       → qualitative review (Sonnet-driven, structured report)
/ido4specs:validate-spec     → structural validation (bundled parser, deterministic)
       ↓
(handoff to /ido4dev:ingest-spec or any downstream tool)
       ↓
GitHub issues
```

`/ido4specs:refine-spec` handles iterative edits to an existing technical spec, with structural re-validation after every edit pass.

## Quick start

Place your strategic spec in your project's `specs/` directory (any path works):

```
project/
└── specs/
    └── notification-system-strategic-spec.md
```

Then run the pipeline:

```
/ido4specs:create-spec specs/notification-system-strategic-spec.md
  → writes specs/notification-system-tech-canvas.md

/ido4specs:synthesize-spec specs/notification-system-tech-canvas.md
  → writes specs/notification-system-tech-spec.md
  → auto-runs structural validation

/ido4specs:review-spec specs/notification-system-tech-spec.md
  → qualitative review with structured Spec Review Report
```

Filename suffixes carry the disambiguation: `-strategic-spec.md` for the input, `-tech-canvas.md` for the intermediate, `-tech-spec.md` for the final artifact. `specs/*-tech-*.md` is a clean glob for everything `ido4specs` produced.

### Don't have a strategic spec?

Write one by hand (it needs a `> format: strategic-spec | version: 1.0` marker), or try the bundled example to see the pipeline run end-to-end:

```
/ido4specs:create-spec references/example-strategic-spec.md
```

### Expected duration and compute

The pipeline uses Opus-level compute for inline synthesis. As long as the progress indicator's token count is moving, synthesis is proceeding normally.

| Spec size | create-spec | synthesize-spec | Total |
|---|---|---|---|
| Small (5–10 capabilities) | 3–10 min | 3–10 min | ~10–20 min |
| Large (25+ capabilities) | 10–25 min | 10–20 min | ~25–40 min |

`validate-spec`, `review-spec`, and `refine-spec` are much faster (1–5 minutes each).

<!-- BEGIN SKILL INVENTORY -->
## Skills

### Commands

| Skill | Description |
|-------|-------------|
| `/ido4specs:create-spec` | Phase 1 — strategic spec + codebase → technical canvas. |
| `/ido4specs:doctor` | Diagnostic checks for the ido4specs plugin. |
| `/ido4specs:refine-spec` | Edits an existing technical spec artifact using natural-language instructions. |
| `/ido4specs:review-spec` | Runs a qualitative review of a technical spec artifact — two-stage protocol (format compliance then content quality) ... |
| `/ido4specs:synthesize-spec` | Phase 2 — technical canvas → technical spec artifact. |
| `/ido4specs:validate-spec` | Validates a technical spec artifact for format compliance and content quality. |

### Auto-triggered skills

These activate automatically during conversation when relevant — you don't invoke them directly.

| Skill | Description |
|-------|-------------|
| `help` | Explains what ido4specs does, what skills are available, how the pipeline works, and how to get started. |
<!-- END SKILL INVENTORY -->

## Visible signals

`ido4specs` is **polite by default** — silent in projects that don't use it, informative when they do.

**SessionStart context** (injected into Claude's awareness; surfaces in the first reply):

- Project has artifacts → Claude opens with the right next-step suggestion (`validate-spec`, `synthesize-spec`, etc.)
- First session in a project with no artifacts → one-time greeting (version, getting-started hint, link to the example spec). Marker file at `${CLAUDE_PLUGIN_DATA}/welcomed-{hash}` prevents repeat.
- Subsequent sessions in irrelevant projects → silent.

### Optional: enable the status line

`ido4specs` ships `scripts/statusline.sh` for users who want a project-state-aware indicator at the bottom of the Claude Code UI. Not enabled by default (Claude Code's plugin `settings.json` does not yet support shipping a `statusLine` directly). To opt in, add to `~/.claude/settings.json` (replace the path with your install location — run `/ido4specs:doctor` to get the exact path):

```jsonc
{
  "statusLine": {
    "type": "command",
    "command": "/absolute/path/to/ido4specs/scripts/statusline.sh",
    "padding": 1
  }
}
```

Output examples:

| Project state | Status line |
|---|---|
| Tech spec ready | `ido4specs · spec ✓ {name}` |
| Canvas ready, no spec | `ido4specs · synth {name}` |
| Strategic spec only | `ido4specs · plan {name}` |
| No artifacts | *(silent — your previous status line falls through)* |

### Disable the plugin

To disable `ido4specs` entirely for a specific project (or globally), add to `.claude/settings.json` (or `~/.claude/settings.json`):

```jsonc
{
  "enabledPlugins": {
    "ido4specs@ido4-plugins": false
  }
}
```

## How it works

`ido4specs` ships two zero-dependency parser bundles that do the structural validation work:

- **`dist/tech-spec-validator.js`** — `@ido4/tech-spec-format`, ~15 KB. Validates technical specs at synthesis time and on every refine-spec edit.
- **`dist/spec-validator.js`** — `@ido4/spec-format`, ~9 KB. Parses upstream strategic specs at the start of `create-spec`.

Both are committed to git, version-marked, checksummed, and copied to `${CLAUDE_PLUGIN_DATA}` by the `SessionStart` hook so skills can invoke them deterministically. **No npm install at session start. No MCP server runtime dependency.** The parsers are the architectural seam between the AI synthesis layer and the downstream tooling — they make the technical spec a structurally validated artifact, not just a Markdown file.

This **parser-as-seam** pattern is what lets the technical spec be methodology-neutral: any downstream tool that can read the format can consume it. Today that includes `/ido4dev:ingest-spec` (which turns it into GitHub issues) and your own tooling. Tomorrow it can include anything else built against the [`@ido4/tech-spec-format`](https://github.com/ido4-dev/ido4) reference.

## Resources

**For users:**

- [`references/example-strategic-spec.md`](references/example-strategic-spec.md) — minimal parseable strategic-spec example (try it: `/ido4specs:create-spec references/example-strategic-spec.md`)
- [`references/example-technical-spec.md`](references/example-technical-spec.md) — minimal parseable technical-spec example
- [`references/technical-spec-format.md`](references/technical-spec-format.md) — canonical format reference
- [`SECURITY.md`](SECURITY.md) — what the plugin reads, what it writes, where data lives, hook surface
- [`PRIVACY.md`](PRIVACY.md) — privacy policy: no telemetry, no analytics, no network calls, no data collection

**For contributors:**

- [`CONTRIBUTING.md`](CONTRIBUTING.md) — how to modify skills, run tests, release
- [`CLAUDE.md`](CLAUDE.md) — development context for working in this repo

## License

MIT — see [LICENSE](LICENSE).
