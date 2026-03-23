#!/usr/bin/env bash
set -euo pipefail

readonly repo_url="https://github.com/microsoft/typescript-go"
readonly build_dir="/tmp/tsgo"
readonly repo_dir="${build_dir}/source"
readonly pr_ref="pull/2020/head"
readonly pr_branch="pr-2020"
readonly go_cache_dir="${build_dir}/.cache/go-build"
readonly go_mod_cache_dir="${build_dir}/.cache/go-mod"
readonly revision_file="${build_dir}/REVISION"

mkdir -p \
  "${build_dir}" \
  "${go_cache_dir}" \
  "${go_mod_cache_dir}"

if [ ! -d "${repo_dir}/.git" ]; then
  mkdir -p "$(dirname "${repo_dir}")"
  git clone --filter=blob:none "${repo_url}" "${repo_dir}"
fi

git -C "${repo_dir}" fetch origin "${pr_ref}:${pr_branch}"
git -C "${repo_dir}" checkout --detach "${pr_branch}"

cd "${repo_dir}"

GOCACHE="${go_cache_dir}" \
GOMODCACHE="${go_mod_cache_dir}" \
GOTOOLCHAIN="auto" \
go install ./cmd/tsgo

git -C "${repo_dir}" rev-parse HEAD > "${revision_file}"
