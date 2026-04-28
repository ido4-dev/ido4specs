---
name: doctor
description: >
  Diagnostic checks for the ido4specs plugin. Use when the user says "something's
  wrong", "validator not found", "plugin not working", "doctor", "diagnose",
  "check plugin health", or when any other ido4specs skill fails with a
  validator-related error.
allowed-tools: Bash, Read
user-invocable: true
---

Run the bundled diagnostic script and relay its output. The script runs all 8 health checks in one shell invocation and produces a fully formatted report — no further parsing or formatting needed in the skill body.

```bash
bash "${CLAUDE_SKILL_DIR}/../../scripts/doctor.sh"
```

Display the script's output verbatim. If the script's exit code is non-zero, one or more checks failed; the failing line(s) carry their own remediation hints. Read those lines and surface the remediation conversationally if the user looks like they want help acting on a failure.

If check 8 reports `not configured (opt-in available)` and the user wants to enable the status line, emit this config block (substituting the absolute path to `scripts/statusline.sh` resolved from the plugin location):

```jsonc
{
  "statusLine": {
    "type": "command",
    "command": "<absolute path to scripts/statusline.sh>",
    "padding": 1
  }
}
```

Tell the user to add it to `~/.claude/settings.json` (global) or `.claude/settings.json` (project).

## What the script reports

The script's output structure is stable across runs:

```
ido4specs doctor — diagnostic report

Plugin version:  0.4.2

1. Node.js:             PASS (v20.18.1)
2. Bundled validators:  PASS (both in plugin data)
3. Validator execution: PASS (both run without crash)
4. Version markers:     PASS (tech-spec-format@0.9.1, spec-format@0.9.1)
5. Checksums:           PASS (both match)
6. Round-trip test:     PASS (example-technical-spec.md validates clean)
7. Workspace state:     strategic spec at data-connector-spec.md
                        → next: /ido4specs:create-spec data-connector-spec.md
8. Status line:         not configured (opt-in available)

Result: ALL CHECKS PASSED
```

The plugin version line is read from `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json`. Check 7 surfaces a workspace-aware next-action suggestion when an artifact is found. The script's logic for all 8 checks lives in `scripts/doctor.sh` — see the script for the exact bash for each check and the failure-case remediation strings.

## Why a script, not inline bash

The previous version of this skill ran 8 separate Bash tool calls (one per check). That worked, but produced ~25 lines of intermediate raw bash output that the user had to mentally filter through to get to the 8-line summary. The single-script approach reduces that to one Bash tool call with deterministic structured output. The skill body shrinks; the diagnostic logic gets versioned and shellcheck-validated alongside the other plugin scripts.
