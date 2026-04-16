---
name: doctor
description: >
  Diagnostic checks for the ido4specs plugin. Use when the user says "something's
  wrong", "validator not found", "plugin not working", "doctor", "diagnose",
  "check plugin health", or when any other ido4specs skill fails with a
  validator-related error.
allowed-tools: Bash, Read, Glob
user-invocable: true
---

Run diagnostic checks and report a PASS/FAIL checklist. If anything fails, provide specific remediation.

## Checks

Run these in order. Stop-on-first-failure is not needed — run all checks and report the full picture.

### 1. Node.js availability

```bash
node --version
```

- PASS: version ≥ 18
- FAIL: "Node.js not found or version too old. Install Node.js 18+ from https://nodejs.org."

### 2. Bundled validators in plugin data directory

Check that the SessionStart hook copied both validators:

```bash
ls "${CLAUDE_PLUGIN_DATA}/tech-spec-validator.js" "${CLAUDE_PLUGIN_DATA}/spec-validator.js"
```

- PASS: both files exist
- FAIL: "Validator not found in plugin data. Start a fresh Claude Code session to re-trigger the SessionStart hook, or manually copy from `dist/` to `${CLAUDE_PLUGIN_DATA}/`."

### 3. Validators execute correctly

```bash
node "${CLAUDE_PLUGIN_DATA}/tech-spec-validator.js" --help 2>&1 || true
node "${CLAUDE_PLUGIN_DATA}/spec-validator.js" --help 2>&1 || true
```

- PASS: both produce output without crashing (exit 0 or exit 2 with usage info — both acceptable)
- FAIL: "Validator crashes on execution. The bundle may be corrupted. Run `scripts/update-tech-spec-validator.sh <version>` to refresh."

### 4. Version markers present and consistent

Read `dist/.tech-spec-format-version` and `dist/.spec-format-version`. Both should contain semver strings.

- PASS: both present with valid semver
- FAIL: "Version marker missing or malformed. Run the corresponding update script."

### 5. Checksum verification

```bash
shasum -a 256 dist/tech-spec-validator.js | awk '{print $1}'
cat dist/.tech-spec-format-checksum | awk '{print $1}'
```

Compare. Repeat for spec-validator.

- PASS: checksums match for both bundles
- FAIL: "Checksum mismatch — the bundle was modified after the last update. Run the update script to refresh both the bundle and checksum."

### 6. Round-trip test

Run the technical-spec validator against the example fixture:

```bash
node "${CLAUDE_PLUGIN_DATA}/tech-spec-validator.js" "${CLAUDE_PLUGIN_ROOT}/references/example-technical-spec.md"
```

- PASS: exit 0, `"valid": true` in JSON output
- FAIL: "The bundled validator cannot parse the example fixture. This indicates a validator/fixture version mismatch. Run `scripts/update-tech-spec-validator.sh` to refresh."

### 7. Workspace artifact scan

Glob for existing ido4specs artifacts in the project:

```bash
ls specs/*-tech-canvas.md specs/*-tech-spec.md docs/specs/*-tech-canvas.md docs/specs/*-tech-spec.md 2>/dev/null
```

Report what exists. No PASS/FAIL — purely informational.

## Output format

```
ido4specs doctor — diagnostic report

1. Node.js:             PASS (v22.1.0)
2. Bundled validators:  PASS (both in plugin data)
3. Validator execution: PASS (both run without crash)
4. Version markers:     PASS (tech-spec-format@0.8.0, spec-format@0.8.0)
5. Checksums:           PASS (both match)
6. Round-trip test:     PASS (example-technical-spec.md validates clean)
7. Workspace state:     specs/notification-system-tech-spec.md (640 lines)

Result: ALL CHECKS PASSED
```

If any check fails:

```
Result: 1 CHECK FAILED — see remediation above
```
