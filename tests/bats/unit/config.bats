#!/usr/bin/env bats
#
# Unit Tests for scripts/config.sh
# Tests core helper functions available after sourcing config.sh
#

load '../helpers/test_helper'

setup() {
    setup_test_env
}

teardown() {
    teardown_test_env
}

# ============================================================================
# Error Counter
# ============================================================================

@test "init_error_counter initializes counter to 0" {
    init_error_counter
    result="$(get_error_count)"
    [ "$result" -eq 0 ]
}

@test "increment_error_counter increases count" {
    init_error_counter
    increment_error_counter
    increment_error_counter
    result="$(get_error_count)"
    [ "$result" -eq 2 ]
}

@test "exit_with_error_count returns 0 when no errors" {
    init_error_counter
    run exit_with_error_count "Test Checks"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "All Test Checks Passed" ]]
}

@test "exit_with_error_count returns 1 when errors exist" {
    init_error_counter
    increment_error_counter
    increment_error_counter
    run exit_with_error_count "Test Checks"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "2 Test Checks Failed" ]]
}

@test "run_check increments counter on failure" {
    init_error_counter
    run_check "Failing Check" "false" || true
    result="$(get_error_count)"
    [ "$result" -eq 1 ]
}

@test "run_check does not increment counter on success" {
    init_error_counter
    run_check "Passing Check" "true"
    result="$(get_error_count)"
    [ "$result" -eq 0 ]
}

# ============================================================================
# command_exists
# ============================================================================

@test "command_exists returns 0 for existing command" {
    run command_exists "bash"
    [ "$status" -eq 0 ]
}

@test "command_exists returns 1 for non-existing command" {
    run command_exists "nonexistent_command_xyz"
    [ "$status" -eq 1 ]
}

# ============================================================================
# ensure_dir
# ============================================================================

@test "ensure_dir creates directory if not exists" {
    local test_dir="${TEST_TEMP_DIR}/new_dir"
    ensure_dir "$test_dir"
    [ -d "$test_dir" ]
}

@test "ensure_dir does not fail if directory already exists" {
    local test_dir="${TEST_TEMP_DIR}/existing_dir"
    mkdir -p "$test_dir"
    run ensure_dir "$test_dir"
    [ "$status" -eq 0 ]
    [ -d "$test_dir" ]
}

# ============================================================================
# has_files
# ============================================================================

@test "has_files returns 0 for a plain single-extension glob with a match" {
    create_test_file "${TEST_TEMP_DIR}/resources/index.scss" "// scss"
    run has_files "${TEST_TEMP_DIR}/resources/"**/*.scss
    [ "$status" -eq 0 ]
}

@test "has_files returns 1 for a plain single-extension glob with no match" {
    mkdir -p "${TEST_TEMP_DIR}/resources"
    run has_files "${TEST_TEMP_DIR}/resources/"**/*.scss
    [ "$status" -eq 1 ]
}

# Regression for the bug found in nexus (2026-07-02): a brace-alternation
# pattern passed as a single quoted argument used to always report "no files"
# because bash never brace-expands the contents of a variable — only unquoted
# literal text at the call site. has_files must be called with the brace
# portion left unquoted so the shell splits it into separate arguments.
@test "has_files matches when called with the brace portion left unquoted (regression)" {
    create_test_file "${TEST_TEMP_DIR}/resources/js/Foo.vue" "<template />"
    run has_files "${TEST_TEMP_DIR}/resources/js/"**/*.{js,ts,vue,jsx,tsx}
    [ "$status" -eq 0 ]
}

@test "has_files returns 1 when called with the brace portion left unquoted and no match exists" {
    mkdir -p "${TEST_TEMP_DIR}/resources/js"
    run has_files "${TEST_TEMP_DIR}/resources/js/"**/*.{js,ts,vue,jsx,tsx}
    [ "$status" -eq 1 ]
}

@test "has_files still returns 1 for a literal quoted brace pattern (documents the pitfall)" {
    create_test_file "${TEST_TEMP_DIR}/resources/js/Foo.vue" "<template />"
    # Entirely quoted — brace expansion cannot happen here. This is the exact
    # shape of the bug: it must fail even though a matching file exists.
    run has_files "${TEST_TEMP_DIR}/resources/js/**/*.{js,ts,vue,jsx,tsx}"
    [ "$status" -eq 1 ]
}

@test "has_files returns 0 when any of several patterns matches" {
    create_test_file "${TEST_TEMP_DIR}/resources/js/Foo.vue" "<template />"
    run has_files "${TEST_TEMP_DIR}/resources/js/"*.ts "${TEST_TEMP_DIR}/resources/js/"*.vue
    [ "$status" -eq 0 ]
}

@test "has_files returns 1 when none of several patterns match" {
    mkdir -p "${TEST_TEMP_DIR}/resources/js"
    run has_files "${TEST_TEMP_DIR}/resources/js/"*.ts "${TEST_TEMP_DIR}/resources/js/"*.jsx
    [ "$status" -eq 1 ]
}

# ============================================================================
# resolve_config (4-level cascade: project root → config/dev-tools/ → config/ → DEV_TOOLS_ROOT bundled)
# ============================================================================

@test "resolve_config returns file at project root (level 1)" {
    local old_project_root="$PROJECT_ROOT"
    local old_dev_tools_root="$DEV_TOOLS_ROOT"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export DEV_TOOLS_ROOT="${PROJECT_ROOT}"

    create_test_file "${TEST_TEMP_DIR}/eslint.config.js" "// root override"
    create_test_file "${TEST_TEMP_DIR}/config/dev-tools/eslint.config.js" "// published"

    result="$(resolve_config "eslint.config.js")"

    export PROJECT_ROOT="$old_project_root"
    export DEV_TOOLS_ROOT="$old_dev_tools_root"

    [ "$result" = "${TEST_TEMP_DIR}/eslint.config.js" ]
}

@test "resolve_config returns config/dev-tools/ file (level 2)" {
    local old_project_root="$PROJECT_ROOT"
    local old_dev_tools_root="$DEV_TOOLS_ROOT"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export DEV_TOOLS_ROOT="${PROJECT_ROOT}"

    create_test_file "${TEST_TEMP_DIR}/config/dev-tools/eslint.config.js" "// published"

    result="$(resolve_config "eslint.config.js")"

    export PROJECT_ROOT="$old_project_root"
    export DEV_TOOLS_ROOT="$old_dev_tools_root"

    [ "$result" = "${TEST_TEMP_DIR}/config/dev-tools/eslint.config.js" ]
}

@test "resolve_config returns config/ legacy fallback (level 3)" {
    local old_project_root="$PROJECT_ROOT"
    local old_dev_tools_root="$DEV_TOOLS_ROOT"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export DEV_TOOLS_ROOT="${PROJECT_ROOT}"

    create_test_file "${TEST_TEMP_DIR}/config/eslint.config.js" "// legacy"

    result="$(resolve_config "eslint.config.js")"

    export PROJECT_ROOT="$old_project_root"
    export DEV_TOOLS_ROOT="$old_dev_tools_root"

    [ "$result" = "${TEST_TEMP_DIR}/config/eslint.config.js" ]
}

@test "resolve_config returns DEV_TOOLS_ROOT bundled default (level 4)" {
    local old_project_root="$PROJECT_ROOT"
    local old_dev_tools_root="$DEV_TOOLS_ROOT"
    local bundled_dir="${TEST_TEMP_DIR}/bundled"
    export PROJECT_ROOT="${TEST_TEMP_DIR}/project"
    export DEV_TOOLS_ROOT="$bundled_dir"

    mkdir -p "$PROJECT_ROOT"
    create_test_file "${bundled_dir}/config/eslint.config.js" "// bundled default"

    result="$(resolve_config "eslint.config.js")"

    export PROJECT_ROOT="$old_project_root"
    export DEV_TOOLS_ROOT="$old_dev_tools_root"

    [ "$result" = "${bundled_dir}/config/eslint.config.js" ]
}

@test "resolve_config returns empty string when no file exists" {
    local old_project_root="$PROJECT_ROOT"
    local old_dev_tools_root="$DEV_TOOLS_ROOT"
    export PROJECT_ROOT="${TEST_TEMP_DIR}/project"
    export DEV_TOOLS_ROOT="${TEST_TEMP_DIR}/bundled"

    mkdir -p "$PROJECT_ROOT"

    result="$(resolve_config "nonexistent.config.js")"

    export PROJECT_ROOT="$old_project_root"
    export DEV_TOOLS_ROOT="$old_dev_tools_root"

    [ -z "$result" ]
}

# ============================================================================
# file_hash
# ============================================================================

@test "file_hash returns a non-empty string for an existing file" {
    local test_file="${TEST_TEMP_DIR}/hashme.txt"
    create_test_file "$test_file" "content"

    result="$(file_hash "$test_file")"

    [ -n "$result" ]
}

@test "file_hash returns same hash for same content" {
    local file1="${TEST_TEMP_DIR}/a.txt"
    local file2="${TEST_TEMP_DIR}/b.txt"
    create_test_file "$file1" "same content"
    create_test_file "$file2" "same content"

    hash1="$(file_hash "$file1")"
    hash2="$(file_hash "$file2")"

    [ "$hash1" = "$hash2" ]
}

@test "file_hash returns different hash for different content" {
    local file1="${TEST_TEMP_DIR}/a.txt"
    local file2="${TEST_TEMP_DIR}/b.txt"
    create_test_file "$file1" "content A"
    create_test_file "$file2" "content B"

    hash1="$(file_hash "$file1")"
    hash2="$(file_hash "$file2")"

    [ "$hash1" != "$hash2" ]
}
