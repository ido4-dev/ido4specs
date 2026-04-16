<!--
  Example strategic spec for trying the ido4specs pipeline without ido4shape.
  Copied from ido4/tests/fixtures/strategic-spec-context-pipeline.md during the
  ido4specs extraction (2026-04-14). A small, parseable spec with 2 groups and
  5 capabilities — runs through the full pipeline in ~10 minutes.

  Usage: /ido4specs:create-spec references/example-strategic-spec.md
-->

# Development Context Pipeline
> format: strategic-spec | version: 1.0

> AI agents in ido4-governed projects start each task with minimal context —
> they know the rules (BRE, audit, compliance) but not the project. When an
> agent begins task #42, it gets a title and status transition but must
> manually fetch dependency context, sibling decisions, and downstream
> expectations. Most agents skip this and code from the title alone, leading
> to integration failures, duplicated patterns, and missed interfaces.

> We need a context delivery system that assembles the right knowledge at
> the right moment — upstream decisions, sibling patterns, downstream
> expectations — and delivers it to any agent starting or resuming work.

**Stakeholders:**
- Bogdan (Product/Architecture): Defined the "system carries knowledge, not the agent" principle. Agents are stateless — context must be assembled per-session. GitHub issues are living specs that accumulate context over their lifecycle.
- Agent teams (consumers): Need structured context at task start without manual fetching. Current workflow requires 5-8 separate API calls to understand a task's position in the project graph.
- Enterprise users (future): Need audit trail of what context was provided to agents and what decisions they made — accountability requires traceability.

**Constraints:**
- Must work with existing GitHub issue infrastructure — comments, bodies, labels. No external storage.
- Must integrate with existing ServiceContainer and MCP tool architecture — no new server processes.
- Context comments must be parseable by both humans and machines — structured but readable.
- Must not require changes to the BRE validation pipeline — context is additive, not a new gate.

**Non-goals:**
- Real-time collaboration between concurrent agents — context is assembled at task start, not streamed.
- Replacing the task spec (issue body) — context enriches, it doesn't redefine the work.
- Agent-specific formatting — context is delivered in a universal format, not tailored per AI model.

**Open questions:**
- Should context snapshots be cached or assembled fresh each time? Caching is faster but may go stale.
- How much upstream context is too much? Deep dependency chains could overwhelm agent context windows.

---

## Cross-Cutting Concerns

### Performance
Context assembly touches multiple GitHub API endpoints (task details, dependency graph, comments for each dependency). Must batch where possible and parallelize fetches. Target: full context assembly under 5 seconds for a task with 3 dependencies and 5 siblings.

### Data Integrity
Context comments become part of the audit trail. Once written, they should not be edited — append-only pattern. Context must accurately reflect the state at the time of assembly, not a cached or stale view.

### Observability
Every context assembly should be traceable — what was fetched, what was included, what was omitted (and why). This enables debugging when an agent makes a bad decision despite "having context."

---

## Group: Context Assembly
> priority: must-have

The engine that gathers and structures context for a task. Builds on existing infrastructure — the task execution aggregator (packages/mcp/src/aggregators/task-execution-aggregator.ts) already fetches upstream dependencies, epic siblings, and downstream dependents. The context comment parser (packages/core/src/shared/utils/context-comment-parser.ts) already parses structured ido4 context blocks. What's missing is the enrichment layer that combines these into a self-contained context package.

### CTX-01: Context Enrichment Service
> priority: must-have | risk: medium
> depends_on: -

The orchestrator that combines raw task data (from the existing task execution aggregator) with parsed context comments (from the existing context comment parser) to produce enriched context packages. For each upstream dependency, includes not just status but the decisions made, interfaces created, and patterns established. For siblings, includes what parallel agents decided so the current agent can align.

Per Bogdan: the system carries the knowledge, not the agent. This service is the "institutional memory" assembler — every agent gets the same rich context regardless of which AI model powers it.

**Success conditions:**
- Produces enriched context that includes upstream decisions and interface descriptions
- Integrates with existing task execution aggregator (does not duplicate its functionality)
- Integrates with existing context comment parser (does not duplicate its functionality)
- Context package is self-contained — an agent can understand its task without additional API calls
- Handles partial context gracefully (some deps may have no context comments)

### CTX-02: Context Snapshot Persistence
> priority: should-have | risk: low
> depends_on: CTX-01

Persist assembled context snapshots so they can be audited and compared. When context is assembled for a task, the snapshot records what information was available at that moment. This enables tracing: "the agent had this context when it started working."

Per enterprise users: accountability requires traceability — what did the agent know when it made its decisions?

**Success conditions:**
- Context snapshots are persisted as part of the audit trail
- Snapshots include: what was fetched, what was included, what was omitted (and why)
- Snapshots are queryable by task number and timestamp
- No modification of existing audit service — uses the existing event pattern

---

## Group: Context Delivery
> priority: must-have

How context reaches agents. The MCP tools and prompts that deliver assembled context at the right moment in the task lifecycle.

### CDL-01: Start Task Context Injection
> priority: must-have | risk: medium
> depends_on: CTX-01

When an agent calls `start_task`, automatically assemble and deliver the full context package alongside the task briefing. The agent receives not just "start working on #42" but a complete understanding of what upstream produced, what siblings decided, and what downstream expects.

Per Bogdan: agents are stateless — each session starts fresh. The right 100K tokens of context will outperform a "specialized" agent with the wrong context.

**Success conditions:**
- `start_task` response includes assembled context alongside task details
- Context is structured for agent consumption (clear sections, not raw JSON)
- Agent can understand task position in the project graph without additional calls
- Existing `start_task` behavior is preserved — context is additive

### CDL-02: Context Writing MCP Tool
> priority: must-have | risk: low
> depends_on: -

MCP tool for agents to write structured context back to issues at key transitions. Uses the existing context comment formatter (packages/core/src/shared/utils/context-comment-formatter.ts) to produce machine-parseable, human-readable comments. When an agent makes a design decision, it writes structured context that future agents can consume.

**Success conditions:**
- MCP tool `write_task_context` accepts transition type, content, and optional agent identity
- Uses existing formatIdo4ContextComment — does not create a new format
- Written context is immediately parseable by the existing context comment parser
- Integrates with existing audit trail (context writes are governance events)

### CDL-03: Context-Aware Prompts
> priority: should-have | risk: low
> depends_on: CTX-01, CDL-01

Enhanced MCP prompts (standup, board, health) that leverage assembled context to produce richer, more actionable guidance. A standup that knows what each agent's upstream dependencies decided is more valuable than one that just reports statuses.

**Success conditions:**
- Standup prompt includes upstream decision summaries for in-progress tasks
- Board prompt highlights context gaps (tasks with dependencies that have no context comments)
- Prompts degrade gracefully when context is unavailable
