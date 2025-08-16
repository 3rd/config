return lib.module.create({
  name = "workflow/search",
  hosts = "*",
  plugins = {
    -- cword highlight
    {
      "tzachar/local-highlight.nvim",
      event = "VeryLazy",
      enabled = false,
      opts = {
        -- file_types = {},
        -- disable_file_types = { "tex" },
        -- hlgroup = "CWordHighlight",
        -- cw_hlgroup = nil,
        -- insert_mode = false,
        animate = {
          enabled = false,
        },
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
    {
      "MagicDuck/grug-far.nvim",
      opts = { headerMaxWidth = 80 },
      cmd = "GrugFar",
      keys = {
        {
          "<C-S-f>",
          function()
            local grug = require("grug-far")
            local ext = vim.bo.buftype == "" and vim.fn.expand("%:e")
            grug.open({
              transient = true,
              prefills = {
                filesFilter = ext and ext ~= "" and "*." .. ext or nil,
              },
            })
          end,
          mode = { "n", "v" },
          desc = "Search and Replace",
        },
      },
    },
  },
})
