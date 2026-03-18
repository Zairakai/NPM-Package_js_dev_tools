#!/usr/bin/env bash
#
# Zairakai NPM Dev Tools - Project Setup Script
#
# Usage:
#   bash setup-project.sh                            # Normal setup (Makefile + .editorconfig + eslint baseline)
#   bash setup-project.sh --publish                  # Publish all configs to config/dev-tools/
#   bash setup-project.sh --publish=quality          # Publish quality group (eslint)
#   bash setup-project.sh --publish=style            # Publish style group (prettier, stylelint, ignore files)
#   bash setup-project.sh --publish=testing          # Publish vitest config
#   bash setup-project.sh --publish=gitlab-ci          # Publish GitLab CI (auto-detects project type)
#   bash setup-project.sh --publish=eslint            # Publish specific config
#   bash setup-project.sh --with-makefile             # Also generate/inject Makefile
#   bash setup-project.sh --force                     # Force overwrite existing files
#   bash setup-project.sh --silent                    # Suppress output (errors only)
#   bash setup-project.sh --help                      # Show this help
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/config.sh"

# ============================================================================
# CI Mode Detection — delegates to IS_CI exported by config.sh
# ============================================================================
CI_MODE="$IS_CI"

# ============================================================================
# Publishable configs registry
# Format: [key]="source_relative_to_dev_tools|target_relative_to_project|group"
# Note: gitlab-ci has a special handler (auto-detects project type) — not in this registry.
# ============================================================================

declare -A PUBLISHABLE=(
    ["eslint"]="stubs/quality/eslint.config.js.stub|config/dev-tools/eslint.config.js|quality"
    ["knip"]="stubs/quality/knip.config.js.stub|config/dev-tools/knip.config.js|quality"
    ["prettier"]="stubs/style/prettier.config.js.stub|config/dev-tools/prettier.config.js|style"
    ["stylelint"]="stubs/style/stylelint.config.js.stub|config/dev-tools/stylelint.config.js|style"
    ["prettierignore"]="config/.prettierignore|config/dev-tools/.prettierignore|style"
    ["stylelintignore"]="config/.stylelintignore|config/dev-tools/.stylelintignore|style"
    ["markdownlint"]="config/.markdownlint.json|config/dev-tools/.markdownlint.json|style"
    ["markdownlintignore"]="config/.markdownlintignore|config/dev-tools/.markdownlintignore|style"
    ["vitest"]="stubs/testing/vitest.config.js.stub|config/dev-tools/vitest.config.js|testing"
    ["tsconfig"]="stubs/typescript/tsconfig.json.stub|tsconfig.json|typescript"
)

declare -A PUBLISH_GROUPS=(
    ["quality"]="eslint knip"
    ["style"]="prettier stylelint prettierignore stylelintignore markdownlint markdownlintignore"
    ["testing"]="vitest"
    ["typescript"]="tsconfig"
    ["hooks"]="hooks"
    ["governance"]="governance"
    ["all"]="eslint knip prettier stylelint prettierignore stylelintignore markdownlint markdownlintignore vitest tsconfig hooks"
)

# ============================================================================
# Argument Parsing
# ============================================================================

FORCE_OVERWRITE=false
SILENT_MODE=false
PUBLISH_TARGET=""
WITH_MAKEFILE=false

for arg in "$@"; do
    case "$arg" in
        --force|-f)      FORCE_OVERWRITE=true ;;
        --silent|-s)     SILENT_MODE=true ;;
        --with-makefile) WITH_MAKEFILE=true ;;
        --publish)       PUBLISH_TARGET="all" ;;
        --publish=*)     PUBLISH_TARGET="${arg#--publish=}" ;;
        --help|-h)
            echo ""
            echo "Usage: bash setup-project.sh [options]"
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "  Options"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "  (no options)              Normal setup (Makefile + .editorconfig + eslint baseline)"
            echo "  --publish                 Publish ALL configs to config/dev-tools/"
            echo "  --publish=<group>         Publish a config group"
            echo "  --publish=<key>           Publish a specific config"
            echo "  --with-makefile           Generate or inject Makefile"
            echo "  --force, -f               Overwrite existing files"
            echo "  --silent, -s              Suppress output (for postinstall)"
            echo "  --help, -h                Show this help"
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "  Groups (--publish=<group>)"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "  quality    eslint"
            echo "  style      prettier, stylelint, markdownlint, .prettierignore, .stylelintignore, .markdownlintignore"
            echo "  testing    vitest"
            echo "  typescript tsconfig"
            echo "  all        all configs (except gitlab-ci)"
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "  Specific configs (--publish=<key>)"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "  eslint              → config/dev-tools/eslint.config.js"
            echo "  prettier            → config/dev-tools/prettier.config.js"
            echo "  stylelint           → config/dev-tools/stylelint.config.js"
            echo "  prettierignore      → config/dev-tools/.prettierignore"
            echo "  stylelintignore     → config/dev-tools/.stylelintignore"
            echo "  markdownlint        → config/dev-tools/.markdownlint.json"
            echo "  markdownlintignore  → config/dev-tools/.markdownlintignore"
            echo "  vitest              → config/dev-tools/vitest.config.js"
            echo "  tsconfig            → tsconfig.json (extends bundled base)"
            echo "  gitlab-ci           → auto-detect: .gitlab-ci.yml or .gitlab/pipeline-js-app.yml"
            echo "  governance          → SECURITY.md, CONTRIBUTING.md, CODE_OF_CONDUCT.md"
            echo ""
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option: $arg" >&2
            echo "Use --help for usage information" >&2
            exit 1
            ;;
    esac
done

# ============================================================================
# Silent Mode Override
# ============================================================================

if [[ "$SILENT_MODE" == "true" ]]; then
    log_header()  { :; }
    log_step()    { :; }
    log_info()    { :; }
    log_success() { :; }
    log_warning() { :; }
fi

# ============================================================================
# Optional Dependencies Check
# Runs after setup — shows informative messages even in silent mode (postinstall)
# ============================================================================

check_optional_deps() {
    local -a missing=()

    # zod — runtime type validation (validates API responses / form inputs at runtime)
    [[ ! -d "${PROJECT_ROOT}/node_modules/zod" ]] \
        && missing+=("zod|Runtime type validation for JS/Vue (validates API responses, forms)|${PM} install zod")

    # typescript — enables make typecheck and make build
    [[ ! -d "${PROJECT_ROOT}/node_modules/typescript" ]] \
        && missing+=("typescript|TypeScript compiler — enables make typecheck + make build|${PM} install --save-dev typescript")

    # tsup — fast TS bundler (recommended for npm packages to publish)
    [[ ! -d "${PROJECT_ROOT}/node_modules/tsup" ]] \
        && missing+=("tsup|Fast TypeScript bundler for npm packages (esbuild-based)|${PM} install --save-dev tsup")

    # knip — unused exports, files and dependencies detector
    [[ ! -d "${PROJECT_ROOT}/node_modules/knip" ]] \
        && missing+=("knip|Unused exports and dependencies detector (make knip)|${PM} install --save-dev knip")

    [[ ${#missing[@]} -eq 0 ]] && return 0

    if [[ "$SILENT_MODE" == "true" ]]; then
        echo ""
        echo "  ┌─ @zairakai/js-dev-tools — optional packages not installed ─┐"
        for entry in "${missing[@]}"; do
            local pkg="${entry%%|*}"
            local rest="${entry#*|}"
            local install_cmd="${rest#*|}"
            printf "  │  %-12s  %s\n" "${pkg}" "${install_cmd}"
        done
        echo "  └─ Run: bash setup-project.sh (without --silent) for details ┘"
        echo ""
        return 0
    fi

    echo ""
    echo -e "${YELLOW}┌──────────────────────────────────────────────────────┐${NC}"
    echo -e "${YELLOW}│${NC}       ${YELLOW}Recommended Optional Packages${NC}               ${YELLOW}│${NC}"
    echo -e "${YELLOW}├──────────────────────────────────────────────────────┤${NC}"
    for entry in "${missing[@]}"; do
        local pkg="${entry%%|*}"
        local rest="${entry#*|}"
        local reason="${rest%%|*}"
        local install_cmd="${rest#*|}"
        echo -e "${YELLOW}│${NC}  ${CYAN}${pkg}${NC}"
        echo -e "${YELLOW}│${NC}    ${reason}"
        echo -e "${YELLOW}│${NC}    ${GREEN}${install_cmd}${NC}"
        echo -e "${YELLOW}│${NC}"
    done
    echo -e "${YELLOW}└──────────────────────────────────────────────────────┘${NC}"
    echo ""
}

# ============================================================================
# Result Tracking
# ============================================================================

declare -a CREATED_FILES=()
declare -a SKIPPED_FILES=()
declare -a BACKED_UP_FILES=()
declare -a PUBLISHED_FILES=()

track_created()   { CREATED_FILES+=("$1"); }
track_skipped()   { SKIPPED_FILES+=("$1"); }
track_backed_up() { BACKED_UP_FILES+=("$1"); }
track_published() { PUBLISHED_FILES+=("$1"); }

# ============================================================================
# File Helpers
# ============================================================================

# Publish a config to config/dev-tools/ (user-facing, hash-protected)
publish_file() {
    local source="$1"
    local target="$2"
    local name="$3"

    if [[ ! -f "$source" ]]; then
        log_warning "Source not found for ${name}: ${source#"$DEV_TOOLS_ROOT"/}"
        return 0
    fi

    if [[ -f "$target" ]] && [[ "$FORCE_OVERWRITE" != "true" ]]; then
        local src_hash tgt_hash
        src_hash="$(file_hash "$source")"
        tgt_hash="$(file_hash "$target")"

        if [[ -n "$src_hash" ]] && [[ "$src_hash" == "$tgt_hash" ]]; then
            cp "$source" "$target"
            track_published "${name} → ${target#"$PROJECT_ROOT"/} (refreshed)"
        else
            track_skipped "$name"
            log_info "Skipping modified: ${name} (use --force to overwrite)"
        fi
        return 0
    fi

    if [[ -f "$target" ]] && [[ "$FORCE_OVERWRITE" == "true" ]]; then
        if backup_file "$target" 2>/dev/null; then
            track_backed_up "$name"
        fi
    fi

    mkdir -p "$(dirname "$target")"
    cp "$source" "$target"
    track_published "${name} → ${target#"$PROJECT_ROOT"/}"
    log_success "Published: ${name} → ${target#"$PROJECT_ROOT"/}"
}

# Copy file for standard setup (skips if exists unless --force or CI)
setup_file() {
    local source="$1"
    local target="$2"
    local name="$3"

    if [[ "$CI_MODE" == "true" ]] || [[ "$FORCE_OVERWRITE" == "true" ]]; then
        if [[ -f "$target" ]] && [[ ! -L "$target" ]] && [[ "$CI_MODE" != "true" ]]; then
            if backup_file "$target" 2>/dev/null; then
                track_backed_up "$name"
            fi
        fi
        rm -f "$target" 2>/dev/null || true
        mkdir -p "$(dirname "$target")"
        if cp "$source" "$target" 2>/dev/null; then
            track_created "$name"
            log_success "Created: $name"
        fi
    else
        if [[ -f "$target" ]] || [[ -L "$target" ]]; then
            track_skipped "$name"
            return 0
        fi
        mkdir -p "$(dirname "$target")"
        if cp "$source" "$target" 2>/dev/null; then
            track_created "$name"
            log_success "Created: $name"
        fi
    fi
}

# ============================================================================
# Governance Files Publisher
# Publishes SECURITY.md, CONTRIBUTING.md, CODE_OF_CONDUCT.md to project root.
# Replaces PACKAGE_GITLAB_ISSUES with the actual GitLab issues URL.
# Hash-protected: skips files modified by the user (use --force to overwrite).
# Not included in "all" — requires explicit opt-in (--publish=governance).
# ============================================================================

publish_governance_file() {
    local source="$1"
    local target="$2"
    local name="$3"
    local issues_url="$4"

    if [[ ! -f "$source" ]]; then
        log_warning "Stub not found: stubs/governance/${name}"
        return 0
    fi

    # Process placeholders into a temp file for hash comparison and copy
    local processed
    processed="$(mktemp)"
    sed "s|PACKAGE_GITLAB_ISSUES|${issues_url}|g" "$source" > "$processed"

    if [[ -f "$target" ]] && [[ "$FORCE_OVERWRITE" != "true" ]]; then
        local src_hash tgt_hash
        src_hash="$(file_hash "$processed")"
        tgt_hash="$(file_hash "$target")"

        if [[ -n "$src_hash" ]] && [[ "$src_hash" == "$tgt_hash" ]]; then
            cp "$processed" "$target"
            track_published "${name} (refreshed)"
        else
            track_skipped "$name"
            log_info "Skipping modified: ${name} (use --force to overwrite)"
        fi
        rm -f "$processed"
        return 0
    fi

    if [[ -f "$target" ]] && [[ "$FORCE_OVERWRITE" == "true" ]]; then
        backup_file "$target" 2>/dev/null || true
        track_backed_up "$name"
    fi

    cp "$processed" "$target"
    rm -f "$processed"
    track_published "$name"
    log_success "Published: ${name}"
}

publish_governance_files() {
    local pkg_name
    pkg_name="$(node -e "try{const p=require('${PROJECT_ROOT}/package.json');console.log(p.name||'')}catch(e){}" 2>/dev/null || echo "")"

    local pkg_short="${pkg_name##*/}"   # strip scope: @zairakai/js-dev-tools → dev-tools
    local issues_url="https://gitlab.com/zairakai/npm-packages/${pkg_short}/-/issues"

    local -a docs=("SECURITY.md" "CONTRIBUTING.md" "CODE_OF_CONDUCT.md")

    for filename in "${docs[@]}"; do
        publish_governance_file \
            "${DEV_TOOLS_ROOT}/stubs/governance/${filename}.stub" \
            "${PROJECT_ROOT}/${filename}" \
            "$filename" \
            "$issues_url"
    done
}

# ============================================================================
# GitLab CI — Placeholder Replacement Helper
# ============================================================================

# Extract package name and derive cache key from package.json
get_package_info() {
    local pkg_name pkg_cache_key

    pkg_name="$(node -e "try{const p=require('${PROJECT_ROOT}/package.json');console.log(p.name||'')}catch(e){}" 2>/dev/null || echo "")"
    pkg_cache_key="${pkg_name##*/}"   # strip scope: @org/my-pkg → my-pkg
    pkg_cache_key="${pkg_cache_key}-v1"

    echo "${pkg_name}|${pkg_cache_key}"
}

# Replace placeholders in a published GitLab CI file
replace_gitlab_ci_placeholders() {
    local target="$1"
    local pkg_info
    pkg_info="$(get_package_info)"

    local pkg_name="${pkg_info%%|*}"
    local pkg_cache_key="${pkg_info#*|}"

    # Get current version of @zairakai/js-dev-tools
    local dev_tools_version
    dev_tools_version="$(node -e "try{const p=require('${DEV_TOOLS_ROOT}/package.json');console.log(p.version||'0.0.0')}catch(e){}" 2>/dev/null || echo "0.0.0")"

    if [[ -n "$pkg_name" ]]; then
        sed -i "s|PACKAGE_NPM_NAME|${pkg_name}|g" "$target"
        sed -i "s|PACKAGE_CACHE_KEY|${pkg_cache_key}|g" "$target"
    fi

    if [[ -n "$dev_tools_version" ]]; then
        sed -i "s|v0.0.0|v${dev_tools_version}|g" "$target"
    fi
}

# ============================================================================
# GitLab CI — NPM Package (.gitlab-ci.yml)
# ============================================================================

publish_gitlab_ci_npm() {
    local source="${DEV_TOOLS_ROOT}/stubs/gitlab-ci/gitlab-ci.yml.stub"
    local target="${PROJECT_ROOT}/.gitlab-ci.yml"
    local name="gitlab-ci"

    if [[ ! -f "$source" ]]; then
        log_warning "Stub not found: stubs/gitlab-ci/gitlab-ci.yml.stub"
        return 0
    fi

    if [[ -f "$target" ]] && [[ "$FORCE_OVERWRITE" != "true" ]]; then
        track_skipped "$name"
        log_info "Already exists: .gitlab-ci.yml (use --force to overwrite)"
        return 0
    fi

    if [[ -f "$target" ]] && [[ "$FORCE_OVERWRITE" == "true" ]]; then
        if backup_file "$target" 2>/dev/null; then
            track_backed_up ".gitlab-ci.yml"
        fi
    fi

    cp "$source" "$target"
    replace_gitlab_ci_placeholders "$target"

    track_published ".gitlab-ci.yml"
    log_success "Published: .gitlab-ci.yml"
    log_info "ref: v0.0.0 will be updated automatically on: ${PM} update @zairakai/js-dev-tools"
}

# ============================================================================
# GitLab CI — Laravel App (.gitlab/pipeline-js-app.yml + inject .gitlab-ci.yml)
# ============================================================================

# Publish .gitlab/pipeline-js-app.yml (the JS pipeline fragment)
publish_gitlab_pipeline_js() {
    local source="${DEV_TOOLS_ROOT}/stubs/gitlab-ci/gitlab-pipeline-js-app.yml.stub"
    local target="${PROJECT_ROOT}/.gitlab/pipeline-js-app.yml"
    local name="gitlab/pipeline-js-app.yml"

    if [[ ! -f "$source" ]]; then
        log_warning "Stub not found: stubs/gitlab-ci/gitlab-pipeline-js-app.yml.stub"
        return 0
    fi

    if [[ -f "$target" ]] && [[ "$FORCE_OVERWRITE" != "true" ]]; then
        track_skipped "$name"
        log_info "Already exists: .gitlab/pipeline-js-app.yml (use --force to overwrite)"
        return 0
    fi

    if [[ -f "$target" ]] && [[ "$FORCE_OVERWRITE" == "true" ]]; then
        if backup_file "$target" 2>/dev/null; then
            track_backed_up ".gitlab/pipeline-js-app.yml"
        fi
    fi

    mkdir -p "${PROJECT_ROOT}/.gitlab"
    cp "$source" "$target"
    replace_gitlab_ci_placeholders "$target"

    track_published ".gitlab/pipeline-js-app.yml"
    log_success "Published: .gitlab/pipeline-js-app.yml"
}

# Inject the local pipeline-js-app.yml include into .gitlab-ci.yml (or create it)
inject_or_create_gitlab_ci() {
    local target="${PROJECT_ROOT}/.gitlab-ci.yml"
    local marker="# @zairakai/js-dev-tools — JS"

    if [[ ! -f "$target" ]]; then
        # No .gitlab-ci.yml yet — create a minimal one
        cat > "$target" << 'GITLAB_EOF'
# .gitlab-ci.yml
# Generated by @zairakai/js-dev-tools setup-project.sh
# To regenerate:
#   bash node_modules/@zairakai/js-dev-tools/scripts/setup-project.sh --publish=gitlab-ci --force

include:
  # JavaScript/frontend pipeline:
  - local: '.gitlab/pipeline-js-app.yml'

# @zairakai/js-dev-tools — JS ────────────────────────────────────────────────────
GITLAB_EOF
        track_created ".gitlab-ci.yml"
        log_success "Created: .gitlab-ci.yml (includes .gitlab/pipeline-js-app.yml)"
        return 0
    fi

    # .gitlab-ci.yml exists — check if already injected
    if grep -qF "$marker" "$target" 2>/dev/null; then
        log_info ".gitlab-ci.yml already includes pipeline-js-app.yml — skipping"
        track_skipped ".gitlab-ci.yml (already injected)"
        return 0
    fi

    log_info "Existing .gitlab-ci.yml detected — injecting pipeline-js-app.yml include"

    if [[ "$FORCE_OVERWRITE" == "true" ]]; then
        if backup_file "$target" 2>/dev/null; then
            track_backed_up ".gitlab-ci.yml"
        fi
    fi

    cat >> "$target" << 'INJECT_EOF'

# @zairakai/js-dev-tools — JS ────────────────────────────────────────────────────
# Injected by: bash node_modules/@zairakai/js-dev-tools/scripts/setup-project.sh --publish=gitlab-ci
# Adds JavaScript quality and test jobs.
include:
  - local: '.gitlab/pipeline-js-app.yml'
INJECT_EOF

    track_created ".gitlab-ci.yml (injected)"
    log_success "Injected pipeline-js-app.yml include into .gitlab-ci.yml"
}

publish_gitlab_ci_laravel() {
    publish_gitlab_pipeline_js
    inject_or_create_gitlab_ci
}

# ============================================================================
# Git Hooks — Install into .git/hooks
# ============================================================================

publish_hooks() {
    local installer="${DEV_TOOLS_ROOT}/scripts/install-hooks.sh"

    if [[ ! -f "$installer" ]]; then
        log_warning "Hooks installer not found: scripts/install-hooks.sh"
        return 0
    fi

    log_info "Git hooks detected → installing hooks via scripts/install-hooks.sh"
    bash "$installer" --install
}

# ============================================================================
# Publish Logic
# ============================================================================

resolve_publish_keys() {
    local target="$1"

    # Special handlers — not in PUBLISHABLE
    if [[ "$target" == "gitlab-ci" || "$target" == "hooks" ]]; then
        echo "$target"
        return 0
    fi

    if [[ -n "${PUBLISH_GROUPS[$target]:-}" ]]; then
        echo "${PUBLISH_GROUPS[$target]}"
        return 0
    fi

    if [[ -n "${PUBLISHABLE[$target]:-}" ]]; then
        echo "$target"
        return 0
    fi

    log_error "Unknown publish target: '${target}'"
    echo "" >&2
    echo "Valid groups: ${!PUBLISH_GROUPS[*]}" >&2
    echo "Valid configs: ${!PUBLISHABLE[*]} gitlab-ci hooks" >&2
    echo "Run --help for details" >&2
    exit 1
}

# Dispatch --publish=gitlab-ci based on detected project type.
# When laravel-dev-tools is present, delegates to it so the fullstack stub
# (single source of truth in laravel-dev-tools) is used automatically.
publish_gitlab_ci() {
    if [[ "$PROJECT_TYPE" == "laravel-app" ]]; then
        local laravel_setup="${PROJECT_ROOT}/vendor/zairakai/laravel-dev-tools/scripts/setup-package.sh"
        if [[ -f "$laravel_setup" ]]; then
            log_info "laravel-dev-tools detected → delegating gitlab-ci publish (fullstack)"
            local extra_args=()
            [[ "$FORCE_OVERWRITE" == "true" ]] && extra_args+=("--force")
            [[ "$SILENT_MODE" == "true" ]] && extra_args+=("--silent")
            bash "$laravel_setup" --publish=gitlab-ci "${extra_args[@]}"
            return 0
        fi
        log_info "Project type: laravel-app → publishing .gitlab/pipeline-js-app.yml"
        publish_gitlab_ci_laravel
    else
        log_info "Project type: npm-package → publishing .gitlab-ci.yml"
        publish_gitlab_ci_npm
    fi
}

do_publish() {
    local -a keys
    read -ra keys <<< "$(resolve_publish_keys "$PUBLISH_TARGET")"

    log_header "Publishing Dev Tools Configs"

    for key in "${keys[@]}"; do
        # Dispatch special handler — project-type aware
        if [[ "$key" == "gitlab-ci" ]]; then
            publish_gitlab_ci
            continue
        fi

        # Dispatch special handler — git hooks
        if [[ "$key" == "hooks" ]]; then
            publish_hooks
            continue
        fi

        # Dispatch special handler — governance files
        if [[ "$key" == "governance" ]]; then
            publish_governance_files
            continue
        fi

        local entry="${PUBLISHABLE[$key]:-}"
        [[ -z "$entry" ]] && continue

        local source_rel="${entry%%|*}"
        local rest="${entry#*|}"
        local target_rel="${rest%%|*}"

        publish_file \
            "${DEV_TOOLS_ROOT}/${source_rel}" \
            "${PROJECT_ROOT}/${target_rel}" \
            "$key"

        # After publishing markdownlint config to config/dev-tools/, also create a root
        # .markdownlint.json that extends it — IDEs and editor extensions look at root.
        if [[ "$key" == "markdownlint" ]]; then
            local root_markdownlint="${PROJECT_ROOT}/.markdownlint.json"
            local root_content='{"extends":"./config/dev-tools/.markdownlint.json"}'

            if [[ ! -f "$root_markdownlint" ]]; then
                echo "$root_content" > "$root_markdownlint"
                track_created ".markdownlint.json (root — extends config/dev-tools/)"
                log_success "Created: .markdownlint.json → extends config/dev-tools/.markdownlint.json"
            fi
        fi
    done
}

# ============================================================================
# Makefile Setup
# ============================================================================

generate_makefile() {
    local target="${PROJECT_ROOT}/Makefile"
    local package_name

    package_name="$(node -e "try{const p=require('${PROJECT_ROOT}/package.json');console.log(p.name||'')}catch(e){}" 2>/dev/null || echo "")"

    cat > "$target" << 'MAKEFILE_EOF'
# Makefile
# Generated by @zairakai/js-dev-tools setup-project.sh
# Run `make help` to see available commands.
#
# To regenerate:
#   bash node_modules/@zairakai/js-dev-tools/scripts/setup-project.sh --with-makefile --force

MAKEFILE_EOF

    if [[ -n "$package_name" ]]; then
        echo "NPM_DIRECTORY_TOOLS_PROJECT_NAME := \"${package_name}\"" >> "$target"
        echo "" >> "$target"
    fi

    cat >> "$target" << 'MAKEFILE_EOF'
DEV_TOOLS_NPM := node_modules/@zairakai/js-dev-tools

include $(DEV_TOOLS_NPM)/tools/make/core.mk
MAKEFILE_EOF

    track_created "Makefile"
    log_success "Created: Makefile"
}

inject_makefile() {
    local target="${PROJECT_ROOT}/Makefile"
    local marker="# @zairakai/js-dev-tools"

    if grep -qF "$marker" "$target" 2>/dev/null; then
        log_info "Makefile already includes @zairakai/js-dev-tools — skipping"
        track_skipped "Makefile (already injected)"
        return 0
    fi

    log_info "Existing Makefile detected — injecting @zairakai/js-dev-tools includes"

    cat >> "$target" << 'INJECT_EOF'

# ─── @zairakai/js-dev-tools ─────────────────────────────────────────────────────
# Injected by: bash node_modules/@zairakai/js-dev-tools/scripts/setup-project.sh --with-makefile
# Provides: eslint, prettier, stylelint, markdownlint, shellcheck, typecheck, build, knip, test, quality, bats targets
DEV_TOOLS_NPM := node_modules/@zairakai/js-dev-tools
-include $(DEV_TOOLS_NPM)/tools/make/variables.mk
-include $(DEV_TOOLS_NPM)/tools/make/help.mk
-include $(DEV_TOOLS_NPM)/tools/make/code-style.mk
-include $(DEV_TOOLS_NPM)/tools/make/stylelint.mk
-include $(DEV_TOOLS_NPM)/tools/make/markdownlint.mk
-include $(DEV_TOOLS_NPM)/tools/make/shellcheck.mk
-include $(DEV_TOOLS_NPM)/tools/make/typescript.mk
-include $(DEV_TOOLS_NPM)/tools/make/quality.mk
-include $(DEV_TOOLS_NPM)/tools/make/test.mk
-include $(DEV_TOOLS_NPM)/tools/make/bats.mk
INJECT_EOF

    track_created "Makefile (injected)"
    log_success "Injected @zairakai/js-dev-tools targets into existing Makefile"
    log_info "Note: 'make help' will show JS targets alongside your existing targets"
}

setup_makefile() {
    local target="${PROJECT_ROOT}/Makefile"

    if [[ -f "$target" ]]; then
        inject_makefile
    else
        generate_makefile
    fi
}

# ============================================================================
# Main Setup
# ============================================================================

setup_project() {
    [[ "$SILENT_MODE" != "true" ]] && {
        echo ""
        echo -e "${MAGENTA}📦 NPM Dev Tools Setup${NC}"
        echo -e "${CYAN}Type:${NC} ${PROJECT_TYPE} | ${CYAN}Package manager:${NC} ${PM}"
        echo ""
    }

    # ─── Publish mode ────────────────────────────────────────────────────────
    if [[ -n "$PUBLISH_TARGET" ]]; then
        do_publish

        [[ "$WITH_MAKEFILE" == "true" ]] && setup_makefile

        echo ""
        echo -e "${MAGENTA}┌────────────────────────────────────────┐${NC}"
        echo -e "${MAGENTA}│${NC}         ${GREEN}Publish Complete${NC}              ${MAGENTA}│${NC}"
        echo -e "${MAGENTA}├────────────────────────────────────────┤${NC}"

        for f in "${PUBLISHED_FILES[@]}"; do
            echo -e "${MAGENTA}│${NC} ${GREEN}✓${NC} ${f}"
        done

        if [[ ${#CREATED_FILES[@]} -gt 0 ]]; then
            for f in "${CREATED_FILES[@]}"; do
                echo -e "${MAGENTA}│${NC} ${GREEN}✓${NC} ${f}"
            done
        fi

        if [[ ${#SKIPPED_FILES[@]} -gt 0 ]]; then
            echo -e "${MAGENTA}│${NC} ${YELLOW}○ Skipped (modified):${NC} ${SKIPPED_FILES[*]}"
            echo -e "${MAGENTA}│${NC}   ${YELLOW}→ Use --force to overwrite${NC}"
        fi

        if [[ ${#BACKED_UP_FILES[@]} -gt 0 ]]; then
            echo -e "${MAGENTA}│${NC} ${CYAN}↩ Backed up:${NC} ${BACKED_UP_FILES[*]}"
            echo -e "${MAGENTA}│${NC}   ${CYAN}→ ${BACKUP_DIR}${NC}"
        fi

        echo -e "${MAGENTA}├────────────────────────────────────────┤${NC}"
        echo -e "${MAGENTA}│${NC} ${CYAN}Edit configs in:${NC} config/dev-tools/"
        echo -e "${MAGENTA}│${NC} ${CYAN}Help:${NC} bash setup-project.sh --help"
        echo -e "${MAGENTA}└────────────────────────────────────────┘${NC}"
        echo ""
        exit 0
    fi

    # ─── Normal setup ────────────────────────────────────────────────────────

    ensure_dir "${PROJECT_ROOT}/config/dev-tools"

    if [[ "$PROJECT_TYPE" == "laravel-app" ]] \
        && [[ -f "${PROJECT_ROOT}/vendor/zairakai/laravel-dev-tools/scripts/setup-package.sh" ]]; then
        log_info "Laravel app detected — delegating setup to laravel-dev-tools (full-stack)"
        extra_args=()
        [[ "$FORCE_OVERWRITE" == "true" ]] && extra_args+=("--force")
        [[ "$SILENT_MODE" == "true" ]] && extra_args+=("--silent")
        bash "${PROJECT_ROOT}/vendor/zairakai/laravel-dev-tools/scripts/setup-package.sh" --fullstack "${extra_args[@]}"
    else
        if [[ "$WITH_MAKEFILE" == "true" ]] || [[ ! -f "${PROJECT_ROOT}/Makefile" ]]; then
            setup_makefile
        fi

        # .editorconfig (always copied - needed by IDEs)
        setup_file "${DEV_TOOLS_ROOT}/.editorconfig" "${PROJECT_ROOT}/.editorconfig" ".editorconfig"

        # ESLint baseline (published config only)
        setup_file "${DEV_TOOLS_ROOT}/stubs/quality/eslint.config.js.stub" \
            "${PROJECT_ROOT}/config/dev-tools/eslint.config.js" \
            "config/dev-tools/eslint.config.js"
    fi

    # ─── Summary ─────────────────────────────────────────────────────────────
    if [[ "$SILENT_MODE" == "true" ]]; then
        check_optional_deps
        [[ ${#CREATED_FILES[@]} -eq 0 ]] && exit 0
    fi

    echo ""
    echo -e "${MAGENTA}┌────────────────────────────────────────┐${NC}"
    echo -e "${MAGENTA}│${NC}            ${GREEN}Setup Complete${NC}             ${MAGENTA}│${NC}"
    echo -e "${MAGENTA}├────────────────────────────────────────┤${NC}"

    if [[ ${#CREATED_FILES[@]} -gt 0 ]]; then
        echo -e "${MAGENTA}│${NC} ${GREEN}✓ Created:${NC} ${CREATED_FILES[*]}"
    fi

    if [[ ${#SKIPPED_FILES[@]} -gt 0 ]]; then
        echo -e "${MAGENTA}│${NC} ${YELLOW}○ Skipped:${NC} ${SKIPPED_FILES[*]}"
    fi

    if [[ ${#BACKED_UP_FILES[@]} -gt 0 ]]; then
        echo -e "${MAGENTA}│${NC} ${CYAN}↩ Backed up:${NC} ${BACKED_UP_FILES[*]}"
        echo -e "${MAGENTA}│${NC}   ${CYAN}→ ${BACKUP_DIR}${NC}"
    fi

    echo -e "${MAGENTA}├────────────────────────────────────────┤${NC}"
    echo -e "${MAGENTA}│${NC} ${CYAN}Type:${NC} ${PROJECT_TYPE} | ${CYAN}PM:${NC} ${PM}"
    echo -e "${MAGENTA}│${NC} ${CYAN}Publish configs:${NC} bash setup-project.sh --publish"
    echo -e "${MAGENTA}│${NC} ${CYAN}Run:${NC}  make help"
    echo -e "${MAGENTA}└────────────────────────────────────────┘${NC}"

    check_optional_deps
}

# ============================================================================
# Execute
# ============================================================================

setup_project
