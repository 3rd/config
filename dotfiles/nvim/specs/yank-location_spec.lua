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

local links = require("modules/workflow/yank-location")
local buffer = vim.api.nvim_create_buf(false, true)
vim.api.nvim_set_current_buf(buffer)
vim.api.nvim_buf_set_name(buffer, "/tmp/link-example/src/a file.ts")
vim.bo.modified = false
local system = vim.system
local notify = vim.notify
local remote = "git@github.com:example/project.git"
local changed = ""
local warning
vim.notify = function(message, level)
  if level == vim.log.levels.WARN then warning = message end
end
vim.system = function(command)
  assert(command[1] == "git" and command[2] == "-C" and command[3] == "/tmp/link-example/src")
  local result
  if command[4] == "rev-parse" then
    result = command[5] == "HEAD" and "abc123" or "/tmp/link-example"
  elseif command[4] == "config" then
    result = remote
  elseif command[4] == "symbolic-ref" then
    result = "feature/review"
  elseif command[4] == "status" then
    result = changed
  else
    error(vim.inspect(command))
  end
  return {
    wait = function()
      return { code = 0, stdout = result .. "\n", stderr = "" }
    end,
  }
end
for _, url in ipairs({
  "git@github.com:example/project.git",
  "https://github.com/example/project.git",
  "ssh://git@github.com/example/project.git",
}) do
  remote = url
  links.exports.copy_github_link()
  assert(vim.fn.getreg("+") == "https://github.com/example/project/blob/abc123/src/a%20file.ts#L1")
end
links.actions[1][3]()
assert(vim.fn.getreg("+") == "https://github.com/example/project/blob/feature/review/src/a%20file.ts#L1")
changed = " M src/a file.ts"
links.exports.copy_github_link()
assert(warning and warning:find("local changes are not included", 1, true))
vim.system = system
vim.notify = notify
print("ok: GitHub permalinks pin commits, branch links remain explicit, and local changes are reported")
