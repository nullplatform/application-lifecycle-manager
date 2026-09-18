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
  export BITBUCKET_EMAIL="bot@nullplatform.com"
  export BITBUCKET_API_TOKEN="test-token"
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
  unset BITBUCKET_EMAIL BITBUCKET_API_TOKEN BITBUCKET_WORKSPACE \
    BITBUCKET_PROJECT_KEY BITBUCKET_INSTALLATION_URL BITBUCKET_API_BASE \
    REPOSITORY_SLUG
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

# The locals below are named __lib_* on purpose. These helpers SOURCE the script
# under test, and bash scopes dynamically: a plain `local var` is visible to the
# sourced script, so a step that loops with `for var in ...` -- github/build_context
# does exactly that -- overwrites it, and `${!var}` then reads the wrong variable.
# It does not fail, it returns a plausible wrong answer.

# run_step NAME -> STEP_OUTPUT, STEP_STATUS
run_step() {
  local __lib_step="$1"

  # shellcheck disable=SC1090
  STEP_OUTPUT=$(cd "$REPO_ROOT" && source "scripts/code-repo/bitbucket/$__lib_step" 2>&1)
  STEP_STATUS=$?
}

# capture_export NAME VAR -> the value the step exported into VAR
capture_export() {
  local __lib_step="$1" __lib_var="$2"

  (
    cd "$REPO_ROOT" || exit 1
    # shellcheck disable=SC1090
    source "scripts/code-repo/bitbucket/$__lib_step" >/dev/null 2>&1
    printf '%s' "${!__lib_var}"
  )
}

# request_body METHOD PATH -> the body sent with that request. Newlines come back
# escaped as a literal \n, the way the curl stub records them.
request_body() {
  local method="$1" path="$2"

  grep -F "$(printf '%s\t%s\t' "$method" "$path")" "$BB_CALLS" | head -1 | cut -f3
}

# request_content_type METHOD PATH -> the Content-Type header sent with it
request_content_type() {
  local method="$1" path="$2"

  grep -F "$(printf '%s\t%s\t' "$method" "$path")" "$BB_CALLS" | head -1 | cut -f4
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
# The helpers above are bound to scripts/code-repo/bitbucket. These two are the
# provider-agnostic equivalents, for the steps that live directly under
# scripts/code-repo (resolve_repository_name, generate_secrets, ...).

# run_script_step PATH -> STEP_OUTPUT, STEP_STATUS -- PATH is relative to scripts/
run_script_step() {
  local __lib_step="$1"

  # shellcheck disable=SC1090
  STEP_OUTPUT=$(cd "$REPO_ROOT" && source "scripts/$__lib_step" 2>&1)
  STEP_STATUS=$?
}

# run_code_repo_step NAME -> STEP_OUTPUT, STEP_STATUS
run_code_repo_step() {
  local __lib_step="$1"

  # shellcheck disable=SC1090
  STEP_OUTPUT=$(cd "$REPO_ROOT" && source "scripts/code-repo/$__lib_step" 2>&1)
  STEP_STATUS=$?
}

# capture_code_repo_export NAME VAR -> the value the step exported into VAR
capture_code_repo_export() {
  local __lib_step="$1" __lib_var="$2"

  (
    cd "$REPO_ROOT" || exit 1
    # shellcheck disable=SC1090
    source "scripts/code-repo/$__lib_step" >/dev/null 2>&1
    printf '%s' "${!__lib_var}"
  )
}

# gh_install_sandbox -- a PATH we fully control, for the install_gh cases.
#
# Two reasons it is this elaborate. The runner's own gh (GitHub Actions ships one)
# would make the install branch unreachable and the cases vacuous. And the
# fallback only supports Linux, so `uname` is faked: without it these cases would
# pass on CI and fail on a developer's macOS, which is the wrong way round for a
# path that only ever runs on Linux.
#
# Leaves behind: $GH_SANDBOX_BIN (the curated PATH), $GH_SANDBOX_DEST (where gh is
# installed), $GH_SANDBOX_PKG (the package name the fake release serves) and
# $GH_SANDBOX_SUM (its real checksum). mise fails, as it does on the agent image.
gh_install_sandbox() {
  GH_SANDBOX_BIN="$TEST_TMP/gh-bin"
  GH_SANDBOX_DEST="$TEST_TMP/gh-dest"
  mkdir -p "$GH_SANDBOX_BIN" "$GH_SANDBOX_DEST"

  local missing="" t p
  for t in tar gzip gunzip tr mkdir cp rm chmod mktemp dirname cat sed grep awk cut jq install sh; do
    if p=$(command -v "$t" 2>/dev/null); then
      ln -sf "$p" "$GH_SANDBOX_BIN/$t"
    else
      missing="$missing $t"
    fi
  done

  if ! command -v sha256sum >/dev/null 2>&1 && ! command -v shasum >/dev/null 2>&1; then
    missing="$missing sha256sum-or-shasum"
  fi
  command -v sha256sum >/dev/null 2>&1 && ln -sf "$(command -v sha256sum)" "$GH_SANDBOX_BIN/sha256sum"
  command -v shasum    >/dev/null 2>&1 && ln -sf "$(command -v shasum)"    "$GH_SANDBOX_BIN/shasum"

  if [[ -n "$missing" ]]; then
    echo "  FAIL: this host is missing tools the sandbox needs:$missing"
    return 1
  fi

  local arch
  case "$(uname -m)" in
    x86_64|amd64)  arch="amd64" ;;
    aarch64|arm64) arch="arm64" ;;
    *)             arch="amd64" ;;
  esac

  # Linux, whatever the host really is.
  # Single quotes on purpose: $1 belongs to the generated stub, not to us.
  # shellcheck disable=SC2016
  printf '#!/bin/bash\ncase "$1" in -s) echo Linux ;; -m) echo %s ;; *) echo Linux ;; esac\n' \
    "$( [[ "$arch" == "amd64" ]] && echo x86_64 || echo aarch64 )" > "$GH_SANDBOX_BIN/uname"
  chmod +x "$GH_SANDBOX_BIN/uname"

  # mise present and broken, exactly like the agent image.
  cat > "$GH_SANDBOX_BIN/mise" <<'MISE'
#!/bin/bash
echo "mise ERROR GitHub attestations verification failed" >&2
exit 1
MISE
  chmod +x "$GH_SANDBOX_BIN/mise"

  GH_SANDBOX_PKG="gh_2.101.0_linux_${arch}"

  mkdir -p "$TEST_TMP/gh-src/$GH_SANDBOX_PKG/bin"
  printf '#!/bin/bash\necho "gh version 2.101.0"\n' > "$TEST_TMP/gh-src/$GH_SANDBOX_PKG/bin/gh"
  chmod +x "$TEST_TMP/gh-src/$GH_SANDBOX_PKG/bin/gh"
  tar czf "$TEST_TMP/gh-release.tgz" -C "$TEST_TMP/gh-src" "$GH_SANDBOX_PKG"

  if command -v sha256sum >/dev/null 2>&1; then
    GH_SANDBOX_SUM=$(sha256sum "$TEST_TMP/gh-release.tgz" | cut -d' ' -f1)
  else
    GH_SANDBOX_SUM=$(shasum -a 256 "$TEST_TMP/gh-release.tgz" | cut -d' ' -f1)
  fi

  # Serves the tarball and the checksums file. $GH_SANDBOX_BAD_SUM corrupts the
  # published checksum; $GH_SANDBOX_CURL_FAIL makes every request fail while still
  # printing the url, the way real curl does with -w '%{url_effective}'.
  cat > "$GH_SANDBOX_BIN/curl" <<CURL
#!/bin/bash
out=""; url=""
while [[ \$# -gt 0 ]]; do
  case "\$1" in -o) out="\$2"; shift 2 ;; -*) shift ;; *) url="\$1"; shift ;; esac
done
if [[ -n "\$GH_SANDBOX_CURL_FAIL" ]]; then printf '%s' "\$url"; exit 6; fi
if [[ "\$url" == *checksums.txt ]]; then
  printf '%s  %s\n' "\${GH_SANDBOX_BAD_SUM:-$GH_SANDBOX_SUM}" "$GH_SANDBOX_PKG.tar.gz" > "\$out"
else
  cp "$TEST_TMP/gh-release.tgz" "\$out"
fi
exit 0
CURL
  chmod +x "$GH_SANDBOX_BIN/curl"

  export PATH="$GH_SANDBOX_BIN"
  export GH_CLI_VERSION="2.101.0"
  export GH_INSTALL_DIR="$GH_SANDBOX_DEST"
}

# secret_fixture ID JSON -- the SecretString the aws stub returns for that id.
secret_fixture() {
  local key

  key="secret_$(printf '%s' "$1" | sed -e 's|[^A-Za-z0-9]|_|g')"
  printf '%s' "$2" > "$BB_FIXTURES/${key}.body"
}

# wizard_rule -- the REPOSITORY_NAME_RULE most resolve_repository_name cases use:
# a two-branch wizard (.NET / Node) with a free-name fallback for the branches
# that ask for nothing else. It mirrors the shape of a real metadata
# specification, so the cases read the way the wizard is filled in.
#
# The fallback is the last entry and carries no `condition`, which is how the
# rule spells "matches anything": branches are tried in order, so a catch-all
# anywhere but last would shadow the ones after it.
wizard_rule() {
  cat <<'JSON'
{
  "branches": [
    {
      "condition": { ".application.metadata.application.architecture": ".NET" },
      "naming_pattern": "{.application.metadata.application.architecture}-{.application.metadata.application.dotnet_type}-{.application.metadata.application.domain}-{.application.metadata.application.subdomain}"
    },
    {
      "condition": { ".application.metadata.application.architecture": "Node" },
      "naming_pattern": "{.application.metadata.application.architecture}-{.application.metadata.application.node_type}-{.application.metadata.application.domain}-{.application.metadata.application.subdomain}"
    },
    {
      "naming_pattern": "{.application.metadata.application.architecture}-{.application.metadata.application.free_name}"
    }
  ]
}
JSON
}

# wizard_context [NAMESPACE_SLUG] -- the $CONTEXT base_context builds, wrapped
# around whatever $APPLICATION currently holds. Only the cases that reach outside
# the application document need it; the step assembles the same shape itself when
# CONTEXT is unset, which is what keeps the rest of the cases to one variable.
wizard_context() {
  jq -nc --argjson app "$APPLICATION" --arg ns "${1:-acme}" \
    '{application: $app, namespace: {slug: $ns}, account: {slug: "root"}}'
}

# wizard_metadata KEY=VALUE... -- an $APPLICATION document carrying those wizard
# answers under the "application" metadata key.
#
# It carries a template_id because that is what a real creation looks like: the
# console sets one whenever the application is created from a template, and its
# absence is what marks an import. A case that wants the import path deletes it.
wizard_metadata() {
  local pairs="{}" pair

  for pair in "$@"; do
    pairs=$(jq -c --arg k "${pair%%=*}" --arg v "${pair#*=}" '. + {($k): $v}' <<<"$pairs")
  done

  jq -nc --argjson md "$pairs" '{repository_url: null, template_id: 1777342392, metadata: {application: $md}}'
}
