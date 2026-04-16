# Contributing to ido4specs

## Quick start

```bash
# Load the plugin locally for testing
claude --plugin-dir /path/to/this/repo

# Run the validation suite (should pass before any commit)
bash tests/validate-plugin.sh

# After making skill or agent changes in a live session
/reload-plugins
```

## What to change where

| I want to... | Edit this |
|---|---|
| Change how a pipeline phase works | `skills/{name}/SKILL.md` |
| Change how an agent reasons about its task | `agents/{name}.md` |
| Change what the SessionStart hook does | `hooks/hooks.json` + `scripts/session-status.sh` |
| Update the bundled tech-spec validator | `scripts/update-tech-spec-validator.sh <version>` |
| Update the bundled strategic-spec validator | `scripts/update-spec-validator.sh <version>` |
| Add a new validation check | `tests/validate-plugin.sh` |
| Change the release process | `scripts/release.sh` |

## Authoring constraints

Read `~/dev-projects/ido4-suite/docs/prompt-strategy.md` before editing skills or agents. Key rules:

- **Skills under 500 lines, agents under 300 lines.** Use progressive disclosure (sibling reference files) if you're approaching the limit.
- **No all-caps directive language** (`MUST`, `NEVER`, `ALWAYS`, `IMPORTANT`, `CRITICAL`). Use principles with WHYs instead. The `validate-plugin.sh` Test 9 enforces a ceiling of 10 retained instances across the whole plugin.
- **No XML tags in skill bodies.** Use markdown headers.
- **No MCP tool calls.** ido4specs has zero runtime coupling to `@ido4/mcp`. Use the bundled validators via `node "${CLAUDE_PLUGIN_DATA}/..."`. The `validate-plugin.sh` Test 10 greps for MCP leaks.
- **No methodology references.** No Scrum, Shape-Up, Hydro, BRE. The `validate-plugin.sh` Test 11 greps for methodology leaks.
- **Agents are read inline, not spawned as subagents.** Plugin-defined subagents hang at ~25–30 tool uses in Claude Code. Skills read agent `.md` files as template/rules references with full conversation context. Only built-in `Explore` subagents are spawned.
- **Filename conventions:** outputs use `-tech-canvas.md` and `-tech-spec.md`. Never `-canvas.md` or `-technical.md`. The `validate-plugin.sh` Test 12 enforces this.
- **Task tracking:** use `TaskCreate` / `TaskUpdate`, not `TodoWrite`.

## Testing changes

`validate-plugin.sh` has 14 test groups covering structure, validators, skills, agents, hooks, references, language hygiene, MCP coupling, methodology neutrality, filename conventions, shell quality, and `claude plugin validate`. Run it before every commit.

For behavioral testing (does the skill actually do the right thing when invoked?), follow the E2E Testing Protocol in `CLAUDE.md` — two sessions in parallel, structured observations, report in `reports/`.

## Releasing

```bash
bash scripts/release.sh [--dry-run] [patch|minor|major] "Release message"
```

The release script runs `validate-plugin.sh` as pre-flight. If it fails, the release aborts. CI (`sync-marketplace.yml`) automatically syncs to the `ido4-plugins` marketplace after a successful push.

## Questions?

Open an issue at [github.com/ido4-dev/ido4specs](https://github.com/ido4-dev/ido4specs/issues).
