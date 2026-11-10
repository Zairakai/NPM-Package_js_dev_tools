# Variables - Zairakai NPM Dev Tools
# Shared configuration and styling

# Critical path detection — works from any inclusion depth
NPM_DIRECTORY_TOOLS_MAKE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
NPM_DIRECTORY_TOOLS_PACKAGE_ROOT := $(abspath $(NPM_DIRECTORY_TOOLS_MAKE_DIR)../../)/
NPM_DIRECTORY_TOOLS_SCRIPTS_DIR := $(NPM_DIRECTORY_TOOLS_PACKAGE_ROOT)scripts/
NPM_DIRECTORY_TOOLS_TOOLS_SCRIPTS_DIR := $(NPM_DIRECTORY_TOOLS_PACKAGE_ROOT)tools/scripts/

# Project root (caller context). Prefer $(shell pwd) over $(CURDIR).
NPM_DIRECTORY_TOOLS_PROJECT_ROOT ?= $(shell pwd)

# Validate paths exist
ifeq ($(wildcard $(NPM_DIRECTORY_TOOLS_SCRIPTS_DIR)),)
$(error Zairakai scripts directory not found: $(NPM_DIRECTORY_TOOLS_SCRIPTS_DIR))
endif

# Project information (can be overridden in project Makefile BEFORE including core.mk)
NPM_DIRECTORY_TOOLS_PROJECT_NAME ?= Zairakai Project
NPM_DIRECTORY_TOOLS_TWITCH_URL   ?= https://twitch.tv/zairakai
NPM_DIRECTORY_TOOLS_GITLAB_URL   ?= https://gitlab.com/zairakai

# Help styling
NPM_DIRECTORY_TOOLS_HELP_WIDTH := 70

# ANSI Colors (only used in Make, not exported to scripts)
NPM_DIRECTORY_TOOLS_COLOR_RESET     := \033[0m
NPM_DIRECTORY_TOOLS_COLOR_HEADER_BG := \033[46m
NPM_DIRECTORY_TOOLS_COLOR_HEADER_FG := \033[1;37m
NPM_DIRECTORY_TOOLS_COLOR_SECTION   := \033[1;33m
NPM_DIRECTORY_TOOLS_COLOR_TARGET    := \033[32m
NPM_DIRECTORY_TOOLS_COLOR_FOOTER_BG := \033[44m
NPM_DIRECTORY_TOOLS_COLOR_FOOTER_FG := \033[1;37m

# Export only what shell scripts need
export NPM_DIRECTORY_TOOLS_PROJECT_ROOT
export NPM_DIRECTORY_TOOLS_PACKAGE_ROOT
export NPM_DIRECTORY_TOOLS_SCRIPTS_DIR
export NPM_DIRECTORY_TOOLS_TOOLS_SCRIPTS_DIR
export NPM_DIRECTORY_TOOLS_PROJECT_NAME
export NPM_DIRECTORY_TOOLS_TWITCH_URL
export NPM_DIRECTORY_TOOLS_GITLAB_URL
