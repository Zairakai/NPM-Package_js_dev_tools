#!/usr/bin/env bash
#
# Zairakai NPM Dev Tools - Setup Update
# Publishes again the files that setup-check.sh reports (missing or different), and only those.
#
# A file of the project that is replaced is copied in .dev-tools-backup/ first: nothing is merged, the project puts its own
# settings back from the copy.
#
# Usage:
#   bash setup-update.sh              # Publish again the files
#   DRY_RUN=true bash setup-update.sh # Lists the files, writes nothing
#

set -euo pipefail

# Load central configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/config.sh"
# shellcheck source=setup-state.sh
source "${SCRIPT_DIR}/setup-state.sh"

log_header "Setup update (files published by the setup)"

DRY_RUN="${DRY_RUN:-false}"

temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT

setup_generate "$temporary"

result=()
while IFS='|' read -r state file _; do
  [[ "$state" == "same" ]] && continue

  target="${PROJECT_ROOT}/${file}"

  # A symbolic link is the project's: writing in it would write in what it points at, and no copy of it is kept
  if [[ -L "$target" ]]; then
    result+=("keep: ${file} (symbolic link)")
    continue
  fi

  # A dry run says what it would do
  would=""
  [[ "$DRY_RUN" == "true" ]] && would="would "

  if [[ "$state" == "missing" ]]; then
    result+=("${would}create: ${file}")
  else
    result+=("${would}replace: ${file}")
  fi

  [[ "$DRY_RUN" == "true" ]] && continue

  # A Makefile that does not include the dev-tools is not replaced: the setup adds its block to it
  if [[ "$file" == "Makefile" ]]; then
    setup_backup "$target"
    bash "${SCRIPT_DIR}/setup-project.sh" --with-makefile --silent > /dev/null 2>&1 || true
    continue
  fi

  if [[ "$state" == "different" ]]; then
    setup_backup "$target"
  fi

  mkdir -p "$(dirname "$target")"
  cp "${temporary}/${file}" "$target"
done < <(setup_results "$temporary")

if [[ ${#result[@]} -eq 0 ]]; then
  log_success "Nothing to update: every file of the setup is the same as the package's"
  exit 0
fi

for line in "${result[@]}"; do
  log_info "$line"
done

if [[ "$DRY_RUN" == "true" ]]; then
  log_info "Dry run: nothing was written. Run: make setup-update"
else
  log_success "Updated. Put your own settings back from the copies in .dev-tools-backup/, then run: make setup-check"
fi
