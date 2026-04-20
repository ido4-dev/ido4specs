#!/bin/bash
# ido4specs Plugin Validation Suite
# Tests: structure, bundled validators, skills, agents, hooks, references,
#        language hygiene, methodology neutrality, filename conventions.
# Run: bash tests/validate-plugin.sh

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0
WARN=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
warn() { echo "  WARN: $1"; WARN=$((WARN + 1)); }

echo "========================================="
echo "ido4specs Plugin Validation"
echo "========================================="
echo ""

# ─── TEST 1: Plugin Manifest ───────────────────────────────

echo "--- Test 1: Plugin Manifest ---"

PLUGIN_JSON="$PLUGIN_DIR/.claude-plugin/plugin.json"

if [ -f "$PLUGIN_JSON" ]; then
  pass "plugin.json exists"
else
  fail "plugin.json missing"
fi

if python3 -m json.tool "$PLUGIN_JSON" > /dev/null 2>&1; then
  pass "plugin.json is valid JSON"
else
  fail "plugin.json is NOT valid JSON"
fi

for field in name description version repository license; do
  if python3 -c "import json; d=json.load(open('$PLUGIN_JSON')); assert '$field' in d" 2>/dev/null; then
    pass "plugin.json has '$field' field"
  else
    fail "plugin.json missing '$field' field"
  fi
done

NAME=$(python3 -c "import json; print(json.load(open('$PLUGIN_JSON'))['name'])" 2>/dev/null)
if [ "$NAME" = "ido4specs" ]; then
  pass "plugin name is 'ido4specs'"
else
  fail "plugin name is '$NAME', expected 'ido4specs'"
fi

REPO_URL=$(python3 -c "import json; print(json.load(open('$PLUGIN_JSON'))['repository'])" 2>/dev/null)
if echo "$REPO_URL" | grep -q "ido4-dev/ido4specs"; then
  pass "repository URL points to ido4-dev/ido4specs"
else
  fail "repository URL '$REPO_URL' should point to ido4-dev/ido4specs"
fi

for field in homepage keywords; do
  if python3 -c "import json; d=json.load(open('$PLUGIN_JSON')); assert '$field' in d" 2>/dev/null; then
    pass "plugin.json has '$field' field"
  else
    warn "plugin.json missing recommended '$field' field"
  fi
done

if python3 -c "
import json
kw = json.load(open('$PLUGIN_JSON')).get('keywords', [])
assert any(k in kw for k in ['specification', 'technical-spec', 'task-decomposition'])
" 2>/dev/null; then
  pass "keywords include searchable terms"
else
  warn "keywords may lack searchable terms (specification, technical-spec, task-decomposition)"
fi

echo ""

# ─── TEST 2: Directory Structure ───────────────────────────

echo "--- Test 2: Directory Structure ---"

REQUIRED_DIRS=("skills" "agents" "hooks" "references" "dist" "scripts" "tests" ".claude-plugin")
for dir in "${REQUIRED_DIRS[@]}"; do
  if [ -d "$PLUGIN_DIR/$dir" ]; then
    pass "directory '$dir' exists"
  else
    fail "directory '$dir' missing"
  fi
done

echo ""

# ─── TEST 3: Documentation Files ─────────────────────────

echo "--- Test 3: Documentation Files ---"

for doc in README.md SECURITY.md CHANGELOG.md LICENSE CLAUDE.md; do
  if [ -f "$PLUGIN_DIR/$doc" ]; then
    pass "$doc exists"
  else
    fail "$doc missing"
  fi
done

CURRENT_VERSION=$(python3 -c "import json; print(json.load(open('$PLUGIN_JSON'))['version'])" 2>/dev/null)
if grep -q "\[$CURRENT_VERSION\]" "$PLUGIN_DIR/CHANGELOG.md" 2>/dev/null; then
  pass "CHANGELOG includes current version ($CURRENT_VERSION)"
else
  warn "CHANGELOG missing entry for current version ($CURRENT_VERSION)"
fi

echo ""

# ─── TEST 4: Bundled Validators (dual) ─────────────────────

echo "--- Test 4: Bundled Validators ---"

TECH_BUNDLE="$PLUGIN_DIR/dist/tech-spec-validator.js"
TECH_VERSION_FILE="$PLUGIN_DIR/dist/.tech-spec-format-version"
TECH_CHECKSUM_FILE="$PLUGIN_DIR/dist/.tech-spec-format-checksum"

SPEC_BUNDLE="$PLUGIN_DIR/dist/spec-validator.js"
SPEC_VERSION_FILE="$PLUGIN_DIR/dist/.spec-format-version"
SPEC_CHECKSUM_FILE="$PLUGIN_DIR/dist/.spec-format-checksum"

# tech-spec-format bundle
if [ -f "$TECH_BUNDLE" ]; then
  pass "tech-spec-validator bundle exists"
else
  fail "tech-spec-validator bundle missing (dist/tech-spec-validator.js)"
fi

if [ -f "$TECH_VERSION_FILE" ]; then
  TECH_V=$(cat "$TECH_VERSION_FILE" | tr -d '[:space:]')
  if echo "$TECH_V" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    pass "tech-spec-format version marker valid (v$TECH_V)"
  else
    fail "tech-spec-format version marker malformed: '$TECH_V'"
  fi
else
  fail "tech-spec-format version marker missing (dist/.tech-spec-format-version)"
fi

if [ -f "$TECH_BUNDLE" ]; then
  if head -3 "$TECH_BUNDLE" | grep -q "@ido4/tech-spec-format v"; then
    pass "tech-spec-validator bundle has version header"
  else
    fail "tech-spec-validator bundle missing version header"
  fi
fi

if [ -f "$TECH_CHECKSUM_FILE" ]; then
  pass "tech-spec-format checksum file exists"
  if [ -f "$TECH_BUNDLE" ]; then
    EXPECTED=$(cat "$TECH_CHECKSUM_FILE" | awk '{print $1}')
    ACTUAL=$(shasum -a 256 "$TECH_BUNDLE" | awk '{print $1}')
    if [ "$EXPECTED" = "$ACTUAL" ]; then
      pass "tech-spec-validator checksum matches bundle (SHA-256 verified)"
    else
      fail "tech-spec-validator checksum MISMATCH — expected $EXPECTED, got $ACTUAL"
    fi
  fi
else
  warn "tech-spec-format checksum file missing"
fi

# spec-format bundle
if [ -f "$SPEC_BUNDLE" ]; then
  pass "spec-validator bundle exists"
else
  fail "spec-validator bundle missing (dist/spec-validator.js)"
fi

if [ -f "$SPEC_VERSION_FILE" ]; then
  SPEC_V=$(cat "$SPEC_VERSION_FILE" | tr -d '[:space:]')
  if echo "$SPEC_V" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    pass "spec-format version marker valid (v$SPEC_V)"
  else
    fail "spec-format version marker malformed: '$SPEC_V'"
  fi
else
  fail "spec-format version marker missing (dist/.spec-format-version)"
fi

if [ -f "$SPEC_BUNDLE" ]; then
  if head -3 "$SPEC_BUNDLE" | grep -q "@ido4/spec-format v"; then
    pass "spec-validator bundle has version header"
  else
    fail "spec-validator bundle missing version header"
  fi
fi

if [ -f "$SPEC_CHECKSUM_FILE" ]; then
  pass "spec-format checksum file exists"
  if [ -f "$SPEC_BUNDLE" ]; then
    EXPECTED=$(cat "$SPEC_CHECKSUM_FILE" | awk '{print $1}')
    ACTUAL=$(shasum -a 256 "$SPEC_BUNDLE" | awk '{print $1}')
    if [ "$EXPECTED" = "$ACTUAL" ]; then
      pass "spec-validator checksum matches bundle (SHA-256 verified)"
    else
      fail "spec-validator checksum MISMATCH — expected $EXPECTED, got $ACTUAL"
    fi
  fi
else
  warn "spec-format checksum file missing"
fi

# Round-trip smoke test — our own technical validator must parse our own example cleanly
if command -v node &>/dev/null && [ -f "$TECH_BUNDLE" ]; then
  EXAMPLE="$PLUGIN_DIR/references/example-technical-spec.md"
  if [ -f "$EXAMPLE" ]; then
    if node "$TECH_BUNDLE" "$EXAMPLE" >/dev/null 2>&1; then
      pass "tech-spec-validator executes successfully on example-technical-spec.md"
    else
      fail "tech-spec-validator execution failed on example-technical-spec.md"
    fi
    RESULT=$(node "$TECH_BUNDLE" "$EXAMPLE" 2>/dev/null)
    if echo "$RESULT" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d.get('valid') is True" 2>/dev/null; then
      pass "example-technical-spec.md passes validation (round-trip clean)"
    else
      fail "example-technical-spec.md does NOT pass validation"
    fi
  else
    warn "example-technical-spec.md missing — skipping round-trip smoke test"
  fi
else
  warn "node not available — skipping bundle smoke test"
fi

echo ""

# ─── TEST 5: SKILL.md Files ─────────────────────────────

echo "--- Test 5: SKILL.md Files ---"

SKILL_DIRS=(
  "skills/create-spec"
  "skills/synthesize-spec"
  "skills/review-spec"
  "skills/validate-spec"
  "skills/refine-spec"
  "skills/spec-quality"
  "skills/doctor"
  "skills/help"
)

for skill_dir in "${SKILL_DIRS[@]}"; do
  skill_name=$(basename "$skill_dir")
  skill_file="$PLUGIN_DIR/$skill_dir/SKILL.md"

  if [ -f "$skill_file" ]; then
    pass "$skill_name/SKILL.md exists"
  else
    fail "$skill_name/SKILL.md missing"
    continue
  fi

  if head -1 "$skill_file" | grep -q "^---$"; then
    pass "$skill_name has YAML frontmatter"
  else
    fail "$skill_name missing YAML frontmatter"
  fi

  if grep -q "^name:" "$skill_file"; then
    SNAME=$(grep "^name:" "$skill_file" | head -1 | sed 's/name: *//')
    if [ "$SNAME" = "$skill_name" ]; then
      pass "$skill_name: name field matches directory"
    else
      fail "$skill_name: name field '$SNAME' doesn't match directory '$skill_name'"
    fi
  else
    fail "$skill_name missing 'name' field in frontmatter"
  fi

  if grep -q "^description:" "$skill_file"; then
    pass "$skill_name has description"
  else
    fail "$skill_name missing description"
  fi

  # Line count (under 500 per prompt-strategy)
  LINES=$(wc -l < "$skill_file" | tr -d ' ')
  if [ "$LINES" -lt 50 ]; then
    warn "$skill_name body may be too short ($LINES lines)"
  elif [ "$LINES" -gt 500 ]; then
    fail "$skill_name body exceeds 500 lines ($LINES) — consider progressive disclosure"
  else
    pass "$skill_name line count OK ($LINES lines)"
  fi
done

echo ""

# ─── TEST 6: Agent Files ────────────────────────────────

echo "--- Test 6: Agent Files ---"

AGENTS=("code-analyzer.md" "technical-spec-writer.md" "spec-reviewer.md")
for agent in "${AGENTS[@]}"; do
  agent_file="$PLUGIN_DIR/agents/$agent"
  agent_name=$(basename "$agent" .md)

  if [ -f "$agent_file" ]; then
    pass "$agent_name agent exists"
  else
    fail "$agent_name agent missing"
    continue
  fi

  if head -1 "$agent_file" | grep -q "^---$"; then
    pass "$agent_name has YAML frontmatter"
  else
    fail "$agent_name missing YAML frontmatter"
  fi

  for field in name description model tools; do
    if grep -q "^${field}:" "$agent_file"; then
      pass "$agent_name has $field field"
    else
      if [ "$field" = "tools" ]; then
        warn "$agent_name missing $field field"
      else
        fail "$agent_name missing $field field"
      fi
    fi
  done

  # No Bash access on agents (security constraint)
  if grep -q "^tools:.*Bash" "$agent_file" 2>/dev/null; then
    fail "$agent_name has Bash access (violates security claim in SECURITY.md)"
  else
    pass "$agent_name has no Bash access"
  fi

  # No network-capable tools
  if grep -qE "^tools:.*WebFetch|^tools:.*WebSearch" "$agent_file" 2>/dev/null; then
    fail "$agent_name has network-capable tools"
  else
    pass "$agent_name has no network tools"
  fi

  # Under 300 lines per prompt-strategy
  LINES=$(wc -l < "$agent_file" | tr -d ' ')
  if [ "$LINES" -gt 300 ]; then
    warn "$agent_name exceeds 300 lines ($LINES) — consider progressive disclosure"
  else
    pass "$agent_name line count OK ($LINES lines)"
  fi
done

# review-spec references spec-reviewer
if [ -f "$PLUGIN_DIR/skills/review-spec/SKILL.md" ]; then
  if grep -q "spec-reviewer" "$PLUGIN_DIR/skills/review-spec/SKILL.md" 2>/dev/null; then
    pass "review-spec references spec-reviewer agent"
  else
    fail "review-spec doesn't reference spec-reviewer agent"
  fi
fi

# create-spec references code-analyzer
if [ -f "$PLUGIN_DIR/skills/create-spec/SKILL.md" ]; then
  if grep -q "code-analyzer" "$PLUGIN_DIR/skills/create-spec/SKILL.md" 2>/dev/null; then
    pass "create-spec references code-analyzer agent"
  else
    fail "create-spec doesn't reference code-analyzer agent"
  fi
fi

# synthesize-spec references technical-spec-writer
if [ -f "$PLUGIN_DIR/skills/synthesize-spec/SKILL.md" ]; then
  if grep -q "technical-spec-writer" "$PLUGIN_DIR/skills/synthesize-spec/SKILL.md" 2>/dev/null; then
    pass "synthesize-spec references technical-spec-writer agent"
  else
    fail "synthesize-spec doesn't reference technical-spec-writer agent"
  fi
fi

echo ""

# ─── TEST 7: Hooks ────────────────────────────────────────

echo "--- Test 7: Hooks ---"

HOOKS_FILE="$PLUGIN_DIR/hooks/hooks.json"
if [ -f "$HOOKS_FILE" ]; then
  pass "hooks.json exists"
else
  fail "hooks.json missing"
fi

if python3 -m json.tool "$HOOKS_FILE" > /dev/null 2>&1; then
  pass "hooks.json is valid JSON"
else
  fail "hooks.json is NOT valid JSON"
fi

# SessionStart hook must copy both bundles
if grep -q "SessionStart" "$HOOKS_FILE" 2>/dev/null; then
  pass "SessionStart hook defined"
else
  fail "SessionStart hook missing"
fi

if grep -q "tech-spec-validator.js" "$HOOKS_FILE" 2>/dev/null; then
  pass "SessionStart copies tech-spec-validator.js"
else
  fail "SessionStart doesn't copy tech-spec-validator.js"
fi

if grep -q "\"${CLAUDE_PLUGIN_DATA}/spec-validator.js\"\|spec-validator.js" "$HOOKS_FILE" 2>/dev/null; then
  pass "SessionStart copies spec-validator.js"
else
  fail "SessionStart doesn't copy spec-validator.js"
fi

# No hook scripts referenced (all inline cp commands)
SCRIPTS_REF=$(grep -oE '\$\{CLAUDE_PLUGIN_ROOT\}/scripts/[a-zA-Z0-9_-]+\.sh' "$HOOKS_FILE" 2>/dev/null | sort -u)
for script in $SCRIPTS_REF; do
  script_name=$(echo "$script" | sed 's|.*/||')
  if [ -f "$PLUGIN_DIR/scripts/$script_name" ]; then
    pass "hook script scripts/$script_name exists"
  else
    fail "hook script scripts/$script_name missing (referenced in hooks.json)"
  fi
done

# No network calls in hooks.json
if grep -qE "curl |wget |https?://" "$HOOKS_FILE" 2>/dev/null; then
  fail "hooks.json contains network calls"
else
  pass "hooks.json makes no network requests"
fi

echo ""

# ─── TEST 8: References ────────────────────────────────────

echo "--- Test 8: References ---"

for ref in technical-spec-format.md example-technical-spec.md; do
  if [ -f "$PLUGIN_DIR/references/$ref" ]; then
    pass "references/$ref exists"
  else
    fail "references/$ref missing"
  fi
done

# Technical spec example should have format marker
EXAMPLE="$PLUGIN_DIR/references/example-technical-spec.md"
if [ -f "$EXAMPLE" ]; then
  if grep -q "format: tech-spec" "$EXAMPLE"; then
    pass "example-technical-spec has 'format: tech-spec' marker"
  else
    fail "example-technical-spec missing 'format: tech-spec' marker"
  fi

  # Project heading anywhere in the first 20 lines (allows HTML comment headers above)
  if head -20 "$EXAMPLE" | grep -qE "^# [^#]"; then
    pass "example-technical-spec has project heading"
  else
    fail "example-technical-spec missing project heading"
  fi

  CAP_COUNT=$(grep -cE "^## Capability: " "$EXAMPLE" || true)
  if [ "$CAP_COUNT" -gt 0 ]; then
    pass "example-technical-spec has $CAP_COUNT capabilities"
  else
    fail "example-technical-spec has no '## Capability:' headings"
  fi

  TASK_COUNT=$(grep -cE "^### [A-Z]{2,5}-[0-9]{2,3}[A-Z]?:" "$EXAMPLE" || true)
  if [ "$TASK_COUNT" -gt 0 ]; then
    pass "example-technical-spec has $TASK_COUNT tasks matching ref pattern"
  else
    fail "example-technical-spec has no tasks matching ref pattern"
  fi

  # Must HAVE implementation metadata (unlike strategic specs)
  for key in effort type ai; do
    if grep -qE "^> .*${key}:" "$EXAMPLE"; then
      pass "example-technical-spec has '$key' metadata"
    else
      warn "example-technical-spec missing '$key' metadata"
    fi
  done
fi

echo ""

# ─── TEST 9: Language Hygiene (prompt-strategy compliance) ─

echo "--- Test 9: Language Hygiene ---"

# All-caps directive ceiling — prompt-strategy.md says dial back aggressive language.
# Allow a small number of load-bearing retained instances.
AGGRESSIVE_COUNT=$(grep -rE '\b(MUST|NEVER|ALWAYS|IMPORTANT|CRITICAL)\b' \
  "$PLUGIN_DIR/skills/" "$PLUGIN_DIR/agents/" 2>/dev/null | wc -l | tr -d ' ')
if [ "$AGGRESSIVE_COUNT" -eq 0 ]; then
  pass "No all-caps directive language in skills/agents"
elif [ "$AGGRESSIVE_COUNT" -le 10 ]; then
  pass "All-caps directive count ($AGGRESSIVE_COUNT) within ceiling of 10"
else
  fail "All-caps directive count ($AGGRESSIVE_COUNT) exceeds ceiling of 10 — language pass incomplete"
fi

# No TodoWrite references (Claude Code uses TaskCreate/TaskUpdate)
TODO_LEAKS=$(grep -rE '\bTodoWrite\b' "$PLUGIN_DIR/skills/" "$PLUGIN_DIR/agents/" 2>/dev/null | wc -l | tr -d ' ')
if [ "$TODO_LEAKS" -eq 0 ]; then
  pass "No TodoWrite references (current Claude Code uses TaskCreate/TaskUpdate)"
else
  fail "$TODO_LEAKS TodoWrite references found — replace with TaskCreate/TaskUpdate"
fi

# No XML tags in skill bodies (Cowork injection defense; also cleaner style)
XML_LEAKS=$(grep -rlE '^<[a-z_-]+>' "$PLUGIN_DIR/skills/" 2>/dev/null | wc -l | tr -d ' ')
if [ "$XML_LEAKS" -eq 0 ]; then
  pass "No XML tags in skill bodies"
else
  warn "$XML_LEAKS skills contain XML tags — consider markdown headers instead"
fi

echo ""

# ─── TEST 10: Zero Runtime Coupling (MCP / ido4dev leaks) ─

echo "--- Test 10: Zero Runtime Coupling ---"

# No MCP tool references in skills or agents
MCP_LEAKS=$(grep -rE 'mcp__|parse_strategic_spec|ingest_spec|@ido4/mcp' \
  "$PLUGIN_DIR/skills/" "$PLUGIN_DIR/agents/" 2>/dev/null | wc -l | tr -d ' ')
if [ "$MCP_LEAKS" -eq 0 ]; then
  pass "No MCP tool references in skills/agents"
else
  fail "$MCP_LEAKS MCP references found — ido4specs has zero runtime coupling to @ido4/mcp"
  grep -rnE 'mcp__|parse_strategic_spec|ingest_spec|@ido4/mcp' \
    "$PLUGIN_DIR/skills/" "$PLUGIN_DIR/agents/" 2>/dev/null | head -5 | sed 's/^/    /'
fi

# No ido4dev skill references
IDO4DEV_LEAKS=$(grep -rE '/ido4dev:decompose|/ido4dev:spec-validate' \
  "$PLUGIN_DIR/skills/" "$PLUGIN_DIR/agents/" 2>/dev/null | wc -l | tr -d ' ')
if [ "$IDO4DEV_LEAKS" -eq 0 ]; then
  pass "No stale ido4dev skill references"
else
  fail "$IDO4DEV_LEAKS stale ido4dev skill references found"
fi

echo ""

# ─── TEST 11: Methodology Neutrality ───────────────────────

echo "--- Test 11: Methodology Neutrality ---"

# Skills and agents should not reference methodology concepts.
# The references/technical-spec-format.md is allowed to mention methodology
# as downstream context, so it's excluded from this check.
METHODOLOGY_LEAKS=$(grep -rnE '\b(Scrum|Shape-Up|Hydro|BRE|methodology profile|container-bound)\b' \
  "$PLUGIN_DIR/skills/" "$PLUGIN_DIR/agents/" 2>/dev/null | wc -l | tr -d ' ')
if [ "$METHODOLOGY_LEAKS" -eq 0 ]; then
  pass "No methodology-specific references in skills/agents"
else
  fail "$METHODOLOGY_LEAKS methodology references found — ido4specs is methodology-neutral"
  grep -rnE '\b(Scrum|Shape-Up|Hydro|BRE|methodology profile|container-bound)\b' \
    "$PLUGIN_DIR/skills/" "$PLUGIN_DIR/agents/" 2>/dev/null | head -5 | sed 's/^/    /'
fi

echo ""

# ─── TEST 12: Filename Conventions (§5 of Phase 2 plan) ───

echo "--- Test 12: Filename Conventions ---"

# Old ido4dev naming must be gone from all skills/agents.
# The [^-] guard prevents false positives on -tech-canvas.md.
STALE_CANVAS=$(grep -rnE '\-canvas\.md[^-]' "$PLUGIN_DIR/skills/" "$PLUGIN_DIR/agents/" 2>/dev/null | grep -v '\-tech-canvas\.md' | wc -l | tr -d ' ')
STALE_TECHNICAL=$(grep -rnE '\-technical\.md' "$PLUGIN_DIR/skills/" "$PLUGIN_DIR/agents/" 2>/dev/null | wc -l | tr -d ' ')

if [ "$STALE_CANVAS" -eq 0 ]; then
  pass "No stale '-canvas.md' references (all should be '-tech-canvas.md')"
else
  fail "$STALE_CANVAS stale '-canvas.md' references found"
fi

if [ "$STALE_TECHNICAL" -eq 0 ]; then
  pass "No stale '-technical.md' references (all should be '-tech-spec.md')"
else
  fail "$STALE_TECHNICAL stale '-technical.md' references found"
fi

# The canonical suffixes should appear in skills (at least one each)
if grep -rq '\-tech-canvas\.md' "$PLUGIN_DIR/skills/" 2>/dev/null; then
  pass "Canonical '-tech-canvas.md' suffix referenced in skills"
else
  warn "No '-tech-canvas.md' references found in skills"
fi

if grep -rq '\-tech-spec\.md' "$PLUGIN_DIR/skills/" 2>/dev/null; then
  pass "Canonical '-tech-spec.md' suffix referenced in skills"
else
  warn "No '-tech-spec.md' references found in skills"
fi

echo ""

# ─── TEST 13: Shell Script Quality ─────────────────────────

echo "--- Test 13: Shell Script Quality ---"

for script_path in "$PLUGIN_DIR"/scripts/*.sh; do
  [ -f "$script_path" ] || continue
  script_name=$(basename "$script_path")

  if [ -x "$script_path" ]; then
    pass "scripts/$script_name is executable"
  else
    fail "scripts/$script_name is NOT executable (run: chmod +x scripts/$script_name)"
  fi

  if bash -n "$script_path" 2>/dev/null; then
    pass "scripts/$script_name has valid bash syntax"
  else
    SYNTAX_ERR=$(bash -n "$script_path" 2>&1)
    fail "scripts/$script_name has bash syntax errors: $SYNTAX_ERR"
  fi
done

if command -v shellcheck >/dev/null 2>&1; then
  for script_path in "$PLUGIN_DIR"/scripts/*.sh; do
    [ -f "$script_path" ] || continue
    script_name=$(basename "$script_path")
    if shellcheck -S error "$script_path" >/dev/null 2>&1; then
      pass "shellcheck (error level): scripts/$script_name"
    else
      ERR=$(shellcheck -S error "$script_path" 2>&1 | head -5)
      fail "shellcheck: scripts/$script_name — $ERR"
    fi
  done
else
  warn "shellcheck not installed locally — shell quality checks skipped"
fi

# Validate the validation script itself
if [ -x "$PLUGIN_DIR/tests/validate-plugin.sh" ]; then
  pass "tests/validate-plugin.sh is executable"
else
  warn "tests/validate-plugin.sh is not executable (run: chmod +x tests/validate-plugin.sh)"
fi

echo ""

# ─── TEST 14: claude plugin validate ─────────────────────

echo "--- Test 14: claude plugin validate ---"

if command -v claude >/dev/null 2>&1; then
  if claude plugin validate "$PLUGIN_DIR" >/dev/null 2>&1; then
    pass "claude plugin validate passes"
  else
    ERR=$(claude plugin validate "$PLUGIN_DIR" 2>&1 | tail -5)
    fail "claude plugin validate failed: $ERR"
  fi
else
  warn "claude CLI not available — skipping plugin validate"
fi

echo ""

# ─── SUMMARY ────────────────────────────────────────────

echo "========================================="
echo "RESULTS: $PASS passed, $FAIL failed, $WARN warnings"
echo "========================================="

if [ "$FAIL" -gt 0 ]; then
  echo "STATUS: FAIL — $FAIL issues must be fixed"
  exit 1
else
  echo "STATUS: PASS"
  exit 0
fi
