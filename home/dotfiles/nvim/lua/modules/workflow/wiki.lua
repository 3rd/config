local lib = require("lib")

local api = {
  get = function(id)
    local command = string.format("WIKI_ROOT=$HOME/brain/wiki TASK_ROOT=$HOME/brain/wiki core wiki resolve '%s'", id)
    return lib.shell.exec(command)
  end,
  list = function()
    local command = "WIKI_ROOT=$HOME/brain/wiki TASK_ROOT=$HOME/brain/wiki core wiki ls | sort"
    local entries = lib.string.split(lib.shell.exec(command), "\n")
    return entries
  end,
}

local handle_select = function()
  local entries = api.list()

  local fzf = require("fzf")
  coroutine.wrap(function()
    local options = {
      height = 10,
      relative = "win",
    }

    local result = fzf.fzf(entries, "--print-query --nth 1 --print-query --expect=ctrl-s,ctrl-v,ctrl-x", options)
    if not result then
      return
    end

    local target = result[3]

    local command = "e %s"
    if result[2] == "ctrl-s" then
      command = "sp %s"
    elseif result[2] == "ctrl-v" then
      command = "vs %s"
    elseif result[2] == "ctrl-x" then
      target = result[1]
    end

    local path = api.get(target)
    local vim_command = string.format(command, path)
    vim.cmd(vim_command)
  end)()
end

return require("lib").module.create({
  name = "workflow/wiki",
  mappings = {
    { "n", "<M-n>", ":lua require('modules/workflow/wiki').export.select()<cr>" },
  },
  export = {
    select = handle_select,
  },
})
