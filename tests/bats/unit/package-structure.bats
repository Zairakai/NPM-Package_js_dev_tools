#!/usr/bin/env bats
#
# Unit Tests — Package Structure
# Verifies that all required files are present in the npm package.
# These tests run against the source tree (not an installed package).
#

load '../helpers/test_helper'

setup() {
    setup_test_env
}

teardown() {
    teardown_test_env
}

# ============================================================================
# scripts/
# ============================================================================

@test "scripts/config.sh exists" {
    assert_file_exists "${PROJECT_ROOT}/scripts/config.sh"
}

@test "scripts/eslint.sh exists" {
    assert_file_exists "${PROJECT_ROOT}/scripts/eslint.sh"
}

@test "scripts/eslint-fix.sh exists" {
    assert_file_exists "${PROJECT_ROOT}/scripts/eslint-fix.sh"
}

@test "scripts/prettier.sh exists" {
    assert_file_exists "${PROJECT_ROOT}/scripts/prettier.sh"
}

@test "scripts/prettier-fix.sh exists" {
    assert_file_exists "${PROJECT_ROOT}/scripts/prettier-fix.sh"
}

@test "scripts/stylelint.sh exists" {
    assert_file_exists "${PROJECT_ROOT}/scripts/stylelint.sh"
}

@test "scripts/stylelint-fix.sh exists" {
    assert_file_exists "${PROJECT_ROOT}/scripts/stylelint-fix.sh"
}

@test "scripts/test.sh exists" {
    assert_file_exists "${PROJECT_ROOT}/scripts/test.sh"
}

@test "scripts/ci-quality.sh exists" {
    assert_file_exists "${PROJECT_ROOT}/scripts/ci-quality.sh"
}

@test "scripts/setup-project.sh exists" {
    assert_file_exists "${PROJECT_ROOT}/scripts/setup-project.sh"
}

@test "scripts/typecheck.sh exists" {
    assert_file_exists "${PROJECT_ROOT}/scripts/typecheck.sh"
}

@test "scripts/build.sh exists" {
    assert_file_exists "${PROJECT_ROOT}/scripts/build.sh"
}

@test "scripts/knip.sh exists" {
    assert_file_exists "${PROJECT_ROOT}/scripts/knip.sh"
}

@test "scripts/validate-shellcheck.sh exists" {
    assert_file_exists "${PROJECT_ROOT}/scripts/validate-shellcheck.sh"
}

@test "scripts/markdownlint.sh exists" {
    assert_file_exists "${PROJECT_ROOT}/scripts/markdownlint.sh"
}

@test "scripts/markdownlint-fix.sh exists" {
    assert_file_exists "${PROJECT_ROOT}/scripts/markdownlint-fix.sh"
}

@test "scripts/install-shellcheck.sh exists" {
    assert_file_exists "${PROJECT_ROOT}/scripts/install-shellcheck.sh"
}

@test "scripts/install-bats.sh exists" {
    assert_file_exists "${PROJECT_ROOT}/scripts/install-bats.sh"
}

@test "scripts/install-markdownlint.sh exists" {
    assert_file_exists "${PROJECT_ROOT}/scripts/install-markdownlint.sh"
}

@test "scripts/doctor.sh exists" {
    assert_file_exists "${PROJECT_ROOT}/scripts/doctor.sh"
}

# ============================================================================
# scripts/ — shebang check
# ============================================================================

@test "all scripts have correct shebang" {
    local failed=0
    local script
    while IFS= read -r -d '' script; do
        first_line="$(head -n1 "$script")"
        if [[ "$first_line" != "#!/usr/bin/env bash" ]]; then
            echo "Bad shebang in: $script" >&2
            failed=$((failed + 1))
        fi
    done < <(find "${PROJECT_ROOT}/scripts" -name "*.sh" -print0)
    [ "$failed" -eq 0 ]
}

# ============================================================================
# config/
# ============================================================================

@test "LICENSE exists" {
    assert_file_exists "${PROJECT_ROOT}/LICENSE"
}

@test ".editorconfig exists" {
    assert_file_exists "${PROJECT_ROOT}/.editorconfig"
}

@test "config/eslint.config.js exists" {
    assert_file_exists "${PROJECT_ROOT}/config/eslint.config.js"
}

@test "config/prettier.config.js exists" {
    assert_file_exists "${PROJECT_ROOT}/config/prettier.config.js"
}

@test "config/stylelint.config.js exists" {
    assert_file_exists "${PROJECT_ROOT}/config/stylelint.config.js"
}

@test "config/vitest.config.js exists" {
    assert_file_exists "${PROJECT_ROOT}/config/vitest.config.js"
}

@test "config/.prettierignore exists" {
    assert_file_exists "${PROJECT_ROOT}/config/.prettierignore"
}

@test "config/.stylelintignore exists" {
    assert_file_exists "${PROJECT_ROOT}/config/.stylelintignore"
}

@test "config/.markdownlint.json exists" {
    assert_file_exists "${PROJECT_ROOT}/config/.markdownlint.json"
}

@test "config/.markdownlintignore exists" {
    assert_file_exists "${PROJECT_ROOT}/config/.markdownlintignore"
}

# ============================================================================
# stubs/
# ============================================================================

@test "stubs/quality/eslint.config.js.stub exists" {
    assert_file_exists "${PROJECT_ROOT}/stubs/quality/eslint.config.js.stub"
}

@test "stubs/quality/knip.config.js.stub exists" {
    assert_file_exists "${PROJECT_ROOT}/stubs/quality/knip.config.js.stub"
}

@test "stubs/style/prettier.config.js.stub exists" {
    assert_file_exists "${PROJECT_ROOT}/stubs/style/prettier.config.js.stub"
}

@test "stubs/style/stylelint.config.js.stub exists" {
    assert_file_exists "${PROJECT_ROOT}/stubs/style/stylelint.config.js.stub"
}

@test "stubs/testing/vitest.config.js.stub exists" {
    assert_file_exists "${PROJECT_ROOT}/stubs/testing/vitest.config.js.stub"
}

@test "stubs/typescript/tsconfig.json.stub exists" {
    assert_file_exists "${PROJECT_ROOT}/stubs/typescript/tsconfig.json.stub"
}

@test "stubs/gitlab-ci/gitlab-ci.yml.stub exists" {
    assert_file_exists "${PROJECT_ROOT}/stubs/gitlab-ci/gitlab-ci.yml.stub"
}

@test "stubs/gitlab-ci/gitlab-pipeline-js-app.yml.stub exists" {
    assert_file_exists "${PROJECT_ROOT}/stubs/gitlab-ci/gitlab-pipeline-js-app.yml.stub"
}

@test "stubs/githooks/commit-msg exists" {
    assert_file_exists "${PROJECT_ROOT}/stubs/githooks/commit-msg"
}

@test "stubs/githooks/prepare-commit-msg exists" {
    assert_file_exists "${PROJECT_ROOT}/stubs/githooks/prepare-commit-msg"
}

@test "stubs/githooks/pre-commit exists" {
    assert_file_exists "${PROJECT_ROOT}/stubs/githooks/pre-commit"
}

@test "stubs/githooks/pre-push exists" {
    assert_file_exists "${PROJECT_ROOT}/stubs/githooks/pre-push"
}

# ============================================================================
# tools/make/
# ============================================================================

@test "tools/make/core.mk exists" {
    assert_file_exists "${PROJECT_ROOT}/tools/make/core.mk"
}

@test "tools/make/variables.mk exists" {
    assert_file_exists "${PROJECT_ROOT}/tools/make/variables.mk"
}

@test "tools/make/help.mk exists" {
    assert_file_exists "${PROJECT_ROOT}/tools/make/help.mk"
}

@test "tools/make/quality.mk exists" {
    assert_file_exists "${PROJECT_ROOT}/tools/make/quality.mk"
}

@test "tools/make/code-style.mk exists" {
    assert_file_exists "${PROJECT_ROOT}/tools/make/code-style.mk"
}

@test "tools/make/stylelint.mk exists" {
    assert_file_exists "${PROJECT_ROOT}/tools/make/stylelint.mk"
}

@test "tools/make/markdownlint.mk exists" {
    assert_file_exists "${PROJECT_ROOT}/tools/make/markdownlint.mk"
}

@test "tools/make/shellcheck.mk exists" {
    assert_file_exists "${PROJECT_ROOT}/tools/make/shellcheck.mk"
}

@test "tools/make/test.mk exists" {
    assert_file_exists "${PROJECT_ROOT}/tools/make/test.mk"
}

@test "tools/make/typescript.mk exists" {
    assert_file_exists "${PROJECT_ROOT}/tools/make/typescript.mk"
}

@test "tools/make/bats.mk exists" {
    assert_file_exists "${PROJECT_ROOT}/tools/make/bats.mk"
}

@test "tools/make/knip.mk exists" {
    assert_file_exists "${PROJECT_ROOT}/tools/make/knip.mk"
}

@test "tools/make/utils.mk exists" {
    assert_file_exists "${PROJECT_ROOT}/tools/make/utils.mk"
}

@test "config/tsconfig.base.json exists" {
    assert_file_exists "${PROJECT_ROOT}/config/tsconfig.base.json"
}

# ============================================================================
# .gitlab/ci/
# ============================================================================

@test ".gitlab/ci/pipeline-js-package.yml exists" {
    assert_file_exists "${PROJECT_ROOT}/.gitlab/ci/pipeline-js-package.yml"
}

@test ".gitlab/ci/pipeline-js-app.yml exists" {
    assert_file_exists "${PROJECT_ROOT}/.gitlab/ci/pipeline-js-app.yml"
}

# ============================================================================
# package.json — files[] declaration
# ============================================================================

@test "package.json includes config/ in files[]" {
    run grep -q '"config/"' "${PROJECT_ROOT}/package.json"
    [ "$status" -eq 0 ]
}

@test "package.json includes scripts/ in files[]" {
    run grep -q '"scripts/"' "${PROJECT_ROOT}/package.json"
    [ "$status" -eq 0 ]
}

@test "package.json includes tools/ in files[]" {
    run grep -q '"tools/"' "${PROJECT_ROOT}/package.json"
    [ "$status" -eq 0 ]
}

@test "package.json includes stubs/ in files[]" {
    run grep -q '"stubs/"' "${PROJECT_ROOT}/package.json"
    [ "$status" -eq 0 ]
}
