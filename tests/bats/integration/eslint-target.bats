#!/usr/bin/env bats
#
# Integration Tests — scripts/eslint.sh / scripts/eslint-fix.sh target resolution
#
# Regression coverage for two bugs found while auditing nexus (2026-07-02):
#   1. has_files() never matched a brace-alternation pattern passed as a single
#      quoted string (bash only brace-expands unquoted literal text), so ESLint
#      was silently skipped on every laravel-app project.
#   2. LINT_TARGET="." (npm-package projects with no src/ dir) concatenated
#      directly with "**/*.ext" produced the invalid glob ".**/*.ext".
#
# Both made `make quality` / `make quality-fix` report success without ESLint
# ever running — no BATS coverage caught it because these scripts were never
# exercised end-to-end, only asserted to exist (package-structure.bats).
#

load '../helpers/test_helper'

setup() {
    setup_test_env
    setup_fake_project

    # Fake eslint binary — records that it was invoked and exits 0.
    cat > "${FAKE_PROJECT}/node_modules/.bin/eslint" <<'EOF'
#!/usr/bin/env bash
echo "eslint invoked with: $*" > "${ESLINT_CALL_LOG}"
exit 0
EOF
    chmod +x "${FAKE_PROJECT}/node_modules/.bin/eslint"
    export ESLINT_CALL_LOG="${TEST_TEMP_DIR}/eslint-call.log"
}

teardown() {
    teardown_test_env
}

@test "eslint.sh does not skip a laravel-app project with real Vue files" {
    mkdir -p "${FAKE_PROJECT}/resources/js"
    touch "${FAKE_PROJECT}/artisan"
    echo '<template />' > "${FAKE_PROJECT}/resources/js/Foo.vue"

    run bash "${FAKE_PROJECT}/node_modules/@zairakai/js-dev-tools/scripts/eslint.sh"

    [ "$status" -eq 0 ]
    [[ ! "$output" =~ "No JS/TS files found" ]]
    [ -f "$ESLINT_CALL_LOG" ]
}

@test "eslint.sh still skips gracefully when a laravel-app project has no JS/TS files" {
    mkdir -p "${FAKE_PROJECT}/resources/js"
    touch "${FAKE_PROJECT}/artisan"

    run bash "${FAKE_PROJECT}/node_modules/@zairakai/js-dev-tools/scripts/eslint.sh"

    [ "$status" -eq 0 ]
    [[ "$output" =~ "No JS/TS files found" ]]
    [ ! -f "$ESLINT_CALL_LOG" ]
}

@test "eslint.sh does not skip an npm-package project falling back to LINT_TARGET=." {
    # No artisan, no src/ — triggers the "." fallback target.
    echo 'export default {}' > "${FAKE_PROJECT}/index.js"

    run bash "${FAKE_PROJECT}/node_modules/@zairakai/js-dev-tools/scripts/eslint.sh"

    [ "$status" -eq 0 ]
    [[ ! "$output" =~ "No JS/TS files found" ]]
    [ -f "$ESLINT_CALL_LOG" ]
}

@test "eslint-fix.sh does not skip a laravel-app project with real Vue files" {
    mkdir -p "${FAKE_PROJECT}/resources/js"
    touch "${FAKE_PROJECT}/artisan"
    echo '<template />' > "${FAKE_PROJECT}/resources/js/Foo.vue"

    run bash "${FAKE_PROJECT}/node_modules/@zairakai/js-dev-tools/scripts/eslint-fix.sh"

    [ "$status" -eq 0 ]
    [[ ! "$output" =~ "No JS/TS files found" ]]
    [ -f "$ESLINT_CALL_LOG" ]
}
