#!/usr/bin/env bats
#
# Integration Tests for scripts/setup-update.sh
#
# The update publishes again what setup-check reports. The tests build a project with the layout of an installed package.
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

update_the_setup() {
  cd "${PROJECT}" || return 1
  run bash "${PACKAGE}/scripts/setup-update.sh"
}

check_the_setup() {
  cd "${PROJECT}" || return 1
  run bash "${PACKAGE}/scripts/setup-check.sh"
}

@test "setup-update.sh writes nothing when every file is the same" {
  update_the_setup

  [ "$status" -eq 0 ]
  [[ "$output" == *"Nothing to update"* ]]
  [ ! -d "${PROJECT}/.dev-tools-backup" ]
}

@test "setup-update.sh publishes a file that is missing, with no copy to keep" {
  rm "${PROJECT}/config/dev-tools/vitest.config.js"

  update_the_setup

  [ "$status" -eq 0 ]
  [ -f "${PROJECT}/config/dev-tools/vitest.config.js" ]
  [ ! -d "${PROJECT}/.dev-tools-backup" ]
}

@test "setup-update.sh replaces a different file after a copy of it in .dev-tools-backup" {
  printf '// mine\n' > "${PROJECT}/config/dev-tools/vitest.config.js"

  update_the_setup

  [ "$status" -eq 0 ]
  run grep -c '// mine' "${PROJECT}/config/dev-tools/vitest.config.js"
  [ "$output" = "0" ]
  run grep -rl '// mine' "${PROJECT}/.dev-tools-backup"
  [[ "$output" == *"config/dev-tools/vitest.config.js" ]]
}

@test "setup-update.sh leaves a file that is the same out of the copies" {
  printf '// mine\n' > "${PROJECT}/config/dev-tools/vitest.config.js"

  update_the_setup

  [ -z "$(find "${PROJECT}/.dev-tools-backup" -name 'prettier.config.js' | head -n 1)" ]
}

@test "setup-check.sh ends with 0 after setup-update.sh" {
  rm "${PROJECT}/config/dev-tools/vitest.config.js"
  printf '// mine\n' >> "${PROJECT}/config/dev-tools/stylelint.config.js"

  update_the_setup
  [ "$status" -eq 0 ]

  check_the_setup
  [ "$status" -eq 0 ]
}

@test "setup-update.sh adds the dev-tools to a Makefile that does not include them, and keeps its targets" {
  printf 'build:\n\t@echo mine\n' > "${PROJECT}/Makefile"

  update_the_setup

  [ "$status" -eq 0 ]
  run grep -c 'build:' "${PROJECT}/Makefile"
  [ "$output" = "1" ]
  run grep -c 'js-dev-tools' "${PROJECT}/Makefile"
  [ "$output" -gt 0 ]
  run grep -rl 'build:' "${PROJECT}/.dev-tools-backup"
  [[ "$output" == *"/Makefile" ]]

  check_the_setup
  [ "$status" -eq 0 ]
}

@test "setup-update.sh with DRY_RUN=true lists the files and writes nothing" {
  printf '// mine\n' > "${PROJECT}/config/dev-tools/vitest.config.js"
  export DRY_RUN=true

  update_the_setup

  [ "$status" -eq 0 ]
  [[ "$output" == *"would replace: config/dev-tools/vitest.config.js"* ]]
  run grep -c '// mine' "${PROJECT}/config/dev-tools/vitest.config.js"
  [ "$output" = "1" ]
  [ ! -d "${PROJECT}/.dev-tools-backup" ]
}

@test "setup-update.sh leaves a symbolic link alone and names it" {
  printf '# shared\n' > "${TEST_TEMP_DIR}/shared-editorconfig"
  rm "${PROJECT}/.editorconfig"
  ln -s "${TEST_TEMP_DIR}/shared-editorconfig" "${PROJECT}/.editorconfig"

  update_the_setup

  [ "$status" -eq 0 ]
  [[ "$output" == *"keep: .editorconfig (symbolic link)"* ]]
  [ -L "${PROJECT}/.editorconfig" ]
  [ "$(cat "${TEST_TEMP_DIR}/shared-editorconfig")" = "# shared" ]
}

