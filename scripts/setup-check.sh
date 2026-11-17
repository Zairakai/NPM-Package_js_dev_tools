#!/usr/bin/env bash
#
# Zairakai NPM Dev Tools - Setup Check
# Tells which files of the setup are missing or differ from what the package publishes now. Writes nothing.
#
# Usage:
#   bash setup-check.sh    # Exit code 0 when every file is the same, 1 when a file is missing or different
#

set -euo pipefail

# Load central configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/config.sh"
# shellcheck source=setup-state.sh
source "${SCRIPT_DIR}/setup-state.sh"

log_header "Setup check (files published by the setup)"

# Read only: the files that the setup would publish are generated in a temporary folder and compared with the project's.
# A file that differs is a change of the project or a file late on the package: the check shows the difference.
temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT

setup_generate "$temporary"

problems=()
while IFS='|' read -r state file detail; do
  [[ "$state" == "same" ]] && continue
  problems+=("${file}: ${state}${detail:+ (${detail})}")
done < <(setup_results "$temporary")

if [[ ${#problems[@]} -gt 0 ]]; then
  for line in "${problems[@]}"; do
    log_warning "$line"
  done
  log_info "To publish again what is missing or late (the old file is kept in .dev-tools-backup/): make setup-update"
  exit 1
fi

log_success "Every file of the setup is published and the same as the package's"
