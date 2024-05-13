return lib.module.create({
  name = "workflow/bullets",
  -- enabled = false,
  hosts = "*",
  plugins = {
    {
      "hupfdule/bullets.vim",
      commit = "fdcc2d1abe3213eee182a513dbb69b5cc2be2216",
      ft = { "markdown", "syslang" },
      init = function()
        vim.g.bullets_enabled_file_types = { "markdown", "syslang", "text", "gitcommit", "scratch" }
        vim.g.bullets_set_mappings = 0
        vim.g.bullets_nested_checkboxes = 0
        vim.g.bullets_list_item_styles = { "-", "\\[ \\]" }
        -- vim.g.bullets_outline_levels = { "num", "abc", "std-" }

        -- mappings
        vim.api.nvim_create_autocmd("FileType", {
          group = vim.api.nvim_create_augroup("bullets", {}),
          pattern = { "markdown", "syslang" },
          callback = function()
            vim.keymap.set("n", "o", ":InsertNewBullet<CR>", { buffer = true })
            vim.keymap.set("n", "gN", ":RenumberList<CR>", { buffer = true })
            vim.keymap.set("v", "gN", function()
              vim.cmd("RenumberList")
            end, { buffer = true })
            vim.keymap.set("i", "<cr>", function()
              vim.cmd("InsertNewBullet")
            end, { buffer = true })
          end,
        })
      end,
    },
  },
})
