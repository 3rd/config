require("lib")

vim.opt.runtimepath:append(vim.fn.stdpath("data") .. "/lazy/gitsigns.nvim")
vim.o.signcolumn = "yes"
vim.cmd.colorscheme("static")

local project_root = vim.fn.tempname()
vim.fn.mkdir(project_root, "p")

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
  return result.stdout
end

local project_file = project_root .. "/sample.txt"
local lines = { "first", "second", "third", "fourth", "fifth", "sixth", "seventh", "eighth" }
vim.fn.writefile(lines, project_file)
run_git({ "init", "--quiet", "--template=" })
run_git({ "add", "sample.txt" })
run_git({ "commit", "--quiet", "-m", "test: baseline" })

lines[2] = "staged change"
vim.fn.writefile(lines, project_file)
run_git({ "add", "sample.txt" })
require("modules/workflow/git").plugins[1].config()
vim.cmd.edit(vim.fn.fnameescape(project_file))

local bufnr = vim.api.nvim_get_current_buf()
local find_sign = function(line, text)
  vim.cmd.redraw()
  local marks = vim.api.nvim_buf_get_extmarks(bufnr, -1, { line - 1, 0 }, { line - 1, -1 }, {
    details = true,
    type = "sign",
  })

  for _, mark in ipairs(marks) do
    if vim.trim(mark[4].sign_text) == text then return mark[4] end
  end
end

local has_sign = function(line, text)
  return find_sign(line, text) ~= nil
end

local has_line_highlight = function(line)
  vim.cmd.redraw()
  local marks = vim.api.nvim_buf_get_extmarks(bufnr, -1, { line - 1, 0 }, { line - 1, -1 }, { details = true })

  for _, mark in ipairs(marks) do
    local group = mark[4].hl_group
    if group and group:find("^GitSigns") then return true end
  end

  return false
end

assert(
  vim.wait(2000, function()
    return has_sign(2, "┆")
  end),
  "staged-only changes must have a gutter sign"
)
local staged_color = vim.api.nvim_get_hl(0, { name = "GitSignsStagedChange", link = false })
local unstaged_color = vim.api.nvim_get_hl(0, { name = "GitSignsChange", link = false })
assert(staged_color.fg == unstaged_color.fg, "staged signs must retain the visible theme color")

local staged_sign = assert(find_sign(2, "┆"))
local staged_number_color = vim.api.nvim_get_hl(0, { name = staged_sign.number_hl_group, link = false })
assert(staged_number_color.fg == staged_color.fg, "staged line numbers must retain the visible sign color")
assert(not has_line_highlight(2), "whole-line highlighting must remain opt-in")

vim.api.nvim_buf_set_lines(bufnr, 5, 6, false, { "working change" })
assert(
  vim.wait(2000, function()
    return has_sign(6, "┃") and has_sign(2, "┆")
  end),
  "staged and unstaged changes must have distinct signs"
)
local unstaged_sign = assert(find_sign(6, "┃"))
local unstaged_number_color = vim.api.nvim_get_hl(0, { name = unstaged_sign.number_hl_group, link = false })
assert(unstaged_number_color.fg == unstaged_color.fg, "unstaged line numbers must match the sign color")

require("gitsigns").toggle_linehl(true)
assert(vim.wait(2000, function()
  local staged_highlight = find_sign(2, "┆")
  local unstaged_highlight = find_sign(6, "┃")
  if not staged_highlight or not unstaged_highlight then return false end

  return has_line_highlight(2) and has_line_highlight(6)
end))

for _, group in ipairs({ "GitSignsAddLn", "GitSignsChangeLn", "GitSignsStagedAddLn", "GitSignsStagedChangeLn" }) do
  local highlight = vim.api.nvim_get_hl(0, { name = group, link = false })
  assert(highlight.bg ~= nil and highlight.fg == nil, "whole-line highlighting must preserve syntax colors")
end

local boundary_buffer = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(boundary_buffer, 0, -1, false, { "last line" })
local boundary_signs = require("gitsigns.signs").new(true)
boundary_signs:add(boundary_buffer, { { lnum = 1, type = "add" }, { lnum = 2, type = "add" } })

local boundary_highlights =
  vim.api.nvim_buf_get_extmarks(boundary_buffer, boundary_signs.line_highlight_namespace, 0, -1, { details = true })
assert(#boundary_highlights == 1, "only existing lines must receive layered highlights")
assert(boundary_highlights[1][2] == 0, "the last buffer line must remain highlighted")
assert(boundary_highlights[1][4].end_row == 1, "the final highlight must end at the buffer boundary")
assert(boundary_highlights[1][4].hl_group == "GitSignsStagedAddLn")
vim.api.nvim_buf_delete(boundary_buffer, { force = true })

require("gitsigns").toggle_linehl(false)
assert(vim.wait(2000, function()
  local staged_highlight = find_sign(2, "┆")
  local unstaged_highlight = find_sign(6, "┃")
  if not staged_highlight or not unstaged_highlight then return false end

  return not has_line_highlight(2) and not has_line_highlight(6)
end))

local press_keys = function(keys)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "xt", false)
end

local navigate_to_hunk = function(keys, line)
  press_keys(keys)
  assert(
    vim.wait(2000, function()
      return vim.api.nvim_win_get_cursor(0)[1] == line
    end),
    keys .. " did not navigate to the expected staged or unstaged hunk"
  )
end

navigate_to_hunk("]h", 2)
navigate_to_hunk("]H", 6)
navigate_to_hunk("[h", 2)
navigate_to_hunk("]h", 6)
navigate_to_hunk("[H", 2)
navigate_to_hunk("]H", 6)

press_keys("gh_")
assert(
  vim.wait(2000, function()
    return has_sign(6, "┆")
  end),
  "the gh operator must stage its motion range"
)
assert(run_git({ "show", ":sample.txt" }):find("working change", 1, true))

press_keys("ghgh")
assert(
  vim.wait(2000, function()
    return has_sign(6, "┃")
  end),
  "the gh textobject must select a staged hunk for unstaging"
)
assert(not run_git({ "show", ":sample.txt" }):find("working change", 1, true))

press_keys("Vgh")
assert(
  vim.wait(2000, function()
    return has_sign(6, "┆")
  end),
  "visual gh must stage the selected lines"
)
assert(vim.fn.mode() == "n", "staging a visual selection must return to normal mode")

run_git({ "restore", "--staged", "sample.txt" })
assert(
  vim.wait(2000, function()
    return has_sign(2, "┃") and has_sign(6, "┃") and not has_sign(2, "┆") and not has_sign(6, "┆")
  end),
  "external index updates must refresh the gutter"
)

press_keys("gH_")
assert(
  vim.wait(2000, function()
    return vim.api.nvim_buf_get_lines(bufnr, 5, 6, false)[1] == "sixth"
  end),
  "the gH operator must reset its motion range"
)
vim.api.nvim_win_set_cursor(0, { 2, 0 })
press_keys(".")
assert(
  vim.wait(2000, function()
    return vim.api.nvim_buf_get_lines(bufnr, 1, 2, false)[1] == "second"
  end),
  "resetting a motion must remain dot-repeatable"
)

vim.api.nvim_buf_set_lines(bufnr, 5, 6, false, { "visual reset" })
assert(vim.wait(2000, function()
  return has_sign(6, "┃")
end))
vim.api.nvim_win_set_cursor(0, { 6, 0 })
press_keys("VgH")
assert(
  vim.wait(2000, function()
    return vim.api.nvim_buf_get_lines(bufnr, 5, 6, false)[1] == "sixth"
  end),
  "visual gH must reset the selected lines"
)

vim.api.nvim_buf_set_lines(
  bufnr,
  1,
  7,
  false,
  { "edit two", "edit three", "edit four", "edit five", "edit six", "edit seven" }
)
assert(vim.wait(2000, function()
  return has_sign(3, "┃") and has_sign(7, "┃")
end))
vim.api.nvim_win_set_cursor(0, { 2, 0 })
press_keys("gH2j")
assert(
  vim.wait(2000, function()
    return vim.api.nvim_buf_get_lines(bufnr, 1, 4, false)[3] == "fourth"
  end),
  "resetting a multiline motion must include the whole range"
)
vim.api.nvim_win_set_cursor(0, { 5, 0 })
press_keys(".")
assert(
  vim.wait(2000, function()
    return vim.api.nvim_buf_get_lines(bufnr, 4, 7, false)[3] == "seventh"
  end),
  "dot-repeat must preserve the multiline motion"
)

vim.api.nvim_buf_delete(bufnr, { force = true })
vim.fn.delete(project_root, "rf")
print("ok: staged Git signs, index refresh, hunk navigation, and stage/reset mappings")
