local setup = function()
  local treesitter = require("nvim-treesitter.configs")

  local parser_config = require("nvim-treesitter.parsers").get_parser_configs()
  parser_config.syslang = {
    install_info = {
      url = "~/brain/core/tree-sitter-syslang",
      files = { "src/parser.c", "src/scanner.cc" },
      generate_requires_npm = false,
      requires_generate_from_grammar = true,
    },
    filetype = "syslang",
  }

  local config = {
    ensure_installed = {
      "syslang",
      "astro",
      "bash",
      "c",
      "cpp",
      "css",
      "dockerfile",
      "fish",
      "go",
      "gomod",
      "graphql",
      "javascript",
      "json",
      "json5",
      "jsonc",
      "lua",
      "make",
      "nix",
      "python",
      "rust",
      "scss",
      "svelte",
      "toml",
      "tsx",
      "typescript",
      "v",
      "vim",
      "vue",
      "yaml",
      "zig",
    },
    highlight = {
      enable = true,
    },
    incremental_selection = {
      enable = true,
      keymaps = {
        init_selection = "<cr>",
        node_incremental = "<cr>",
        node_decremental = "<bs>",
        scope_incremental = "<nop>",
      },
    },
    autotag = {
      enable = false,
    },
    matchup = {
      enable = true,
    },
  }

  treesitter.setup(config)

  require("hlargs").setup()
end

return require("lib").module.create({
  name = "language-support/tree-sitter",
  plugins = {
    {
      "nvim-treesitter/nvim-treesitter",
      requires = {
        "nvim-treesitter/playground",
        "windwp/nvim-ts-autotag",
        "m-demare/hlargs.nvim",
      },
      config = setup,
    },
  },
})
