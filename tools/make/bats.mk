# BATS Testing Targets
# Shell script testing with Bash Automated Testing System

## —— 🧪 Shell Script Testing ——
.PHONY: bats
bats:: ## Run shell script tests (BATS)
	@if ! command -v bats &>/dev/null; then \
		echo "❌ BATS not installed - run: make install-bats"; \
		exit 1; \
	fi; \
	FILES=$$(find tests/bats -name "*.bats" 2>/dev/null); \
	if [ -z "$$FILES" ]; then \
		echo "ℹ️  No BATS tests found — skipping"; \
	else \
		bats $$FILES; \
	fi

.PHONY: bats-unit
bats-unit:: ## Run BATS unit tests
	@if ! command -v bats &>/dev/null; then \
		echo "❌ BATS not installed - run: make install-bats"; \
		exit 1; \
	fi; \
	if [ ! -d tests/bats/unit ] || [ -z "$$(find tests/bats/unit -name "*.bats" 2>/dev/null)" ]; then \
		echo "ℹ️  No BATS unit tests found — skipping"; \
	else \
		bats tests/bats/unit/*.bats; \
	fi

.PHONY: bats-integration
bats-integration:: ## Run BATS integration tests
	@if ! command -v bats &>/dev/null; then \
		echo "❌ BATS not installed - run: make install-bats"; \
		exit 1; \
	fi; \
	if [ ! -d tests/bats/integration ] || [ -z "$$(find tests/bats/integration -name "*.bats" 2>/dev/null)" ]; then \
		echo "ℹ️  No BATS integration tests found — skipping"; \
	else \
		bats tests/bats/integration/*.bats; \
	fi
.PHONY: test-all
test-all:: test bats ## Run all tests (Vitest + BATS)
	@echo ""
	@echo "✅ All tests passed"

##
.PHONY: install-bats
install-bats:: ## Install BATS framework
	@bash $(NPM_DIRECTORY_TOOLS_SCRIPTS_DIR)/install-bats.sh
