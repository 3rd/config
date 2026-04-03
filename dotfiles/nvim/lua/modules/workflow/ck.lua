local CK_MAP = "<leader><leader>f"

local normalize_query = function(text)
	if type(text) ~= "string" then
		return nil
	end

	local query = vim.trim(text:gsub("%s*\n%s*", " "))
	if query == "" then
		return nil
	end

	return query
end

local get_cwd = function()
	local rooter = require("modules/workflow/rooter").exports
	return rooter.get_cwd()
end

local ensure_server = function()
	if type(vim.v.servername) == "string" and vim.v.servername ~= "" then
		return vim.v.servername
	end

	local primary = string.format("/tmp/ck-nvim-%d.sock", vim.fn.getpid())
	local ok, server = pcall(vim.fn.serverstart, primary)
	if ok and type(server) == "string" and server ~= "" then
		return server
	end

	local fallback = vim.fn.tempname() .. ".sock"
	ok, server = pcall(vim.fn.serverstart, fallback)
	if ok and type(server) == "string" and server ~= "" then
		return server
	end

	return nil
end

local build_editor_script = function()
	return [[
server="${NVIM_CK_SERVER:-}"
if [ -z "$server" ]; then
  exit 1
fi

open_in_tab=false
if [ "$#" -gt 0 ] && [ "${!#}" = "-p" ]; then
  open_in_tab=true
  set -- "${@:1:$(($# - 1))}"
fi

while [ "$#" -ge 2 ]; do
  line="$1"
  file="$2"
  shift 2

  if [ -z "$file" ]; then
    continue
  fi

  line="${line#+}"
  case "$line" in
    ''|*[!0-9]*) line=1 ;;
  esac

  expr=$(printf "luaeval('require(\"modules/workflow/ck\").exports.remote_open([=[%s]=], %s, %s)')" "$file" "$line" "$open_in_tab")
  nvim --server "$server" --remote-expr "$expr" >/dev/null 2>&1
done
]]
end

local build_editor_command = function()
	return table.concat({
		"bash",
		"-lc",
		vim.fn.shellescape(build_editor_script()),
		"ck-remote",
	}, " ")
end

local open_tui = function(query)
	if vim.fn.executable("ck") ~= 1 then
		vim.notify("ck is not installed", vim.log.levels.ERROR)
		return
	end

	local server = ensure_server()
	if not server then
		vim.notify("ck could not start a Neovim server", vim.log.levels.ERROR)
		return
	end

	local editor_command = build_editor_command()
	local cmd = {
		"env",
		"EDITOR=" .. editor_command,
		"VISUAL=" .. editor_command,
		"NVIM_CK_SERVER=" .. server,
		"ck",
		"--tui",
	}

	if query then
		table.insert(cmd, query)
	end

	lib.term.open({
		cmd = cmd,
		cwd = get_cwd(),
	})
end

local open = function()
	open_tui()
end

local open_selection = function()
	open_tui(normalize_query(lib.buffer.current.get_selected_text()))
end

local remote_open = function(path, line_number, open_in_tab)
	if type(path) ~= "string" or path == "" then
		return false
	end

	local command = (open_in_tab and "tab drop " or "drop ") .. vim.fn.fnameescape(path)
	vim.cmd(command)

	local line = tonumber(line_number) or 1
	if line < 1 then
		line = 1
	end

	vim.fn.cursor(line, 1)
	vim.cmd("normal! zz")
	return true
end

local setup = function()
	vim.api.nvim_create_user_command("CkSearch", function(opts)
		open_tui(normalize_query(opts.args))
	end, {
		nargs = "*",
		desc = "Open ck search",
	})
end

return lib.module.create({
	name = "workflow/ck",
	hosts = "*",
	setup = setup,
	mappings = {
		{ "n", CK_MAP, open, { desc = "Search: ck" } },
		{ "v", CK_MAP, open_selection, { desc = "Search: ck selection" } },
	},
	exports = {
		open = open_tui,
		remote_open = remote_open,
	},
})
