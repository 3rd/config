---@class Command
---@field kind "action"|"toggle"
---@field name string
---@field mode "n"|"v"|nil
---@field group string|nil
---@field plugin string|nil
---@field condition (fun(): boolean)|nil

---@class ActionCommand: Command
---@field kind "action"
---@field run function|string

---@class ToggleCommand: Command
---@field kind "toggle"
---@field id string
---@field is_enabled fun(): boolean
---@field set_enabled fun(is_enabled: boolean)
---@field persist boolean|nil

---@alias ModuleAction ActionCommand|ToggleCommand|{ [1]: string, [2]: string, [3]: string|function, [4]: (fun(): boolean)|nil }

local commands = {}
local active_toggles = {}
local initialized_plugins = {}

local warn = function(id, message)
  vim.notify("Command toggle " .. id .. ": " .. message, vim.log.levels.WARN)
end

local get_state_path = function(id)
  assert(id:match("^[a-z][a-z0-9_.-]*$"), "Invalid command toggle ID: " .. id)
  return vim.fn.stdpath("state") .. "/command-toggles/" .. id .. ".json"
end

local read_state = function(id)
  local path = get_state_path(id)
  local stat, stat_error, error_code = vim.uv.fs_stat(path)
  if error_code == "ENOENT" then return end
  if not stat then
    warn(id, "cannot read saved state: " .. stat_error)
    return
  end

  local did_read, contents = pcall(vim.fn.readfile, path)
  if not did_read then
    warn(id, "cannot read saved state: " .. contents)
    return
  end

  local did_decode, is_enabled = pcall(vim.json.decode, table.concat(contents, "\n"))
  if not did_decode or type(is_enabled) ~= "boolean" then
    warn(id, "saved state must be a JSON boolean; keeping the current setting")
    return
  end

  return is_enabled
end

local save_state = function(toggle)
  local is_enabled = toggle.is_enabled()
  assert(type(is_enabled) == "boolean", "Command toggle must return a boolean: " .. toggle.id)

  local path = get_state_path(toggle.id)
  local temporary_path = path .. "." .. vim.fn.getpid() .. ".tmp"
  local did_write, write_error = pcall(function()
    vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
    vim.fn.writefile({ vim.json.encode(is_enabled) }, temporary_path)
    local did_rename, rename_error = vim.uv.fs_rename(temporary_path, path)
    if not did_rename then error(rename_error) end
  end)
  if not did_write then
    vim.uv.fs_unlink(temporary_path)
    warn(toggle.id, "cannot save state: " .. write_error)
    return
  end

  if active_toggles[toggle.id] then active_toggles[toggle.id].is_enabled = is_enabled end
end

---@param toggle ToggleCommand
---@param is_enabled boolean
local set_enabled = function(toggle, is_enabled)
  toggle.set_enabled(is_enabled)

  if toggle.persist then save_state(toggle) end
end

local initialize_command = function(command)
  if command.kind ~= "toggle" or not command.persist then return end

  local is_enabled = read_state(command.id)
  if is_enabled ~= nil then command.set_enabled(is_enabled) end

  active_toggles[command.id] = { toggle = command, is_enabled = command.is_enabled() }
end

local initialize_plugin = function(name)
  for _, command in ipairs(commands) do
    if command.plugin == name then initialize_command(command) end
  end

  initialized_plugins[name] = true
end

local has_plugin_commands = function(name)
  for _, command in ipairs(commands) do
    if command.plugin == name then return true end
  end

  return false
end

local normalize_action = function(action)
  if action.kind then return action end

  return {
    kind = "action",
    mode = action[1],
    name = action[2],
    run = action[3],
    condition = action[4],
  }
end

---@param modules Module[]
local setup = function(modules)
  commands = {}
  active_toggles = {}
  initialized_plugins = {}

  for _, module in ipairs(modules) do
    for _, action in ipairs(module.actions or {}) do
      local command = normalize_action(action)
      table.insert(commands, command)

      if not command.plugin then initialize_command(command) end
    end
  end

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = vim.api.nvim_create_augroup("command-toggles", { clear = true }),
    callback = function()
      for _, state in pairs(active_toggles) do
        if state.toggle.is_enabled() ~= state.is_enabled then save_state(state.toggle) end
      end
    end,
  })
end

---@param mode "n"|"v"
local get_actions = function(mode)
  local actions = {}
  for _, command in ipairs(commands) do
    if (command.mode or "n") == mode then
      if command.plugin and not initialized_plugins[command.plugin] then
        require("lazy").load({ plugins = { command.plugin } })
        assert(initialized_plugins[command.plugin], "Command plugin did not initialize: " .. command.plugin)
      end

      if not command.condition or command.condition() then
        local prefix = command.group and command.group .. ": " or ""
        if command.kind == "toggle" then
          local should_enable = not command.is_enabled()
          local verb = should_enable and "Enable" or "Disable"
          actions[prefix .. verb .. " " .. command.name] = function()
            set_enabled(command, should_enable)
          end
        else
          actions[prefix .. command.name] = command.run
        end
      end
    end
  end

  return actions
end

return {
  setup = setup,
  get_actions = get_actions,
  has_plugin_commands = has_plugin_commands,
  initialize_plugin = initialize_plugin,
}
