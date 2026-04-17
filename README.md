# ido4specs

A Claude Code plugin that turns a strategic spec into a structurally-validated technical spec on disk. Companion to [ido4shape](https://github.com/ido4-dev/ido4shape) for engineers planning implementation work, part of the [ido4 ecosystem](https://github.com/ido4-dev/ido4).

Methodology-neutral. Zero runtime dependency on an MCP server. Bundles the `@ido4/tech-spec-format` and `@ido4/spec-format` CLIs as zero-dependency parsers for deterministic structural validation at both ends of the pipeline.

## Pipeline

```
strategic spec (ido4shape)
       ↓
/ido4specs:create-spec       → technical canvas (code analysis + strategic context)
       ↓
/ido4specs:synthesize-spec   → technical spec .md (methodology-neutral)
       ↓
/ido4specs:review-spec       → qualitative review (spec-reviewer agent on Sonnet)
/ido4specs:validate-spec     → structural validation (bundled parser)
       ↓
(handoff to /ido4dev:ingest-spec or any downstream tool for GitHub issue creation)
```

`/ido4specs:refine-spec` handles iterative edits to an existing technical spec, with structural re-validation after every edit pass.

<!-- BEGIN SKILL INVENTORY -->
## Skills

### Commands

| Skill | Description |
|-------|-------------|
| `/ido4specs:create-spec` | Phase 1 of the technical-spec pipeline. |
| `/ido4specs:doctor` | Diagnostic checks for the ido4specs plugin. |
| `/ido4specs:refine-spec` | Edits an existing technical spec artifact using natural-language instructions. |
| `/ido4specs:review-spec` | Runs a qualitative review of a technical spec artifact — two-stage protocol (format compliance then content quality) ... |
| `/ido4specs:synthesize-spec` | Phase 2 of the technical-spec pipeline. |
| `/ido4specs:validate-spec` | Validates a technical spec artifact for format compliance and content quality. |

### Auto-triggered skills

These activate automatically during conversation when relevant — you don't invoke them directly.

| Skill | Description |
|-------|-------------|
| `help` | Explains what ido4specs does, what skills are available, how the pipeline works, and how to get started. |
<!-- END SKILL INVENTORY -->

## Getting started

After installing the plugin, place your strategic spec in your project's `specs/` directory (or wherever you prefer — `ido4specs` accepts any path):

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
  → qualitative review verdict

/ido4specs:validate-spec specs/notification-system-tech-spec.md
  → structural + content assertions

# Then hand off to your downstream tool of choice:
/ido4dev:ingest-spec specs/notification-system-tech-spec.md
  → creates GitHub issues
```

At each step, the filename tells you which artifact you're looking at: `-strategic-spec.md` for strategic, `-tech-canvas.md` for the intermediate canvas, `-tech-spec.md` for the final technical spec. `specs/*-tech-*.md` is a clean glob for everything `ido4specs` produced.

### Don't have a strategic spec?

If you don't have ido4shape, you can write a strategic spec by hand (it needs a `> format: strategic-spec | version: 1.0` marker). Or try the built-in example:

```
/ido4specs:create-spec references/example-strategic-spec.md
```

### Expected duration and compute

The full pipeline (`create-spec` + `synthesize-spec`) uses Opus-level compute for inline synthesis:

| Spec size | create-spec | synthesize-spec | Total |
|---|---|---|---|
| Small (5–10 capabilities) | 3–10 min | 3–10 min | ~10–20 min |
| Large (25+ capabilities) | 10–25 min | 10–20 min | ~25–40 min |

`validate-spec`, `review-spec`, and `refine-spec` are much faster (1–5 minutes each). The progress indicator shows active token generation during long operations — as long as it's moving, synthesis is proceeding normally.

## Visible signals

`ido4specs` is **polite by default** — it stays out of the way in projects that don't use it, and surfaces relevant guidance when they do.

**SessionStart context** (injected into Claude's awareness; surfaces in the first reply):

- Project has artifacts → Claude opens with the right next-step suggestion (`validate-spec`, `synthesize-spec`, etc.)
- First session in a project with no artifacts → one-time greeting (version, getting-started hint, link to the example spec). Marker file at `${CLAUDE_PLUGIN_DATA}/welcomed-{hash}` prevents repeat.
- Subsequent sessions in irrelevant projects → silent.

### Optional: enable the status line

`ido4specs` ships `scripts/statusline.sh` for users who want a project-state-aware status line at the bottom of the Claude Code UI. It is **not enabled by default** because Claude Code does not yet support shipping a `statusLine` from a plugin's `settings.json` (only `subagentStatusLine` and `agent` keys are supported there, and `${CLAUDE_PLUGIN_ROOT}` does not expand in `settings.json`). To opt in, add the following to `~/.claude/settings.json` (replace the absolute path with your install location):

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

## Bundled validators

`ido4specs` ships two zero-dependency parser bundles:

- **`dist/tech-spec-validator.js`** — `@ido4/tech-spec-format`, ~15 KB. Validates technical specs.
- **`dist/spec-validator.js`** — `@ido4/spec-format`, ~9 KB. Parses upstream strategic specs at the start of `create-spec`.

Both are committed to git, version-marked, checksummed, and copied to `${CLAUDE_PLUGIN_DATA}` by the `SessionStart` hook so skills can invoke them deterministically. No npm install at session start.

## Documentation

- [`docs/extraction-plan.md`](docs/extraction-plan.md) — full plan for extracting ido4specs from `ido4dev`
- [`docs/phase-2-execution-plan.md`](docs/phase-2-execution-plan.md) — concrete porting plan for the plugin scaffold
- [`references/technical-spec-format.md`](references/technical-spec-format.md) — canonical format reference for the technical spec
- [`references/example-technical-spec.md`](references/example-technical-spec.md) — minimal parseable technical-spec example
- [`references/example-strategic-spec.md`](references/example-strategic-spec.md) — minimal parseable strategic-spec example (try it with `create-spec`)
- [`SECURITY.md`](SECURITY.md) — what the plugin creates, where data lives, hook surface
- [`CLAUDE.md`](CLAUDE.md) — development context for working in this repo
- [`CONTRIBUTING.md`](CONTRIBUTING.md) — how to modify skills, run tests, release

## License

MIT — see [LICENSE](LICENSE).
