#!/usr/bin/env bash
#
# Zairakai NPM Dev Tools - Config Copies Check
# The root of the project and config/dev-tools/ must say the same.
#
# The root holds what the editors read: thin files that point at config/dev-tools/ (the bridges and .markdownlint.json),
# and copies of the ignore files, which cannot point at another file. The scripts read config/dev-tools/.
#
# Usage:
#   bash check-config-copies.sh             # Exit code 0 when the root agrees, 1 otherwise
#   SYNC=true bash check-config-copies.sh   # Writes the copies of the root again from config/dev-tools/ first
#

set -euo pipefail

# Load central configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/config.sh"

log_header "Configuration of the editor (root and config/dev-tools)"

if [[ ! -d "${PROJECT_ROOT}/config/dev-tools" ]]; then
  log_info "No config/dev-tools/ in this project, nothing to compare"
  exit 0
fi

# The ignore files that the root holds as copies
copies=(.prettierignore .stylelintignore .markdownlintignore)

# SYNC=true writes again the copies of the root from config/dev-tools/ before the check
if [[ "${SYNC:-false}" == "true" ]]; then
  log_step "Writing again the copies of the root…"

  for name in "${copies[@]}"; do
    if [[ -f "${PROJECT_ROOT}/config/dev-tools/${name}" ]]; then
      cp "${PROJECT_ROOT}/config/dev-tools/${name}" "${PROJECT_ROOT}/${name}"
    fi
  done
fi

problems=()

for name in "${copies[@]}"; do
  published="${PROJECT_ROOT}/config/dev-tools/${name}"
  [[ -f "$published" ]] || continue

  if [[ ! -f "${PROJECT_ROOT}/${name}" ]]; then
    problems+=("${name} is missing at the root: it is a copy of config/dev-tools/${name}")
  elif ! cmp -s "${PROJECT_ROOT}/${name}" "$published"; then
    problems+=("${name} at the root differs from config/dev-tools/${name}")
  fi
done

# A thin file points at the file that it stands for: the one of config/dev-tools/ that exists
for key in eslint prettier stylelint vitest; do
  bridge="${PROJECT_ROOT}/${key}.config.mjs"
  published="config/dev-tools/${key}.config.js"

  [[ -f "$bridge" ]] || continue
  [[ -f "${PROJECT_ROOT}/${published}" ]] || continue

  # A bridge that the project replaced by its own configuration is not a thin file: it does not name config/dev-tools/
  if grep -qF "config/dev-tools/" "$bridge" && ! grep -qF "$published" "$bridge"; then
    problems+=("${key}.config.mjs at the root does not point at ${published}")
  fi
done

if [[ -f "${PROJECT_ROOT}/.markdownlint.json" ]] && [[ -f "${PROJECT_ROOT}/config/dev-tools/.markdownlint.json" ]]; then
  if ! grep -qF "config/dev-tools/.markdownlint.json" "${PROJECT_ROOT}/.markdownlint.json"; then
    problems+=(".markdownlint.json at the root does not point at config/dev-tools/.markdownlint.json")
  fi
fi

if [[ ${#problems[@]} -gt 0 ]]; then
  for line in "${problems[@]}"; do
    log_error "$line"
  done
  log_info "Run: SYNC=true bash node_modules/@zairakai/js-dev-tools/scripts/check-config-copies.sh"
  exit 1
fi

log_success "The files of the root agree with config/dev-tools/"
