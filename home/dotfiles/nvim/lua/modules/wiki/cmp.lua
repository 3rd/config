local list_nodes = function()
  local command = "WIKI_ROOT=$HOME/brain/wiki TASK_ROOT=$HOME/brain/wiki core wiki ls | sort"
  local nodes = string.split(vim.fn.trim(lib.shell.exec(command)), "\n")
  local items = {}
  for _, node in ipairs(nodes) do
    table.insert(items, {
      label = "[[" .. node .. "]]",
    })
  end
  return items
end

local source = {}

source.new = function()
  local self = setmetatable({}, { __index = source })
  self.cache = {}
  return self
end

function source.is_available()
  log("syslang is available", vim.bo.filetype == "syslang")
  return vim.bo.filetype == "syslang"
end

function source.get_debug_name()
  return "syslang"
end

-- function source.get_trigger_characters()
--   return { "[" }
-- end

function source.get_keyword_pattern()
  return "\\[\\[\\w*"
end

function source.complete(self, _, callback)
  local bufnr = vim.api.nvim_get_current_buf()
  local items = {}

  if not self.cache[bufnr] then
    items = list_nodes()
    if type(items) ~= "table" then return callback() end
    self.cache[bufnr] = items
  else
    items = self.cache[bufnr]
  end

  log("syslang completion items", items)

  callback({ items = items or {}, isIncomplete = false })
end

function source.resolve(_, completion_item, callback)
  callback(completion_item)
end

function source.execute(_, completion_item, callback)
  callback(completion_item)
end

return source
