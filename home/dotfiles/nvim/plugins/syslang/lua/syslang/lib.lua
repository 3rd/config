local M = {}

local capitalize_special_cases = {
  ["^project[-]"] = "Project: ",
  ["^consume[-]"] = "Consume: ",
}

local function capitalize_fallback_title(title)
  local replaced = false
  for pattern, replacement in pairs(capitalize_special_cases) do
    if title:find(pattern) then
      title = title:gsub(pattern, replacement)
      replaced = true
      break
    end
  end

  title = title:gsub("-", " ")

  local words = {}
  for word in title:gmatch("%S+") do
    if not replaced then word = word:sub(1, 1):upper() .. word:sub(2) end
    table.insert(words, word)
    replaced = false
  end

  return table.concat(words, " ")
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
