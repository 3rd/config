local lib = require("lib")

local cmd = vim.cmd
local exec = function(command) vim.api.nvim_exec(command, true) end

local actions = {
  -- dev
  plugin_update = function() exec([[PackerSync]]) end,
  debug_scripts = function() cmd([[scriptnames]]) end,
  debug_binds = function() cmd([[verbose map]]) end,
  -- snippets
  snippets_edit = function()
    local snippets_dir = lib.path.resolve(lib.env.dirs.config .. "/snippets")
    local filetype = lib.buffer.current.get_filetype()
    local snippet_file =
      lib.path.resolve(snippets_dir .. "/" .. filetype .. ".snippets")
    cmd("edit " .. snippet_file)
  end,
  -- fs
  file_new = function() exec([[ call feedkeys(":e %:h\<tab>", "tn") ]]) end,
  file_rename = function() exec([[ call feedkeys(":Move %\<tab>", "tn") ]]) end,
  file_delete = function() exec([[Delete!]]) end,
  -- sort
  lines_sort = function() exec([[%sort]]) end,
  lines_sort_desc = function() exec([[%sort!]]) end,
  visual_sort = function() cmd([[exe '''<,''>sort']]) end,
  visual_sort_desc = function() cmd([[exe '''<,''>sort!']]) end,
  -- silicon
  silicon_normal = function()
    local options = "--output /tmp/silicon.png --tab-width 2 --pad-horiz 50 --pad-vert 60 --no-window-controls -l "
      .. lib.buffer.current.get_filetype()
    local text = lib.buffer.current.get_text()
    lib.shell.exec("silicon " .. options, text)
    lib.shell.exec(
      "copyq write image/png - < /tmp/silicon.png && copyq select 0"
    )
  end,
  silicon_visual = function()
    local options = "--output /tmp/silicon.png --tab-width 2 --pad-horiz 50 --pad-vert 60 --no-window-controls -l "
      .. lib.buffer.current.get_filetype()
    local text = lib.buffer.current.get_selected_text()
    lib.shell.exec("silicon " .. options, text)
    lib.shell.exec(
      "copyq write image/png - < /tmp/silicon.png && copyq select 0"
    )
  end,
  silicon_highlight = function()
    local context = 6
    local options = "--output /tmp/silicon.png --tab-width 2 --pad-horiz 50 --pad-vert 60 --no-window-controls -l "
      .. lib.buffer.current.get_filetype()
    local text = lib.buffer.current.get_selected_text()
    local context_text = lib.buffer.current.get_selected_text(context)
    local line_count = #vim.split(text, "\n")
    if line_count == 0 then line_count = 1 end
    local lines = {}
    local i = 1
    while i <= line_count do
      table.insert(lines, i + context)
      i = i + 1
    end
    lines = vim.fn.shellescape(vim.fn.join(lines, ";"))
    options = options .. " --highlight-lines " .. lines
    lib.shell.exec("silicon " .. options, context_text)
    lib.shell.exec(
      "copyq write image/png - < /tmp/silicon.png && copyq select 0"
    )
  end,
  -- linx
  gist = function()
    local path = lib.buffer.current.get_path()
    lib.shell.exec("gist " .. vim.fn.shellescape(path))
  end,
  gist_visual = function()
    local tmp = vim.fn.tempname()
    local text = lib.buffer.current.get_selected_text()

    local extension = lib.buffer.current.get_extension()
    local petname = lib.string.trim(lib.shell.exec("petname"))
    local filename = petname .. "." .. extension

    lib.shell.write_file(tmp, text)
    local output =
      lib.shell.exec("gist -f " .. filename .. " " .. vim.fn.shellescape(tmp))
    local link = vim.fn.matchstr(output, "https://gist.ro/\\S*")
    if link ~= "" then
      require("notify")("Gist created: " .. link)
    else
      require("notify")("Failed to create gist:\n" .. output, "error")
    end
  end,
  ts_playground = function() cmd(":TSPlaygroundToggle") end,
  -- toggle show whitespace
  toggle_whitespace = function()
    local default_listchars = require("config").options.set.listchars or {}
    local forced_listchars = {
      space = "???",
      tab = "?? ",
      trail = "??",
      nbsp = "??",
      eol = "$",
      extends = "???",
      precedes = "???",
    }

    if vim.g.csp_whitespace_enabled then
      vim.g.csp_whitespace_enabled = false
      vim.opt.listchars = default_listchars
    else
      vim.g.csp_whitespace_enabled = true
      vim.opt.listchars = forced_listchars
      vim.opt.list = true
    end
  end,
  focus_toggle_autoresize = function() vim.cmd("FocusToggle") end,
  refactor = function() require("refactoring").select_refactor() end,
  -- -- hex
  -- toggle_hex = function()
  --   cmd(":Hexmode")
  -- end,
  -- -- rosa_parse
  -- to_yaml = function()
  --   cmd(":%!to-yaml")
  --   exec("setlocal ft=yaml")
  -- end,
  -- to_json = function()
  --   cmd(":%!to-json")
  --   exec("setlocal ft=json")
  -- end,
  -- to_toml = function()
  --   cmd(":%!to-toml")
  --   exec("setlocal ft=toml")
  -- end,
  -- treesitter
}

local exported_commands = {
  normal = {
    ["Vim: Reload"] = actions.vim_reload,
    ["Vim: Update plugins"] = actions.plugin_update,
    ["Vim: Debug scripts"] = actions.debug_scripts,
    ["Vim: Debug binds"] = actions.debug_binds,
    ["Snippets: Edit snippets"] = actions.snippets_edit,
    ["File: New"] = actions.file_new,
    ["File: Rename"] = actions.file_rename,
    ["File: Delete"] = actions.file_delete,
    ["Buffer: Sort lines"] = actions.lines_sort,
    ["Buffer: Sort lines (desc)"] = actions.lines_sort_desc,
    ["Silicon: File"] = actions.silicon_normal,
    ["Gist: Upload current file"] = actions.gist,
    -- ["Convert: To YAML"] = actions.to_yaml,
    -- ["Convert: To JSON"] = actions.to_json,
    -- ["Convert: To TOML"] = actions.to_toml,
    -- ["Hex: Toggle hex mode"] = actions.toggle_hex,
    ["Treesitter: Open playground"] = actions.ts_playground,
    ["Toggle whitespace"] = actions.toggle_whitespace,
    ["Focus: Toggle auto-resize"] = actions.focus_toggle_autoresize,
    ["Refactor"] = actions.refactor,
  },
  visual = {
    ["Sort lines"] = actions.visual_sort,
    ["Sort lines (desc)"] = actions.visual_sort_desc,
    ["Silicon: Selection"] = actions.silicon_visual,
    ["Silicon: Highlight"] = actions.silicon_highlight,
    ["Gist: Upload selection"] = actions.gist_visual,
    ["Refactor"] = actions.refactor,
  },
}

local setup = function()
  local lib = require("lib")
  local commands = require("modules/workflow/command-menu").export.commands

  -- load module actions
  local modules = lib.module.get_enabled_modules()
  for _, module in ipairs(modules) do
    if module.actions then
      -- { "n", "Action name", command or function }
      for _, action in ipairs(module.actions) do
        local mode = action[1]
        local name = action[2]
        local command = action[3]
        if mode == "n" then
          commands.normal[name] = command
        elseif mode == "v" then
          commands.visual[name] = command
        end
      end
    end
  end

  local create_source = function(entries)
    local result = {}
    for k, _ in pairs(entries) do
      table.insert(result, k)
    end
    return result
  end

  local create_handler = function(command_index)
    return function(action_name)
      if action_name == "" then return end
      local action = command_index[action_name]
      if action == nil then
        throw("Command menu cannot find mapped action.")
      else
        if type(action) == "function" then
          action()
        else
          cmd(action)
        end
      end
    end
  end

  local create_menu = function(command_index)
    local source = create_source(command_index)
    local handler = create_handler(command_index)

    return function()
      local fzf = require("fzf")
      coroutine.wrap(function()
        local options = {
          height = 10,
          relative = "editor",
        }
        vim.cmd([[20 new]])
        local result = fzf.provided_win_fzf(source, "", options)
        if result then handler(result[1]) end
      end)()
    end
  end

  local normal_menu = create_menu(commands.normal)
  lib.map.fnmap("n", "<M-p>", normal_menu)
  lib.map.fnmap("n", "<c-s-p>", normal_menu)

  local visual_menu = create_menu(commands.visual)
  lib.map.fnmap("v", "<M-p>", visual_menu)
  lib.map.fnmap("v", "<c-s-p>", visual_menu)
end

return require("lib").module.create({
  name = "workflow/command-menu",
  setup = setup,
  export = {
    commands = exported_commands,
  },
})
