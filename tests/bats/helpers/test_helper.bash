#!/usr/bin/env bash
#
# BATS Test Helpers - @zairakai/js-dev-tools
# Common utilities for BATS tests
#

# Setup test environment
setup_test_env() {
  # Create temporary test directory
  export TEST_TEMP_DIR="${BATS_TEST_TMPDIR}/zairakai-test-$$"
  mkdir -p "$TEST_TEMP_DIR"

  # Export project root (tests are in tests/bats/{unit,integration}/)
  export PROJECT_ROOT
  PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"

  # Export scripts directory
  export SCRIPT_DIR="${PROJECT_ROOT}/scripts"

  # Source config.sh for helpers
  # DEV_TOOLS_ROOT must be set before sourcing (config.sh uses it for path resolution)
  export DEV_TOOLS_ROOT="${PROJECT_ROOT}"

  # config.sh sets "set -euo pipefail" and its own traps: left in the test, they replace what Bats relies on, and a test
  # that fails ends silently, without a "not ok". The options and the traps of Bats are put back.
  local saved_flags="$-" saved_pipefail saved_traps
  saved_pipefail="$(set +o | grep ' pipefail$')"
  saved_traps="$(trap -p EXIT INT TERM)"

  # shellcheck source=../../../scripts/config.sh
  source "${SCRIPT_DIR}/config.sh" 2>/dev/null || true

  set +eu
  [[ "$saved_flags" == *e* ]] && set -e
  [[ "$saved_flags" == *u* ]] && set -u
  eval "$saved_pipefail"
  trap - EXIT INT TERM
  eval "$saved_traps"
}

# Teardown test environment
teardown_test_env() {
  if [[ -n "${TEST_TEMP_DIR:-}" ]] && [[ -d "$TEST_TEMP_DIR" ]]; then
    rm -rf "$TEST_TEMP_DIR"
  fi
}

# Create a minimal fake consumer project for integration tests
setup_fake_project() {
  local project_dir="${TEST_TEMP_DIR}/fake-project"
  mkdir -p "${project_dir}/node_modules/.bin"
  mkdir -p "${project_dir}/node_modules/@zairakai/js-dev-tools"

  # Symlink dev-tools scripts into the fake project
  ln -sf "${PROJECT_ROOT}/scripts" "${project_dir}/node_modules/@zairakai/js-dev-tools/scripts"
  ln -sf "${PROJECT_ROOT}/config"  "${project_dir}/node_modules/@zairakai/js-dev-tools/config"
  ln -sf "${PROJECT_ROOT}/stubs"   "${project_dir}/node_modules/@zairakai/js-dev-tools/stubs"

  # Create minimal package.json
  echo '{"name":"fake-project","version":"1.0.0"}' > "${project_dir}/package.json"

  export FAKE_PROJECT="${project_dir}"
}

# Assert file exists
assert_file_exists() {
  local file="$1"

  if [[ ! -f "$file" ]]; then
    echo "ASSERTION FAILED: File does not exist: $file" >&2
    return 1
  fi
}

# Assert file does not exist
assert_file_not_exists() {
  local file="$1"

  if [[ -f "$file" ]]; then
    echo "ASSERTION FAILED: File exists but shouldn't: $file" >&2
    return 1
  fi
}

# Assert directory exists
assert_dir_exists() {
  local dir="$1"

  if [[ ! -d "$dir" ]]; then
    echo "ASSERTION FAILED: Directory does not exist: $dir" >&2
    return 1
  fi
}

# Assert a file contains a fixed string
assert_file_contains() {
  local file="$1"
  local text="$2"

  if ! grep -qF -- "$text" "$file"; then
    echo "ASSERTION FAILED: ${file} does not contain: ${text}" >&2
    return 1
  fi
}

# Assert a file does not contain a fixed string
assert_file_not_contains() {
  local file="$1"
  local text="$2"

  if grep -qF -- "$text" "$file"; then
    echo "ASSERTION FAILED: ${file} contains: ${text}" >&2
    return 1
  fi
}

# Assert two files are identical
assert_same_file() {
  if ! diff -q "$1" "$2" >/dev/null; then
    echo "ASSERTION FAILED: $1 and $2 differ" >&2
    return 1
  fi
}

# Assert output contains string
# shellcheck disable=SC2154  # $output is a BATS magic variable
assert_output_contains() {
  local needle="$1"

  if [[ ! "$output" =~ $needle ]]; then
    echo "ASSERTION FAILED: Output does not contain: $needle" >&2
    echo "Actual output: $output" >&2
    return 1
  fi
}

# Assert output equals string
# shellcheck disable=SC2154  # $output is a BATS magic variable
assert_output_equals() {
  local expected="$1"

  if [[ "$output" != "$expected" ]]; then
    echo "ASSERTION FAILED: Output mismatch" >&2
    echo "Expected: $expected" >&2
    echo "Actual:   $output" >&2
    return 1
  fi
}

# Create test file with content
create_test_file() {
  local filepath="$1"
  local content="${2:-test content}"

  mkdir -p "$(dirname "$filepath")"
  echo "$content" > "$filepath"
}

# Mock a binary in PATH
mock_command() {
  local command_name="$1"
  local mock_output="${2:-}"
  local mock_exit_code="${3:-0}"

  local mock_dir="${TEST_TEMP_DIR}/bin"
  mkdir -p "$mock_dir"

  cat > "${mock_dir}/${command_name}" << MOCK_EOF
#!/usr/bin/env bash
echo "${mock_output}"
exit ${mock_exit_code}
MOCK_EOF

  chmod +x "${mock_dir}/${command_name}"
  export PATH="${mock_dir}:${PATH}"
}

# Command that runs the given shell body, found first in the PATH
fake_command() {
  local command_name="$1"
  local body="$2"
  local fake_dir="${TEST_TEMP_DIR}/fake-bin"

  mkdir -p "$fake_dir"
  printf '#!/usr/bin/env bash\n%s\n' "$body" > "${fake_dir}/${command_name}"
  chmod +x "${fake_dir}/${command_name}"

  case ":${PATH}:" in
    *":${fake_dir}:"*) ;;
    *) export PATH="${fake_dir}:${PATH}" ;;
  esac
}

# Project with a copy of scripts/ (the scripts take their root from their own folder), a node_modules/ (config.sh refuses a
# project without it) and a package.json
make_script_project() {
  export PROJECT="${TEST_TEMP_DIR}/project"

  mkdir -p "${PROJECT}/node_modules"
  cp -R "${PROJECT_ROOT}/scripts" "${PROJECT}/scripts"

  # update-dependencies.mjs imports semver: the copy of the scripts finds it where its own folder says
  if [[ -d "${PROJECT_ROOT}/node_modules/semver" ]]; then
    ln -s "${PROJECT_ROOT}/node_modules/semver" "${PROJECT}/node_modules/semver"
  fi
  printf '{\n  "name": "sample"\n}\n' > "${PROJECT}/package.json"
}

# Skips the test when a tool that it needs is not installed (the image of the pipeline has fewer tools than a machine)
require_command() {
  command -v "$1" > /dev/null 2>&1 || skip "$1 is not installed"
}

# Project with the layout of an installed package (node_modules/@zairakai/js-dev-tools), set up and with the configurations
# published: a project that ran `npm install`, then the setup
make_installed_project() {
  export PROJECT="${TEST_TEMP_DIR}/project"
  export PACKAGE="${PROJECT}/node_modules/@zairakai/js-dev-tools"
  export DEV_TOOLS_NO_DOCKER=true

  local path group

  mkdir -p "${PACKAGE}"
  for path in scripts stubs config tools .editorconfig package.json; do
    cp -R "${PROJECT_ROOT}/${path}" "${PACKAGE}/"
  done

  printf '{\n  "name": "acme-sample"\n}\n' > "${PROJECT}/package.json"

  (cd "${PROJECT}" && bash "${PACKAGE}/scripts/setup-project.sh" --silent) > /dev/null 2>&1
  for group in quality style testing; do
    (cd "${PROJECT}" && bash "${PACKAGE}/scripts/setup-project.sh" "--publish=${group}" --silent) > /dev/null 2>&1
  done
}

