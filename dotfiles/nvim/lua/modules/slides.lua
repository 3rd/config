return lib.module.create({
  name = "slides",
  hosts = "*",
  plugins = {
    {
      "sotte/presenting.nvim",
      ft = { "markdown" },
      config = function()
        require("presenting").setup({})

        Presenting.config = {
          options = {
            -- get all available width
            width = vim.o.columns,
          },
          separator = {
            markdown = "^---$",
          },
          keep_separator = true,
          keymaps = {
            n = nil,
            p = nil,
            f = nil, -- Presenting.first()
            l = nil, -- Presenting.last()
            ["<CR>"] = function()
              Presenting.next()
            end,
            ["<Right>"] = function()
              Presenting.next()
            end,
            ["<Left>"] = function()
              Presenting.prev()
            end,
            ["<BS>"] = function()
              Presenting.prev()
            end,
            ["Q"] = function()
              Presenting.quit()
            end,
          },
          configure_slide_buffer = Presenting.config.configure_slide_buffer,
        }
      end,
    },
    cmd = { "Presenting" },
  },
})
