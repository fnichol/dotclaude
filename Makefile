SH_SOURCES := $(shell find . -type f \( -name '*.sh' -o -name 'claude-plugins' \) 2>/dev/null)
JSON_SOURCES := $(shell find . -type f -name '*.json' 2>/dev/null)
TEST_TOOLS += bash git jq

include vendor/mk/base.mk
include vendor/mk/shell.mk
include vendor/mk/json.mk

.PHONY: build
build: ## Builds the project

.PHONY: check
check: check-shell check-json ## Checks the project

.PHONY: clean
clean: clean-shell ## Cleans the project

.PHONY: test
test: testtools ## Tests the project
	@printf -- "---\n%s\n" "$@"
	test/claude-plugins/run.sh
