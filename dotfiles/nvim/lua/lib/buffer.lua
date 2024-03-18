---@param bufnr number
local get_name = function(bufnr)
  return vim.api.nvim_buf_get_name(bufnr)
end

---@param bufnr number
---@param name string
local set_name = function(bufnr, name)
  vim.api.nvim_buf_set_name(bufnr, name)
end

---@param bufnr number
---@param name string
local get_option = function(bufnr, name)
  return vim.api.nvim_get_option_value(name, { buf = bufnr })
end

---@param bufnr number
---@param name string
local set_option = function(bufnr, name, value)
  vim.api.nvim_set_option_value(name, value, { buf = bufnr })
end

---@param bufnr number
---@param start? number
---@param finish? number
---@return string[]
local get_lines = function(bufnr, start, finish)
  return vim.api.nvim_buf_get_lines(bufnr, start or 0, finish or -1, true)
end

---@param bufnr number
---@param start number
---@param finish number
---@param lines string[]
local set_lines = function(bufnr, start, finish, lines)
  vim.api.nvim_buf_set_lines(bufnr, start or 0, finish or -1, true, lines)
end

---@param bufnr number
local get_text = function(bufnr)
  return vim.fn.join(get_lines(bufnr), "\n")
end

---@param bufnr number
---@param text string
local set_text = function(bufnr, text)
  set_lines(bufnr, 0, -1, vim.fn.split(text, "\n"))
end

---@param bufnr number
---@param context number
local get_selected_text = function(bufnr, context)
  local first = vim.fn.getpos("'<")[2] - 1
  local last = vim.fn.getpos("'>")[2]
  if context and context > 0 then
    first = first - context
    last = last + context
  end
  local lines = vim.api.nvim_buf_get_lines(bufnr, first, last, false)
  local text = vim.fn.join(lines, "\n")
  return text
end

local has_treesitter_highlighting = function(bufnr)
  if vim.fn.bufnr(bufnr) == -1 then return false end
  return vim.treesitter.highlighter.active[bufnr] ~= nil
end

local current_get_bufnr = function()
  return vim.api.nvim_get_current_buf()
end

local current_get_shortname = function()
  return vim.fn.expand("%:t:r")
end

local current_get_path = function()
  return vim.fn.expand("%:p")
end

local current_get_filetype = function()
  return vim.api.nvim_eval("&ft")
end

---@param value string
local current_set_filetype = function(value)
  vim.bo.filetype = value
end

local current_get_extension = function()
  return vim.fn.expand("%:e")
end

local current_get_directory = function()
  return vim.fn.expand("%:p:h")
end

local current_get_path_without_extension = function()
  return vim.fn.expand("%:p:r")
end

local current_get_current_line = function()
  return vim.api.nvim_get_current_line()
end

---@param value string
local current_set_current_line = function(value)
  vim.api.nvim_set_current_line(value)
end

local current_get_current_word = function()
  return vim.fn.expand("<cword>")
end

---@param fn function
---@vararg any
local apply = function(fn, ...)
  local args = { ... }
  return function(...)
    return fn(unpack(vim.tbl_flatten({ args, { ... } })))
  end
end

return {
  get_name = get_name,
  set_name = set_name,
  get_option = get_option,
  set_option = set_option,
  get_lines = get_lines,
  set_lines = set_lines,
  get_text = get_text,
  set_text = set_text,
  get_selected_text = get_selected_text,
  has_treesitter_highlighting = has_treesitter_highlighting,
  current = {
    get_name = apply(get_name, 0),
    set_name = apply(set_name, 0),
    get_option = apply(get_option, 0),
    set_option = apply(set_option, 0),
    get_lines = apply(get_lines, 0),
    set_lines = apply(set_lines, 0),
    get_text = apply(get_text, 0),
    set_text = apply(set_text, 0),
    get_selected_text = apply(get_selected_text, 0),
    get_bufnr = current_get_bufnr,
    get_shortname = current_get_shortname,
    get_path = current_get_path,
    get_filetype = current_get_filetype,
    set_filetype = current_set_filetype,
    get_extension = current_get_extension,
    get_directory = current_get_directory,
    get_path_without_extension = current_get_path_without_extension,
    get_current_line = current_get_current_line,
    set_current_line = current_set_current_line,
    get_current_word = current_get_current_word,
  },
}
