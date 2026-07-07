SHELL               = /usr/bin/env bash
CARGO               ?= cargo
CARGO_LINKER_CONFIG ?= --config 'target.x86_64-unknown-linux-gnu.linker="gcc"'
NIX                 ?= nix
NIX_DEVELOP         ?= $(NIX) develop .
NIX_SHELL           ?= $(NIX_DEVELOP) -c
TEST_ENV            ?= env -u CONDOM_TPROXY_ROUTING -u CONDOM_TPROXY_PORT -u CONDOM_TPROXY_TCP_PORTS -u CONDOM_TPROXY_MARK -u CONDOM_TPROXY_TABLE -u CONDOM_TPROXY_TABLE_NAME -u CONDOM_TPROXY_INTERFACE
PREFIX              ?= $(HOME)/.local
BINDIR              ?= $(PREFIX)/bin
INSTALL             ?= install
SYSTEMCTL           ?= sudo systemctl

.DEFAULT_GOAL = help
.PHONY: help build install uninstall fmt-check check clippy test verify

help: ## show available commands
	@grep -E '^[a-zA-Z_0-9%-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "%-20s %s\n", $$1, $$2}'

build: ## build release binaries
	$(NIX_SHELL) $(CARGO) build --release $(CARGO_LINKER_CONFIG)

install: build ## install release binaries to BINDIR
	$(INSTALL) -d "$(BINDIR)"
	$(INSTALL) -m 0755 target/release/condom "$(BINDIR)/condom"
	$(INSTALL) -m 0755 target/release/condom-helper "$(BINDIR)/condom-helper"
	$(INSTALL) -m 0755 target/release/condom-approval "$(BINDIR)/condom-approval"

uninstall: ## remove installed binaries from BINDIR
	rm -f "$(BINDIR)/condom" "$(BINDIR)/condom-helper" "$(BINDIR)/condom-approval"

fmt-check: ## check rust formatting
	$(NIX_SHELL) $(CARGO) fmt --check

check: ## check rust types
	$(NIX_SHELL) $(CARGO) check $(CARGO_LINKER_CONFIG)

clippy: ## lint rust targets
	$(NIX_SHELL) $(CARGO) clippy --all-targets $(CARGO_LINKER_CONFIG) -- -D warnings

test: ## run rust tests
	$(NIX_SHELL) $(TEST_ENV) $(CARGO) test $(CARGO_LINKER_CONFIG) -- --test-threads=1

verify: fmt-check check clippy test ## run all local source checks
