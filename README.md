# ido4specs

Claude Code plugin for authoring technical specs from strategic specs, part of the [ido4 ecosystem](https://github.com/ido4-dev/ido4).

Takes a strategic spec produced by [ido4shape](https://github.com/ido4-dev/ido4shape) and turns it into a structurally-validated technical spec on disk. Methodology-neutral. Zero runtime dependency on an MCP server. Bundles the `@ido4/tech-spec-format` CLI for deterministic structural validation.

## Status

**Under construction.** This plugin is being extracted from `ido4dev` in five phases. Phase 1 (extracting the `@ido4/tech-spec-format` npm package from `@ido4/core`) landed 2026-04-14. The plugin scaffold itself is the work of Phase 2 and beyond.

See [`docs/extraction-plan.md`](docs/extraction-plan.md) for the full plan and current state.

## What this will be (once built)

```
strategic spec (ido4shape)
       ↓
/ido4specs:create-spec       → canvas (code analysis + strategic context)
       ↓
/ido4specs:synthesize-spec   → technical spec .md (methodology-neutral)
       ↓
/ido4specs:review-spec       → qualitative review (spec-reviewer agent)
/ido4specs:validate-spec     → structural validation (bundled parser)
       ↓
(handoff to /ido4dev:ingest-spec for GitHub issue creation)
```

Also: `/ido4specs:refine-spec` for iterative edits, `/ido4specs:repair-spec` for interactive recovery after validation or ingestion failures.

## License

MIT — see [LICENSE](LICENSE) once added.
