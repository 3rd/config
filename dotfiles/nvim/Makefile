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
STYLUA_CONFIG=$(SOURCE)/linters/stylua.toml
FORMAT_LUA_TARGETS?=init.lua lua after colors plugins specs

.DEFAULT_GOAL = help
.PHONY: help clean dev format profile profile-viml profile-startup benchmark benchmark-baseline benchmark-startup doctor doctor-tools doctor-runtime

help: ## help
	@echo "🔥 ${YELLOW}nvim${RESET}"
	@grep -E '^[a-zA-Z_0-9%-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "${BLUE}%-20s${RESET} %s\n", $$1, $$2}'

clean: ## clean-up profiling artifacts
	@-rm .tmp.* 2>&1 >/dev/null

format: ## format lua files
	@stylua --config-path "$(STYLUA_CONFIG)" --respect-ignores $(FORMAT_LUA_TARGETS)

dev: ## watch
	@watchexec --stop-timeout=0 --no-process-group -e ".lua,.vim" -i "**/sandbox/**" -r -c clear "nvim -c \"call feedkeys(\\\"$(DEV_FEEDKEYS)\\\")\" $(DEV_EXTRA_ARGS)"

run: ## run
	@bash -c "nvim $(DEV_EXTRA_ARGS)"

dev-sandbox: ## watch in sandbox
	$(eval SANDBOX_HOME=$(SOURCE)/sandbox)
	$(eval SANDBOX_NVIM=$(SANDBOX_HOME)/nvim)
	@mkdir -p "$(SANDBOX_HOME)"
	@ln -fns "$(SOURCE)" "$(SANDBOX_NVIM)"
	@watchexec --stop-timeout=0 --no-process-group -e ".lua,.vim" -i "**/sandbox/**" -r -c clear "env DEV=true XDG_CONFIG_HOME=$(SANDBOX_HOME) nvim -c \"call feedkeys(\\\"$(DEV_FEEDKEYS)\\\")\" $(DEV_EXTRA_ARGS)"
	
run-sandbox: ## run in sandbox
	$(eval SANDBOX_HOME=$(SOURCE)/sandbox)
	$(eval SANDBOX_NVIM=$(SANDBOX_HOME)/nvim)
	@mkdir -p "$(SANDBOX_HOME)"
	@ln -fns "$(SOURCE)" "$(SANDBOX_NVIM)"
	@bash -c "env DEV=true XDG_CONFIG_HOME=$(SANDBOX_HOME) nvim $(DEV_EXTRA_ARGS)"

profile: profile-startup profile-viml ## profile everything

profile-startup: ## profile startup (--startuptime)
	@-rm profile-startup.log
	@nvim --startuptime profile-startup.log +q
	@cat profile-startup.log | sort -k 2
	
profile-viml: ## profile viml (func *, file *)
	@-rm profile-viml.log
	@nvim -c 'profile start profile-viml.log' -c 'profile func *' -c 'profile file *'
	@cat profile-viml.log

profile-lua: ## profile lua (https://github.com/charlesmallah/lua-profiler)
	@echo TODO

benchmark: benchmark-baseline benchmark-startup ## benchmark everything (baseline, startup)

benchmark-baseline: ## run baseline benchmark (-u NONE)
	$(call print_mod_start,${MAGENTA}Benchmark:${RESET} baseline)
	@hyperfine --warmup 10 --runs 40 "nvim -u NONE -c 'q' init.lua" > profile-bench-baseline.log
	@rg Time < profile-bench-baseline.log | awk '{print $$5}'| xargs -0 printf '│ • ${CYAN}Mean${RESET}: ${YELLOW}%s${RESET}'
	@rg Time < profile-bench-baseline.log | awk '{print $$11}' | xargs -0 printf '│ • ${CYAN}User${RESET}: ${YELLOW}%s${RESET}'
	@rg Time < profile-bench-baseline.log | awk '{print $$14}'| xargs -0 printf '│ • ${CYAN}System${RESET}: ${YELLOW}%s${RESET}'
	$(call print_mod_end)

benchmark-startup: ## run startup benchmark
	$(call print_mod_start,${MAGENTA}Benchmark:${RESET} startup)
	@hyperfine --warmup 10 --runs 40 "nvim -c 'q' init.lua" > profile-bench-startup.log
	@rg Time < profile-bench-startup.log | awk '{print $$5}'| xargs -0 printf '│ • ${CYAN}Mean${RESET}: ${YELLOW}%s${RESET}'
	@rg Time < profile-bench-startup.log | awk '{print $$11}' | xargs -0 printf '│ • ${CYAN}User${RESET}: ${YELLOW}%s${RESET}'
	@rg Time < profile-bench-startup.log | awk '{print $$14}'| xargs -0 printf '│ • ${CYAN}System${RESET}: ${YELLOW}%s${RESET}'
	$(call print_mod_end)

doctor: doctor-tools doctor-runtime ## verify external tools and runtime smoke checks

doctor-tools: ## verify external commands used by this config
	$(call print_mod_start,${MAGENTA}Doctor:${RESET} tools)
	@for cmd in nvim git rg fd bat curl tree-sitter cc xclip; do \
		if command -v "$$cmd" >/dev/null; then \
			printf '│ • ${CYAN}%-14s${RESET} ${GREEN}ok${RESET}\n' "$$cmd"; \
		else \
			printf '│ • ${CYAN}%-14s${RESET} ${RED}missing${RESET}\n' "$$cmd"; \
			exit 1; \
		fi; \
	done
	@for cmd in watchexec hyperfine; do \
		if command -v "$$cmd" >/dev/null; then \
			printf '│ • ${CYAN}%-14s${RESET} ${GREEN}ok${RESET} ${WHITE}(workflow)${RESET}\n' "$$cmd"; \
		else \
			printf '│ • ${CYAN}%-14s${RESET} ${YELLOW}missing${RESET} ${WHITE}(workflow)${RESET}\n' "$$cmd"; \
		fi; \
	done
	@printf '│ • ${CYAN}%-14s${RESET} %s\n' "nvim" "$$(nvim --version | sed -n '1p')"
	@printf '│ • ${CYAN}%-14s${RESET} %s\n' "tree-sitter" "$$(tree-sitter --version)"
	$(call print_mod_end)

doctor-runtime: ## run headless runtime smoke checks
	$(call print_mod_start,${MAGENTA}Doctor:${RESET} runtime)
	@nvim --headless --clean --cmd "set runtimepath^=$(SOURCE)" \
		'+lua require("lib")' \
		'+lua _G.__doctor_failures = 0' \
		'+lua _G.__doctor_check = function(name, ok, detail) local status = ok and "ok" or "fail"; local suffix = detail and (" " .. detail) or ""; print(string.format("│ • %s %s%s", status, name, suffix)); if not ok then _G.__doctor_failures = _G.__doctor_failures + 1 end end' \
		'+lua local search = require("modules/workflow/search").exports; __doctor_check("search.exports.find_files", type(search.find_files) == "function"); __doctor_check("search.exports.grep", type(search.grep) == "function"); __doctor_check("search.exports.resume", type(search.resume) == "function")' \
		'+lua local site = vim.fn.stdpath("data") .. "/site"; local exists = function(path) return vim.uv.fs_stat(path) ~= nil end; __doctor_check("treesitter.parser.json", exists(site .. "/parser/json.so")); __doctor_check("treesitter.query.json", exists(site .. "/queries/json/highlights.scm")); __doctor_check("treesitter.parser.markdown", exists(site .. "/parser/markdown.so")); __doctor_check("treesitter.query.markdown", exists(site .. "/queries/markdown/highlights.scm")); __doctor_check("treesitter.parser.syslang", exists(site .. "/parser/syslang.so")); __doctor_check("treesitter.query.syslang", exists(site .. "/queries/syslang/highlights.scm"))' \
		'+lua if _G.__doctor_failures > 0 then vim.cmd("cquit " .. _G.__doctor_failures) end' \
		'+qa'
	@printf '\n'
	$(call print_mod_end)
