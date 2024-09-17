return lib.module.create({
  name = "code-action",
  hosts = "*",
  mappings = {
    {
      { "n", "v" },
      "<leader>ac",
      "<cmd>lua require('fzf-lua').lsp_code_actions()<CR>",
      { desc = "LSP: Code action" },
    },
  },
})
