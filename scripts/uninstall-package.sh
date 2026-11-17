#!/usr/bin/env bash
#
# Zairakai NPM Dev Tools - Package Uninstall Script
# Removes the files installed by setup-project.sh, and only the ones that are still what the package publishes.
#
# Usage:
#   bash uninstall-package.sh             # Interactive mode (shows the files, asks before removing)
#   bash uninstall-package.sh --dry-run   # Lists the files, removes nothing
#   bash uninstall-package.sh --force     # Removes without asking, the files that the project changed included
#

set -euo pipefail

# Bootstrap
# ================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/config.sh"
# shellcheck source=setup-state.sh
source "${SCRIPT_DIR}/setup-state.sh"

# Arguments Parsing
# ================

FORCE_MODE=false
# DRY_RUN=true in the environment does the same as --dry-run (`DRY_RUN=true make uninstall`)
DRY_RUN="${DRY_RUN:-false}"

for arg in "$@"; do
  case "$arg" in
    --force|-f)
      FORCE_MODE=true
      ;;
    --dry-run|-n)
      DRY_RUN=true
      ;;
    --help|-h)
      echo "Usage: $0 [--dry-run] [--force]"
      echo ""
      echo "Removes the files installed by setup-project.sh that are still what the package publishes:"
      echo "  - Makefile and .editorconfig"
      echo "  - the thin files of the root (the bridges of the editors, .markdownlint.json) that point at config/dev-tools/"
      echo "  - the copies of the ignore files of the root"
      echo "  - config/dev-tools/ (the files that the project changed only after confirmation)"
      echo "  - the git hooks that the setup linked"
      echo ""
      echo "A file that the project changed is kept and named. Everything that is removed is copied first in"
      echo ".dev-tools-backup/<date>/, under its path from the root, and that folder is kept: to put everything"
      echo "back, copy it at the root (cp -R .dev-tools-backup/<date>/. .)."
      echo ""
      echo "Options:"
      echo "  --dry-run, -n  List the files, remove nothing"
      echo "  --force, -f    Remove without confirmation, the files of config/dev-tools/ that were changed included"
      echo "  --help, -h     Show this help message"
      exit 0
      ;;
    *)
      log_error "Unknown option: $arg"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Helpers
# ================

# What the uninstall does with a file of the setup that the project has, one line per file: "remove: <file>" when the file
# is still what the package publishes, "keep: <file> (<reason>)" when the project changed it. $2 is true to remove the
# files of config/dev-tools/ that the project changed too.
plan() {
  local temporary="$1" customized="$2" state file

  while IFS='|' read -r state file _; do
    [[ "$state" == "missing" ]] && continue

    local mine="${PROJECT_ROOT}/${file}"
    local generated="${temporary}/${file}"
    local ours=false
    local reason="customized"

    # A symbolic link is the project's: it stays, and no copy of it is kept
    if [[ -L "$mine" ]]; then
      echo "keep: ${file} (symbolic link)"
      continue
    fi

    case "$file" in
      Makefile)
        # The Makefile that the setup generated goes; one with the project's own targets stays
        cmp -s "$mine" "$generated" && ours=true
        ;;
      *.config.mjs | .markdownlint.json)
        # A thin file points at config/dev-tools/: without it, it would point at nothing
        grep -qF "config/dev-tools/" "$mine" && ours=true
        ;;
      config/dev-tools/*)
        if [[ "$state" == "same" ]] || [[ "$customized" == "true" ]]; then
          ours=true
        fi
        ;;
      *)
        [[ "$state" == "same" ]] && ours=true
        ;;
    esac

    if [[ "$ours" == "true" ]]; then
      echo "remove: ${file}"
    else
      echo "keep: ${file} (${reason})"
    fi
  done < <(setup_results "$temporary")
}

# The git hooks that the setup linked (install-hooks.sh links the hooks of the package in .git/hooks)
linked_hooks() {
  local hook count=0

  for hook in commit-msg prepare-commit-msg pre-commit pre-push; do
    [[ -L "${PROJECT_ROOT}/.git/hooks/${hook}" ]] && count=$((count + 1))
  done

  echo "$count"
}

remove_hooks() {
  local count
  count="$(linked_hooks)"
  [[ "$count" -gt 0 ]] || return 0

  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "  would remove the ${count} git hook(s) that the setup linked"
  else
    bash "${SCRIPT_DIR}/install-hooks.sh" --remove > /dev/null
    log_success "  Removed the ${count} git hook(s) that the setup linked"
  fi
}

# Main
# ================

# The folder of the generation: a global one, so the trap that removes it still sees it when the script ends
temporary=""
trap 'rm -rf "$temporary"' EXIT

uninstall_package() {
  log_header "🗑️  Package Development Uninstall"

  local lines changed line response
  temporary="$(mktemp -d)"

  setup_generate "$temporary"

  lines="$(plan "$temporary" "$FORCE_MODE")"

  if [[ -z "$lines" ]]; then
    log_info "Nothing to remove: no file of the setup is left"
    remove_hooks
    exit 0
  fi

  # With --force the removal itself lists the files: the plan is shown to ask, or for a dry run
  if [[ "$FORCE_MODE" != "true" ]] || [[ "$DRY_RUN" == "true" ]]; then
    while IFS= read -r line; do
      case "$line" in
        remove:*) log_info "  ${line}" ;;
        keep:*) log_warning "  ${line}" ;;
      esac
    done <<< "$lines"
    echo ""
  fi

  # The files of config/dev-tools/ that the project changed: removing them loses what the project wrote
  changed="$(grep -c '^keep: config/dev-tools/' <<< "$lines" || true)"

  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "Dry run: nothing was removed"
    remove_hooks
    exit 0
  fi

  local customized="$FORCE_MODE"

  if [[ "$FORCE_MODE" != "true" ]]; then
    read -r -p "Remove these files? [y/N] " response
    [[ "$response" =~ ^[Yy]$ ]] || {
      log_info "Uninstall cancelled"
      exit 0
    }

    if [[ "$changed" -gt 0 ]]; then
      echo ""
      read -r -p "Remove the ${changed} file(s) of config/dev-tools/ that were changed too (a copy is kept)? [y/N] " response
      [[ "$response" =~ ^[Yy]$ ]] && customized=true
    fi

    lines="$(plan "$temporary" "$customized")"
  fi

  echo ""
  log_step "Removing…"

  while IFS= read -r line; do
    case "$line" in
      remove:*)
        # Everything that goes is copied first: the folder of the backup is what puts it back
        setup_backup "${PROJECT_ROOT}/${line#remove: }"
        rm -f "${PROJECT_ROOT}/${line#remove: }"
        log_success "  ${line}"
        ;;
      keep:*) log_warning "  ${line}" ;;
    esac
  done <<< "$lines"

  # The folder of the configurations goes with its last file
  rmdir "${PROJECT_ROOT}/config/dev-tools" 2> /dev/null || true

  remove_hooks

  echo ""
  log_header "✅ Uninstall completed"
  echo ""

  if [[ -n "$BACKUP_DIR" ]]; then
    log_info "Everything that was removed is copied in ${BACKUP_DIR#"${PROJECT_ROOT}"/}/"
    log_info "To put it back: cp -R ${BACKUP_DIR#"${PROJECT_ROOT}"/}/. ."
    echo ""
  fi
}

# Execute
# ================

uninstall_package
