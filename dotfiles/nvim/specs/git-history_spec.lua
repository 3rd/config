require("lib")

for _, plugin in ipairs({ "git-messenger.vim", "lush.nvim" }) do
  vim.opt.runtimepath:append(vim.fn.stdpath("data") .. "/lazy/" .. plugin)
end

vim.cmd("syntax on")
local palette = require("config/palette")
local added_color = tonumber(palette["green-medium"]:sub(2), 16)
local removed_color = tonumber(palette["red-medium"]:sub(2), 16)

local assert_syntax_color = function(line, column, expected_color)
  local syntax_id = vim.fn.synID(line, column, 1)
  local group = vim.fn.synIDattr(syntax_id, "name")
  local highlight = vim.api.nvim_get_hl(0, { name = group, link = false })
  assert(highlight.fg == expected_color, group .. " must use the diff color")
end

for _, theme in ipairs({ "static", "dynamic" }) do
  vim.cmd.colorscheme(theme)

  for _, filetype in ipairs({ "gitmessengerpopup", "diff" }) do
    vim.cmd("enew!")
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "-local greeting = 'Hello'", "+local greeting = 'Welcome'" })
    vim.bo.filetype = filetype
    assert_syntax_color(1, 2, removed_color)
    assert_syntax_color(2, 2, added_color)
  end

  vim.cmd("enew!")
  vim.b.__gitmessenger_diff = "current.word"
  local word_diff = "local greeting = [-Hello-]{+Welcome+}"
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { word_diff })
  vim.bo.filetype = "gitmessengerpopup"
  assert_syntax_color(1, assert(word_diff:find("Hello", 1, true)), removed_color)
  assert_syntax_color(1, assert(word_diff:find("Welcome", 1, true)), added_color)
end

vim.cmd("runtime plugin/gitmessenger.vim")
local git_module = require("modules/workflow/git")
git_module.plugins[2].config()

local project_root = vim.fn.tempname()
vim.fn.mkdir(project_root .. "/before", "p")
vim.fn.mkdir(project_root .. "/after", "p")

local run_git = function(args)
  local command = { "git", "-c", "user.name=Test", "-c", "user.email=test@example.com", "-c", "commit.gpgsign=false" }
  vim.list_extend(command, args)

  local result = vim
    .system(command, {
      cwd = project_root,
      text = true,
      env = { GIT_CONFIG_NOSYSTEM = "1", GIT_CONFIG_GLOBAL = "/dev/null" },
    })
    :wait()
  assert(result.code == 0, result.stderr)
end

local lines = { 'local greeting = "Hello"', "", "return greeting" }
for index = 4, 30 do
  lines[index] = "local value_" .. index .. " = " .. index
end

vim.fn.writefile(lines, project_root .. "/before/greeting.lua")
run_git({ "init", "--quiet", "--template=" })
run_git({ "add", "before/greeting.lua" })
run_git({ "commit", "--quiet", "-m", "test: initial greeting" })

assert(vim.uv.fs_rename(project_root .. "/before/greeting.lua", project_root .. "/after/greeting.lua"))
lines[1] = 'local greeting = "Welcome"'
vim.fn.writefile(lines, project_root .. "/after/greeting.lua")
run_git({ "add", "-A" })
vim.cmd.edit(project_root .. "/after/greeting.lua")
vim.api.nvim_win_set_cursor(0, { 1, 0 })
vim.cmd.GitMessenger()
assert(
  vim.wait(3000, function()
    return vim.bo.filetype == "gitmessengerpopup"
  end),
  vim.fn.execute("messages")
)

local popup_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
for _, expected in ipairs({
  "This line is not committed yet",
  "rename from before/greeting.lua",
  "rename to after/greeting.lua",
  '-local greeting = "Hello"',
  '+local greeting = "Welcome"',
}) do
  assert(vim.tbl_contains(popup_lines, expected), "history popup must contain " .. expected)
end

vim.cmd.GitMessengerClose()
run_git({ "commit", "--quiet", "-m", "test: move greeting" })
vim.cmd.GitMessenger()
assert(
  vim.wait(3000, function()
    return vim.bo.filetype == "gitmessengerpopup"
  end),
  vim.fn.execute("messages")
)
assert(vim.tbl_contains(vim.api.nvim_buf_get_lines(0, 0, -1, false), "test: move greeting"))

vim.cmd.normal("o")
assert(
  vim.wait(3000, function()
    return vim.tbl_contains(vim.api.nvim_buf_get_lines(0, 0, -1, false), "test: initial greeting")
  end),
  "history navigation must follow the file to its original name"
)
vim.cmd.GitMessengerClose()
vim.fn.delete(project_root, "rf")

print("ok: Git history colors, staged rename diffs, and committed history navigation")
