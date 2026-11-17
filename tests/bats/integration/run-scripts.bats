#!/usr/bin/env bats
#
# Integration Tests for scripts/bats-run.sh and scripts/validate-shellcheck.sh
#
# Each test builds a small project and runs the script on it. The count of the tests of bats-run.sh is checked by the job
# js:quality:bats, which runs it on this repository.
#

# Load test helpers
load '../helpers/test_helper'

setup() {
  setup_test_env
  make_script_project
}

teardown() {
  teardown_test_env
}

run_in_project() {
  local script="$1"
  shift

  cd "${PROJECT}" || return 1
  run bash "${PROJECT}/scripts/${script}" "$@"
}

# bats-run.sh
# ================

@test "bats-run.sh skips when there is no Bats test" {
  run_in_project bats-run.sh

  [ "$status" -eq 0 ]
  [[ "$output" == *"No Bats tests found"* ]]
}

@test "bats-run.sh fails when Bats is not installed" {
  # PATH with the tools the script needs, but not bats
  local bin="${TEST_TEMP_DIR}/no-bats"
  mkdir -p "$bin"
  for tool in bash dirname cat mktemp rm find sort grep sed head awk cut sleep kill env date mkdir tr uname git; do
    ln -sf "$(command -v "$tool")" "${bin}/${tool}" 2> /dev/null || true
  done

  cd "${PROJECT}" || return 1
  PATH="$bin" run /bin/bash "${PROJECT}/scripts/bats-run.sh"

  [ "$status" -eq 1 ]
  [[ "$output" == *"Bats is not installed"* ]]
}

# validate-shellcheck.sh
# ================

@test "validate-shellcheck.sh passes on a clean script" {
  require_command shellcheck
  printf '#!/usr/bin/env bash\necho "ok"\n' > "${PROJECT}/clean.sh"

  run_in_project validate-shellcheck.sh

  [ "$status" -eq 0 ]
  [[ "$output" == *"passed ShellCheck"* ]]
}

@test "validate-shellcheck.sh fails and names the script that does not pass" {
  require_command shellcheck
  printf '#!/usr/bin/env bash\ncd $1\nrm -rf $2/*\n' > "${PROJECT}/bad.sh"

  run_in_project validate-shellcheck.sh

  [ "$status" -eq 1 ]
  [[ "$output" == *"bad.sh - ShellCheck failed"* ]]
}

@test "validate-shellcheck.sh uses the severity of SHELLCHECK_SEVERITY" {
  require_command shellcheck
  printf '#!/usr/bin/env bash\nrm -rf $1/*\n' > "${PROJECT}/loose.sh"

  SHELLCHECK_SEVERITY=error run_in_project validate-shellcheck.sh

  [ "$status" -eq 0 ]
}
