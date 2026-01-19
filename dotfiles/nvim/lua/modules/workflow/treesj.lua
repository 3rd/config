return lib.module.create({
  name = "treesj",
  hosts = "*",
  plugins = {
    {
      "Wansmer/treesj",
      dependencies = {
        { "nvim-treesitter/nvim-treesitter", branch = "master" },
      },
      opts = {
        use_default_keymaps = false,
        check_syntax_error = true,
        max_join_length = 150,
        cursor_behavior = "hold",
        notify = false,
        dot_repeat = false,
      },
    },
  },
  mappings = {
    {
      "n",
      "J",
      function()
        require("treesj").toggle()
      end,
      "Toggle join",
    },
  },
})
