SHELL     = /usr/bin/env bash
UNAME     = $(shell uname -s | tr A-Z a-z)
USERNAME  = $(shell whoami)
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
	$(eval SRC=$(SOURCE)/dotfiles/$(strip $(1)))
	$(eval LOG="${RED}linkdot${RESET} ${MAGENTA}$(strip $(1))${RESET} -> ${YELLOW}$(strip $(2)${RESET})")
	$(call print_mod,"$(LOG)")
	@ln -fns $(SRC) $(2)
endef

.DEFAULT_GOAL = help
.PHONY: nix home check update clean swap help

nix: ## apply nixos configuration
	@./scripts/flakey.sh --nix

home: ## apply home-manager configuration
	@./scripts/flakey.sh --home

update: ## update flake.lock
	@./scripts/flakey.sh --update

check: ## check
	@nix run github:DeterminateSystems/flake-checker

clean: ## clean
	@nix-store --gc --print-roots
	@nix-collect-garbage --delete-older-than 14d
	@sudo nix-collect-garbage --delete-older-than 14d
	@sudo nix-store --optimise

cclean: ## clean (immediate)
	@nix-store --gc --print-roots
	@nix-collect-garbage -d
	@sudo nix-collect-garbage -d
	@sudo nix-store --optimise

link: ## link dotfiles
	@echo " 🔥 Linking dotfiles for ${YELLOW}☯ $(HOSTNAME)${RESET} ${MAGENTA}($(UNAME))${RESET}"
	$(call print_mod_start,Link)
	$(call link,bin,~/.config/bin)
	@mkdir -p ~/.local/share/fonts
	$(call link,assets/fonts,~/.local/share/fonts/custom)
	$(call link,ssh,~/.ssh)
	@mkdir -p ~/.config/tmux
	$(call link,home-manager/programs/tmux/tmux.conf,~/.config/tmux/tmux.conf)
	$(call linkdot,nvim,~/.config/nvim)
	$(call linkdot,emacs,~/.emacs.d)
	$(call linkdot,wezterm,~/.config/wezterm)
	$(call linkdot,ranger,~/.config/ranger)
	$(call linkdot,yazi,~/.config/yazi)
	$(call linkdot,superfile,~/.config/superfile)
	$(call linkdot,wired,~/.config/wired)
	$(call print_mod_end)

swap: ## swap
	@./scripts/swap.sh

help: ## help
	@grep -E '^[a-zA-Z_0-9%-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "${BLUE}%-20s${RESET} %s\n", $$1, $$2}'
