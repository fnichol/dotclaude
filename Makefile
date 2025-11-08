SH_SOURCES := $(shell find . -type f -name '*.sh' 2>/dev/null)
JSON_SOURCES := $(shell find . -type f -name '*.json' 2>/dev/null)

include vendor/mk/base.mk
include vendor/mk/shell.mk
include vendor/mk/json.mk
include vendor/mk/yaml.mk

.PHONY: build
build: ## Builds the project

.PHONY: check
check: check-shell check-json ## Checks the project

.PHONY: clean
clean: clean-shell ## Cleans the project

.PHONY: test
test: ## Tests the project
