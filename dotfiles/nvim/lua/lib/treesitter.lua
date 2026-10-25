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

M.for_each_tree_in_range = function(parser, start_row, end_row, callback)
  local regions = parser:included_regions()

  for index, tree in pairs(parser:trees()) do
    local ranges = regions[index]
    local is_visible = #ranges == 0

    for _, range in ipairs(ranges) do
      if range[1] <= end_row and range[4] >= start_row then
        is_visible = true
        break
      end
    end

    if is_visible then
      local root = tree:root()
      local root_start, _, root_end = root:range()
      if root_start <= end_row and root_end >= start_row then callback(tree, parser, root) end
    end
  end

  for _, child in pairs(parser:children()) do
    M.for_each_tree_in_range(child, start_row, end_row, callback)
  end
end

M.register_prose_queries = function()
  local prose = require("config/prose")
  vim.treesitter.query.add_directive("prose-icon!", function(_, _, _, predicate, metadata)
    local capture = predicate[2]
    local symbol = assert(prose[predicate[3]], "Unknown prose symbol: " .. predicate[3])
    metadata[capture] = metadata[capture] or {}
    metadata[capture].conceal = symbol
  end, { force = true })

  vim.treesitter.query.add_predicate("prose-external-link?", function(match, _, source, predicate)
    local node = match[predicate[2]][1]
    return vim.treesitter.get_node_text(node, source):match(prose.external_link_pattern) ~= nil
  end, { force = true })
end

return M
