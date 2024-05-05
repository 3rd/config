return lib.module.create({
  name = "completion/codeium",
  -- enabled = false,
  plugins = {
    {
      "Exafunction/codeium.vim",
      event = "VeryLazy",
      config = function()
        vim.g.codeium_enabled = false
        vim.g.codeium_filetypes = {
          dotenv = false,
          markdown = false,
          syslang = false,
        }
        vim.g.codeium_idle_delay = 75
        vim.g.codeium_render = true
        vim.g.codeium_disable_bindings = 1

        vim.keymap.set("i", "<c-l>", function()
          return vim.fn["codeium#Accept"]()
        end, { expr = true, silent = true })
        vim.keymap.set("i", "<c-right>", function()
          return vim.fn["codeium#CycleCompletions"](1)
        end, { expr = true, silent = true })
        vim.keymap.set("i", "<c-left>", function()
          return vim.fn["codeium#CycleCompletions"](-1)
        end, { expr = true, silent = true })
        vim.keymap.set("n", "<F12>", function()
          return vim.cmd(":CodeiumToggle")
        end, { expr = true, silent = true })
      end,
    },
  },
})
