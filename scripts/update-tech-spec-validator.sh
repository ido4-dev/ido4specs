#!/bin/bash
# Update the bundled @ido4/tech-spec-format validator from npm or a local ido4 build.
#
# Usage:
#   ./scripts/update-tech-spec-validator.sh 0.1.0            # Fetch from npm
#   ./scripts/update-tech-spec-validator.sh ~/dev/ido4       # Copy from local build
#
# The bundle is a single self-contained .js file (~15 KB) with zero npm dependencies.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$(dirname "$SCRIPT_DIR")"
DIST_DIR="$PLUGIN_DIR/dist"
BUNDLE_FILE="$DIST_DIR/tech-spec-validator.js"
VERSION_FILE="$DIST_DIR/.tech-spec-format-version"
CHECKSUM_FILE="$DIST_DIR/.tech-spec-format-checksum"

usage() {
  echo "Usage: $0 <version|path-to-ido4>"
  echo ""
  echo "Examples:"
  echo "  $0 0.1.0              # Fetch from npm, extract bundle"
  echo "  $0 ~/dev/ido4         # Copy from local build"
  exit 1
}

[ $# -eq 1 ] || usage

SOURCE="$1"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$DIST_DIR"

if [ -d "$SOURCE" ]; then
  LOCAL_BUNDLE="$SOURCE/packages/tech-spec-format/dist/tech-spec-validator.bundle.js"
  if [ ! -f "$LOCAL_BUNDLE" ]; then
    echo "ERROR: Bundle not found at $LOCAL_BUNDLE"
    echo "Run 'npm run build:bundle -w @ido4/tech-spec-format' in $SOURCE first"
    exit 1
  fi
  cp "$LOCAL_BUNDLE" "$BUNDLE_FILE"
  VERSION=$(head -3 "$BUNDLE_FILE" | grep -o 'v[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*' | head -1 | sed 's/^v//' || echo "unknown")
  echo "Copied bundle from local build (v$VERSION)"
else
  VERSION="$SOURCE"
  echo "Fetching @ido4/tech-spec-format@$VERSION from npm..."
  cd "$TMPDIR"
  npm pack "@ido4/tech-spec-format@$VERSION" --silent 2>&1
  tar xzf ido4-tech-spec-format-*.tgz

  if [ -f "package/dist/tech-spec-validator.bundle.js" ]; then
    cp "package/dist/tech-spec-validator.bundle.js" "$BUNDLE_FILE"
    echo "Extracted bundle from npm package"
  else
    echo "Bundle not in npm package. Building from extracted source..."
    if ! command -v npx &>/dev/null; then
      echo "ERROR: npx not found. Install Node.js or use a local ido4 build instead."
      exit 1
    fi
    cd package
    npx esbuild src/cli.ts --bundle --platform=node --target=node18 \
      --format=cjs --outfile="$BUNDLE_FILE" --minify \
      --banner:js="// @ido4/tech-spec-format v$VERSION | bundled $(date +%Y-%m-%d)"
    echo "Built bundle from source"
  fi
fi

# Smoke test: run against the example technical spec
TEST_SPEC="$PLUGIN_DIR/references/example-technical-spec.md"
if [ -f "$TEST_SPEC" ]; then
  echo "Smoke testing bundle..."
  RESULT=$(node "$BUNDLE_FILE" "$TEST_SPEC" 2>&1) || {
    echo "ERROR: Bundle smoke test failed"
    echo "$RESULT"
    rm -f "$BUNDLE_FILE"
    exit 1
  }
  echo "$RESULT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    assert 'valid' in d, 'missing valid field'
    assert 'meta' in d, 'missing meta field'
    assert 'metrics' in d, 'missing metrics field'
    print(f'  Result: valid={d[\"valid\"]}, groups={d[\"metrics\"][\"groupCount\"]}, tasks={d[\"metrics\"][\"taskCount\"]}')
except Exception as e:
    print(f'ERROR: Invalid parser output — {e}', file=sys.stderr)
    sys.exit(1)
" || {
    echo "ERROR: Bundle output is not valid parser JSON"
    rm -f "$BUNDLE_FILE"
    exit 1
  }
  echo "Smoke test passed."
else
  echo "WARNING: No test fixture found at $TEST_SPEC — skipping smoke test"
fi

# Write version marker
printf "%s\n" "$VERSION" > "$VERSION_FILE"

# Write checksum
shasum -a 256 "$BUNDLE_FILE" | sed "s|$DIST_DIR/||" > "$CHECKSUM_FILE"

SIZE=$(wc -c < "$BUNDLE_FILE" | tr -d ' ')
echo ""
echo "Updated tech-spec-validator.js to v$VERSION"
echo "  Bundle:   $BUNDLE_FILE ($SIZE bytes)"
echo "  Version:  $VERSION_FILE"
echo "  Checksum: $CHECKSUM_FILE"
