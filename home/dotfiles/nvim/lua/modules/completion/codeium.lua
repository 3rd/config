return lib.module.create({
  enabled = false,
  name = "codeium",
  plugins = {
    {
      "Exafunction/codeium.vim",
      event = { "InsertEnter" },
      init = function()
        vim.g.codeium_enabled = 1
        vim.g.codeium_disable_bindings = 1
        vim.g.codeium_idle_delay = 50
        vim.g.codeium_telemetry = false
      end,
      config = function()
        vim.keymap.set("i", "<tab>", function()
          return vim.fn["codeium#Accept"]()
        end, { expr = true })
        vim.keymap.set("i", "<c-left>", function()
          return vim.fn["codeium#CycleCompletions"](-1)
        end, { expr = true })
        vim.keymap.set("i", "<c-right>", function()
          return vim.fn["codeium#CycleCompletions"](1)
        end, { expr = true })
        vim.keymap.set("i", "<c-]>", function()
          return vim.fn["codeium#Clear"]()
        end, { expr = true })

        vim.api.nvim_set_hl(0, "CodeiumSuggestion", { link = "Comment" })
      end,
    },
  },
})
