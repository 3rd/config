#!/usr/bin/env bash

set -u

session_dir="${XDG_CONFIG_HOME:-$HOME/.config}/sublime-merge/Local"
repo_path=""

for arg in "$@"; do
  case "$arg" in
    -h | --help | -v | --version | search | blame | log | mergetool)
      break
      ;;
    -*)
      continue
      ;;
    *)
      if [ -e "$arg" ]; then
        if [ -d "$arg" ]; then
          repo_path="$(cd "$arg" 2>/dev/null && pwd -P)"
        else
          repo_path="$(cd "$(dirname "$arg")" 2>/dev/null && pwd -P)"
        fi
      fi
      break
      ;;
  esac
done

repair_session_file() {
  local file="$1"
  local tmp

  [ -f "$file" ] || return 0

  tmp="$(mktemp "${TMPDIR:-/tmp}/smerge-session.XXXXXX")" || return 0
  if jq --arg repo "$repo_path" '
    def widths: [312.0, 553.0, 1395.0];
    def apply_layout:
      .side_bar_visible = true
      | .table_of_contents_tab_selected = false
      | .table_of_contents_tree_mode = false
      | .sidebar.lhs_widths = widths;
    def normalize_recent:
      if (.path? | type) == "string" then apply_layout else . end;

    .new_window_session.window_width = 2542.0
    | .new_window_session.window_height = 1394.0
    | .new_window_session.sidebar.lhs_widths = widths
    | .recent = ((.recent // []) | map(normalize_recent))
    | if $repo == "" then
        .
      else
        .recent = ([{path: $repo} | apply_layout] + ((.recent // []) | map(select(.path != $repo))))
      end
  ' "$file" > "$tmp"; then
    mv "$tmp" "$file"
  else
    rm -f "$tmp"
  fi
}

repair_session_file "$session_dir/Session.sublime_session"
repair_session_file "$session_dir/Auto Save Session.sublime_session"
