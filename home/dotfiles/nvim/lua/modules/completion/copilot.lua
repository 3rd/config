vim.g.copilot_no_tab_map = true
vim.g.copilot_assume_mapped = true
vim.g.copilot_tab_fallback = ""

local enabled = false

if enabled then
  vim.g.copilot_filetypes = {
    ["*"] = false,
    lua = true,
    nix = true,
    go = true,
    rust = true,
    sh = true,
    typescript = true,
    typescriptreact = true,
    javascript = true,
    javascriptreact = true,
    html = true,
    vue = true,
    css = true,
    scss = true,
    astro = true,
    mdx = true,
  }
else
  vim.g.copilot_filetypes = { ["*"] = false }
end

return require("lib").module.create({
  name = "completion/copilot",
  plugins = {
    { "github/copilot.vim" },
  },
})
