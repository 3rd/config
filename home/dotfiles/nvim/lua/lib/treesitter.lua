local M = {}

--- @param node TSNode
--- @param type string
--- @param recursive? boolean
M.find_child = function(node, type, recursive)
  for _, child in ipairs(node:named_children()) do
    if child:type() == type then return child end
    if recursive then
      local result = M.find_child(child, type, recursive)
      if result ~= nil then return result end
    end
  end
  return nil
end

--- @param node TSNode
--- @param type string
--- @param recursive? boolean
M.find_children = function(node, type, recursive)
  local result = {}
  for i = 0, node:named_child_count() - 1 do
    local child = node:named_child(i)
    if child:type() == type then table.insert(result, child) end
    if recursive then
      local children = M.find_children(child, type, recursive)
      for _, c in ipairs(children) do
        table.insert(result, c)
      end
    end
  end
  return result
end

--- @param node TSNode
--- @param type string
M.find_parent = function(node, type)
  local parent = node:parent()
  while parent ~= nil do
    if parent:type() == type then return parent end
    parent = parent:parent()
  end
  return nil
end

return M
