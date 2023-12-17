SHELL     = /usr/bin/env bash
UNAME     = $(shell uname -s | tr A-Z a-z)
HOSTNAME  = $(shell hostname)
USER_HOME = ${HOME}
SOURCE    = $(realpath $(dir $(realpath $(lastword $(MAKEFILE_LIST)))))

BLACK     = $(shell tput -Txterm setaf 0)
RED       = $(shell tput -Txterm setaf 1)
GREEN     = $(shell tput -Txterm setaf 2)
YELLOW    = $(shell tput -Txterm setaf 3)
BLUE      = $(shell tput -Txterm setaf 4)
MAGENTA   = $(shell tput -Txterm setaf 5)
CYAN      = $(shell tput -Txterm setaf 6)
WHITE     = $(shell tput -Txterm setaf 7)
RESET     = $(shell tput -Txterm sgr0)

define print_mod_start
	@echo "╭── $(1)"
endef
define print_mod
	@echo "│ • $(1)"
endef
define print_mod_end
	@echo "╰──────"
endef

define link
	$(eval REL_SRC=$(strip $(1)))
	$(eval SRC=$(SOURCE)/$(strip $(1)))
	$(eval LOG="${RED}link${RESET} ${MAGENTA}$(REL_SRC)${RESET} -> ${YELLOW}$(strip $(2)${RESET})")
	$(call print_mod,"$(LOG)")
	@ln -fns $(SRC) $(2)
endef
define linkdot
	$(eval SRC=$(SOURCE)/home/dotfiles/$(strip $(1)))
	$(eval LOG="${RED}linkdot${RESET} ${MAGENTA}$(strip $(1))${RESET} -> ${YELLOW}$(strip $(2)${RESET})")
	$(call print_mod,"$(LOG)")
	@ln -fns $(SRC) $(2)
endef

.DEFAULT_GOAL = help
.PHONY: setup nix home home-build home-generations link clean swap help

setup: ## setup machine
	@./setup/setup-machine.sh "$(HOSTNAME)"

nix: ## apply nixos configuration
	@sudo nix-channel --update
	@sudo nixos-rebuild switch --upgrade
	@sudo /run/current-system/bin/switch-to-configuration boot

nix-offline: ## apply nixos configuration (offline)
	@sudo nixos-rebuild switch --option substitute false

home: ## apply home-manager configuration
	@nix-channel --update
	@home-manager switch
home-build: ## build home-manager configuration to ./result
	@home-manager build
home-generations: ## list home-manager generations
	@home-manager generations

link: ## link configuration files
	@echo " 🔥 Linking configuration for ${YELLOW}☯ $(HOSTNAME)${RESET} ${MAGENTA}($(UNAME))${RESET}"
	$(call print_mod_start,Link)
	$(call link,home/bin,~/.config/bin)
	@mkdir -p ~/.local/share/fonts
	$(call link,home/fonts,~/.local/share/fonts/custom)
	$(call link,home/ssh,~/.ssh)
	@mkdir -p ~/.config/tmux
	$(call link,home/modules/programs/tmux/tmux.conf,~/.config/tmux/tmux.conf)
	$(call linkdot,nvim,~/.config/nvim)
	$(call linkdot,emacs,~/.emacs.d)
	$(call linkdot,wezterm,~/.config/wezterm)
	$(call linkdot,ranger,~/.config/ranger)
	$(call linkdot,yazi,~/.config/yazi)
	$(call print_mod_end)

clean: ## clean
	@nix-store --gc --print-roots
	@sudo nix-collect-garbage --delete-older-than 30d
	@sudo nix-store --optimise

swap: ## swap
	@./setup/swap.sh

help: ## help
	@grep -E '^[a-zA-Z_0-9%-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "${BLUE}%-20s${RESET} %s\n", $$1, $$2}'
