# Security & Data Handling

## What ido4specs Creates

`ido4specs` reads a strategic spec, analyzes your codebase, and produces two markdown artifacts in your project's `specs/` directory (or `docs/specs/` if the project uses that convention):

```
specs/
├── {name}-tech-canvas.md     # Intermediate canvas — code-to-capability mapping
└── {name}-tech-spec.md       # Final technical spec — ingestion-ready
```

No workspace directories, no hidden state files, no databases, no binary formats. Everything the plugin produces is plain-text markdown under your project root, committable to git if you want version history for your specs.

## Data Locality

**All data stays on your local machine.** The plugin makes no network requests, connects to no external services, and sends no telemetry. The only data that leaves your machine is what Claude processes through the standard Anthropic API — the same as any Claude conversation.

## Bundled Validators

The plugin ships two zero-dependency parser bundles in `dist/`:

| Bundle | Purpose | Source |
|---|---|---|
| `tech-spec-validator.js` (~15 KB) | Parses and validates technical specs produced by this plugin | [@ido4/tech-spec-format](https://github.com/ido4-dev/ido4/tree/main/packages/tech-spec-format) |
| `spec-validator.js` (~9 KB) | Parses strategic specs at the start of `/ido4specs:create-spec` | [@ido4/spec-format](https://github.com/ido4-dev/ido4/tree/main/packages/spec-format) |

Both bundles:

- Run via Node.js, read a single file, output JSON to stdout
- Make no network requests
- Have zero npm dependencies
- Have SHA-256 checksums recorded in `dist/.tech-spec-format-checksum` and `dist/.spec-format-checksum`
- Have version markers in `dist/.tech-spec-format-version` and `dist/.spec-format-version`

The `SessionStart` hook runs three commands:

1. Copies `dist/tech-spec-validator.js` → `${CLAUDE_PLUGIN_DATA}/tech-spec-validator.js`
2. Copies `dist/spec-validator.js` → `${CLAUDE_PLUGIN_DATA}/spec-validator.js`
3. Runs `scripts/session-status.sh` — a read-only script that scans for existing `*-tech-canvas.md`, `*-tech-spec.md`, and `*-strategic-spec.md` artifacts in the project and outputs a one-line contextual status when artifacts are present. When no artifacts are present, it emits a one-time first-install greeting (writing a marker file at `${CLAUDE_PLUGIN_DATA}/welcomed-{shasum-of-cwd}` so the greeting never repeats for that project) and stays silent on subsequent sessions. The output (when present) is injected into the model's context so the first response is contextual. The script reads only filenames (via `ls` globbing) — it never reads file contents, makes network requests, or modifies any files outside of the plugin's own `${CLAUDE_PLUGIN_DATA}` directory.

The plugin also bundles `scripts/statusline.sh` as an **opt-in** status line script (not active by default — see README "Optional: enable the status line"). When a user wires it into their own `~/.claude/settings.json`, it performs the same read-only artifact scan as `session-status.sh` and prints a single line (e.g., `ido4specs · spec ✓ {name}`), or nothing when no artifacts are present. No file contents are read, no network requests, no modifications. The plugin does not ship a `statusLine` default in its own `settings.json`.

No `PreToolUse`, `Stop`, `PreCompact`, or `UserPromptSubmit` hooks — `ido4specs` is a transform pipeline, not a dialogue tool, and has no runtime state to inject or check beyond the session-start scan.

## Sub-Agents

`ido4specs` uses sub-agents sparingly and only for context-isolated work:

| Skill | Sub-agents | Type | Tools | Model |
|---|---|---|---|---|
| `create-spec` | Codebase/integration-target exploration | Built-in `Explore` | n/a | inherited |

The three plugin-defined agents (`code-analyzer`, `technical-spec-writer`, `spec-reviewer`) are **read inline** as template and rules references by the skills that use them — they are not spawned as subagents. This pattern avoids a known Claude Code constraint where plugin-defined subagents hang at ~25–30 tool uses (documented in `ido4dev/reports/e2e-003-ido4shape-cloud.md`). Built-in `Explore` subagents remain reliable and are used only for scoped codebase analysis.

No plugin-defined agent has `Bash` access. No agent has network-capable tools (`WebFetch`, `WebSearch`). Tool permissions are declared in each agent's frontmatter.

## Runtime Coupling

`ido4specs` has **no runtime dependency** on any other plugin. Specifically:

- No MCP server (neither installs nor consumes one)
- No dependency on `@ido4/mcp`, `ido4dev`, or any downstream ingestion tool
- No call into `ingest_spec` or any other MCP tool
- No knowledge of methodology profiles or governance engines

The only cross-plugin signal is a read-only filesystem probe for `.ido4/project-info.json` at the end of `synthesize-spec` / `review-spec` / `validate-spec` — used solely to tailor the end-of-flow message (suggesting `/ido4dev:ingest-spec` if the marker exists, or the install instructions otherwise). The probe is informational, not functional.

## Cleanup

To remove `ido4specs` artifacts from a project:

```bash
rm -rf specs/
# or just the technical ones if strategic specs share the directory:
rm specs/*-tech-canvas.md specs/*-tech-spec.md
```

There is no other persistence. The plugin does not write to global directories, registries, or configuration files beyond the session-scoped `${CLAUDE_PLUGIN_DATA}` directory managed by Claude Code itself.

## Recommendations

- Commit `specs/` to git if you want version history for your technical specs (recommended — the `.md` files are human-readable and diff cleanly)
- Be mindful of sensitive information in spec content — spec text is processed through the Claude API under [Anthropic's data policies](https://www.anthropic.com/policies)
- Both bundled validators can be updated via `scripts/update-tech-spec-validator.sh <version>` and `scripts/update-spec-validator.sh <version>`. Checksums change on update.
