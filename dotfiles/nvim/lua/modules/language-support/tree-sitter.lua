local config = {
  ensure_installed = {
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
    "markdown",
    "markdown_inline",
    "nix",
    "prisma",
    "python",
    "query",
    "rust",
    "scss",
    "svelte",
    "syslang",
    "toml",
    "tsx",
    "typescript",
    "v",
    "vim",
    "vimdoc",
    "vue",
    "yaml",
    "zig",
  },
  highlight = {
    enable = true,
    disable = function(lang, buf)
      -- bash injections, fucked again after https://github.com/neovim/neovim/issues/27078
      for _, l in ipairs({ "bash" }) do
        if lang == l then return true end
      end

      local max_filesize = 1024 * 1024
      local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
      if ok and stats and stats.size > max_filesize then
        log("tree-sitter disabled due to large file")
        return true
      end
      -- lush
      --   local text = lib.buffer.get_text(buf)
      --   if string.includes(text, "lush%(function") then return true end
      --   return false
    end,
  },
  indent = {
    enable = false,
  },
  playground = {
    enable = true,
    disable = {},
    updatetime = 25,
    persist_queries = true,
    keybindings = {
      toggle_query_editor = "o",
      toggle_hl_groups = "i",
      toggle_injected_languages = "t",
      toggle_anonymous_nodes = "a",
      toggle_language_display = "I",
      focus_language = "f",
      unfocus_language = "F",
      update = "R",
      goto_node = "<cr>",
      show_help = "?",
    },
  },
  query_linter = {
    enable = true,
    use_virtual_text = true,
    lint_events = { "BufWrite", "CursorHold" },
  },
  incremental_selection = {
    enable = false,
    keymaps = {
      init_selection = "<cr>",
      node_incremental = "<cr>",
      node_decremental = "<bs>",
      scope_incremental = false,
    },
  },
}

local setup_treesitter = function()
  local treesitter = require("nvim-treesitter.configs")

  local parser_config = require("nvim-treesitter.parsers").get_parser_configs()
  parser_config.syslang = {
    install_info = {
      url = "~/brain/core/syslang/tree-sitter-syslang",
      files = { "src/parser.c", "src/scanner.cc" },
      generate_requires_npm = false,
      requires_generate_from_grammar = true,
    },
    filetype = "syslang",
  }

  treesitter.setup(config)

  -- only enable folds for selected grammars
  local grammars_with_folds_enabled = { "syslang", "markdown" }
  for grammar in pairs(parser_config) do
    if not vim.tbl_contains(grammars_with_folds_enabled, grammar) then
      pcall(vim.treesitter.query.set, grammar, "folds", "")
    end
  end
end

return lib.module.create({
  name = "language-support/tree-sitter",
  plugins = {
    {
      "nvim-treesitter/nvim-treesitter",
      event = { "BufReadPre", "BufNewFile" },
      dependencies = { "nvim-treesitter/playground" },
      build = ":TSUpdate",
      config = setup_treesitter,
    },
    {
      "sustech-data/wildfire.nvim",
      event = "VeryLazy",
      dependencies = { "nvim-treesitter/nvim-treesitter" },
      config = function()
        require("wildfire").setup({
          surrounds = {
            { "(", ")" },
            { "{", "}" },
            { "<", ">" },
            { "[", "]" },
          },
          keymaps = {
            init_selection = "<CR>",
            node_incremental = "<CR>",
            node_decremental = "<BS>",
          },
          filetype_exclude = { "qf" }, --keymaps will be unset in excluding filetypes
        })
      end,
    },
    {
      "briangwaltney/paren-hint.nvim",
      event = { "BufReadPre", "BufNewFile" },
      dependencies = {
        "nvim-treesitter/nvim-treesitter",
      },
      config = function()
        require("paren-hint").setup({
          include_paren = true,
        })
      end,
    },
  },
})
