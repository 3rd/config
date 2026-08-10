require("lib")

vim.opt.runtimepath:append(vim.fn.stdpath("data") .. "/lazy/hlchunk.nvim")

local bufnr = vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
  "  {",
  "    first wrapped line",
  "    second wrapped line",
  "  }",
})
vim.bo[bufnr].filetype = "syslang"
vim.bo[bufnr].shiftwidth = 2

local hlchunk = require("hlchunk")
local setup = hlchunk.setup
local configured_opts = nil
hlchunk.setup = function(opts)
  configured_opts = opts
  return setup(opts)
end
require("modules/ui/indent-guides").plugins[1].config()
hlchunk.setup = setup

assert(configured_opts.chunk.delay > 0, "hlchunk context rendering is not debounced")

local indent_namespace = vim.api.nvim_get_namespaces().indent
local indent_extmarks = vim.api.nvim_buf_get_extmarks(bufnr, indent_namespace, 0, -1, { details = true })
local indent_priority = nil

for _, extmark in ipairs(indent_extmarks) do
  local details = extmark[4]
  assert(details.virt_text_repeat_linebreak, "Syslang indent guide does not repeat on wrapped lines")
  indent_priority = details.priority
end

assert(indent_priority, "hlchunk did not create a Syslang indent guide")

local chunk_mod = require("hlchunk.mods.chunk")({
  enable = true,
  use_treesitter = false,
  delay = configured_opts.chunk.delay,
  duration = configured_opts.chunk.duration,
})
local scope = require("hlchunk.utils.scope")(bufnr, 0, 3)
chunk_mod:render(scope, { error = false, lazy = true })

local chunk_extmarks = vim.api.nvim_buf_get_extmarks(bufnr, chunk_mod.meta.ns_id, 0, -1, { details = true })
local vertical_segments = 0

for _, extmark in ipairs(chunk_extmarks) do
  local details = extmark[4]
  if details.virt_text[1][1] == chunk_mod.conf.chars.vertical_line then
    vertical_segments = vertical_segments + 1
    assert(details.virt_text_repeat_linebreak, "Syslang context guide does not repeat on wrapped lines")
    assert(details.priority > indent_priority, "Syslang context guide does not render above indent guides")
  else
    assert(not details.virt_text_repeat_linebreak, "Syslang context corner repeats on wrapped lines")
  end
end

assert(vertical_segments > 0, "hlchunk did not create a vertical Syslang context guide")

print("ok: Syslang indent and context guides repeat with the correct priority")
