local lib = require("lib")

local cmd = vim.cmd
local exec = function(command)
  vim.api.nvim_exec(command, true)
end

local actions = {
  -- dev
  plugin_update = function()
    exec([[PackerSync]])
  end,
  debug_scripts = function()
    cmd([[scriptnames]])
  end,
  debug_binds = function()
    cmd([[verbose map]])
  end,
  -- snippets
  snippets_edit = function()
    local snippets_dir = lib.path.resolve(lib.env.dirs.config .. "/snippets")
    local filetype = lib.buffer.current.get_filetype()
    local snippet_file = lib.path.resolve(snippets_dir .. "/" .. filetype .. ".snippets")
    cmd("edit " .. snippet_file)
  end,
  -- fs
  file_new = function()
    exec([[
    call feedkeys(":e %:h\<tab>", "tn")
    ]])
  end,
  file_rename = function()
    exec([[
    call feedkeys(":Move %\<tab>", "tn")
    ]])
  end,
  file_delete = function()
    exec([[Delete!]])
  end,
  -- sort
  lines_sort = function()
    exec([[%sort]])
  end,
  lines_sort_desc = function()
    exec([[%sort!]])
  end,
  visual_sort = function()
    cmd([[exe '''<,''>sort']])
  end,
  visual_sort_desc = function()
    cmd([[exe '''<,''>sort!']])
  end,
  -- silicon
  silicon_normal = function()
    local options = "--output /tmp/silicon.png --tab-width 2 --pad-horiz 50 --pad-vert 60 --no-window-controls -l "
        .. lib.buffer.current.get_filetype()
    local text = lib.buffer.current.get_text()
    lib.shell.exec("silicon " .. options, text)
    lib.shell.exec("copyq write image/png - < /tmp/silicon.png && copyq select 0")
  end,
  silicon_visual = function()
    local options = "--output /tmp/silicon.png --tab-width 2 --pad-horiz 50 --pad-vert 60 --no-window-controls -l "
        .. lib.buffer.current.get_filetype()
    local text = lib.buffer.current.get_selected_text()
    lib.shell.exec("silicon " .. options, text)
    lib.shell.exec("copyq write image/png - < /tmp/silicon.png && copyq select 0")
  end,
  silicon_highlight = function()
    local context = 6
    local options = "--output /tmp/silicon.png --tab-width 2 --pad-horiz 50 --pad-vert 60 --no-window-controls -l "
        .. lib.buffer.current.get_filetype()
    local text = lib.buffer.current.get_selected_text()
    local context_text = lib.buffer.current.get_selected_text(context)
    local line_count = #vim.split(text, "\n")
    if line_count == 0 then
      line_count = 1
    end
    local lines = {}
    local i = 1
    while i <= line_count do
      table.insert(lines, i + context)
      i = i + 1
    end
    lines = vim.fn.shellescape(vim.fn.join(lines, ";"))
    options = options .. " --highlight-lines " .. lines
    lib.shell.exec("silicon " .. options, context_text)
    lib.shell.exec("copyq write image/png - < /tmp/silicon.png && copyq select 0")
  end,
  -- linx
  linx = function()
    local path = lib.buffer.current.get_path()
    lib.shell.execute("linx " .. vim.fn.shellescape(path))
  end,
  linx_visual = function()
    local tmp = vim.fn.tempname()
    local text = lib.buffer.current.get_selected_text()
    lib.shell.write_file(tmp, vim.split(text, "\n"))
    lib.shell.execute("linx " .. vim.fn.shellescape(tmp))
  end,
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
  ts_playground = function()
    cmd(":TSPlaygroundToggle")
  end,
  -- toggle show whitespace
  toggle_whitespace = function()
    local default_listchars = require("config").options.set.listchars or {}
    local forced_listchars = {
      space = "␣",
      tab = "» ",
      trail = "·",
      nbsp = "×",
      eol = "$",
      extends = "›",
      precedes = "‹",
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
  focus_toggle_autoresize = function()
    vim.cmd("FocusToggle")
  end,
  refactor = function()
    require("refactoring").select_refactor()
  end,
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
    ["Upload: gist.ro"] = actions.linx,
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
    ["Upload: gist.ro"] = actions.linx_visual,
    ["Refactor"] = actions.refactor,
  },
}

local setup = function()
  local map = require("lib.map")
  local commands = require("modules/workflow/command-menu").export.commands

  local create_source = function(entries)
    local result = {}
    for k, _ in pairs(entries) do
      table.insert(result, k)
    end
    return result
  end

  local create_handler = function(command_index)
    return function(action_name)
      if action_name == "" then
        return
      end
      local action = command_index[action_name]
      if action == nil then
        throw("Command menu cannot find mapped action.")
      else
        action()
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
          relative = "win",
        }
        local result = fzf.fzf(source, "", options)
        if result then
          handler(result[1])
        end
      end)()
    end
  end

  local normal_menu = create_menu(commands.normal)
  map.fnmap("n", "<M-p>", normal_menu)
  map.fnmap("n", "<C-S-p>", normal_menu)

  local visual_menu = create_menu(commands.visual)
  map.fnmap("v", "<M-p>", visual_menu)
  map.fnmap("v", "<C-S-p>", visual_menu)
end

return require("lib").module.create({
  name = "workflow/command-menu",
  setup = setup,
  export = {
    commands = exported_commands,
  },
})
