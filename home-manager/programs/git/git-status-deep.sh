#!/usr/bin/env bash

pushd() {
  command pushd "$@" >/dev/null || exit
}

popd() {
  command popd >/dev/null || exit
}

is_valid_git_repo() {
  repo_path=$1
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
  if [[ $repo_root == "$repo_path" ]]; then
    return 1
  fi
  return 0
}

display_uncommitted_changes() {
  repo_path=$1
  echo "Repository: $repo_path"

  if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    echo "Uncommitted changes:"
    git status --short
  else
    echo "No uncommitted changes"
  fi

  echo "------------------------"
}

fd -t d -u -a ".git\$" | while read -r git_dir; do
  repo_path=$(dirname "$git_dir")
  pushd "$repo_path" || exit

  is_valid_git_repo "$repo_path"
  is_valid=$?

  if [ $is_valid = 1 ]; then
    display_uncommitted_changes "$repo_path"
  fi
  popd || exit
done
