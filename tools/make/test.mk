# Vitest Testing Targets
# Delegates to scripts/test.sh with appropriate environment variables
## —— 🧪 Testing ——

.PHONY: test
test:: ## Run all tests (without coverage)
	@bash $(NPM_DIRECTORY_TOOLS_SCRIPTS_DIR)/test.sh

.PHONY: test-coverage
test-coverage:: ## Run tests with coverage report
	@COVERAGE=true bash $(NPM_DIRECTORY_TOOLS_SCRIPTS_DIR)/test.sh

.PHONY: test-watch
test-watch:: ## Run tests in watch mode
	@$(NPM_DIRECTORY_TOOLS_PROJECT_ROOT)/node_modules/.bin/vitest

.PHONY: test-ci
test-ci:: ## Run tests in CI mode (strict + coverage)
	@CI=true bash $(NPM_DIRECTORY_TOOLS_SCRIPTS_DIR)/test.sh
