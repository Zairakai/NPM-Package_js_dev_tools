# Knip Dead Code Analysis Targets
# Delegates to scripts/knip.sh

## —— ✂️  Knip ——
.PHONY: knip
knip: ## Run dead code analysis (Knip)
	@bash $(NPM_DIRECTORY_TOOLS_SCRIPTS_DIR)/knip.sh
