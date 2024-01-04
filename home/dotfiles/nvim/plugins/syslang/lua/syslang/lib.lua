local M = {}

local capitalize_fallback_title = function(title)
  local title_case = function(str)
    return str
      :gsub("(%a)([%w_']*)", function(first, rest)
        return first:upper() .. rest:lower()
      end)
      :gsub("-", " ")
  end

  -- Handle special cases
  if title:match("^project%-") then
    return "Project: " .. title_case(title:sub(9))
  elseif title:match("^consume%-") then
    return "Consume: " .. title_case(title:sub(9))
  else
    return title_case(title)
  end
end

M.get_root = function()
  if vim.bo.filetype ~= "syslang" then error("syslang function called on wrong filetype") end
  local parser = vim.treesitter.get_parser(0)
  if parser:lang() ~= "syslang" then error("wrong parser") end
  return parser:parse()[1]:root()
end

M.get_document_meta = function()
  local root = M.get_root()

  local meta_node = lib.ts.find_child(root, "document_meta", true)
  if not meta_node then return nil end

  local result = {}
  local meta_fields = lib.ts.find_children(meta_node, "document_meta_field", true)
  for _, field in ipairs(meta_fields) do
    local key = lib.ts.find_child(field, "document_meta_field_key", true)
    local value = lib.ts.find_child(field, "document_meta_field_value", true)
    if key and value then result[lib.ts.get_node_text(key)] = lib.ts.get_node_text(value) end
  end
  return result
end

M.get_document_title = function()
  local prefix = "   "
  local fallback = vim.fn.expand("%:t")
  local meta = M.get_document_meta()
  return prefix .. (meta and meta["title"] or capitalize_fallback_title(fallback))
end

return M
