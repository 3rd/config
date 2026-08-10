require("lib")

local handler = nil
package.loaded.async = function() end
package.loaded.ufo = {
  setup = function(config)
    handler = config.fold_virt_text_handler
  end,
  closeAllFolds = function() end,
}

require("modules/workflow/folds").plugins[1].config()
assert(handler, "nvim-ufo did not receive a fold virtual text handler")

local create_syslang_buffer = function(lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].filetype = "syslang"
  return bufnr
end

local render_fold = function(bufnr, start_line, end_line)
  local chunks = handler({ { "* Fold", "Normal" } }, start_line, end_line, 100, function(text, width)
    return text:sub(1, width)
  end, { bufnr = bufnr, winid = 0 })

  local text = ""
  for _, chunk in ipairs(chunks) do
    text = text .. chunk[1]
  end
  return text
end

local primary_bufnr = create_syslang_buffer({
  "[ ] Compact session",
  "  Session: 2026.08.09 10:00-11:30",
  "[x] Cross-date session",
  "  Session: 2026.08.09 23:00 - 2026.08.10 01:00",
})
local secondary_bufnr = create_syslang_buffer({
  "[ ] Secondary session",
  "  Session: 2026.08.09 08:00-08:30",
  "secondary note",
})
vim.api.nvim_buf_set_lines(secondary_bufnr, 2, 3, false, { "changed secondary note" })

assert(
  vim.api.nvim_buf_line_count(primary_bufnr) ~= vim.api.nvim_buf_line_count(secondary_bufnr),
  "test buffers must have different line counts"
)
assert(
  vim.api.nvim_buf_get_changedtick(primary_bufnr) ~= vim.api.nvim_buf_get_changedtick(secondary_bufnr),
  "test buffers must have different changedticks"
)

local parser_requests = {}
local get_parser = vim.treesitter.get_parser
vim.treesitter.get_parser = function(bufnr, ...)
  parser_requests[bufnr] = (parser_requests[bufnr] or 0) + 1
  return get_parser(bufnr, ...)
end

vim.api.nvim_set_current_buf(secondary_bufnr)
local compact = render_fold(primary_bufnr, 0, 2)
assert(compact:find("0/1", 1, true), compact)
assert(compact:find("1h30m", 1, true), compact)
assert(parser_requests[primary_bufnr] == 1, "initial fold metadata was not parsed")

local compact_cached = render_fold(primary_bufnr, 0, 2)
assert(compact_cached == compact, "identical fold range did not reuse its metadata")
assert(parser_requests[primary_bufnr] == 1, "identical fold range missed the metadata cache")

local cross_date = render_fold(primary_bufnr, 2, 4)
assert(cross_date:find("1/1", 1, true), cross_date)
assert(cross_date:find("2h", 1, true), cross_date)
assert(parser_requests[primary_bufnr] == 2, "different fold range reused cached metadata")

local secondary = render_fold(secondary_bufnr, 0, 2)
assert(secondary:find("30m", 1, true), secondary)
assert(parser_requests[secondary_bufnr] == 1, "different buffer reused cached metadata")

vim.api.nvim_buf_set_lines(primary_bufnr, 0, 1, false, { "[x] Compact session" })
local compact_updated = render_fold(primary_bufnr, 0, 2)
assert(compact_updated:find("1/1", 1, true), compact_updated)
assert(parser_requests[primary_bufnr] == 3, "changedtick did not invalidate cached metadata")

local large_lines = { "[ ] Large-buffer task" }
for index = 2, 200 do
  large_lines[index] = "large line " .. index
end
local large_bufnr = create_syslang_buffer(large_lines)

vim.api.nvim_set_current_buf(primary_bufnr)
local large = render_fold(large_bufnr, 0, 200)
assert(large:find("0/1", 1, true), large)
assert(parser_requests[large_bufnr] == nil, "large buffer did not preserve the line-scanning fallback")

vim.treesitter.get_parser = get_parser

print("ok: Syslang fold metadata is buffer-local, range-cached, and duration-complete")
