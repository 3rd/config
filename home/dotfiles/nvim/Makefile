SHELL         = /usr/bin/env bash
.SHELLFLAGS   = -eu -o pipefail -c
SOURCE        = $(realpath $(dir $(realpath $(lastword $(MAKEFILE_LIST)))))

# colors
BLACK         = $(shell tput -Txterm setaf 0)
RED           = $(shell tput -Txterm setaf 1)
GREEN         = $(shell tput -Txterm setaf 2)
YELLOW        = $(shell tput -Txterm setaf 3)
MAGENTA       = $(shell tput -Txterm setaf 5)
CYAN          = $(shell tput -Txterm setaf 6)
WHITE         = $(shell tput -Txterm setaf 7)
BLUE          = $(shell tput -Txterm setaf 4)
RESET         = $(shell tput -Txterm sgr0)

# log helper
define print_mod_start
	@echo "╭── $(1)"
endef
define print_mod
	@echo "│ • $(1)"
endef
define print_mod_end
	@echo "╰──────"
endef

DEV_FEEDKEYS=:e\n
DEV_EXTRA_ARGS=init.lua

.DEFAULT_GOAL = help
.PHONY: help clean dev profile profile-viml profile-startup benchmark benchmark-baseline benchmark-startup

help: ## help
	@echo "🔥 ${YELLOW}nvim${RESET}"
	@grep -E '^[a-zA-Z_0-9%-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "${BLUE}%-20s${RESET} %s\n", $$1, $$2}'

clean: ## clean-up profiling artifacts
	@-rm .tmp.* 2>&1 >/dev/null

dev: ## development mode
	$(eval SANDBOX_HOME=$(SOURCE)/sandbox)
	$(eval SANDBOX_NVIM=$(SANDBOX_HOME)/nvim)
	@mkdir -p "$(SANDBOX_HOME)"
	@ln -fns "$(SOURCE)" "$(SANDBOX_NVIM)"
	@watchexec -e ".lua,.vim" -i "**/.packer/**" -i "**/sandbox/**" -r -c "env DEV=true XDG_CONFIG_HOME=$(SANDBOX_HOME) nvim -c \"call feedkeys(\\\"$(DEV_FEEDKEYS)\\\")\" $(DEV_EXTRA_ARGS)"

profile: profile-viml profile-startup ## profile everything

profile-viml: ## profile viml (func *, file *)
	@nvim -c 'profile start .tmp.profile.data' -c 'profile func *' -c 'profile file *'
	@cat .tmp.profile.data

profile-startup: ## profile startup (--startuptime)
	@-rm .tmp.profile.startup.data
	@nvim --startuptime .tmp.profile.startup.data +q
	@cat .tmp.profile.startup.data | sort -k 2

benchmark: benchmark-baseline benchmark-startup ## benchmark everything (baseline, startup)

benchmark-baseline: ## run baseline benchmark (-u NONE)
	$(call print_mod_start,${MAGENTA}Benchmark:${RESET} nvim -u NONE +q)
	@hyperfine --warmup 2 --runs 40 -s basic "nvim -u NONE +q init.lua" > .tmp.benchmark.baseline.data
	@rg Time < .tmp.benchmark.baseline.data | awk '{print $$5}'| xargs -0 printf '│ • ${CYAN}Mean${RESET}: ${YELLOW}%s${RESET}'
	@rg Time < .tmp.benchmark.baseline.data | awk '{print $$11}' | xargs -0 printf '│ • ${CYAN}User${RESET}: ${YELLOW}%s${RESET}'
	@rg Time < .tmp.benchmark.baseline.data | awk '{print $$14}'| xargs -0 printf '│ • ${CYAN}System${RESET}: ${YELLOW}%s${RESET}'
	$(call print_mod_end)

benchmark-startup: ## run startup benchmark
	$(call print_mod_start,${MAGENTA}Benchmark:${RESET} nvim +q)
	@hyperfine --warmup 2 --runs 40 -s basic "nvim +q init.lua" > .tmp.benchmark.startup.data
	@rg Time < .tmp.benchmark.startup.data | awk '{print $$5}'| xargs -0 printf '│ • ${CYAN}Mean${RESET}: ${YELLOW}%s${RESET}'
	@rg Time < .tmp.benchmark.startup.data | awk '{print $$11}' | xargs -0 printf '│ • ${CYAN}User${RESET}: ${YELLOW}%s${RESET}'
	@rg Time < .tmp.benchmark.startup.data | awk '{print $$14}'| xargs -0 printf '│ • ${CYAN}System${RESET}: ${YELLOW}%s${RESET}'
	$(call print_mod_end)

