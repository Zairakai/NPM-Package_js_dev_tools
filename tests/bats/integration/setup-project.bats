#!/usr/bin/env bats
#
# Integration Tests — scripts/setup-project.sh
# Tests the project setup and publish functionality.
#

load '../helpers/test_helper'

setup() {
    setup_test_env
    setup_fake_project
}

teardown() {
    teardown_test_env
}

# ============================================================================
# --help
# ============================================================================

@test "setup-project.sh --help outputs usage information" {
    run bash "${SCRIPT_DIR}/setup-project.sh" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage:" ]]
    [[ "$output" =~ "--publish" ]]
    [[ "$output" =~ "--force" ]]
}

@test "setup-project.sh --help lists config groups" {
    run bash "${SCRIPT_DIR}/setup-project.sh" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "quality" ]]
    [[ "$output" =~ "style" ]]
    [[ "$output" =~ "testing" ]]
}

@test "setup-project.sh --help lists gitlab-ci keys" {
    run bash "${SCRIPT_DIR}/setup-project.sh" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "gitlab-ci" ]]
}

# ============================================================================
# Unknown option
# ============================================================================

@test "setup-project.sh exits 1 on unknown option" {
    run bash "${SCRIPT_DIR}/setup-project.sh" --invalid-option
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Unknown option" ]] || [[ "$output" =~ "ERROR" ]]
}

# ============================================================================
# Script structure checks
# ============================================================================

@test "setup-project.sh sources config.sh" {
    run grep -q "source.*config.sh" "${SCRIPT_DIR}/setup-project.sh"
    [ "$status" -eq 0 ]
}

@test "setup-project.sh has correct shebang" {
    run head -n1 "${SCRIPT_DIR}/setup-project.sh"
    [[ "$output" =~ "#!/usr/bin/env bash" ]]
}

@test "setup-project.sh declares PUBLISHABLE associative array" {
    run grep -q "declare -A PUBLISHABLE" "${SCRIPT_DIR}/setup-project.sh"
    [ "$status" -eq 0 ]
}

@test "setup-project.sh declares PUBLISH_GROUPS associative array" {
    run grep -q "declare -A PUBLISH_GROUPS" "${SCRIPT_DIR}/setup-project.sh"
    [ "$status" -eq 0 ]
}

@test "setup-project.sh has eslint in PUBLISHABLE" {
    run grep -q '\["eslint"\]' "${SCRIPT_DIR}/setup-project.sh"
    [ "$status" -eq 0 ]
}

@test "setup-project.sh has knip in PUBLISHABLE" {
    run grep -q '\["knip"\]' "${SCRIPT_DIR}/setup-project.sh"
    [ "$status" -eq 0 ]
}

@test "setup-project.sh has vitest in PUBLISHABLE" {
    run grep -q '"vitest"' "${SCRIPT_DIR}/setup-project.sh"
    [ "$status" -eq 0 ]
}

@test "setup-project.sh handles gitlab-ci with project-type dispatch" {
    run grep -q 'publish_gitlab_ci\b' "${SCRIPT_DIR}/setup-project.sh"
    [ "$status" -eq 0 ]
}

@test "setup-project.sh dispatches to npm handler for npm-package type" {
    run grep -q 'publish_gitlab_ci_npm' "${SCRIPT_DIR}/setup-project.sh"
    [ "$status" -eq 0 ]
}

@test "setup-project.sh dispatches to laravel handler for laravel-app type" {
    run grep -q 'publish_gitlab_ci_laravel' "${SCRIPT_DIR}/setup-project.sh"
    [ "$status" -eq 0 ]
}

@test "setup-project.sh uses stubs/quality/ for eslint publish" {
    run grep -q 'stubs/quality/eslint.config.js.stub' "${SCRIPT_DIR}/setup-project.sh"
    [ "$status" -eq 0 ]
}

@test "setup-project.sh uses stubs/testing/ for vitest publish" {
    run grep -q 'stubs/testing/vitest.config.js.stub' "${SCRIPT_DIR}/setup-project.sh"
    [ "$status" -eq 0 ]
}

@test "setup-project.sh uses gitlab-ci/gitlab-ci.yml.stub for npm pipeline" {
    run grep -q 'stubs/gitlab-ci/gitlab-ci.yml.stub' "${SCRIPT_DIR}/setup-project.sh"
    [ "$status" -eq 0 ]
}

@test "setup-project.sh uses gitlab-ci/gitlab-pipeline-js-app.yml.stub for laravel pipeline" {
    run grep -q 'stubs/gitlab-ci/gitlab-pipeline-js-app.yml.stub' "${SCRIPT_DIR}/setup-project.sh"
    [ "$status" -eq 0 ]
}

@test "setup-project.sh supports hooks publish" {
    run grep -q 'publish_hooks' "${SCRIPT_DIR}/setup-project.sh"
    [ "$status" -eq 0 ]
}

# ============================================================================
# --publish=eslint (in fake project context)
# ============================================================================

@test "setup-project.sh --publish=eslint creates config/dev-tools/eslint.config.js" {
    cd "$FAKE_PROJECT"

    run bash "node_modules/@zairakai/js-dev-tools/scripts/setup-project.sh" --publish=eslint

    assert_file_exists "${FAKE_PROJECT}/config/dev-tools/eslint.config.js"
}

@test "published eslint.config.js imports from @zairakai/js-dev-tools" {
    cd "$FAKE_PROJECT"
    bash "node_modules/@zairakai/js-dev-tools/scripts/setup-project.sh" --publish=eslint

    run grep -q "@zairakai/js-dev-tools" "${FAKE_PROJECT}/config/dev-tools/eslint.config.js"
    [ "$status" -eq 0 ]
}

@test "setup-project.sh --publish=prettier creates config/dev-tools/prettier.config.js" {
    cd "$FAKE_PROJECT"

    run bash "node_modules/@zairakai/js-dev-tools/scripts/setup-project.sh" --publish=prettier

    assert_file_exists "${FAKE_PROJECT}/config/dev-tools/prettier.config.js"
}

@test "setup-project.sh --publish=style creates all style configs" {
    cd "$FAKE_PROJECT"

    run bash "node_modules/@zairakai/js-dev-tools/scripts/setup-project.sh" --publish=style

    assert_file_exists "${FAKE_PROJECT}/config/dev-tools/prettier.config.js"
    assert_file_exists "${FAKE_PROJECT}/config/dev-tools/stylelint.config.js"
    assert_file_exists "${FAKE_PROJECT}/config/dev-tools/.prettierignore"
    assert_file_exists "${FAKE_PROJECT}/config/dev-tools/.stylelintignore"
    assert_file_exists "${FAKE_PROJECT}/config/dev-tools/.markdownlint.json"
    assert_file_exists "${FAKE_PROJECT}/config/dev-tools/.markdownlintignore"
}

# ============================================================================
# --publish=all
# ============================================================================

@test "setup-project.sh --publish creates all config files" {
    cd "$FAKE_PROJECT"

    run bash "node_modules/@zairakai/js-dev-tools/scripts/setup-project.sh" --publish

    assert_file_exists "${FAKE_PROJECT}/config/dev-tools/eslint.config.js"
    assert_file_exists "${FAKE_PROJECT}/config/dev-tools/prettier.config.js"
    assert_file_exists "${FAKE_PROJECT}/config/dev-tools/stylelint.config.js"
    assert_file_exists "${FAKE_PROJECT}/config/dev-tools/.markdownlint.json"
    assert_file_exists "${FAKE_PROJECT}/config/dev-tools/.markdownlintignore"
    assert_file_exists "${FAKE_PROJECT}/config/dev-tools/vitest.config.js"
    assert_file_exists "${FAKE_PROJECT}/tsconfig.json"
}

# ============================================================================
# Helper — simulate a Laravel app project
# ============================================================================

setup_fake_laravel_project() {
    touch "${FAKE_PROJECT}/artisan"
    mkdir -p "${FAKE_PROJECT}/resources/js"
}

# ============================================================================
# --publish=gitlab-ci (npm-package type — default fake project)
# ============================================================================

@test "setup-project.sh --publish=gitlab-ci creates .gitlab-ci.yml for npm-package" {
    cd "$FAKE_PROJECT"

    run bash "node_modules/@zairakai/js-dev-tools/scripts/setup-project.sh" --publish=gitlab-ci

    assert_file_exists "${FAKE_PROJECT}/.gitlab-ci.yml"
}

@test "published .gitlab-ci.yml includes zairakai/npm-packages/js-dev-tools project" {
    cd "$FAKE_PROJECT"
    bash "node_modules/@zairakai/js-dev-tools/scripts/setup-project.sh" --publish=gitlab-ci

    run grep -q "zairakai/npm-packages/js-dev-tools" "${FAKE_PROJECT}/.gitlab-ci.yml"
    [ "$status" -eq 0 ]
}

@test "published .gitlab-ci.yml references pipeline-js-package.yml" {
    cd "$FAKE_PROJECT"
    bash "node_modules/@zairakai/js-dev-tools/scripts/setup-project.sh" --publish=gitlab-ci

    run grep -q "pipeline-js-package.yml" "${FAKE_PROJECT}/.gitlab-ci.yml"
    [ "$status" -eq 0 ]
}

# ============================================================================
# --publish=gitlab-ci (laravel-app type — fake project with artisan)
# ============================================================================

@test "setup-project.sh --publish=gitlab-ci creates .gitlab/pipeline-js-app.yml for laravel-app" {
    setup_fake_laravel_project
    cd "$FAKE_PROJECT"

    run bash "node_modules/@zairakai/js-dev-tools/scripts/setup-project.sh" --publish=gitlab-ci

    assert_file_exists "${FAKE_PROJECT}/.gitlab/pipeline-js-app.yml"
}

@test "--publish=gitlab-ci (laravel) creates .gitlab-ci.yml when none exists" {
    setup_fake_laravel_project
    cd "$FAKE_PROJECT"
    bash "node_modules/@zairakai/js-dev-tools/scripts/setup-project.sh" --publish=gitlab-ci

    assert_file_exists "${FAKE_PROJECT}/.gitlab-ci.yml"
}

@test "--publish=gitlab-ci (laravel) injects include into existing .gitlab-ci.yml" {
    setup_fake_laravel_project
    cd "$FAKE_PROJECT"

    # Create a pre-existing .gitlab-ci.yml (like the PHP one)
    echo "# Existing PHP pipeline" > "${FAKE_PROJECT}/.gitlab-ci.yml"
    echo "include:" >> "${FAKE_PROJECT}/.gitlab-ci.yml"
    echo "  - project: 'zairakai/packagist/laravel-dev-tools'" >> "${FAKE_PROJECT}/.gitlab-ci.yml"

    bash "node_modules/@zairakai/js-dev-tools/scripts/setup-project.sh" --publish=gitlab-ci

    run grep -q "pipeline-js-app.yml" "${FAKE_PROJECT}/.gitlab-ci.yml"
    [ "$status" -eq 0 ]
}

@test "--publish=gitlab-ci (laravel) does not duplicate injection" {
    setup_fake_laravel_project
    cd "$FAKE_PROJECT"

    # First injection
    bash "node_modules/@zairakai/js-dev-tools/scripts/setup-project.sh" --publish=gitlab-ci

    # Second injection — should be skipped
    run bash "node_modules/@zairakai/js-dev-tools/scripts/setup-project.sh" --publish=gitlab-ci

    count="$(grep -c "pipeline-js-app.yml" "${FAKE_PROJECT}/.gitlab-ci.yml" || echo 0)"
    [ "$count" -eq 1 ]
}

# ============================================================================
# --force
# ============================================================================

@test "--force overwrites an existing published file" {
    cd "$FAKE_PROJECT"

    # First publish
    bash "node_modules/@zairakai/js-dev-tools/scripts/setup-project.sh" --publish=eslint

    # Modify the published file
    echo "// modified" >> "${FAKE_PROJECT}/config/dev-tools/eslint.config.js"

    # Force overwrite
    bash "node_modules/@zairakai/js-dev-tools/scripts/setup-project.sh" --publish=eslint --force

    # File should no longer contain the modification
    run grep -q "// modified" "${FAKE_PROJECT}/config/dev-tools/eslint.config.js"
    [ "$status" -ne 0 ]
}

# ============================================================================
# ci-quality.sh — structure checks
# ============================================================================

@test "ci-quality.sh uses error counter pattern" {
    run grep -q "init_error_counter" "${SCRIPT_DIR}/ci-quality.sh"
    [ "$status" -eq 0 ]
}

@test "ci-quality.sh uses run_check pattern" {
    run grep -q "run_check" "${SCRIPT_DIR}/ci-quality.sh"
    [ "$status" -eq 0 ]
}

@test "ci-quality.sh exits with error count" {
    run grep -q "exit_with_error_count" "${SCRIPT_DIR}/ci-quality.sh"
    [ "$status" -eq 0 ]
}
