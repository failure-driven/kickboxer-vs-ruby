.DEFAULT_GOAL := usage

# user and repo
USER        = $$(whoami)
CURRENT_DIR = $(notdir $(shell pwd))

# terminal colours
RED     = \033[0;31m
GREEN   = \033[0;32m
YELLOW  = \033[0;33m
NC      = \033[0m

.PHONY: check-tools
check-tools:
	bin/makefile/check-tools

.PHONY: asdf-install
asdf-install:
	asdf install

.PHONY: install
install: asdf-install check-tools

.PHONY: build
	echo "no build yet"

.PHONY: usage
usage:
	@echo
	@echo "Hi ${GREEN}${USER}!${NC} Welcome to ${RED}${CURRENT_DIR}${NC}"
	@echo
	@echo "Getting started"
	@echo
	@echo "${YELLOW}make${NC}              this menu"
	@echo "${YELLOW}make install${NC}      install all the things"
	@echo
	@echo "${YELLOW}make build${NC}        run the build"
	@echo
	@echo "Development"
	@echo
