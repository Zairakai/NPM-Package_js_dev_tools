#!/usr/bin/env bats
#
# Integration Tests for Git Hooks
#
# commit-msg and prepare-commit-msg follow the commit convention of the zairakai handbook.
#

setup() {
    export PROJECT_ROOT
    PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
    export TEST_TEMP_DIR="${BATS_TEST_TMPDIR}/hooks"
    mkdir -p "${TEST_TEMP_DIR}"

    export TEST_REPO="${TEST_TEMP_DIR}/test-repo"
    mkdir -p "${TEST_REPO}"
    cd "${TEST_REPO}" || return
    git init >/dev/null 2>&1
    git config user.name "Test User"
    git config user.email "test@example.com"
}

teardown() {
    rm -rf "${TEST_TEMP_DIR}"
}

# ============================================================================
# commit-msg Hook Tests
# ============================================================================

# Writes a message in a file and runs the commit-msg hook on it
run_commit_msg() {
    local msg_file="${TEST_TEMP_DIR}/commit-msg.txt"

    printf '%b' "$1" > "$msg_file"

    run bash "${PROJECT_ROOT}/stubs/githooks/commit-msg" "$msg_file"
}

@test "commit-msg accepts the handbook format" {
    run_commit_msg "feat(auth): #123 add user authentication\n"

    [ "$status" -eq 0 ]
    [[ "$output" =~ "Commit message OK" ]]
}

@test "commit-msg accepts a message without scope" {
    run_commit_msg "fix: #456 correct email validation\n"

    [ "$status" -eq 0 ]
}

@test "commit-msg accepts a body after a blank second line" {
    run_commit_msg "fix(api): #7 handle null response\n\nThe gateway can answer null.\n"

    [ "$status" -eq 0 ]
}

@test "commit-msg accepts all valid types" {
    local type

    for type in feat fix docs style refactor perf test chore ci build; do
        run_commit_msg "${type}(x): #1 valid commit message here\n"

        [ "$status" -eq 0 ]
    done
}

@test "commit-msg rejects a message without ticket" {
    run_commit_msg "feat(auth): add user authentication\n"

    [ "$status" -eq 1 ]
    [[ "$output" =~ "Invalid commit message format" ]]
}

@test "commit-msg rejects the ticket after the subject" {
    run_commit_msg "feat(auth): add user authentication #123\n"

    [ "$status" -eq 1 ]
}

@test "commit-msg rejects invalid format" {
    run_commit_msg "just a random commit message\n"

    [ "$status" -eq 1 ]
    [[ "$output" =~ "Invalid commit message format" ]]
}

@test "commit-msg rejects unknown type" {
    run_commit_msg "unknown(scope): #1 some message\n"

    [ "$status" -eq 1 ]
}

@test "commit-msg rejects a scope in uppercase" {
    run_commit_msg "feat(Auth): #1 add user authentication\n"

    [ "$status" -eq 1 ]
}

@test "commit-msg rejects WIP without the format" {
    run_commit_msg "WIP\n"

    [ "$status" -eq 1 ]
}

@test "commit-msg accepts a work in progress in the format" {
    run_commit_msg "chore(x): #9 wip on the hooks\n"

    [ "$status" -eq 0 ]
}

@test "commit-msg rejects a first line over 72 characters" {
    run_commit_msg "feat(auth): #1 this is a very long commit message that exceeds the maximum length\n"

    [ "$status" -eq 1 ]
    [[ "$output" =~ "the limit is 72" ]]
}

@test "commit-msg rejects a second line that is not blank" {
    run_commit_msg "feat(auth): #1 add user authentication\nnot blank\n"

    [ "$status" -eq 1 ]
    [[ "$output" =~ "second line must be blank" ]]
}

@test "commit-msg accepts the messages that Git writes itself" {
    local message

    for message in "Merge branch 'x' into 'develop'" 'Revert "feat(x): #1 add y"' "fixup! feat(x): #1 add y" "squash! feat(x): #1 add y"; do
        run_commit_msg "${message}\n"

        [ "$status" -eq 0 ]
    done
}

# ============================================================================
# prepare-commit-msg Hook Tests
# ============================================================================

# Runs the prepare-commit-msg hook on a message, on a given branch, and prints the result
prepare_message() {
    local branch="$1"
    local message="$2"
    local source="${3:-}"
    local msg_file="${TEST_TEMP_DIR}/commit-msg.txt"

    git checkout -b "$branch" >/dev/null 2>&1

    printf '%s\n' "$message" > "$msg_file"

    bash "${PROJECT_ROOT}/stubs/githooks/prepare-commit-msg" "$msg_file" "$source" >/dev/null 2>&1

    head -n1 "$msg_file"
}

@test "prepare-commit-msg puts the ticket of a feature branch after the type" {
    run prepare_message "feature/#123-add-login" "feat(auth): add login"

    [ "$output" = "feat(auth): #123 add login" ]
}

@test "prepare-commit-msg puts the ticket of a fix branch after the type" {
    run prepare_message "fix/#456-bug-fix" "fix: correct the bug"

    [ "$output" = "fix: #456 correct the bug" ]
}

@test "prepare-commit-msg puts the ticket of a hotfix branch after the type" {
    run prepare_message "hotfix/#789-critical" "fix(api): critical hotfix"

    [ "$output" = "fix(api): #789 critical hotfix" ]
}

@test "prepare-commit-msg keeps a ticket that is already there" {
    run prepare_message "feature/#123-test" "feat(x): #123 already has ticket"

    [ "$output" = "feat(x): #123 already has ticket" ]
}

@test "prepare-commit-msg does not take #12 for #123" {
    run prepare_message "feature/#12-test" "feat(x): #123 other ticket"

    [ "$output" = "feat(x): #12 #123 other ticket" ]
}

@test "prepare-commit-msg skips merge commits" {
    run prepare_message "feature/#123-test" "Merge branch 'x'" "merge"

    [ "$output" = "Merge branch 'x'" ]
}

@test "prepare-commit-msg leaves a message that is not type and subject" {
    run prepare_message "feature/#123-test" "add login"

    [ "$output" = "add login" ]
}

@test "prepare-commit-msg ignores branches without ticket pattern" {
    run prepare_message "my-branch" "feat(x): add login"

    [ "$output" = "feat(x): add login" ]
}
