#!/usr/bin/env bats
#
# Integration Tests for scripts/check-config-copies.sh
#
# The root of the project and config/dev-tools/ must say the same: the tests build a project with the layout of an
# installed package, set it up, then change the root.
#

# Load test helpers
load '../helpers/test_helper'

setup() {
  setup_test_env
  make_installed_project
}

teardown() {
  teardown_test_env
}

check_the_copies() {
  cd "${PROJECT}" || return 1
  run bash "${PACKAGE}/scripts/check-config-copies.sh"
}

@test "check-config-copies.sh passes after the setup" {
  check_the_copies

  [ "$status" -eq 0 ]
  [[ "$output" == *"The files of the root agree"* ]]
}

@test "check-config-copies.sh has nothing to compare without config/dev-tools" {
  rm -rf "${PROJECT}/config/dev-tools"

  check_the_copies

  [ "$status" -eq 0 ]
  [[ "$output" == *"nothing to compare"* ]]
}

@test "check-config-copies.sh fails when a copy of the root differs from config/dev-tools" {
  printf 'build/\n' > "${PROJECT}/.markdownlintignore"

  check_the_copies

  [ "$status" -eq 1 ]
  [[ "$output" == *".markdownlintignore at the root differs"* ]]
}

@test "check-config-copies.sh fails when a copy of the root is missing" {
  rm "${PROJECT}/.prettierignore"

  check_the_copies

  [ "$status" -eq 1 ]
  [[ "$output" == *".prettierignore is missing at the root"* ]]
}

@test "check-config-copies.sh fails when a thin file of the root does not point at config/dev-tools" {
  printf '{"extends":"./config/dev-tools/old.json"}\n' > "${PROJECT}/.markdownlint.json"

  check_the_copies

  [ "$status" -eq 1 ]
  [[ "$output" == *".markdownlint.json at the root does not point at config/dev-tools/.markdownlint.json"* ]]
}

@test "check-config-copies.sh accepts a configuration of its own at the root instead of a bridge" {
  printf 'export default []\n' > "${PROJECT}/eslint.config.mjs"

  check_the_copies

  [ "$status" -eq 0 ]
}

@test "check-config-copies.sh with SYNC=true writes the copies again from config/dev-tools" {
  printf 'build/\n' > "${PROJECT}/.markdownlintignore"

  cd "${PROJECT}" || return 1
  SYNC=true run bash "${PACKAGE}/scripts/check-config-copies.sh"

  [ "$status" -eq 0 ]
  run cmp "${PROJECT}/.markdownlintignore" "${PROJECT}/config/dev-tools/.markdownlintignore"
  [ "$status" -eq 0 ]
}
