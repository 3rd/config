#!/usr/bin/env bash
set -euf -o pipefail
IFS=$'\n\t'

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "FATAL: Not in a git repository."
  exit 1
fi

show_usage() {
  cat 1>&2 <<-EOF
		usage: git-branch [name]

		Without arguments, shows a list of branches to switch to via fzf.
		  $ branch

		With a branch name, it switches / creates and switches to that branch.
		The current branch will be the parent of the created one.
		  $ branch feature/50-new-feature
	EOF
}

get_current_branch() {
  local current_branch
  current_branch=$(git symbolic-ref HEAD)
  echo "${current_branch#refs/heads/}"
}

trim() {
  local var="$*"
  var="${var#"${var%%[![:space:]]*}"}"
  var="${var%"${var##*[![:space:]]}"}"
  echo -n "$var"
}

while getopts "h" arg; do
  case "$arg" in
    *)
      show_usage
      exit 1
      ;;
  esac
done

if [ "$#" -eq 0 ]; then
  BRANCH=$(trim "$(git branch --all --sort=-committerdate --format='%(refname:short)' | rg -v "^\*" | sed "s/origin\///g" | awk '!x[$0]++' | grep -v HEAD | fzf)")
  if [[ -n "$BRANCH" ]]; then
    echo "Switching to $BRANCH"
    git checkout --ignore-other-worktrees "$BRANCH"
  fi
else
  BRANCH=$1
  git checkout --ignore-other-worktrees -b "$BRANCH"
fi
