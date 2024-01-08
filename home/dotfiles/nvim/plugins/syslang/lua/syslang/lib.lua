local M = {}

local meta_config = {
  document = { -- default
    title_key = "title",
    title_prefix = "",
    icon = "🖹",
  },
  project = {
    fallback_match = "^project[-]",
    title_prefix = "Project: ",
    icon = "🖬 ",
  },
  consume = {
    fallback_match = "^consume[-]",
    title_prefix = "Consume: ",
    icon = "🕮 ",
  },
  person = {
    title_key = "name",
    icon = "👤",
  },
}

local get_fallback_type = function(node_name)
  for type, config in pairs(meta_config) do
    if config.fallback_match and node_name:find(config.fallback_match) then return type end
  end
  return "document"
end

local get_fallback_title = function(type, node_name)
  local config = meta_config[type]

  if config.fallback_match and config.title_prefix then
    node_name = node_name:gsub(config.fallback_match, config.title_prefix)
  end
  node_name = node_name:gsub("-", " ")

  local words = {}
  for word in node_name:gmatch("%S+") do
    word = word:sub(1, 1):upper() .. word:sub(2)
    table.insert(words, word)
  end

  return table.concat(words, " ")
end

M.get_icon = function(type) return meta_config[type] and meta_config[type].icon or meta_config.document.icon end

M.get_root = function()
  if vim.bo.filetype ~= "syslang" then error("syslang function called on wrong filetype") end
  local parser = vim.treesitter.get_parser(0)
  if parser:lang() ~= "syslang" then error("wrong parser") end
  return parser:parse()[1]:root()
end

M.get_document_meta = function()
  local type = get_fallback_type(vim.fn.expand("%:t"))
  local meta = {
    type = type,
    title = get_fallback_title(type, vim.fn.expand("%:t")),
  }

  local root = M.get_root()
  local meta_node = lib.ts.find_child(root, "document_meta", true)
  if not meta_node then return meta end

  local meta_fields = lib.ts.find_children(meta_node, "document_meta_field", true)
  for _, field in ipairs(meta_fields) do
    local key = lib.ts.find_child(field, "document_meta_field_key", true)
    local value = lib.ts.find_child(field, "document_meta_field_value", true)
    if key and value then meta[lib.ts.get_node_text(key)] = lib.ts.get_node_text(value) end
  end

  local meta_type = meta_config[meta.type] and meta.type or "document"
  local title_key = meta_config[meta_type].title_key or meta_config.document.title_key
  if meta[title_key] then meta.title = meta[title_key] end

  return meta
end

M.get_document_title = function()
  local meta = M.get_document_meta()
  local prefix = " " .. M.get_icon(meta["type"]) .. " "
  return prefix .. meta.title
end

return M
