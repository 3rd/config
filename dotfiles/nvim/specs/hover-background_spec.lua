require("lib")
for _, plugin in ipairs({ "noice.nvim", "nui.nvim" }) do
  vim.opt.runtimepath:prepend(vim.fn.stdpath("data") .. "/lazy/" .. plugin)
end

vim.cmd.colorscheme("static")
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "const label = 'example';" })
vim.bo.filetype = "typescript"
require("modules.ui.noice").plugins[1].config()
if vim.v.vim_did_enter == 0 then vim.api.nvim_exec_autocmds("VimEnter", {}) end
assert(vim.wait(1000, require("noice.config").is_running))

require("noice.lsp.hover").on_hover(nil, {
  contents = { kind = "markdown", value = "```typescript\nconst label: string\n```" },
}, { bufnr = vim.api.nvim_get_current_buf() })
assert(vim.wait(1000, function()
  return #vim.api.nvim_list_wins() == 3
end))

local background = vim.api.nvim_get_hl(0, { name = "Normal" }).bg
for _, win in ipairs(vim.api.nvim_list_wins()) do
  if vim.api.nvim_win_get_config(win).relative ~= "" then
    local normal = vim.wo[win].winhighlight:match("Normal:([^,]+)")
    assert(normal, "hover content and border windows must both set their background")
    assert(vim.api.nvim_get_hl(0, { name = normal }).bg == background, "hover background must match the editor")
  end
end

require("noice").disable()
print("ok: hover content and rounded border share the editor background")
