---
name: help
description: >
  Explains what ido4specs does, what skills are available, how the pipeline works,
  and how to get started. Activates when the user asks "what does ido4specs do",
  "how do I use this plugin", "what skills are available", "help with ido4specs",
  "what can this plugin do", "where do I start", "I just installed ido4specs",
  or when the user seems confused about the plugin's purpose or workflow.
user-invocable: false
---

## What ido4specs does

**The bridge between "what to build" and "GitHub issues."** `ido4specs` takes a strategic spec — yours or one produced by `ido4shape` — analyzes your codebase, and decomposes capabilities into implementation tasks with effort, risk, type, and dependency metadata. The result is a methodology-neutral `.md` file that any downstream tool (or `/ido4dev:ingest-spec`) can turn into GitHub issues. Built for tech leads and staff engineers who want to skip the manual decomposition tax.

## The pipeline

```
Strategic spec (.md)
       ↓
/ido4specs:create-spec       → technical canvas (codebase analysis + strategic context)
       ↓
/ido4specs:synthesize-spec   → technical spec (tasks with effort/risk/type/ai metadata)
       ↓
/ido4specs:validate-spec     → structural + content quality check
/ido4specs:review-spec       → independent qualitative review
       ↓
/ido4specs:refine-spec       → edit the spec with natural-language instructions
       ↓
Hand off to /ido4dev:ingest-spec or your own tooling → GitHub issues
```

## Skills at a glance

| Skill | What it does | When to use |
|---|---|---|
| **create-spec** | Strategic spec + codebase → technical canvas | You have a strategic spec and want to start planning |
| **synthesize-spec** | Canvas → technical spec with task metadata | Canvas is reviewed and ready to become tasks |
| **validate-spec** | Structural parser check + 8 content assertions | Quick verification: is the spec well-formed and fit for ingestion? |
| **review-spec** | Qualitative review via spec-reviewer protocol | Deeper independent review after structural validation |
| **refine-spec** | Edit the spec via natural language | Fix validation findings, add/remove tasks, change metadata |
| **doctor** | Plugin health diagnostics | Something's not working — check validators, versions, checksums |

## Getting started

1. **Place your strategic spec** in the project. The recommended location is `specs/` with the name `{project}-strategic-spec.md`, but any path works.

2. **Run create-spec:**
   ```
   /ido4specs:create-spec path/to/your-strategic-spec.md
   ```
   This parses the strategic spec, explores your codebase (or integration targets for greenfield projects), and produces a technical canvas. Takes 10–25 minutes for large specs (25+ capabilities), 3–10 minutes for smaller ones.

3. **Review the canvas**, then run synthesize-spec:
   ```
   /ido4specs:synthesize-spec specs/your-project-tech-canvas.md
   ```

4. **Validate and review** the technical spec:
   ```
   /ido4specs:validate-spec specs/your-project-tech-spec.md
   /ido4specs:review-spec specs/your-project-tech-spec.md
   ```

5. **Fix any findings:**
   ```
   /ido4specs:refine-spec specs/your-project-tech-spec.md
   ```

## File naming

All ido4specs outputs use the `-tech-` prefix for clean disambiguation:

- `{name}-strategic-spec.md` — your strategic spec (user-placed, recommended naming)
- `{name}-tech-canvas.md` — intermediate canvas (create-spec output)
- `{name}-tech-spec.md` — final technical spec (synthesize-spec output)

`specs/*-tech-*.md` is a clean glob for everything ido4specs produced.

## Don't have a strategic spec?

If you don't have ido4shape, you can write a strategic spec by hand. It needs:
- A `> format: strategic-spec | version: 1.0` marker after the project heading
- `## Group:` sections with `### PREFIX-NN:` capabilities
- Priority, risk, and depends_on metadata

Try the included example:
```
/ido4specs:create-spec ${CLAUDE_PLUGIN_ROOT}/references/example-strategic-spec.md
```

Or install ido4shape to author strategic specs through guided conversation.

## Need help?

- Run `/ido4specs:doctor` to check plugin health
- See `references/technical-spec-format.md` for the format reference
- See `references/example-technical-spec.md` for a complete parseable example
