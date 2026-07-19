#!/bin/bash
# Shared helpers for the code-repo script tests.
#
# The scripts under test are SOURCED, not executed (see the top of
# scripts/code-repo/bitbucket/_api). run_step therefore sources them inside a
# command substitution: a bare `exit 1` in a step then ends that subshell -- it
# reports a failing step without killing the test runner.

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

setup() {
  TEST_TMP=$(mktemp -d)

  BB_FIXTURES="$TEST_TMP/fixtures"
  BB_CALLS="$TEST_TMP/calls.tsv"

  mkdir -p "$BB_FIXTURES"
  : > "$BB_CALLS"

  export BB_FIXTURES BB_CALLS
  export PATH="$REPO_ROOT/tests/stubs:$PATH"

  # The context that build_context exports for every later step.
  export BITBUCKET_TOKEN="test-token"
  export BITBUCKET_WORKSPACE="acme"
  export BITBUCKET_PROJECT_KEY="APP"
  export BITBUCKET_INSTALLATION_URL="https://bitbucket.org"
  export BITBUCKET_API_BASE="https://api.bitbucket.org/2.0"
  export REPOSITORY_SLUG="my-service"
  export REPOSITORY_NAME="my-service"
  export APPLICATION_ID="42"
}

teardown() {
  rm -rf "$TEST_TMP"
}

# clear_context -- drop everything build_context is meant to derive for itself.
# setup() pre-exports that context because it is what the steps AFTER
# build_context consume; a build_context test must start from a clean slate.
clear_context() {
  unset BITBUCKET_TOKEN BITBUCKET_WORKSPACE BITBUCKET_PROJECT_KEY \
    BITBUCKET_INSTALLATION_URL BITBUCKET_API_BASE BITBUCKET_AUTH_METHOD \
    BITBUCKET_OAUTH_KEY BITBUCKET_OAUTH_SECRET REPOSITORY_SLUG
}

# fixture METHOD PATH CODE [BODY]
fixture() {
  local method="$1" path="$2" code="$3" body="${4:-}"
  local key

  key="${method}_$(printf '%s' "$path" | sed -e 's|[^A-Za-z0-9]|_|g')"

  printf '%s' "$code" > "$BB_FIXTURES/${key}.code"
  printf '%s' "$body" > "$BB_FIXTURES/${key}.body"
}

# fixture_seq METHOD PATH N CODE [BODY] -- response for the N-th call.
fixture_seq() {
  local method="$1" path="$2" n="$3" code="$4" body="${5:-}"
  local key

  key="${method}_$(printf '%s' "$path" | sed -e 's|[^A-Za-z0-9]|_|g')"

  printf '%s' "$code" > "$BB_FIXTURES/${key}.${n}.code"
  printf '%s' "$body" > "$BB_FIXTURES/${key}.${n}.body"
}

# run_step NAME -> STEP_OUTPUT, STEP_STATUS
run_step() {
  local step="$1"

  # shellcheck disable=SC1090
  STEP_OUTPUT=$(cd "$REPO_ROOT" && source "scripts/code-repo/bitbucket/$step" 2>&1)
  STEP_STATUS=$?
}

# capture_export NAME VAR -> the value the step exported into VAR
capture_export() {
  local step="$1" var="$2"

  (
    cd "$REPO_ROOT" || exit 1
    # shellcheck disable=SC1090
    source "scripts/code-repo/bitbucket/$step" >/dev/null 2>&1
    printf '%s' "${!var}"
  )
}

# request_body METHOD PATH -> the JSON body sent with that request
request_body() {
  local method="$1" path="$2"

  grep -F "$(printf '%s\t%s\t' "$method" "$path")" "$BB_CALLS" | head -1 | cut -f3
}

assert_status() {
  local expected="$1"

  if [[ "$STEP_STATUS" != "$expected" ]]; then
    echo "  FAIL: expected exit status $expected, got $STEP_STATUS"
    echo "  step output:"
    printf '%s\n' "$STEP_OUTPUT" | sed 's/^/    /'
    return 1
  fi
}

assert_contains() {
  local needle="$1"
  local haystack="${2:-$STEP_OUTPUT}"

  if [[ "$haystack" != *"$needle"* ]]; then
    echo "  FAIL: expected to find '$needle' in:"
    printf '%s\n' "$haystack" | sed 's/^/    /'
    return 1
  fi
}

assert_called() {
  local method="$1" path="$2"

  if ! grep -qF "$(printf '%s\t%s\t' "$method" "$path")" "$BB_CALLS"; then
    echo "  FAIL: expected a '$method $path' call. Calls made:"
    sed 's/^/    /' "$BB_CALLS"
    return 1
  fi
}

assert_called_git() {
  local subcommand="$1"

  # Records are "git<TAB><args...>". Match the subcommand as a whitespace-
  # delimited token anywhere in the args. The leading TAB is itself a boundary,
  # so the first alternative matches a subcommand that comes immediately after
  # it (clone, init, add), while `.*[[:space:]]` matches one that follows other
  # args (push after `-C <dir>`).
  if ! grep -qE "^git([[:space:]]|.*[[:space:]])${subcommand}([[:space:]]|$)" "$BB_CALLS"; then
    echo "  FAIL: expected a 'git $subcommand'. Calls made:"
    sed 's/^/    /' "$BB_CALLS"
    return 1
  fi
}
