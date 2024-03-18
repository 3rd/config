return lib.module.create({
  name = "completion/codeium",
  enabled = false,
  plugins = {
    {
      "Exafunction/codeium.vim",
      event = "VeryLazy",
      config = function()
        vim.g.codeium_disable_bindings = 1
        vim.g.codeium_filetypes = {
          dotenv = false,
          markdown = false,
          syslang = false,
        }

        vim.keymap.set("i", "<c-l>", function()
          return vim.fn["codeium#Accept"]()
        end, { expr = true, silent = true })
        vim.keymap.set("i", "<c-right>", function()
          return vim.fn["codeium#CycleCompletions"](1)
        end, { expr = true, silent = true })
        vim.keymap.set("i", "<c-left>", function()
          return vim.fn["codeium#CycleCompletions"](-1)
        end, { expr = true, silent = true })
      end,
    },
  },
})
