local install = function(api, root)
  vim.api.nvim_create_user_command("BunvimStart", function()
    api.start()
  end, {})
  vim.api.nvim_create_user_command("BunvimStop", function()
    api.stop()
  end, {})
  vim.api.nvim_create_user_command("BunvimRestart", function()
    api.restart()
  end, {})
  vim.api.nvim_create_user_command("BunvimStatus", function()
    vim.print(api.status())
  end, {})
  vim.api.nvim_create_user_command("BunvimLog", function()
    vim.print(api.logs())
  end, {})
  vim.api.nvim_create_user_command("BunvimCancel", function(args)
    local id = tonumber(args.args)
    if not id then error("BunvimCancel requires a request id") end
    api.cancel(id)
  end, { nargs = 1 })
  vim.api.nvim_create_user_command("BunvimDemo", function()
    for _, name in ipairs({ "copy-path", "colorscheme-picker", "format-json", "todo-list" }) do
      api.load(name, { path = root .. "/examples/" .. name .. "/index.ts" })
    end
  end, {})
end

return { install = install }
