require("lib")

vim.opt.runtimepath:append(vim.fn.stdpath("data") .. "/lazy/blink.cmp")

local source = require("modules/completion/file-source").new()
local jobstart = vim.fn.jobstart
local jobstop = vim.fn.jobstop
local started_jobs = {}
local stopped_job = nil

vim.fn.jobstart = function(command, opts)
  local job_id = #started_jobs + 40
  started_jobs[#started_jobs + 1] = { id = job_id, command = command, opts = opts }
  return job_id
end
vim.fn.jobstop = function(job_id)
  stopped_job = job_id
  return 1
end

local responses = {}
local callback = function(response)
  responses[#responses + 1] = response
end

local hidden_context = {
  line = "plain text",
  pos = { row = 0, col = 10 },
  trigger = { initial_kind = "keyword" },
  providers = { "lsp", "files" },
}
local cancel = source:get_completions(hidden_context, callback)
assert(cancel == nil, "hidden file completion returned a cancellation function")
assert(#started_jobs == 0, "hidden file completion started a filesystem scan")
assert(#responses == 1 and #responses[1].items == 0, "hidden file completion did not finish empty")

responses = {}
local manual_context = {
  line = "plain text",
  pos = { row = 0, col = 10 },
  trigger = { initial_kind = "manual" },
  providers = { "files" },
}
cancel = source:get_completions(manual_context, callback)
assert(type(cancel) == "function", "manual file completion did not return a cancellation function")
assert(#started_jobs == 1, "manual file completion did not start one filesystem scan")

local manual_job = started_jobs[1]
cancel()
assert(stopped_job == manual_job.id, "file completion cancellation did not stop its filesystem scan")
manual_job.opts.on_stdout(manual_job.id, { "ignored.lua", "" })
manual_job.opts.on_exit(manual_job.id, 143)
assert(#responses == 0, "canceled file completion emitted a response")

responses = {}
local visible_context = {
  line = "@file",
  pos = { row = 0, col = 5 },
  trigger = { initial_kind = "keyword" },
  providers = { "lsp", "files" },
}
cancel = source:get_completions(visible_context, callback)
assert(type(cancel) == "function", "visible file completion did not return a cancellation function")
assert(#started_jobs == 2, "visible file completion did not start one filesystem scan")

local visible_job = started_jobs[2]
visible_job.opts.on_stdout(visible_job.id, { "file.lua", "" })
visible_job.opts.on_exit(visible_job.id, 0)
assert(#responses == 1, "visible file completion did not emit exactly one response")
assert(#responses[1].items == 1, "visible file completion did not return the scanned file")
assert(responses[1].items[1].label == "file.lua", "visible file completion changed the file label")

for _, case in ipairs({
  { line = "see @first and @src/ne later", col = 22, start_col = 16, end_col = 22 },
  { line = "@src/new.lua later", col = 7, start_col = 1, end_col = 12 },
  { line = "界 @src/ne", col = 11, start_col = 5, end_col = 11 },
}) do
  responses = {}
  source:get_completions({ line = case.line, pos = { row = 2, col = case.col } }, callback)
  local job = started_jobs[#started_jobs]
  job.opts.on_stdout(job.id, { "src/new.lua", "" })
  local item = responses[1].items[1]
  assert(item.sortText == "40_src/new.lua", "file completion must rank the reference under the cursor")
  assert(
    vim.deep_equal(item.textEdit, {
      newText = "src/new.lua",
      range = {
        start = { line = 2, character = case.start_col },
        ["end"] = { line = 2, character = case.end_col },
      },
    }),
    vim.inspect(item.textEdit)
  )
end
assert(not source:should_show_items({ line = "@first plain", pos = { row = 0, col = 12 } }))
assert(not source:should_show_items({ line = "name@example", pos = { row = 0, col = 12 } }))

responses = {}
vim.fn.jobstart = function()
  return -1
end
source:get_completions(visible_context, callback)
assert(#responses == 1 and #responses[1].items == 0, "failed file scan did not finish empty")

vim.fn.jobstart = jobstart
vim.fn.jobstop = jobstop

print("ok: file completion avoids hidden scans and cancels active scans")
