#!/usr/bin/env bats
#
# Unit Tests for install-hooks.sh
#
# Tests the git hooks installation/removal functionality:
# - Hook stubs are executable
# - Installation creates symlinks in .git/hooks/
# - Existing non-symlink hooks are backed up
# - Existing symlinks are replaced without backup
# - Removal deletes symlinks only
# - Non-git repository is rejected
#

load '../helpers/test_helper'

setup() {
    setup_test_env

    # Fake git repository — TEST_PKG_DIR lives inside it so config.sh
    # resolves PROJECT_ROOT to TEST_GIT_DIR (node_modules pattern: 4 levels up)
    export TEST_GIT_DIR="${TEST_TEMP_DIR}/test-repo"
    export TEST_PKG_DIR="${TEST_GIT_DIR}/node_modules/@zairakai/js-dev-tools"

    mkdir -p "${TEST_GIT_DIR}/.git/hooks"
    mkdir -p "${TEST_PKG_DIR}/stubs/githooks"
    mkdir -p "${TEST_PKG_DIR}/scripts"

    cp -r "${PROJECT_ROOT}/stubs/githooks"/* "${TEST_PKG_DIR}/stubs/githooks/"
    cp "${PROJECT_ROOT}/scripts/config.sh"        "${TEST_PKG_DIR}/scripts/"
    cp "${PROJECT_ROOT}/scripts/install-hooks.sh" "${TEST_PKG_DIR}/scripts/"
}

teardown() {
    teardown_test_env
}

# ============================================================================
# Stubs
# ============================================================================

@test "hook stubs are executable" {
    for hook in commit-msg prepare-commit-msg pre-commit pre-push; do
        [ -x "${PROJECT_ROOT}/stubs/githooks/${hook}" ]
    done
}

# ============================================================================
# Installation
# ============================================================================

@test "install creates symlinks for all 4 hooks" {
    cd "${TEST_GIT_DIR}"
    run bash "${TEST_PKG_DIR}/scripts/install-hooks.sh"

    [ "$status" -eq 0 ]
    for hook in commit-msg prepare-commit-msg pre-commit pre-push; do
        [ -L "${TEST_GIT_DIR}/.git/hooks/${hook}" ]
    done
}

@test "install backs up existing non-symlink hook" {
    cd "${TEST_GIT_DIR}"
    echo "#!/bin/bash" > "${TEST_GIT_DIR}/.git/hooks/pre-commit"

    run bash "${TEST_PKG_DIR}/scripts/install-hooks.sh"

    [ "$status" -eq 0 ]
    backups=$(find "${TEST_GIT_DIR}/.git/hooks" -name "pre-commit.backup-*" | wc -l)
    [ "$backups" -eq 1 ]
    [ -L "${TEST_GIT_DIR}/.git/hooks/pre-commit" ]
}

@test "install replaces existing symlink without backup" {
    cd "${TEST_GIT_DIR}"
    ln -s /tmp/fake "${TEST_GIT_DIR}/.git/hooks/pre-commit"

    run bash "${TEST_PKG_DIR}/scripts/install-hooks.sh"

    [ "$status" -eq 0 ]
    [ -L "${TEST_GIT_DIR}/.git/hooks/pre-commit" ]
    backups=$(find "${TEST_GIT_DIR}/.git/hooks" -name "pre-commit.backup-*" | wc -l)
    [ "$backups" -eq 0 ]
}

# ============================================================================
# Removal
# ============================================================================

@test "remove deletes installed symlinks" {
    cd "${TEST_GIT_DIR}"
    bash "${TEST_PKG_DIR}/scripts/install-hooks.sh"

    run bash "${TEST_PKG_DIR}/scripts/install-hooks.sh" --remove

    [ "$status" -eq 0 ]
    for hook in commit-msg prepare-commit-msg pre-commit pre-push; do
        [ ! -e "${TEST_GIT_DIR}/.git/hooks/${hook}" ]
    done
}

@test "remove leaves non-symlink hooks untouched" {
    cd "${TEST_GIT_DIR}"
    echo "#!/bin/bash" > "${TEST_GIT_DIR}/.git/hooks/pre-commit"

    run bash "${TEST_PKG_DIR}/scripts/install-hooks.sh" --remove

    [ "$status" -eq 0 ]
    [ -f "${TEST_GIT_DIR}/.git/hooks/pre-commit" ]
}

# ============================================================================
# Error handling
# ============================================================================

@test "install fails outside a git repository" {
    # Build a separate pkg dir inside a non-git dir so PROJECT_ROOT and $PWD both have no .git
    local no_git_dir="${TEST_TEMP_DIR}/no-git"
    local no_git_pkg="${no_git_dir}/node_modules/@zairakai/js-dev-tools"
    mkdir -p "${no_git_pkg}/scripts"
    cp "${PROJECT_ROOT}/scripts/config.sh"        "${no_git_pkg}/scripts/"
    cp "${PROJECT_ROOT}/scripts/install-hooks.sh" "${no_git_pkg}/scripts/"

    cd "${no_git_dir}"
    run bash "${no_git_pkg}/scripts/install-hooks.sh"

    [ "$status" -eq 1 ]
    [[ "$output" =~ "Not a git repository" ]]
}
