return lib.module.create({
  name = "lens",
  hosts = "*",
  plugins = {
    {
      "oribarilan/lensline.nvim",
      event = "VeryLazy",
      config = function()
        require("lensline").setup({
          profiles = {
            {
              name = "default",
              providers = {
                {
                  name = "references",
                  enabled = true,
                  quiet_lsp = true,
                },
                {
                  name = "last_author",
                  enabled = true,
                  cache_max_files = 50,
                },
                {
                  name = "diagnostics",
                  enabled = false,
                  min_level = "WARN",
                },
                {
                  name = "complexity",
                  enabled = false,
                  min_level = "L",
                },
              },
              style = {
                separator = " • ",
                highlight = "Lens",
                prefix = " ",
                placement = "inline",
                use_nerdfont = true,
                render = "all", -- "all" | "focused"
              },
            },
          },
          limits = {
            exclude = {},
            exclude_gitignored = true,
            max_lines = 2000,
            max_lenses = 200,
          },
          debounce_ms = 300,
          focused_debounce_ms = 100,
          debug_mode = false,
        })
      end,
    },
  },
})
