# Default Makefile delegating to the shared core tooling.

NPM_DIRECTORY_TOOLS_PROJECT_NAME := "Dev-Tools"

NPM_DIRECTORY_TOOLS_PROJECT_ROOT := $(shell pwd)

include tools/make/core.mk
