return lib.module.create({
  name = "dashboard",
  enabled = false,
  plugins = {
    {
      "goolord/alpha-nvim",
      lazy = false,
      dependencies = { "nvim-tree/nvim-web-devicons" },
      config = function()
        local alpha = require("alpha")
        local startify = require("alpha.themes.startify")

        startify.section.header.val = ([[


 ██▀███   ▄▄▄       ▄▄▄▄    ▄▄▄▄    ██▓▄▄▄█████▓
▓██ ▒ ██▒▒████▄    ▓█████▄ ▓█████▄ ▓██▒▓  ██▒ ▓▒
▓██ ░▄█ ▒▒██  ▀█▄  ▒██▒ ▄██▒██▒ ▄██▒██▒▒ ▓██░ ▒░
▒██▀▀█▄  ░██▄▄▄▄██ ▒██░█▀  ▒██░█▀  ░██░░ ▓██▓ ░   (~\       _
░██▓ ▒██▒ ▓█   ▓██▒░▓█  ▀█▓░▓█  ▀█▓░██░  ▒██▒ ░    \ \     / \
░ ▒▓ ░▒▓░ ▒▒   ▓▒█░░▒▓███▀▒░▒▓███▀▒░▓    ▒ ░░       \ \___/ /\\
  ░▒ ░ ▒░  ▒   ▒▒ ░▒░▒   ░ ▒░▒   ░  ▒ ░    ░         | , , |  ~
  ░░   ░   ░   ▒    ░    ░  ░    ░  ▒ ░  ░           ( =v= )
   ░           ░  ░ ░       ░       ░                 ` ^ '
                         ░       ░
]]):split("\n")

        startify.opts.layout[1].val = 2
        startify.opts.opts.margin = 43

        startify.section.top_buttons.val = {
          startify.button("e", " > New file", "<cmd>ene<CR>"),
          startify.button("f", " > Find file", "<cmd>FzfLua files<CR>"),
          startify.button("-", " > File explorer", "<cmd>NvimTreeToggle<CR>"),
        }
        startify.section.mru.val = { { type = "padding", val = 0 } }

        alpha.setup(startify.config)

        vim.cmd([[autocmd FileType alpha setlocal nofoldenable]])
      end,
    },
  },
})
