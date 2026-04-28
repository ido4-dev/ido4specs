#!/bin/bash
# ido4specs doctor — single-call diagnostic check.
#
# Runs all 8 health checks in one shell invocation and emits a formatted
# diagnostic report to stdout. The skill body just relays this output.
#
# Exit codes:
#   0 — all checks passed
#   1 — one or more checks failed (details in the report)

set -u

# ─── Path resolution ───────────────────────────────────────
# Resolve plugin root from the script's location (scripts/doctor.sh → ../).
PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# CLAUDE_PLUGIN_DATA is set by Claude Code when invoking skill bodies.
# Fall back to the conventional path if running outside that context.
PLUGIN_DATA="${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/ido4specs-inline}"

# Workspace = current directory at invocation time.
WORKSPACE="$PWD"

# ─── State accumulators ────────────────────────────────────
PASS=0
FAIL=0
LINE_NODE=""
LINE_BUNDLES=""
LINE_EXEC=""
LINE_VERSIONS=""
LINE_CHECKSUMS=""
LINE_ROUNDTRIP=""
LINE_WORKSPACE=""
LINE_STATUSLINE=""
NEXT_ACTION=""

# Read plugin version from manifest (used in report header).
PLUGIN_VERSION=$(python3 -c "
import json, sys
try:
    print(json.load(open('$PLUGIN_ROOT/.claude-plugin/plugin.json'))['version'])
except Exception:
    print('unknown')
" 2>/dev/null)

# ─── Check 1: Node.js ──────────────────────────────────────
NODE_VERSION=$(node --version 2>/dev/null || echo "")
if [ -n "$NODE_VERSION" ]; then
  NODE_MAJOR=$(echo "$NODE_VERSION" | sed 's/^v//' | cut -d. -f1)
  if [ "$NODE_MAJOR" -ge 18 ] 2>/dev/null; then
    LINE_NODE="PASS ($NODE_VERSION)"
    PASS=$((PASS + 1))
  else
    LINE_NODE="FAIL ($NODE_VERSION — need Node.js 18+; install from https://nodejs.org)"
    FAIL=$((FAIL + 1))
  fi
else
  LINE_NODE="FAIL (node not found on PATH; install Node.js 18+ from https://nodejs.org)"
  FAIL=$((FAIL + 1))
fi

# ─── Check 2: Bundled validators present ───────────────────
TSV="$PLUGIN_DATA/tech-spec-validator.js"
SV="$PLUGIN_DATA/spec-validator.js"
if [ -f "$TSV" ] && [ -f "$SV" ]; then
  LINE_BUNDLES="PASS (both in plugin data)"
  PASS=$((PASS + 1))
else
  MISSING=""
  [ ! -f "$TSV" ] && MISSING="$MISSING tech-spec-validator.js"
  [ ! -f "$SV" ] && MISSING="$MISSING spec-validator.js"
  LINE_BUNDLES="FAIL (missing:$MISSING — start a fresh Claude Code session to re-trigger the SessionStart hook)"
  FAIL=$((FAIL + 1))
fi

# ─── Check 3: Validators execute ───────────────────────────
TSV_OK=false
SV_OK=false
if [ -f "$TSV" ] && node "$TSV" --help >/dev/null 2>&1; then
  TSV_OK=true
elif [ -f "$TSV" ]; then
  # Some validators exit 2 on --help (printing usage to stderr) — that's acceptable.
  if node "$TSV" --help 2>&1 | grep -qiE 'usage|version'; then
    TSV_OK=true
  fi
fi
if [ -f "$SV" ] && node "$SV" --help >/dev/null 2>&1; then
  SV_OK=true
elif [ -f "$SV" ]; then
  if node "$SV" --help 2>&1 | grep -qiE 'usage|version'; then
    SV_OK=true
  fi
fi

if [ "$TSV_OK" = true ] && [ "$SV_OK" = true ]; then
  LINE_EXEC="PASS (both run without crash)"
  PASS=$((PASS + 1))
else
  LINE_EXEC="FAIL (one or both bundles crash on execution — run scripts/update-tech-spec-validator.sh and scripts/update-spec-validator.sh to refresh)"
  FAIL=$((FAIL + 1))
fi

# ─── Check 4: Version markers ──────────────────────────────
TSV_VER=$(tr -d '[:space:]' < "$PLUGIN_ROOT/dist/.tech-spec-format-version" 2>/dev/null)
SV_VER=$(tr -d '[:space:]' < "$PLUGIN_ROOT/dist/.spec-format-version" 2>/dev/null)
if [[ "$TSV_VER" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] && [[ "$SV_VER" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  LINE_VERSIONS="PASS (tech-spec-format@$TSV_VER, spec-format@$SV_VER)"
  PASS=$((PASS + 1))
else
  LINE_VERSIONS="FAIL (version marker missing or malformed — run the corresponding update script)"
  FAIL=$((FAIL + 1))
fi

# ─── Check 5: Checksums ────────────────────────────────────
TSV_CALC=$(shasum -a 256 "$PLUGIN_ROOT/dist/tech-spec-validator.js" 2>/dev/null | awk '{print $1}')
SV_CALC=$(shasum -a 256 "$PLUGIN_ROOT/dist/spec-validator.js" 2>/dev/null | awk '{print $1}')
TSV_STORED=$(awk '{print $1}' < "$PLUGIN_ROOT/dist/.tech-spec-format-checksum" 2>/dev/null)
SV_STORED=$(awk '{print $1}' < "$PLUGIN_ROOT/dist/.spec-format-checksum" 2>/dev/null)
if [ -n "$TSV_CALC" ] && [ "$TSV_CALC" = "$TSV_STORED" ] && [ -n "$SV_CALC" ] && [ "$SV_CALC" = "$SV_STORED" ]; then
  LINE_CHECKSUMS="PASS (both match)"
  PASS=$((PASS + 1))
else
  LINE_CHECKSUMS="FAIL (checksum mismatch — bundle was modified locally; run the corresponding update script to refresh both bundle and checksum)"
  FAIL=$((FAIL + 1))
fi

# ─── Check 6: Round-trip test on the example fixture ──────
EXAMPLE="$PLUGIN_ROOT/references/example-technical-spec.md"
if [ -f "$EXAMPLE" ] && [ -f "$TSV" ]; then
  RT_VALID=$(node "$TSV" "$EXAMPLE" 2>/dev/null | python3 -c "
import json, sys
try:
    print('valid' if json.load(sys.stdin).get('valid') else 'invalid')
except Exception:
    print('error')
" 2>/dev/null)
  if [ "$RT_VALID" = "valid" ]; then
    LINE_ROUNDTRIP="PASS (example-technical-spec.md validates clean)"
    PASS=$((PASS + 1))
  else
    LINE_ROUNDTRIP="FAIL (example fixture failed validation — validator/fixture version mismatch; run scripts/update-tech-spec-validator.sh)"
    FAIL=$((FAIL + 1))
  fi
else
  LINE_ROUNDTRIP="FAIL (example fixture or validator missing — see check 2)"
  FAIL=$((FAIL + 1))
fi

# ─── Check 7: Workspace state + pipeline next-action ──────
# Find existing artifacts in conventional locations.
CANVAS=$(ls "$WORKSPACE"/specs/*-tech-canvas.md "$WORKSPACE"/docs/specs/*-tech-canvas.md 2>/dev/null | head -1)
SPEC=$(ls "$WORKSPACE"/specs/*-tech-spec.md "$WORKSPACE"/docs/specs/*-tech-spec.md 2>/dev/null | head -1)
STRATEGIC=$(ls "$WORKSPACE"/specs/*-strategic-spec.md "$WORKSPACE"/specs/*-spec.md "$WORKSPACE"/docs/specs/*-strategic-spec.md "$WORKSPACE"/*-strategic-spec.md "$WORKSPACE"/*-spec.md 2>/dev/null | grep -vE '(-tech-spec|-tech-canvas)\.md$' | head -1)

# Render compact paths for display (relative to workspace).
CANVAS_REL="${CANVAS#$WORKSPACE/}"
SPEC_REL="${SPEC#$WORKSPACE/}"
STRATEGIC_REL="${STRATEGIC#$WORKSPACE/}"

if [ -n "$SPEC" ]; then
  LINE_WORKSPACE="tech spec at $SPEC_REL"
  NEXT_ACTION="/ido4specs:review-spec $SPEC_REL or /ido4specs:validate-spec $SPEC_REL"
elif [ -n "$CANVAS" ]; then
  LINE_WORKSPACE="canvas at $CANVAS_REL"
  NEXT_ACTION="/ido4specs:synthesize-spec $CANVAS_REL"
elif [ -n "$STRATEGIC" ]; then
  LINE_WORKSPACE="strategic spec at $STRATEGIC_REL"
  NEXT_ACTION="/ido4specs:create-spec $STRATEGIC_REL"
else
  LINE_WORKSPACE="no ido4specs artifacts and no strategic spec detected"
  NEXT_ACTION=""
fi

# ─── Check 8: Status line opt-in ───────────────────────────
EXPECTED_SL="$PLUGIN_ROOT/scripts/statusline.sh"
USER_SL=$(python3 -c "
import json, os
p = os.path.expanduser('~/.claude/settings.json')
print((json.load(open(p)) if os.path.exists(p) else {}).get('statusLine', {}).get('command', ''))
" 2>/dev/null)
PROJ_SL=$(python3 -c "
import json, os
p = '$WORKSPACE/.claude/settings.json'
print((json.load(open(p)) if os.path.exists(p) else {}).get('statusLine', {}).get('command', ''))
" 2>/dev/null)

if [ "$USER_SL" = "$EXPECTED_SL" ]; then
  LINE_STATUSLINE="configured for ido4specs (user)"
elif [ "$PROJ_SL" = "$EXPECTED_SL" ]; then
  LINE_STATUSLINE="configured for ido4specs (project)"
elif [ -n "$USER_SL" ] || [ -n "$PROJ_SL" ]; then
  LINE_STATUSLINE="configured (user's own — ido4specs would not override)"
else
  LINE_STATUSLINE="not configured (opt-in available)"
fi

# ─── Render report ────────────────────────────────────────
echo "ido4specs doctor — diagnostic report"
echo ""
echo "Plugin version:  $PLUGIN_VERSION"
echo ""
echo "1. Node.js:             $LINE_NODE"
echo "2. Bundled validators:  $LINE_BUNDLES"
echo "3. Validator execution: $LINE_EXEC"
echo "4. Version markers:     $LINE_VERSIONS"
echo "5. Checksums:           $LINE_CHECKSUMS"
echo "6. Round-trip test:     $LINE_ROUNDTRIP"
echo "7. Workspace state:     $LINE_WORKSPACE"
if [ -n "$NEXT_ACTION" ]; then
  echo "                        → next: $NEXT_ACTION"
fi
echo "8. Status line:         $LINE_STATUSLINE"
echo ""
if [ "$FAIL" -gt 0 ]; then
  echo "Result: $FAIL CHECK(S) FAILED — see remediation in the relevant line(s) above"
  exit 1
else
  echo "Result: ALL CHECKS PASSED"
  exit 0
fi
