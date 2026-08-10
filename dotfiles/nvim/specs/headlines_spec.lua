require("lib")

vim.opt.runtimepath:append(vim.fn.stdpath("data") .. "/lazy/headlines.nvim")

local bufnr = vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
  "# Heading",
  "",
  "  @code tsx",
  "  const callback = (id, phase, actualDuration, baseDuration, startTime, commitTime, interactions) => {",
  "    console.log(id)",
  "  }",
  "  @end",
})
vim.bo[bufnr].filetype = "syslang"

local get_node_text = vim.treesitter.get_node_text
vim.treesitter.get_node_text = function()
  return ""
end

require("modules/ui/headlines").plugins[1].config()
vim.treesitter.get_node_text = get_node_text

local config = require("headlines").config
for _, filetype in ipairs({ "markdown", "rmd", "norg", "org" }) do
  assert(config[filetype].query == false, filetype .. " headlines query is still active")
end
assert(config.syslang.codeblock_highlight == false, "headlines.nvim still owns Syslang code blocks")

assert(vim.tbl_isempty(vim.b[bufnr].syslang_headline_gutter_rows), "empty headline capture produced gutter rows")
assert(_G.SyslangHeadlineGutterRows == nil, "Syslang headline rows leaked into global state")

local namespace = vim.api.nvim_get_namespaces().syslang_render
local get_syslang_render = function()
  local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, namespace, 0, -1, { details = true })
  local codeblock_background = nil
  local codeblock_background_row = nil
  local codeblock_padding = {}

  for _, extmark in ipairs(extmarks) do
    local details = extmark[4]
    if details.hl_group == "CodeBlock" then
      codeblock_background = details
      codeblock_background_row = extmark[2]
    elseif details.virt_text and details.virt_text[1][2] == "Normal" then
      codeblock_padding[#codeblock_padding + 1] = details
    end
  end

  return extmarks, codeblock_background, codeblock_background_row, codeblock_padding
end

local extmarks, codeblock_background, codeblock_background_row, codeblock_padding = get_syslang_render()
assert(codeblock_background, "Syslang code block has no background extmark")
assert(
  codeblock_background_row == 3 and codeblock_background.end_row == 6,
  string.format(
    "Syslang code block background covers rows %d-%d instead of rows 3-6",
    codeblock_background_row,
    codeblock_background.end_row
  )
)
assert(codeblock_background.hl_eol, "Syslang code block background does not cover line ends")
assert(#codeblock_padding > 0, "Syslang code block has no inset extmarks")

for _, details in ipairs(codeblock_padding) do
  assert(details.virt_text[1][1] == "  ", "Syslang code block inset does not match its whitespace prefix")
  assert(details.virt_text_win_col == 0, "Syslang code block inset is not fixed to the first text column")
  assert(details.virt_text_repeat_linebreak, "Syslang code block inset does not repeat on wrapped lines")
end

local initial_changedtick = vim.api.nvim_buf_get_changedtick(bufnr)
assert(
  vim.b[bufnr].syslang_headline_render_changedtick == initial_changedtick,
  "initial Syslang render did not cache its changedtick"
)

vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
vim.api.nvim_exec_autocmds("TextChanged", { buffer = bufnr })
vim.api.nvim_exec_autocmds("TextChangedI", { buffer = bufnr })
assert(vim.b[bufnr].syslang_headline_render_scheduled == nil, "unchanged text events scheduled a redundant render")
assert(#get_syslang_render() == 0, "unchanged text events rendered an unchanged changedtick")

vim.api.nvim_exec_autocmds("BufEnter", { buffer = bufnr })
extmarks, codeblock_background, codeblock_background_row = get_syslang_render()
assert(#extmarks > 0, "forced BufEnter did not restore Syslang rendering")
assert(codeblock_background, "forced BufEnter did not restore the code-block background")
assert(
  codeblock_background_row == 3 and codeblock_background.end_row == 6,
  "forced BufEnter changed the body-only code-block range"
)
assert(
  vim.b[bufnr].syslang_headline_render_changedtick == initial_changedtick,
  "forced BufEnter did not preserve the rendered changedtick"
)

vim.api.nvim_buf_set_lines(bufnr, 6, 6, false, { "  return callback" })
local changedtick = vim.api.nvim_buf_get_changedtick(bufnr)
assert(changedtick > initial_changedtick, "buffer edit did not advance changedtick")

local defer_fn = vim.defer_fn
local deferred = {}
vim.defer_fn = function(callback, timeout)
  deferred[#deferred + 1] = { callback = callback, timeout = timeout }
end

vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
vim.api.nvim_exec_autocmds("TextChanged", { buffer = bufnr })
assert(vim.b[bufnr].syslang_headline_render_scheduled == true, "changed text did not schedule rendering")
vim.api.nvim_exec_autocmds("TextChangedI", { buffer = bufnr })
assert(vim.b[bufnr].syslang_headline_render_scheduled == true, "insert text did not schedule rendering")
assert(#deferred == 2, "text events did not schedule their render transitions")
assert(deferred[1].timeout == 0, "normal text rendering was unexpectedly delayed")
assert(deferred[2].timeout > 0, "insert text rendering was not debounced")
assert(
  vim.b[bufnr].syslang_headline_render_changedtick == initial_changedtick,
  "scheduled rendering ran before the event-loop transition"
)

deferred[1].callback()
assert(vim.b[bufnr].syslang_headline_render_scheduled == true, "stale rendering cleared the latest request")
assert(
  vim.b[bufnr].syslang_headline_render_changedtick == initial_changedtick,
  "stale rendering reached the edited changedtick"
)

deferred[2].callback()
assert(vim.b[bufnr].syslang_headline_render_scheduled == nil, "debounced rendering remained scheduled")
assert(
  vim.b[bufnr].syslang_headline_render_changedtick == changedtick,
  "debounced Syslang rendering did not reach the edited changedtick"
)

extmarks, codeblock_background, codeblock_background_row = get_syslang_render()
assert(#extmarks > 0, "scheduled rendering did not restore extmarks")
assert(codeblock_background, "scheduled rendering did not restore the code-block background")
assert(
  codeblock_background_row == 3 and codeblock_background.end_row == 7,
  "scheduled rendering did not update the body-only code-block range"
)

vim.api.nvim_buf_set_lines(bufnr, 7, 7, false, { "  final line" })
local insert_changedtick = vim.api.nvim_buf_get_changedtick(bufnr)
deferred = {}
vim.api.nvim_exec_autocmds("TextChangedI", { buffer = bufnr })
assert(#deferred == 1 and deferred[1].timeout > 0, "insert edit did not create one debounced render")
assert(vim.b[bufnr].syslang_headline_render_scheduled == true, "insert edit was not pending")

vim.api.nvim_exec_autocmds("InsertLeave", { buffer = bufnr })
assert(vim.b[bufnr].syslang_headline_render_scheduled == nil, "InsertLeave did not clear the pending render")
assert(
  vim.b[bufnr].syslang_headline_render_changedtick == insert_changedtick,
  "InsertLeave did not render the latest changedtick"
)

vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
deferred[1].callback()
assert(#get_syslang_render() == 0, "canceled insert rendering ran after InsertLeave")
vim.defer_fn = defer_fn

print("ok: Syslang headline and wrapped code-block rendering")
