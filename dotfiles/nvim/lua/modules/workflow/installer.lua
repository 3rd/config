local installer = require("lib/installer")

local commands = {
  status = function()
    vim.api.nvim_echo({ { table.concat(installer.status_lines(), "\n") } }, false, {})
  end,
  sync = function()
    installer.sync_configured()
  end,
}

local get_command_names = function()
  local names = vim.tbl_keys(commands)
  table.sort(names)
  return names
end

local complete_command = function(arg_lead)
  return vim.tbl_filter(function(command)
    return vim.startswith(command, arg_lead)
  end, get_command_names())
end

local run_command = function(args)
  local command = commands[args.args]
  if not command then error("unknown installer command: " .. args.args) end
  command()
end

local setup = function()
  installer.prepend_installed_bins()

  vim.api.nvim_create_user_command("Installer", run_command, {
    nargs = 1,
    complete = complete_command,
    desc = "Manage pinned Neovim tools",
  })
end

return lib.module.create({
  name = "workflow/installer",
  hosts = "*",
  setup = setup,
})
