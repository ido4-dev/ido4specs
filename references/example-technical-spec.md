<!--
  Copied from ido4/tests/fixtures/technical-spec-sample.md during Phase 2 of
  the ido4specs extraction (2026-04-14). This is the round-trip test fixture
  for the bundled @ido4/tech-spec-format validator (see tests/validate-plugin.sh
  Test 4) and the canonical authoring example for the technical-spec format.
  Both ido4specs and the monorepo CI smoke-test against equivalent fixtures —
  if this file ever stops parsing under the bundled validator, the validator
  drifted, not the example.
-->

# Development Context Pipeline
> format: tech-spec | version: 1.0

> Build a system that assembles per-task context for AI coding agents — upstream
> decisions, sibling patterns, downstream expectations — and delivers it at task
> start without manual fetching.

**Constraints:**
- Must work against existing GitHub issue infrastructure
- No agent-side state; context is assembled per session

**Non-goals:**
- A persistent knowledge graph
- Human-facing documentation generation

**Open questions:**
- Do we need a context cache, or is per-session fetch acceptable?

---

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

### CAS-02: Sibling Pattern Scanner
> effort: M | risk: medium | type: feature | ai: assisted
> depends_on: CAS-01

Scan sibling tasks within the same capability for patterns that have already
been established. Helps agents avoid reinventing interfaces and duplicating
utility functions.

**Success conditions:**
- Detects shared patterns across 2+ sibling tasks
- Surfaces pattern references with file-level grounding

### CAS-03: Downstream Expectation Aggregator
> effort: L | risk: medium | type: feature | ai: pair
> depends_on: CAS-01, CAS-02

Identify tasks downstream of the current one and extract their stated
requirements from bodies and success conditions. The agent learns what the
downstream consumers expect so it doesn't have to guess.

**Success conditions:**
- Returns dependency graph edges downstream from the task
- Extracts interface expectations from consumer success conditions
- Handles circular reference reports with clear error context

---

## Capability: Context Delivery
> size: M | risk: low

Delivers the assembled context to the agent at task start.

### CDL-01: Context Bundle Serialization
> effort: S | risk: low | type: feature | ai: full
> depends_on: CAS-03

Serialize the assembled context bundle into the agent's session context in a
structured format that the agent can reference by section.

**Success conditions:**
- Bundle serializes to well-formed markdown
- Sections are addressable by name (Upstream Decisions, Sibling Patterns, Downstream Expectations)

### CDL-02: Delivery Hook
> effort: S | risk: low | type: feature | ai: full
> depends_on: CDL-01

A `SessionStart` hook that fetches the bundle for the current task and injects
it into the agent's working memory before the first turn.

**Success conditions:**
- Fires on session start when a task ID is present in the workspace
- Failure mode is graceful (logs a warning, agent proceeds without context)
