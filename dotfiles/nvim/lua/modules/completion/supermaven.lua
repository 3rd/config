return lib.module.create({
  name = "completion/supermaven",
  enabled = false,
  plugins = {
    {
      -- "supermaven-inc/supermaven-nvim",
      "Hashiraee/supermaven-nvim",
      event = "VeryLazy",
      -- dir = lib.path.resolve(lib.env.dirs.vim.config, "plugins", "supermaven-nvim"),
      config = function()
        require("supermaven-nvim").setup({
          keymaps = {
            accept_suggestion = "<C-l>",
            clear_suggestion = "<C-]>",
          },
          ignore_filetypes = {
            dotenv = false,
            syslang = false,
            markdown = false,
          },
          color = {
            suggestion_color = "#ffffff",
            cterm = 244, -- "#ffffff",
          },
        })
      end,
    },
  },
})
