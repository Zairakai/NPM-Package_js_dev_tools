## —— 🧩 Typescript ——

.PHONY: typecheck
typecheck: ## Type-check TypeScript without emitting files (tsc --noEmit)
	@bash $(NPM_DIRECTORY_TOOLS_SCRIPTS_DIR)/typecheck.sh

.PHONY: build
build: ## Transpile TypeScript to JavaScript (tsup preferred, tsc fallback)
	@bash $(NPM_DIRECTORY_TOOLS_SCRIPTS_DIR)/build.sh

