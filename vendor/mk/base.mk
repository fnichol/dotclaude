CHECK_TOOLS ?=
TEST_TOOLS ?=

.PHONY: all
all: clean build test check ## Runs the clean, build, test, and check targets

.PHONY: checktools
checktools: ## Checks that all required tools are on PATH
	@for tool in $(CHECK_TOOLS); do \
		command -v $$tool >/dev/null 2>&1 || { \
			echo "ERROR: Required tool '$$tool' not found on PATH" >&2; \
			exit 1; \
		}; \
	done

.PHONY: help
help: ## Prints this help (default)
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	  | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

.PHONY: prepush
prepush: check test ## Checks and tests the project before a push
	@printf -- "---\n"
	@printf -- "Ready to push!\n"

.PHONY: testtools
testtools: ## Checks that all required test tools are on PATH
	@for tool in $(TEST_TOOLS); do \
		command -v $$tool >/dev/null 2>&1 || { \
			echo "ERROR: Required tool '$$tool' not found on PATH" >&2; \
			exit 1; \
		}; \
	done
