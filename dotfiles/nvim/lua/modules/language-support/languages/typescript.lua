local filetypes = {
  "typescript",
  "typescriptreact",
  "javascript",
  "javascriptreact",
}

return lib.module.create({
  name = "language-support/languages/typescript",
  -- enabled = false,
  hosts = "*",
  plugins = {
    {
      "axelvc/template-string.nvim",
      ft = filetypes,
      opts = {},
    },
    {
      "marilari88/twoslash-queries.nvim",
      ft = filetypes,
      opts = {
        highlight = "Type",
        multi_line = true,
      },
    },
  },
  hooks = {
    lsp = {
      on_attach = function(client, bufnr)
        local code_action_kinds = vim.tbl_get(client.server_capabilities, "codeActionProvider", "codeActionKinds")
          or {}
        local source_actions = vim.tbl_filter(function(action)
          return vim.startswith(action, "source.")
        end, code_action_kinds)

        if #source_actions > 0 then
          vim.api.nvim_buf_create_user_command(bufnr, "LspTypescriptSourceAction", function()
            vim.lsp.buf.code_action({
              context = {
                only = source_actions,
              },
            })
          end, {})
        end

        local twoslash_clients = {
          "tsc",
          "tsgo",
          "vtsls",
          "ts_ls",
        }
        if not vim.tbl_contains(twoslash_clients, client.name) then return end
        require("twoslash-queries").attach(client, bufnr)
        lib.map.map(
          "n",
          "<leader>?",
          ":TwoslashQueriesInspect<CR>",
          { buffer = bufnr, desc = "Add type inspect comment" }
        )
      end,
    },
  },
})
