return lib.module.create({
  name = "completion/supermaven",
  enabled = false,
  hosts = { "spaceship", "macbook" },
  plugins = {
    {
      "supermaven-inc/supermaven-nvim",
      -- "Hashiraee/supermaven-nvim",
      event = "VeryLazy",
      -- dir = lib.path.resolve(lib.env.dirs.vim.config, "plugins", "supermaven-nvim"),
      config = function()
        require("supermaven-nvim").setup({
          keymaps = {
            accept_suggestion = "<C-l>",
            clear_suggestion = "<C-]>",
          },
          ignore_filetypes = {
            dotenv = true,
            syslang = true,
            markdown = true,
            help = true,
            gitcommit = true,
            gitrebase = true,
            gitstatus = true,
            yaml = true,
            toml = true,
            json = true,
            text = true,
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
