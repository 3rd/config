local M = {}

local find_mapping = function(mode, keys, bufnr)
  local mappings = bufnr and vim.api.nvim_buf_get_keymap(bufnr, mode) or vim.api.nvim_get_keymap(mode)
  local target = vim.api.nvim_replace_termcodes(keys, true, true, true)
  for _, mapping in ipairs(mappings) do
    if vim.api.nvim_replace_termcodes(mapping.lhs, true, true, true) == target then return mapping end
  end
end

local remove_entry = function(entry)
  for _, command in ipairs(entry.commands) do
    local current = vim.api.nvim_get_commands({})[command.name]
    if current and current.callback == command.callback and current.definition == command.definition then
      vim.api.nvim_del_user_command(command.name)
    end
  end

  for _, mapping in ipairs(entry.mappings) do
    if not mapping.buffer or vim.api.nvim_buf_is_valid(mapping.buffer) then
      local current = find_mapping(mapping.mode, mapping.keys, mapping.buffer)
      if current and current.callback == mapping.callback then
        vim.keymap.del(mapping.mode, mapping.keys, { buffer = mapping.buffer })
      end
    end
  end

  for _, id in ipairs(entry.autocmds) do
    pcall(vim.api.nvim_del_autocmd, id)
  end
end

M.create = function(invoke, invoke_sync)
  local scopes = {}

  local remove = function(name, generation, id)
    local scope = scopes[name]
    if not scope or (generation and generation ~= scope.generation) then return end
    if id then
      local entry = scope.entries[id]
      if not entry then return end
      scope.entries[id] = nil
      remove_entry(entry)
      return
    end

    scopes[name] = nil
    for _, entry in pairs(scope.entries) do
      remove_entry(entry)
    end
  end

  local install_command = function(name, generation, entry, owned)
    if vim.fn.exists(":" .. entry.name) == 2 then error("Command already exists: " .. entry.name) end

    local callback = function(args)
      invoke(name, entry.handler, args, nil, generation)
    end

    local complete = entry.complete

    if entry.completion then
      complete = function(arg_lead, cmd_line, cursor_pos)
        local result = invoke_sync(name, entry.completion, { arg_lead, cmd_line, cursor_pos }, nil, generation)
        if type(result) ~= "table" then error("Completion must return an array of strings") end

        for _, value in ipairs(result) do
          if type(value) ~= "string" then error("Completion must return an array of strings") end
        end

        return result
      end
    end

    vim.api.nvim_create_user_command(entry.name, callback, {
      nargs = entry.nargs,
      bang = entry.bang,
      range = entry.range,
      count = entry.count,
      complete = complete,
      desc = entry.desc,
      force = false,
    })
    table.insert(owned.commands, vim.api.nvim_get_commands({})[entry.name])
  end

  local install_keymap = function(name, generation, entry, owned)
    local bufnr = entry.buffer
    if bufnr == 0 then bufnr = vim.api.nvim_get_current_buf() end

    local modes = type(entry.mode) == "table" and entry.mode or { entry.mode }

    for _, mode in ipairs(modes) do
      if find_mapping(mode, entry.keys, bufnr) then error("Mapping already exists: " .. mode .. " " .. entry.keys) end

      local callback = function()
        if entry.expr then
          local result = invoke_sync(name, entry.handler, vim.NIL, bufnr, generation)
          if type(result) ~= "string" then error("Expression mapping must return a string") end
          return result
        end

        invoke(name, entry.handler, vim.NIL, bufnr, generation)
      end

      vim.keymap.set(mode, entry.keys, callback, {
        buffer = bufnr,
        desc = entry.desc,
        silent = entry.silent ~= false,
        expr = entry.expr,
      })
      table.insert(owned.mappings, { mode = mode, keys = entry.keys, buffer = bufnr, callback = callback })
    end
  end

  local install_autocmd = function(name, generation, entry, owned)
    local id = vim.api.nvim_create_autocmd(entry.event, {
      pattern = entry.pattern,
      buffer = entry.buffer,
      once = entry.once,
      desc = entry.desc,
      callback = function(args)
        if entry.execution == "sync" then
          invoke_sync(name, entry.handler, args, args.buf, generation)
        else
          invoke(name, entry.handler, args, args.buf, generation)
        end
      end,
    })
    table.insert(owned.autocmds, id)
  end

  local install = function(name, generation, entries)
    local scope = scopes[name]
    if scope and scope.generation ~= generation then error("Plugin registrations already exist: " .. name) end
    if not scope then
      scope = { generation = generation, entries = {} }
      scopes[name] = scope
    end

    local installed = {}
    local ok, install_error = pcall(function()
      for _, entry in ipairs(entries) do
        if scope.entries[entry.id] then error("Registration already exists: " .. entry.id) end
        local owned = { commands = {}, mappings = {}, autocmds = {} }
        scope.entries[entry.id] = owned
        table.insert(installed, entry.id)

        if entry.kind == "command" then
          install_command(name, generation, entry, owned)
        elseif entry.kind == "keymap" then
          install_keymap(name, generation, entry, owned)
        elseif entry.kind == "autocmd" then
          install_autocmd(name, generation, entry, owned)
        else
          error("Unknown Bunvim registration: " .. tostring(entry.kind))
        end
      end
    end)
    if not ok then
      for _, id in ipairs(installed) do
        remove(name, generation, id)
      end
      error(install_error)
    end
  end

  local clear = function()
    for name in pairs(scopes) do
      remove(name)
    end
  end

  return { install = install, remove = remove, clear = clear }
end

return M
