#!/usr/bin/env bash
set -euo pipefail

script_dir="$(readlink -f -- "$(dirname -- "${BASH_SOURCE[0]}")")"
readonly script_dir
source_dir="$(readlink -f -- "${script_dir}/..")"
readonly source_dir
source_lockfile="${source_dir}/lazy-lock.json"
readonly source_lockfile
tmp_root="$(mktemp -d "/tmp/nvim-plugin-upgrade.XXXXXX")"
readonly tmp_root
readonly runtime_source_root="${tmp_root}/runtime-source"
readonly runtime_root="${tmp_root}/runtime"
readonly runtime_source_config_home="${runtime_source_root}/config"
readonly runtime_source_config="${runtime_source_config_home}/nvim"
readonly runtime_source_data="${runtime_source_root}/data"
readonly runtime_source_state="${runtime_source_root}/state"
readonly runtime_source_cache="${runtime_source_root}/cache"
readonly runtime_config_home="${runtime_root}/config"
readonly runtime_data="${runtime_root}/data"
readonly runtime_lazy_dir="${runtime_data}/nvim/lazy"
readonly runtime_state="${runtime_root}/state"
readonly runtime_cache="${runtime_root}/cache"
readonly condom_state_home="${tmp_root}/condom-state"
readonly lockfile_checkpoint="${tmp_root}/lazy-lock.checkpoint"

log() {
  printf 'nvim update: %s\n' "$*" >&2
}

require_command() {
  local command_name="$1"

  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "missing required command: ${command_name}" >&2
    exit 1
  fi
}

cleanup() {
  rm -rf -- "${tmp_root}"
}

trap cleanup EXIT

has_tty() {
  { : </dev/tty >/dev/tty; } 2>/dev/null
}

mark_lockfile_checkpoint() {
  : > "${lockfile_checkpoint}"
}

discover_lazy_root() {
  local discover_config_home="${tmp_root}/discover-config"
  local lazy_root_file="${tmp_root}/lazy-root"
  local lazy_root=""

  log "discovering Lazy plugin root"
  mkdir -p -- "${discover_config_home}"
  ln -s -- "${source_dir}" "${discover_config_home}/nvim"

  CONDOM_LAZY_ROOT_FILE="${lazy_root_file}" \
    XDG_CONFIG_HOME="${discover_config_home}" \
    "${nvim_bin}" --headless --clean --cmd "set runtimepath^=${source_dir}" \
    +'lua require("lib"); local cfg = require("config/lazy"); vim.fn.writefile({ tostring(cfg.root or "") }, vim.env.CONDOM_LAZY_ROOT_FILE)' \
    +qa

  if [ -f "${lazy_root_file}" ]; then
    IFS= read -r lazy_root < "${lazy_root_file}"
  fi

  if [ -z "${lazy_root}" ]; then
    echo "failed to discover Lazy plugin root from Neovim config" >&2
    exit 1
  fi

  printf '%s\n' "${lazy_root}"
}

write_minimal_config() {
  mkdir -p -- "${runtime_source_config}"
  ln -s -- "${source_dir}/lua" "${runtime_source_config}/lua"
  if [ -d "${source_dir}/plugins" ]; then
    ln -s -- "${source_dir}/plugins" "${runtime_source_config}/plugins"
  fi

  cat > "${runtime_source_config}/init.lua" <<'EOF'
vim.loader.enable(true)
require("lib")

local sanitize_plugin_spec
sanitize_plugin_spec = function(spec)
  if type(spec) ~= "table" then
    return spec
  end

  if spec[1] or spec.dir or spec.url or spec.name then
    spec.lazy = true
    spec.init = nil
    spec.config = nil
    spec.build = nil
  end

  if type(spec.dependencies) == "table" then
    for _, dependency in pairs(spec.dependencies) do
      sanitize_plugin_spec(dependency)
    end
  end

  for _, child in ipairs(spec) do
    sanitize_plugin_spec(child)
  end

  return spec
end

local sanitize_plugin_specs = function(specs)
  for _, spec in ipairs(specs) do
    sanitize_plugin_spec(spec)
  end
  return specs
end

local modules = lib.module.get_enabled_modules()
local plugins = sanitize_plugin_specs(table.join(
  lib.module.get_module_plugins(modules),
  table.map({
    { dir = "tslib", lazy = false },
    { dir = "testing.nvim" },
    { dir = "sqlite.nvim" },
    { dir = "bunvim", lazy = false },
  }, function(item)
    item.dir = lib.path.resolve(lib.env.dirs.vim.config, "plugins", item.dir)
    return item
  end)
))

lib.lazy.install()
vim.opt.rtp:prepend(lib.env.dirs.vim.lazy.plugin)
local lazy_config = require("config/lazy")
lazy_config.lockfile = vim.env.NVIM_PLUGIN_UPGRADE_LOCKFILE or lazy_config.lockfile
lib.lazy.setup(plugins, lazy_config)
vim.cmd("Lazy! update")
vim.cmd("qa")
EOF
}

prepare_runtime_tree() {
  log "preparing isolated runtime under ${runtime_source_root}"
  mkdir -p -- "${runtime_source_data}" "${runtime_source_state}" "${runtime_source_cache}" "${condom_state_home}"
  write_minimal_config
}

run_review() {
  (
    cd -- "${source_dir}"
    export XDG_STATE_HOME="${condom_state_home}"
    # shellcheck disable=SC2016
    local command=(
      "${condom_bin}" review --root "${source_dir}" \
        --ephemeral-overlay "${runtime_source_root}=${runtime_root}" \
        --ephemeral-overlay "${host_lazy_dir}=${runtime_lazy_dir}" \
        -- bash -c '
set -euo pipefail

XDG_CONFIG_HOME="${1}" \
XDG_DATA_HOME="${2}" \
XDG_STATE_HOME="${3}" \
XDG_CACHE_HOME="${4}" \
NVIM_PLUGIN_UPGRADE_LOCKFILE="${5}" \
"${6}" --headless
' condom-nvim-upgrade "${runtime_config_home}" "${runtime_data}" "${runtime_state}" "${runtime_cache}" "${source_lockfile}" "${nvim_bin}"
    )

    log "starting condom review with root ${source_dir}"
    if has_tty; then
      "${command[@]}" </dev/tty >/dev/tty
      return
    fi

    "${command[@]}"
  )
}

report_lockfile_result() {
  if [ "${source_lockfile}" -nt "${lockfile_checkpoint}" ]; then
    echo "updated ${source_lockfile}"
    return 0
  fi

  echo "lazy-lock.json unchanged"
  return 1
}

restore_real_plugins() {
  local restore_config_home="${tmp_root}/restore-config"

  log "restoring accepted plugin lock into real Lazy checkout"
  mkdir -p -- "${restore_config_home}"
  ln -s -- "${source_dir}" "${restore_config_home}/nvim"

  XDG_CONFIG_HOME="${restore_config_home}" \
    "${nvim_bin}" --headless "+Lazy! restore" "+Lazy! clean" +qa
}

require_command nvim
require_command condom
condom_bin="$(command -v condom)"
readonly condom_bin
nvim_bin="$(readlink -f -- "$(command -v nvim)")"
readonly nvim_bin

if [ ! -f "${source_lockfile}" ]; then
  echo "missing Lazy lockfile: ${source_lockfile}" >&2
  exit 1
fi

log "using temporary runtime at ${runtime_source_root}"
host_lazy_dir="$(discover_lazy_root)"
readonly host_lazy_dir
log "Lazy plugin root is ${host_lazy_dir}"
mark_lockfile_checkpoint
prepare_runtime_tree
if ! run_review; then
  cat >&2 <<'EOF'
condom review exited with an error before anything was applied.

Your real Neovim config and lazy-lock.json were not changed unless the review
was already accepted and the patch applied cleanly.
EOF
  exit 1
fi
if report_lockfile_result; then
  restore_real_plugins
fi
