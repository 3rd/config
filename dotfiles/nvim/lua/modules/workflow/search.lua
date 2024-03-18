return lib.module.create({
  name = "workflows/search",
  plugins = {
    -- cword highlight
    {
      "tzachar/local-highlight.nvim",
      event = "VeryLazy",
      opts = {
        -- file_types = {},
        -- disable_file_types = { "tex" },
        hlgroup = "CWordHighlight",
        cw_hlgroup = nil,
        insert_mode = false,
      },
      config = function(_, opts)
        require("local-highlight").setup(opts)
        vim.api.nvim_create_autocmd("BufRead", {
          pattern = { "*.*" },
          callback = function(data)
            require("local-highlight").attach(data.buf)
          end,
        })
        require("local-highlight").attach(0)
      end,
    },
  },
})
