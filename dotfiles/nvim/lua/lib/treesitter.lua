local M = {}

--- @param node TSNode
--- @param type string
--- @param deep? boolean
M.find_child = function(node, type, deep)
  for _, child in ipairs(node:named_children()) do
    if child:type() == type then return child end
    if deep then
      local result = M.find_child(child, type, deep)
      if result ~= nil then return result end
    end
  end
  return nil
end

--- @param node TSNode
--- @param type string | string[] | nil
--- @param deep? boolean
M.find_children = function(node, type, deep)
  local result = {}
  for i = 0, node:named_child_count() - 1 do
    local child = node:named_child(i)
    if child then
      if type == nil or child:type() == type or (lib.is.table(type) and table.includes(type, child:type())) then
        table.insert(result, child)
      end
      if deep then
        local children = M.find_children(child, type, deep)
        for _, c in ipairs(children) do
          table.insert(result, c)
        end
      end
    end
  end
  return result
end

--- @param node TSNode
--- @param types string|string[]
--- @return TSNode|nil
M.find_parent = function(node, types)
  types = type(types) == "table" and types or { types }
  local parent = node:parent()
  while parent ~= nil do
    if vim.tbl_contains(types, parent:type()) then return parent end
    parent = parent:parent()
  end
  return nil
end

--- @param type string|string[]
--- @return TSNode|nil
M.find_parent_at_line = function(type)
  local parent_line = vim.fn.line(".") - 1
  local line_length = #vim.fn.getline(parent_line)
  local parent_start_node = vim.treesitter.get_node({
    bufnr = 0,
    pos = { parent_line, line_length - 1 },
  })

  local types = lib.is.table(type) and type or { type }
  local current = parent_start_node

  while current ~= nil do
    local current_parent_line = current:range()
    if current_parent_line ~= parent_line then break end
    ---@cast types string[]
    for _, t in ipairs(types) do
      if current:type() == t then return current end
    end
    current = current:parent()
  end
  return nil
end

---@param node TSNode
---@param source string|number
---@return string
M.get_node_text = function(node, source)
  return vim.treesitter.get_node_text(node, source or 0)
end

return M
