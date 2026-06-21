#!/usr/bin/env bash
#
# Tests for bin/compile (.buildcache gitignore-like behavior).
# Run with: bash test/run.sh

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMPILE="${REPO_DIR}/bin/compile"

FAILURES=0

# assert_cached <cache_dir> <relative-path>
assert_cached() {
  if [ -e "${1}/buildcache/${2}" ]; then
    echo "  ok: ${2} cached"
  else
    echo "  FAIL: expected ${2} to be cached"
    FAILURES=$((FAILURES + 1))
  fi
}

# assert_not_cached <cache_dir> <relative-path>
assert_not_cached() {
  if [ -e "${1}/buildcache/${2}" ]; then
    echo "  FAIL: expected ${2} to NOT be cached"
    FAILURES=$((FAILURES + 1))
  else
    echo "  ok: ${2} not cached"
  fi
}

run_case() {
  echo "== ${1} =="
}

# ---------------------------------------------------------------------------
# Set up a sample build directory
# ---------------------------------------------------------------------------
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

BUILD="${WORK}/build"
CACHE="${WORK}/cache"
mkdir -p "${BUILD}" "${CACHE}"

mkdir -p "${BUILD}/code/server/node_modules/.cache"
mkdir -p "${BUILD}/code/client/node_modules"
mkdir -p "${BUILD}/logs"
echo "dep" > "${BUILD}/code/server/node_modules/dep.js"
echo "junk" > "${BUILD}/code/server/node_modules/.cache/junk.tmp"
echo "client" > "${BUILD}/code/client/node_modules/client.js"
echo "single" > "${BUILD}/single.txt"
echo "a" > "${BUILD}/logs/a.log"
echo "b" > "${BUILD}/logs/b.log"
echo "data" > "${BUILD}/data.json"

# ---------------------------------------------------------------------------
# Case 1: direct file, folder, glob, and "!" exclusion
# ---------------------------------------------------------------------------
run_case "paths, folders, globs and exclusions"
cat > "${BUILD}/.buildcache" <<'EOF'
# a comment line and a blank line below

single.txt
code/server/node_modules
!code/server/node_modules/.cache
logs/*.log
!logs/b.log
EOF

CACHE1="${CACHE}/c1"
mkdir -p "${CACHE1}"
"${COMPILE}" "${BUILD}" "${CACHE1}" > /dev/null

assert_cached     "${CACHE1}" "single.txt"
assert_cached     "${CACHE1}" "code/server/node_modules/dep.js"
assert_not_cached "${CACHE1}" "code/server/node_modules/.cache/junk.tmp"
assert_cached     "${CACHE1}" "logs/a.log"
assert_not_cached "${CACHE1}" "logs/b.log"
assert_not_cached "${CACHE1}" "data.json"

# ---------------------------------------------------------------------------
# Case 2: recursive ** glob
# ---------------------------------------------------------------------------
run_case "recursive ** glob"
cat > "${BUILD}/.buildcache" <<'EOF'
**/node_modules
EOF

CACHE2="${CACHE}/c2"
mkdir -p "${CACHE2}"
"${COMPILE}" "${BUILD}" "${CACHE2}" > /dev/null

assert_cached "${CACHE2}" "code/server/node_modules/dep.js"
assert_cached "${CACHE2}" "code/client/node_modules/client.js"

# ---------------------------------------------------------------------------
# Case 3: tilde (home) paths still work
# ---------------------------------------------------------------------------
run_case "tilde home paths"
HOME_BACKUP="${HOME}"
export HOME="${WORK}/home"
mkdir -p "${HOME}/.npm"
echo "cfg" > "${HOME}/.npm/cfg"

cat > "${BUILD}/.buildcache" <<'EOF'
~/.npm
EOF

CACHE3="${CACHE}/c3"
mkdir -p "${CACHE3}"
"${COMPILE}" "${BUILD}" "${CACHE3}" > /dev/null
export HOME="${HOME_BACKUP}"

assert_cached "${CACHE3}" "__CACHE_HOME__/.npm/cfg"

# ---------------------------------------------------------------------------
echo
if [ "${FAILURES}" -eq 0 ]; then
  echo "All tests passed."
  exit 0
else
  echo "${FAILURES} assertion(s) failed."
  exit 1
fi
