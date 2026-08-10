require("lib")

local smart_yank = require("modules/workflow/yank-location").mappings[1][3]

local yank_code_block = function(lines, cursor_line)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(bufnr)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].filetype = "syslang"
  vim.api.nvim_win_set_cursor(0, { cursor_line, 0 })

  smart_yank()

  return vim.fn.getreg("+")
end

local dedented = yank_code_block({
  "@code lua",
  "  local value = 1",
  "    print(value)",
  "  ",
  "@end",
}, 2)
assert(dedented == "local value = 1\n  print(value)\n", vim.inspect(dedented))

local unchanged = yank_code_block({
  "@code",
  "  indented",
  "flush_left",
  "@end",
}, 2)
assert(unchanged == "  indented\nflush_left", vim.inspect(unchanged))

print("ok: Syslang code block yanks remove common indentation")
