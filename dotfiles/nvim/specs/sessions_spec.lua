require("lib")

vim.opt.runtimepath:append(vim.fn.stdpath("data") .. "/lazy/auto-session")

local test_dir = vim.fn.tempname()
local project_root = vim.fs.joinpath(test_dir, "project")
local outside_root = vim.fs.joinpath(test_dir, "outside")
local session_dir = vim.fs.joinpath(test_dir, "sessions")
local project_file = vim.fs.joinpath(project_root, "project.lua")
local outside_file = vim.fs.joinpath(outside_root, "outside.lua")
local hidden_outside_file = vim.fs.joinpath(outside_root, "hidden-outside.lua")

vim.fn.mkdir(project_root, "p")
vim.fn.mkdir(outside_root, "p")
vim.fn.writefile({ "return 'project'" }, project_file)
vim.fn.writefile({ "return 'outside'" }, outside_file)
vim.fn.writefile({ "return 'hidden outside'" }, hidden_outside_file)
require("lib/env").dirs.vim.sessions = session_dir

vim.cmd("cd " .. vim.fn.fnameescape(project_root))
vim.cmd("edit " .. vim.fn.fnameescape(project_file))
vim.cmd("vsplit " .. vim.fn.fnameescape(outside_file))
vim.cmd("badd " .. vim.fn.fnameescape(hidden_outside_file))

local outside_winid = vim.api.nvim_get_current_win()
local outside_bufnr = vim.api.nvim_get_current_buf()
local hidden_outside_bufnr = vim.fn.bufnr(hidden_outside_file)
local hidden = vim.o.hidden

vim.api.nvim_buf_set_lines(outside_bufnr, 0, -1, false, { "unsaved outside change" })
vim.bo[outside_bufnr].modified = true

require("modules/workflow/sessions").plugins[1].config()
local saved = require("auto-session").save_session(nil, { show_message = false })
assert(saved, "auto-session did not save the project session")

local session_path = vim.v.this_session
local session = table.concat(vim.fn.readfile(session_path), "\n")
assert(session:find(project_file, 1, true), "project session does not contain its project file")
assert(not session:find(outside_file, 1, true), "project session contains the visible outside file")
assert(not session:find(hidden_outside_file, 1, true), "project session contains the hidden outside file")

assert(vim.api.nvim_win_get_buf(outside_winid) == outside_bufnr, "session save changed the visible outside buffer")
assert(vim.bo[outside_bufnr].buflisted, "session save left the visible outside buffer unlisted")
assert(vim.bo[hidden_outside_bufnr].buflisted, "session save left the hidden outside buffer unlisted")
assert(vim.bo[outside_bufnr].modified, "session save discarded the outside buffer's modifications")
assert(vim.api.nvim_buf_get_lines(outside_bufnr, 0, -1, false)[1] == "unsaved outside change")
assert(vim.o.hidden == hidden, "session save did not restore the hidden option")

for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
  if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_get_name(bufnr) ~= "" then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
end

vim.cmd("source " .. vim.fn.fnameescape(session_path))

local restored_paths = {}
for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name ~= "" then restored_paths[vim.fs.normalize(name)] = true end
end

assert(restored_paths[project_file], "restored session does not contain its project file")
assert(not restored_paths[outside_file], "restored session contains the visible outside file")
assert(not restored_paths[hidden_outside_file], "restored session contains the hidden outside file")

print("ok: project sessions exclude outside files without changing live buffers")
