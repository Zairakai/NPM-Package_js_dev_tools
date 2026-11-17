#!/usr/bin/env bats
#
# Integration Tests for the make targets of the setup
#
# setup-check, setup-update and uninstall are double-colon targets: in a full-stack project, laravel-dev-tools adds its own
# rule, and both run. With a single colon, one rule would replace the other without a word.
#

# Load test helpers
load '../helpers/test_helper'

setup() {
  setup_test_env

  export PROJECT="${TEST_TEMP_DIR}/project"
  mkdir -p "${PROJECT}/node_modules/@zairakai"
  ln -s "${PROJECT_ROOT}" "${PROJECT}/node_modules/@zairakai/js-dev-tools"
  printf '{\n  "name": "acme-sample"\n}\n' > "${PROJECT}/package.json"
}

teardown() {
  teardown_test_env
}

# The Makefile of a project: the dev-tools, then a rule of the project for the same target
make_project_makefile() {
  printf 'include node_modules/@zairakai/js-dev-tools/tools/make/core.mk\n\n%s::\n\t@echo project-rule\n' "$1" > "${PROJECT}/Makefile"
}

@test "make setup-check runs the script of the package and the rule of another package" {
  make_project_makefile setup-check

  cd "${PROJECT}" || return 1
  run make -n setup-check

  [ "$status" -eq 0 ]
  [[ "$output" == *"scripts//setup-check.sh"* ]]
  [[ "$output" == *"project-rule"* ]]
}

@test "make setup-update runs the script of the package and the rule of another package" {
  make_project_makefile setup-update

  cd "${PROJECT}" || return 1
  run make -n setup-update

  [ "$status" -eq 0 ]
  [[ "$output" == *"scripts//setup-update.sh"* ]]
  [[ "$output" == *"project-rule"* ]]
}

@test "make uninstall runs the script of the package and the rule of another package" {
  make_project_makefile uninstall

  cd "${PROJECT}" || return 1
  run make -n uninstall

  [ "$status" -eq 0 ]
  [[ "$output" == *"scripts//uninstall-package.sh"* ]]
  [[ "$output" == *"project-rule"* ]]
}

@test "make help lists each target of the setup once" {
  make_project_makefile setup-check

  cd "${PROJECT}" || return 1
  run make help

  [ "$status" -eq 0 ]

  # Without the colors of the help
  local plain
  plain="$(sed 's/\x1b\[[0-9;]*m//g' <<< "$output")"

  [ "$(grep -c '^  setup-check ' <<< "$plain")" -eq 1 ]
  [ "$(grep -c '^  setup-update ' <<< "$plain")" -eq 1 ]
  [ "$(grep -c '^  uninstall ' <<< "$plain")" -eq 1 ]
}
