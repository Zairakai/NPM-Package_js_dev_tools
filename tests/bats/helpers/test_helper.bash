#!/usr/bin/env bash
#
# BATS Test Helpers — @zairakai/js-dev-tools
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
    # shellcheck source=../../../scripts/config.sh
    source "${SCRIPT_DIR}/config.sh" 2>/dev/null || true
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
