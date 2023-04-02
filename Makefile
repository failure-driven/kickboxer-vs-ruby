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

vendor:
	mkdir vendor

vendor/mruby-esp32:
	git clone --recursive https://github.com/mruby-esp32/mruby-esp32.git vendor/mruby-esp32

.PHONY: vendor-install
vendor-install: vendor vendor/mruby-esp32

.PHONY: brew-bundle
brew-bundle:
	brew bundle

.PHONY: install
install: asdf-install brew-bundle check-tools

.PHONY: rubocop-fix
rubocop-fix:
	bundle exec rubocop -A

.PHONY: rubocop
rubocop:
	bundle exec rubocop

.PHONY: build
build: rubocop

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
	@echo "${YELLOW}make rubocop${NC}      rubocop"
	@echo "${YELLOW}make rubocop-fix${NC}  rubocop fix"
	@echo
