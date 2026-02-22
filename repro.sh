#!/usr/bin/env bash
# Repro: `mr sync` updates devenv.lock/flake.lock but NOT nested megarepo.lock files
#
# Prerequisites: `mr` (megarepo CLI) in PATH
#
# Uses real public repos that use megarepo:
# - livestorejs/livestore — a real megarepo that references effect-ts/effect
# - effect-ts/effect — shared dependency
#
# After syncing, livestore's devenv.lock effect entry is updated to match
# the parent, but livestore's megarepo.lock effect entry is NOT.
set -euo pipefail

echo "=== Setup ==="
echo "Creating a parent megarepo with livestore + effect as members."
echo "livestore is itself a megarepo whose megarepo.lock references effect."
echo ""

# Create a temporary parent megarepo
TMPDIR=$(mktemp -d)
trap "rm -rf '$TMPDIR'" EXIT

cd "$TMPDIR"

cat > megarepo.json << 'MJSON'
{
  "members": {
    "effect": "effect-ts/effect",
    "livestore": "livestorejs/livestore#dev"
  }
}
MJSON

echo "=== Step 1: mr sync (ensure members exist in store) ==="
mr sync 2>&1 | tail -1 | python3 -c "
import json, sys
d = json.load(sys.stdin)
for r in d['results']:
    print(f'  {r[\"name\"]}: {r[\"status\"]} @ {r.get(\"commit\",\"?\")[:12]}')
" || true
echo ""

# The parent megarepo.lock now has commits for both members.
# The key insight: the parent's effect commit will differ from
# livestore's megarepo.lock effect commit (because livestore's lock
# was committed at an earlier point in time).

echo "=== Step 2: Parent megarepo.lock ==="
PARENT_EFFECT=$(python3 -c "import json; print(json.load(open('megarepo.lock'))['members']['effect']['commit'])")
echo "  effect: ${PARENT_EFFECT:0:12}"
echo ""

echo "=== Step 3: Nested megarepo.lock (repos/livestore/megarepo.lock) ==="
NESTED_LOCK="repos/livestore/megarepo.lock"
if [ ! -f "$NESTED_LOCK" ]; then
  echo "  ERROR: $NESTED_LOCK not found"
  exit 1
fi

NESTED_EFFECT=$(python3 -c "
import json
lock = json.load(open('$NESTED_LOCK'))
e = lock['members'].get('effect')
print(e['commit'] if e else 'NOT FOUND')
")
echo "  effect: ${NESTED_EFFECT:0:12}"
echo ""

echo "=== Step 4: Check devenv.lock (for comparison — this IS synced) ==="
DEVENV_LOCK="repos/livestore/devenv.lock"
if [ -f "$DEVENV_LOCK" ]; then
  python3 -c "
import json
devenv = json.load(open('$DEVENV_LOCK'))
for name, node in devenv['nodes'].items():
    locked = node.get('locked', {})
    if locked.get('owner') == 'effect-ts' and locked.get('repo') == 'effect':
        print(f'  devenv.lock/{name}: {locked[\"rev\"][:12]}')
        break
"
else
  echo "  (no devenv.lock)"
fi
echo ""

echo "=== Result ==="
if [ "$PARENT_EFFECT" != "$NESTED_EFFECT" ]; then
  echo "BUG CONFIRMED: mr sync updated devenv.lock but NOT nested megarepo.lock"
  echo ""
  echo "  Parent megarepo.lock  → effect: ${PARENT_EFFECT:0:12}"
  echo "  Nested megarepo.lock  → effect: ${NESTED_EFFECT:0:12}  ← STALE"
  echo "  Nested devenv.lock    → effect: (updated by nix lock sync)"
  echo ""
  echo "Expected: mr sync should also update megarepo.lock entries in nested megarepos"
  echo "Actual:   only devenv.lock/flake.lock are updated"
  exit 1
else
  echo "No drift — bug may be fixed"
  exit 0
fi
