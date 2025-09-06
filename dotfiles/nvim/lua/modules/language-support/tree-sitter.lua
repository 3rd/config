local config = {
  ensure_installed = {
    "astro",
    "bash",
    "c",
    "cpp",
    "css",
    "c_sharp",
    "dockerfile",
    "fish",
    "go",
    "gomod",
    "graphql",
    "html",
    "javascript",
    "json",
    "json5",
    "jsonc",
    "lua",
    "make",
    "markdown",
    "markdown_inline",
    "nix",
    "php",
    "prisma",
    "python",
    "query",
    "rust",
    "scss",
    "sql",
    "svelte",
    "syslang",
    "toml",
    "tsx",
    "typescript",
    "v",
    "vim",
    "vimdoc",
    "vue",
    "xml",
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
      local text = lib.buffer.get_text(buf)
      if string.includes(text, "lush%(function") then return true end
      return false
    end,
  },
  textobjects = {
    select = {
      enable = true,
      lookahead = true,
      keymaps = {
        -- fns
        ["if"] = "@function.inner",
        ["af"] = "@function.outer",
        ["ic"] = "@call.inner",
        ["ac"] = "@call.outer",
        ["iC"] = "@class.inner",
        ["aC"] = "@class.outer",

        -- block/statement
        ["ib"] = "@block.inner",
        ["ab"] = "@block.outer",
        ["is"] = "@statement.inner",
        ["as"] = "@statement.outer",

        -- unused
        -- ["ip"] = "@parameter.inner",
        -- ["ap"] = "@parameter.outer",
        -- ["ig"] = "@comment.inner",
        -- ["ag"] = "@comment.outer",
        -- ["il"] = "@loop.inner",
        -- ["al"] = "@loop.outer",
        -- ["ic"] = "@conditional.inner",
        -- ["ac"] = "@conditional.outer",
        -- ["a="] = "@assignment.outer",
        -- ["i="] = "@assignment.inner",
        -- ["l="] = "@assignment.lhs",
        -- ["r="] = "@assignment.rhs",
        -- ["ar"] = "@return.outer",
        -- ["ir"] = "@return.inner",
        -- ["an"] = "@number.inner",
        -- ["in"] = "@number.inner",
        -- ["i/"] = "@regex.inner",
        -- ["a/"] = "@regex.outer",
        -- ['i"'] = "@string.inner",
        -- ['a"'] = "@string.outer",
        -- ["it"] = "@type.inner",
        -- ["at"] = "@type.outer",
        -- ["ii"] = "@import.inner",
        -- ["ai"] = "@import.outer",
        -- ["iA"] = "@attribute.inner",
        -- ["aA"] = "@attribute.outer",
        -- ["iS"] = "@scope.inner",
        -- ["aS"] = "@scope.outer",
        -- ["iF"] = "@frame.inner",
        -- ["aF"] = "@frame.outer",
      },
      selection_modes = {},
      include_surrounding_whitespace = false,
    },
    move = {
      enable = true,
      set_jumps = true,
      goto_next_start = {
        ["]f"] = "@function.outer",
        ["]c"] = "@class.outer",
        ["]s"] = "@statement.outer",
        ["]b"] = "@block.outer",
        ["]r"] = "@return.outer",
        -- ["]A"] = "@attribute.outer",
        -- ["]a"] = "@parameter.inner",
        -- ["]g"] = "@comment.outer",
        -- ["]i"] = "@import.outer",
        -- ["]l"] = "@call.outer",
        -- ["]o"] = "@loop.outer",
        -- ["]t"] = "@type.outer",
        -- ["]z"] = "@fold",
      },
      goto_next_end = {},
      goto_previous_start = {
        ["[f"] = "@function.outer",
        ["[c"] = "@class.outer",
        ["[s"] = "@statement.outer",
        ["[b"] = "@block.outer",
        ["[r"] = "@return.outer",
        -- ["[A"] = "@attribute.outer",
        -- ["[a"] = "@parameter.inner",
        -- ["[g"] = "@comment.outer",
        -- ["[i"] = "@import.outer",
        -- ["[l"] = "@call.outer",
        -- ["[o"] = "@loop.outer",
        -- ["[t"] = "@type.outer",
        -- ["[z"] = "@fold",
      },
      goto_previous_end = {},
    },
    swap = {
      enable = false,
    },
    lsp_interop = {
      enable = true,
      border = "single",
      floating_preview_opts = {},
      peek_definition_code = {
        ["<leader>k"] = "@function.outer",
        ["<leader>K"] = "@class.outer",
      },
    },
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
    enable = false, -- handled by wildfire
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
      files = { "src/parser.c", "src/scanner.c" },
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
  hosts = "*",
  plugins = {
    {
      "nvim-treesitter/nvim-treesitter",
      event = { "BufReadPre", "BufNewFile" },
      dependencies = {
        "nvim-treesitter/playground",
        { "nvim-treesitter/nvim-treesitter-textobjects" },
        {
          "nvim-treesitter/nvim-treesitter-context",
          opts = {
            enable = true,
            max_lines = 3,
            min_window_height = 0,
            line_numbers = true,
            multiline_threshold = 1,
            trim_scope = "outer",
            mode = "cursor",
            zindex = 20,
            on_attach = function()
              return vim.bo.filetype ~= "help"
            end,
          },
        },
      },
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
  },
})
