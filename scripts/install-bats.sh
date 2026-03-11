#!/usr/bin/env bash
#
# Zairakai NPM Dev Tools - BATS Installer
# Installs BATS (Bash Automated Testing System) for shell script testing
#
# Platform: Linux/macOS/WSL
#
# Usage:
#   bash scripts/install-bats.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/config.sh"

# ============================================================================
# Configuration
# ============================================================================

CI_MODE="${CI:-false}"
TOOL_VERSIONS_FILE="${DEV_TOOLS_ROOT}/.tool-versions"
INSTALL_DIR="${HOME}/.local/share/bats"
BIN_DIR="${HOME}/.local/bin"

# ============================================================================
# Helpers
# ============================================================================

get_bats_version() {
    local version=""

    if [[ -f "${TOOL_VERSIONS_FILE}" ]]; then
        version="$(grep "^bats=" "${TOOL_VERSIONS_FILE}" | awk -F "=" '{print $2}' || echo "")"
        if [[ -n "${version}" ]]; then
            log_info "Found .tool-versions: ${version}"
        fi
    fi

    if [[ -z "${version}" ]]; then
        version="1.11.0"
        log_info "Using default version: ${version}"
    fi

    if [[ ! "${version}" =~ ^v ]]; then
        version="v${version}"
    fi

    echo "${version}"
}

version_ge() {
    local ver1="${1#v}"
    local ver2="${2#v}"

    if [[ "${ver1}" == "${ver2}" ]]; then
        return 0
    fi

    local IFS=.
    # shellcheck disable=SC2206
    local ver1_arr=($ver1) ver2_arr=($ver2)

    local i
    for ((i=${#ver1_arr[@]}; i<${#ver2_arr[@]}; i++)); do
        ver1_arr[i]=0
    done

    for ((i=0; i<${#ver1_arr[@]}; i++)); do
        if [[ -z "${ver2_arr[i]:-}" ]]; then
            ver2_arr[i]=0
        fi

        if ((10#${ver1_arr[i]} > 10#${ver2_arr[i]})); then
            return 0
        fi

        if ((10#${ver1_arr[i]} < 10#${ver2_arr[i]})); then
            return 1
        fi
    done

    return 0
}

check_bats_installed() {
    local required_version="$1"

    if ! command_exists bats; then
        return 1
    fi

    local current_version
    current_version="$(bats --version 2>/dev/null | awk '{print $2}' || echo "")"

    if [[ -z "${current_version}" ]]; then
        log_warning "Could not determine BATS version"
        return 1
    fi

    log_info "Current version: ${current_version}"

    if version_ge "${current_version}" "${required_version}"; then
        log_success "BATS ${current_version} is sufficient (need >=${required_version})"
        return 0
    fi

    log_warning "Version ${current_version} is outdated (need >=${required_version})"

    if [[ "${CI_MODE}" != "true" ]]; then
        echo ""
        read -rp "Upgrade to ${required_version}? (y/N) " -n 1
        echo ""

        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Keeping existing installation"
            return 0
        fi
    else
        log_info "CI mode: upgrading automatically"
    fi

    return 1
}

install_bats_core() {
    local version="$1"

    log_step "Installing BATS ${version} from source…"
    mkdir -p "${INSTALL_DIR}" "${BIN_DIR}"

    if [[ -d "${INSTALL_DIR}/bats-core" ]]; then
        log_info "BATS repository exists, updating…"
        git -C "${INSTALL_DIR}/bats-core" fetch --tags --quiet
        git -C "${INSTALL_DIR}/bats-core" checkout "${version}" --quiet
    else
        log_info "Cloning BATS repository…"
        git clone --quiet --depth 1 --branch "${version}" \
            https://github.com/bats-core/bats-core.git "${INSTALL_DIR}/bats-core"
    fi

    "${INSTALL_DIR}/bats-core/install.sh" "${HOME}/.local"
    log_success "BATS core installed to: ${BIN_DIR}/bats"

    if [[ ":$PATH:" != *":${BIN_DIR}:"* ]]; then
        echo ""
        log_warning "${BIN_DIR} is not in your PATH"
        echo ""
        echo "Add this to your ~/.bashrc or ~/.zshrc:"
        echo ""
        echo -e "  ${CYAN}export PATH=\"\${HOME}/.local/bin:\${PATH}\"${NC}"
        echo ""
    fi
}

install_bats_libraries() {
    log_step "Installing BATS support libraries…"

    local libraries=(
        "bats-support:https://github.com/bats-core/bats-support.git"
        "bats-assert:https://github.com/bats-core/bats-assert.git"
        "bats-file:https://github.com/bats-core/bats-file.git"
    )

    local lib_info lib_name lib_url lib_path
    for lib_info in "${libraries[@]}"; do
        lib_name="${lib_info%%:*}"
        lib_url="${lib_info#*:}"
        lib_path="${INSTALL_DIR}/${lib_name}"

        if [[ -d "${lib_path}" ]]; then
            log_info "${lib_name} already installed"
        else
            log_info "Installing ${lib_name}…"
            git clone --quiet --depth 1 "${lib_url}" "${lib_path}"
            log_success "${lib_name} installed"
        fi
    done
}

# ============================================================================
# Main
# ============================================================================

main() {
    local required_version
    required_version="$(get_bats_version)"

    echo ""
    log_header "BATS Installer"
    echo ""

    if check_bats_installed "${required_version}"; then
        echo ""
        log_info "No action needed — BATS is already available"
        echo ""
        exit 0
    fi

    echo ""
    log_warning "BATS not found or outdated — installing…"
    echo ""

    install_bats_core "${required_version}"
    install_bats_libraries

    echo ""
    log_success "BATS installation complete"
    echo ""

    if command_exists bats; then
        bats --version
        echo ""
        log_info "Libraries installed in: ${INSTALL_DIR}"
        echo ""
        log_info "Run tests with:"
        echo -e "  ${CYAN}make bats${NC}"
        echo -e "  ${CYAN}bats tests/bats/ --recursive${NC}"
        echo ""
    else
        log_error "BATS installation verification failed"
        exit 1
    fi
}

main "$@"
