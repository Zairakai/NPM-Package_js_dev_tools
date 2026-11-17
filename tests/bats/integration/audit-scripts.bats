#!/usr/bin/env bats
#
# Integration Tests for scripts/security-audit.sh
#
# npm is replaced by a command that answers what the test needs: the audit itself needs the network.
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

# security-audit.sh
# ================

@test "security-audit.sh passes when npm finds no advisory" {
  fake_command npm 'echo "{\"vulnerabilities\": {}}"'

  run_in_project security-audit.sh

  [ "$status" -eq 0 ]
  [[ "$output" == *"No security vulnerabilities found"* ]]
}

@test "security-audit.sh fails and names an advisory of the high level" {
  fake_command npm 'echo "{\"vulnerabilities\": {\"acme-lib\": {\"name\": \"acme-lib\", \"via\": [{\"name\": \"acme-lib\", \"source\": 7, \"severity\": \"high\", \"url\": \"https://example.test/7\"}]}}}"; exit 1'

  run_in_project security-audit.sh

  [ "$status" -eq 1 ]
  [[ "$output" == *"Blocking: acme-lib"* ]]
  [[ "$output" == *"high"* ]]
}

@test "security-audit.sh lists an advisory of an unknown severity as a medium one and does not fail" {
  fake_command npm 'echo "{\"vulnerabilities\": {\"acme-lib\": {\"name\": \"acme-lib\", \"via\": [{\"name\": \"acme-lib\", \"source\": 7}]}}}"; exit 1'

  run_in_project security-audit.sh

  [ "$status" -eq 0 ]
  [[ "$output" == *"Not blocking: acme-lib"* ]]
  [[ "$output" == *"unknown"* ]]
}

@test "security-audit.sh lists an advisory below the high level and does not fail" {
  fake_command npm 'echo "{\"vulnerabilities\": {\"acme-lib\": {\"name\": \"acme-lib\", \"via\": [{\"name\": \"acme-lib\", \"source\": 7, \"severity\": \"moderate\"}]}}}"; exit 1'

  run_in_project security-audit.sh

  [ "$status" -eq 0 ]
  [[ "$output" == *"Not blocking: acme-lib"* ]]
  [[ "$output" == *"No security vulnerabilities found"* ]]
}

@test "security-audit.sh fails when npm audit could not run" {
  fake_command npm 'echo "{\"error\": {\"code\": \"ENOTFOUND\"}}"; exit 1'

  run_in_project security-audit.sh

  [ "$status" -eq 1 ]
  [[ "$output" == *"could not run"* ]]
  [[ "$output" != *"No security vulnerabilities found"* ]]
}

@test "security-audit.sh fails when npm answers nothing that is a JSON" {
  fake_command npm 'echo "npm ERR! network"; exit 1'

  run_in_project security-audit.sh

  [ "$status" -eq 1 ]
}

@test "security-audit.sh writes the report in the build folder" {
  fake_command npm 'echo "{\"vulnerabilities\": {}}"'

  run_in_project security-audit.sh

  [ -f "${PROJECT}/build/reports/npm-audit.json" ]
}
