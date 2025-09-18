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
                  name = "references_with_warning",
                  event = { "LspAttach", "BufWritePost" },
                  handler = function(bufnr, func_info, provider_config, callback)
                    local filename = vim.api.nvim_buf_get_name(bufnr)
                    if
                      --
                      filename:match("%.test%.")
                      or filename:match("%.spec%.")
                      or filename:match("_test%.")
                    then
                      callback(nil)
                      return
                    end

                    local utils = require("lensline.utils")
                    utils.get_lsp_references(bufnr, func_info, function(references)
                      if references then
                        local count = #references
                        local icon, text
                        if count == 0 then
                          icon = utils.if_nerdfont_else("⛺ ", "WARN ")
                          text = icon .. "noref"
                        else
                          icon = utils.if_nerdfont_else("󰌹 ", "")
                          local suffix = utils.if_nerdfont_else("", " refs")
                          text = icon .. count .. suffix
                        end
                        callback({ line = func_info.line, text = text })
                      else
                        callback(nil)
                      end
                    end)
                  end,
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
                -- {
                --   name = "references",
                --   enabled = true,
                --   quiet_lsp = true,
                -- },
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
            exclude_gitignored = false,
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
