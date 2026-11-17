#!/usr/bin/env bats
#
# Integration Tests for scripts/setup-check.sh
#
# The check reads the project and the package, and writes nothing: the tests build a project with the layout of an
# installed package and run the script in it.
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

check_the_setup() {
  cd "${PROJECT}" || return 1
  run bash "${PACKAGE}/scripts/setup-check.sh"
}

# A project of Laravel with laravel-dev-tools: it owns the Makefile and the .editorconfig
make_fullstack() {
  mkdir -p "${PROJECT}/resources/js" "${PROJECT}/vendor/zairakai/laravel-dev-tools/scripts"
  touch "${PROJECT}/artisan" "${PROJECT}/vendor/zairakai/laravel-dev-tools/scripts/setup-package.sh"
}

@test "setup-check.sh succeeds when every file is published and the same" {
  check_the_setup

  [ "$status" -eq 0 ]
  [[ "$output" == *"Every file of the setup is published"* ]]
}

@test "setup-check.sh fails and names a file that is missing" {
  rm "${PROJECT}/config/dev-tools/vitest.config.js"

  check_the_setup

  [ "$status" -eq 1 ]
  [[ "$output" == *"config/dev-tools/vitest.config.js: missing"* ]]
  [[ "$output" == *"make setup-update"* ]]
}

@test "setup-check.sh fails and shows what differs in a file" {
  printf '// mine\n' >> "${PROJECT}/config/dev-tools/stylelint.config.js"

  check_the_setup

  [ "$status" -eq 1 ]
  [[ "$output" == *"config/dev-tools/stylelint.config.js: different"* ]]
  [[ "$output" == *"1 line(s) only in the project"* ]]
}

@test "setup-check.sh names the keys that differ in a JSON file" {
  printf '{"extends":"./other.json","mine":true}\n' > "${PROJECT}/config/dev-tools/.markdownlint.json"

  check_the_setup

  [ "$status" -eq 1 ]
  [[ "$output" == *"config/dev-tools/.markdownlint.json: different"* ]]
  [[ "$output" == *"only in the project: mine"* ]]
  [[ "$output" == *"changed: extends"* ]]
}

@test "setup-check.sh writes nothing in the project" {
  rm "${PROJECT}/config/dev-tools/vitest.config.js"

  check_the_setup

  [ ! -e "${PROJECT}/config/dev-tools/vitest.config.js" ]
  [ ! -d "${PROJECT}/.dev-tools-backup" ]
}

@test "setup-check.sh does not ask for a bridge when the project has its own configuration of the tool" {
  rm "${PROJECT}/eslint.config.mjs"
  printf 'export default []\n' > "${PROJECT}/eslint.config.js"

  check_the_setup

  [ "$status" -eq 0 ]
}

@test "setup-check.sh asks for a bridge that is missing" {
  rm "${PROJECT}/prettier.config.mjs"

  check_the_setup

  [ "$status" -eq 1 ]
  [[ "$output" == *"prettier.config.mjs: missing"* ]]
}

@test "setup-check.sh accepts a Makefile with targets of its own that includes the dev-tools" {
  printf 'build:\n\t@echo mine\n\ninclude node_modules/@zairakai/js-dev-tools/tools/make/core.mk\n' > "${PROJECT}/Makefile"

  check_the_setup

  [ "$status" -eq 0 ]
}

@test "setup-check.sh asks for the dev-tools in a Makefile that does not include them" {
  printf 'build:\n\t@echo mine\n' > "${PROJECT}/Makefile"

  check_the_setup

  [ "$status" -eq 1 ]
  [[ "$output" == *"Makefile: missing"* ]]
}

@test "setup-check.sh leaves the Makefile and the .editorconfig to laravel-dev-tools in a full-stack project" {
  make_fullstack
  rm "${PROJECT}/Makefile" "${PROJECT}/.editorconfig"

  check_the_setup

  [ "$status" -eq 0 ]
}
