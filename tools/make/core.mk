# Core Makefile — Zairakai NPM Dev Tools
# Aggregates all modular targets for JavaScript/TypeScript/Vue projects.
#
# Usage in a consumer project (Makefile):
#   DEV_TOOLS_NPM := node_modules/@zairakai/js-dev-tools
#   include $(DEV_TOOLS_NPM)/tools/make/core.mk
#
# Or generate via:
#   bash node_modules/@zairakai/js-dev-tools/scripts/setup-project.sh --with-makefile

# Default goal (only if not already set by the project Makefile)
ifeq ($(origin .DEFAULT_GOAL), undefined)
    .DEFAULT_GOAL := help
endif

SHELL := /bin/bash

# Resolve make files directory from the current MAKEFILE_LIST entry
NPM_DIRECTORY_TOOLS_MAKE_DIR := $(dir $(lastword $(MAKEFILE_LIST)))

# Include variables first (paths, colors, project info)
include $(NPM_DIRECTORY_TOOLS_MAKE_DIR)variables.mk

# Include specialized make files in logical development workflow order:
# 1. Help system (discover available commands)
include $(NPM_DIRECTORY_TOOLS_MAKE_DIR)help.mk

# 2. Documentation linting (Markdown)
include $(NPM_DIRECTORY_TOOLS_MAKE_DIR)markdownlint.mk

# 3. ShellCheck validation
include $(NPM_DIRECTORY_TOOLS_MAKE_DIR)shellcheck.mk

# 4. Code style — ESLint + Prettier
include $(NPM_DIRECTORY_TOOLS_MAKE_DIR)code-style.mk

# 5. CSS/SCSS — Stylelint (optional)
include $(NPM_DIRECTORY_TOOLS_MAKE_DIR)stylelint.mk

# 6. Dead code detection (Knip)
include $(NPM_DIRECTORY_TOOLS_MAKE_DIR)knip.mk

# 7. TypeScript type checking and build
include $(NPM_DIRECTORY_TOOLS_MAKE_DIR)typescript.mk

# 8. Quality aggregation (combines all checks)
include $(NPM_DIRECTORY_TOOLS_MAKE_DIR)quality.mk

# 9. Testing (Vitest)
include $(NPM_DIRECTORY_TOOLS_MAKE_DIR)test.mk

# 10. BATS shell script testing
include $(NPM_DIRECTORY_TOOLS_MAKE_DIR)bats.mk

# 11. Utilities (git, npm)
include $(NPM_DIRECTORY_TOOLS_MAKE_DIR)utils.mk
