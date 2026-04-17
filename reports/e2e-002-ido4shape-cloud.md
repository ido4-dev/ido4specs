# E2E Test Report — ido4shape Enterprise Cloud Platform (round 2)

**Round:** 2
**Date:** 2026-04-17
**Project:** `~/dev-projects/ido4shape-cloud/` (same project as round 1)
**Strategic spec:** `ido4shape-enterprise-cloud-spec.md` (25 capabilities, 5 groups, 45 dependency edges)
**Plugin version:** ido4specs at the working commit `47f1c68` (post-v0.2.0, pre-v0.3.0); both bundled validators still at `0.8.0`
**Pre-round commit context:** This round runs against the uncommitted-then-committed onboarding work that becomes v0.3.0 — polite-by-default SessionStart, opt-in status line script, doctor Check 8, slash-menu description tightening, and the stale "2–8 → 1–8" doc fixes.
**Skills exercised:** SessionStart (artifact-aware branch), `/ido4specs:doctor`, `/ido4specs:validate-spec`, `/ido4specs:review-spec`. Optional skills not exercised: `refine-spec` (no edit needed for regression confirmation), status-line opt-in render test.
**Monitor session:** Separate Claude Code session in `~/dev-projects/ido4specs/`, evaluating against skill/agent definitions.
**Round 1 baseline:** `reports/e2e-001-ido4shape-cloud.md` — full 5-skill pipeline pass with 3 observations (OBS-01 duration-advisory UX gap, OBS-02 architecture-projection heading drift, OBS-03 T8 false-positive on single-task capabilities). All three were addressed in v0.2.0 → working commit. This round is a targeted regression test of the touched surfaces, not a full pipeline re-run (pipeline skill bodies and agents are byte-identical to v0.2.0).

---

## Pipeline Summary (so far)

| Skill | Time | Verdict | Notes |
|---|---|---|---|
| SessionStart hook (artifact branch) | <1s | PASS | Detected existing tech spec, suggested validate/review/refine. Claude relayed cleanly in first reply. |
| `/ido4specs:doctor` | ~30s | PASS (8/8) | Workspace state listed both canvas + tech spec. New Check 8 emitted opt-in config block with absolute path resolved. One parallel-call hiccup logged below. |
| `/ido4specs:validate-spec` | ~1m 40s | PASS (0E/0W) | Round 1 produced 3 T8 false-positives on single-task capabilities; round 2 produces zero. v0.2.0 T8 (1–8) relaxation confirmed. Cross-sell footer fired correctly (no `.ido4/project-info.json` → install-ido4dev variant). |
| `/ido4specs:review-spec` | ~2m 53s | PASS (0E/0W/2S) | Round 1 was PASS WITH WARNINGS (0E/2W/2S); the 2 warnings were T8-related and are now gone. The 2 suggestions in round 2 are fresh content observations (PLUG-02B drain underspec, VIEW-05A v1/v2 schema gap), not regressions. Spec Review Report structure intact: Summary / Errors / Warnings / Suggestions / Downstream Notes / Dependency Graph + cross-sell footer. |

Round 2 continues with `validate-spec` → `review-spec` → optional `refine-spec` → optional status-line opt-in test.

---

## Observations

### OBS-01 — Behavioral drift — Low (watch item)

**When:** `/ido4specs:doctor` execution, during the parallel-tool batch that included Check 8's status-line probe (`python3` reading `~/.claude/settings.json` and `.claude/settings.json`).

**What happened:** The doctor skill's checks are designed to be independent, which Claude correctly noticed and parallelized. One of the parallel `Bash` calls in the batch — an `ls` against an absolute path under `/Users/bogdanionutcoman/dev-projects/…` (full path truncated in the CLI display) — errored, which **cancelled the parallel `python3` status-line check** in the same turn. Trace excerpt:

```
⏺ Bash(python3 -c "import json, os…")
  ⎿ Cancelled: parallel tool call Bash(ls /Users/bogdanionutcoman/dev-projects/…) errored
```

Claude recovered by re-issuing the `python3` call alone in the next turn, which succeeded. Final report came out clean (8/8 PASS), so no functional damage to the diagnostic.

**What was expected:** Either the parallel batch should succeed, or the cancellation message should at least surface the underlying error so we know what failed. The skill spec for Check 7 uses relative paths with `2>/dev/null` suppression, so the absolute-path `ls` was Claude's own invention layered on top — likely a verify-step on an adjacent directory that wasn't in the SKILL.md.

**Evidence:** Pasted trace from round 2 test session.

**Fix candidate:** None recommended yet. Two reasons:
- The retry pattern is what we'd want if any single check ever does fail.
- Sequentializing all doctor checks in `skills/doctor/SKILL.md` would slow the skill for a small reliability gain that the current behavior already provides via retry.

**When this becomes worth fixing:** If the parallel-cancel pattern recurs across multiple test sessions or causes a check to actually be omitted from the final report. Marked as a **watch item** for round 3+.

**Severity justification:** Low. The user-visible report was correct and complete. The hiccup is internal to Claude's tool-batching and wasn't surfaced to the user (other than the truncated cancellation line in the transcript).

### POS-01 — Onboarding from round-2 working commit lands cleanly

**When:** SessionStart hook (artifact-aware branch).

**What happened:** First reply: *"Hi! Technical spec is ready at specs/ido4shape-enterprise-cloud-tech-spec.md. Next step: validate, review, or refine it. What would you like to do?"*

This confirms the polite-by-default refactor preserves the artifact-aware branch unchanged — round 1's behavior pattern (Claude relays the SessionStart context conversationally) still holds. The refactor only changes what happens when no artifacts exist; the artifact-detected branch is byte-identical in observed output.

### POS-03 — T8 (1–8) relaxation lands cleanly on the round-1 spec

**When:** `/ido4specs:validate-spec specs/ido4shape-enterprise-cloud-tech-spec.md`.

**What happened:** Verdict **PASS** with 0 structural errors and 0 structural warnings on the same spec where round 1 produced 3 T8 false-positive warnings (capabilities with exactly 1 task were flagged as "outside 2–8 range" — architecturally justified per OBS-03 in round 1, fixed in v0.2.0 by relaxing T8 to "1–8 tasks fine when the task is M-effort or larger" in both `validate-spec`'s T8 assertion and `spec-reviewer.md`'s quality assessment line).

This round 2 zero-warning result is the empirical confirmation that the v0.2.0 fix landed in the right place. 27 capabilities, 36 tasks → many of those capabilities are single-task M-effort units (STOR-01A, VIEW-01A, etc.) that previously tripped the false-positive.

### POS-04 — Validate-spec qualitative interpretation matches spec-reviewer's nuance

**When:** Same `validate-spec` run.

**What happened:** The "What's working / What needs your input / Next step" output included a smart framing of the max-dependency-depth metric (depth = 9). Instead of flagging it as a warning, the response correctly identified it as **natural greenfield-platform layering** (INFRA → AUTH → STOR → PLUG/VIEW → PROJ) and surfaced it as a **sequencing-expectations note**, not a violation.

This is the same kind of context-aware interpretation the `spec-reviewer` agent provides in `/ido4specs:review-spec`. Suggests the two layers (deterministic parser + LLM-driven validator interpretation) converge on consistent narrative — Layer 1 doesn't just dump raw parser output, it frames intelligently.

### POS-05 — Cross-sell footer fired correctly post-refactor

**When:** End-of-flow message in `validate-spec`.

**What happened:** *"No `.ido4/project-info.json` marker exists in this workspace — to turn this into GitHub issues, install ido4dev (`/plugin install ido4dev@ido4-plugins`), run `/ido4dev:onboard`, then `/ido4dev:ingest-spec`."*

This is the "absent" variant (correct — `ido4-suite` and `ido4shape-cloud` don't have the marker). Confirms the artifact-as-contract probe pattern (the foundation we'd extend in the Plugin Activity Registry brief) survives all the SessionStart / status-line refactoring intact.

### POS-02 — Doctor Check 8 lands as designed

**When:** `/ido4specs:doctor` final report.

**What happened:**
```
8. Status line:         not configured (opt-in available)

To enable the status line, add this to ~/.claude/settings.json (global) or
.claude/settings.json (project):

{
  "statusLine": {
    "type": "command",
    "command": "/Users/bogdanionutcoman/dev-projects/ido4specs/scripts/statusline.sh",
    "padding": 1
  }
}
```

The absolute path is **resolved**, not a literal `${CLAUDE_PLUGIN_ROOT}` placeholder — exactly the user-facing UX the SKILL.md prescribed.

---

## Pending checks

- [x] `/ido4specs:validate-spec specs/ido4shape-enterprise-cloud-tech-spec.md` — verify the relaxed T8 (1–8 tasks) shipped in v0.2.0 produces no false-positive warnings on this round-1 spec (which has multiple single-task capabilities). **Done — PASS (0E/0W).**
- [x] `/ido4specs:review-spec specs/ido4shape-enterprise-cloud-tech-spec.md` — same regression check on the qualitative reviewer's T8 line. **Done — PASS, 2 round-1 warnings disappeared, structure intact.**
- [ ] *Optional, deferred:* status-line opt-in (wire the config block from Check 8 into `~/.claude/settings.json`, restart session, confirm `ido4specs · spec ✓ ido4shape-enterprise-cloud` renders). Skipped for round 2 — the script was unit-tested locally, the doctor check confirmed the opt-in path is correct. Worth doing in round 3 if anyone wants to verify the rendering path end-to-end.
- [ ] *Optional, deferred:* light `refine-spec` edit. Skipped — pipeline skill body and auto-revalidation flow are byte-identical to v0.2.0 (no skill-body or validator changes touched it). Round 1 verified the cycle. Re-running would only re-test untouched code paths.

### POS-06 — Reviewer caught attribution amplification, not just preservation

**When:** `/ido4specs:review-spec` Downstream Notes section.

**What happened:** The reviewer reported: *"Canvas has 3 'Per Bogdan' attributions; spec has 11. Strategic rationale (D1, D8, D9, D10, D11, D13 decision refs) was amplified, not dropped."*

This is pipeline-aware analysis the reviewer surfaced unprompted — confirming the `synthesize-spec` step didn't merely preserve strategic rationale (which is the explicit invariant the spec-reviewer agent checks for) but actually amplified it where it added implementation context. That's a positive observation about the synthesis step's behavior, surfaced by a downstream reviewer reading the upstream artifact pair (canvas + spec). Cross-stage awareness like this is one of the more sophisticated capabilities the inline agents bring to the pipeline.

## Assessment

**Round 2 verdict: production-ready, ship as v0.3.0.**

Every changed surface verified:
- ✓ Polite-by-default SessionStart (greeting case verified in ido4-suite session, artifact-aware case verified here)
- ✓ Doctor Check 8 (8/8 PASS, opt-in config block emitted with absolute path resolved)
- ✓ T8 (1–8) relaxation in `validate-spec` — 3 round-1 false-positives → 0
- ✓ T8 (1–8) relaxation in `agents/spec-reviewer.md` — 2 round-1 warnings → 0, structure intact
- ✓ Cross-sell footer probe pattern (artifact-as-contract) survived the SessionStart refactor

Untouched surfaces (skill bodies for create-spec, synthesize-spec, refine-spec; all 3 agents; both bundled validators; hooks.json) deliberately not re-tested in this round — they're byte-identical to v0.2.0 which round 1 verified.

One watch item (OBS-01: doctor parallel-call cancel-and-retry) — not blocking, marked for round 3+ recurrence check.

## Next steps

1. Push working commit `47f1c68` to origin/main (currently local-only).
2. Cut v0.3.0 release: `bash scripts/release.sh minor "Polite-by-default onboarding and opt-in status line"`.
3. CI runs validate-plugin.sh (150 checks expected to pass).
4. Sync workflow propagates to `ido4-plugins` marketplace.
5. Future: when a pipeline skill, agent, or validator bundle next changes, run a full E2E (round 3 will need to re-verify the unchanged surfaces this round skipped).
