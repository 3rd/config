require("lib")
require("modules/agents/rfc").setup()

local prompts = 0
local annotation_prompts = 0
local answer = 2
vim.fn.confirm = function(message, choices, default)
  assert(choices == "&Yes\n&No" and default == 2)
  if message == "Annotations have not been burned. Exit and discard them?" then
    annotation_prompts = annotation_prompts + 1
  else
    assert(message:find("Exit without changing it?", 1, true))
    prompts = prompts + 1
  end
  return answer
end

local open_buffer = function(path)
  vim.cmd.enew({ bang = true })
  vim.api.nvim_buf_set_name(0, path)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "# Example RFC" })
  vim.bo.modified = false
  vim.api.nvim_exec_autocmds("BufReadPost", { buffer = 0 })
  return vim.api.nvim_get_current_buf()
end

local check_exit = function()
  local window = vim.api.nvim_get_current_win()
  local buffer = vim.api.nvim_get_current_buf()
  local windows = #vim.api.nvim_list_wins()
  vim.api.nvim_exec_autocmds("ExitPre", {})
  assert(vim.api.nvim_get_current_buf() == buffer and #vim.api.nvim_list_wins() == windows)
  return vim.api.nvim_win_is_valid(window)
end

local rfc = open_buffer("/tmp/agents-rfc/exit-confirmation-test.md")
assert(not check_exit(), "unchanged RFC must cancel exit when No is chosen")
assert(prompts == 1)
answer = 0
assert(not check_exit(), "dismissing confirmation must cancel exit")
answer = 1
assert(check_exit(), "Yes must allow an unchanged RFC to close")

vim.api.nvim_buf_set_lines(rfc, 0, -1, false, { "# Revised RFC" })
local before = prompts
assert(check_exit() and prompts == before, "edited RFC must not prompt")
vim.bo.modified = false
assert(check_exit() and prompts == before, "saved edits must not prompt")
vim.api.nvim_exec_autocmds("BufReadPost", { buffer = rfc })
assert(check_exit() and prompts == before, "rereading must not reset the opening contents")

vim.api.nvim_buf_set_lines(rfc, 0, -1, false, { "# Example RFC" })
vim.bo.modified = false
answer = 2
open_buffer("/tmp/unrelated-rfc.md")
assert(not check_exit(), "unchanged hidden RFC must still prompt")
vim.api.nvim_buf_delete(rfc, { force = true })
before = prompts
assert(check_exit() and prompts == before, "unrelated Markdown must not prompt")
open_buffer("/tmp/agents-rfc/nested/example.md")
assert(check_exit() and prompts == before, "nested paths must not match")
open_buffer("/tmp/agents-rfc/example.txt")
assert(check_exit() and prompts == before, "non-Markdown files must not prompt")

local annotations = require("modules/workflow/annotations")
annotations.setup()
local add_annotation = function(comment)
  local source = vim.api.nvim_get_current_buf()
  annotations.mappings[1][3]()
  assert(
    vim.wait(1000, function()
      return vim.api.nvim_get_current_buf() ~= source
    end),
    "annotation prompt did not complete"
  )
  vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(comment, "\n", { plain = true }))
  vim.cmd.write()
end

local unrelated = vim.api.nvim_get_current_buf()
add_annotation("Keep this annotation virtual")
assert(not check_exit() and annotation_prompts == 1, "non-RFC annotations must prompt and No must cancel exit")
answer = 0
assert(not check_exit() and annotation_prompts == 2, "dismissing the annotation prompt must cancel exit")
answer = 1
assert(check_exit() and annotation_prompts == 3, "Yes must allow exit with non-RFC annotations")
assert(annotations.exports.count() == 1, "exit confirmation must not burn annotations")
assert(vim.deep_equal(vim.api.nvim_buf_get_lines(unrelated, 0, -1, false), { "# Example RFC" }))
assert(not vim.bo[unrelated].modified, "exit confirmation must not modify the source buffer")
local directory = "/tmp/agents-rfc"
vim.fn.mkdir(directory, "p")
local path = directory .. "/agents-rfc-test-" .. vim.fn.getpid() .. "-" .. vim.uv.hrtime() .. ".md"
local annotated = open_buffer(path)
add_annotation("Clarify this proposal")
vim.api.nvim_set_current_buf(unrelated)
assert(check_exit() and prompts == before, "hidden annotated RFC must save without confirmation")
assert(annotation_prompts == 4, "mixed buffers must still prompt for non-RFC annotations")
local expected = {
  "# Example RFC",
  "<annotation>",
  "<original>",
  "# Example RFC",
  "</original>",
  "<comment>",
  "Clarify this proposal",
  "</comment>",
  "</annotation>",
}
assert(vim.deep_equal(vim.fn.readfile(path), expected), "RFC annotations must be saved to disk")
assert(not vim.bo[annotated].modified)
assert(annotations.exports.count() == 1, "unrelated annotations must remain virtual")
assert(check_exit() and prompts == before, "a second exit must not duplicate burned annotations")
assert(vim.deep_equal(vim.fn.readfile(path), expected))

vim.api.nvim_set_current_buf(annotated)
answer = 2
assert(not check_exit() and annotation_prompts == 6, "hidden non-RFC annotations must cancel exit")
vim.api.nvim_buf_delete(unrelated, { force = true })
assert(check_exit() and annotation_prompts == 6, "removed annotations must not prompt")
add_annotation("Save this after fixing permissions")
vim.bo.readonly = true
local notify = vim.notify
local failure
vim.notify = function(message)
  failure = message
end
assert(not check_exit(), "failed annotation save must cancel exit")
assert(failure:find("readonly", 1, true), failure)
assert(vim.deep_equal(vim.fn.readfile(path), expected), "failed save must leave disk contents intact")
local burned = vim.api.nvim_buf_get_lines(annotated, 0, -1, false)
vim.bo.readonly = false
assert(check_exit() and prompts == before, "next exit must retry the failed save without another burn")
assert(vim.deep_equal(vim.fn.readfile(path), burned), "retry must persist the burned annotations")
vim.notify = notify
vim.api.nvim_buf_delete(annotated, { force = true })
assert(vim.fn.delete(path) == 0)

print("ok: agents RFC exit confirmation covers unchanged, edited, saved, restored, hidden, and unrelated buffers")
print("ok: RFC exit burns and saves buffer-local annotations, skips confirmation, and retries failed saves")
print("ok: non-RFC annotations confirm exit, cancel on No or dismissal, and remain virtual")
