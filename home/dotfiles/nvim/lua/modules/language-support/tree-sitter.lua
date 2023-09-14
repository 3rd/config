local config = {
  ensure_installed = {
    "astro",
    "bash",
    "c",
    "cpp",
    "css",
    "zig",
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
  },
  highlight = {
    enable = true,
    disable = function(_, buf)
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
      scope_incremental = "<nop>",
    },
  },
  matchup = {
    enable = true,
    disable = {},
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
end

local setup_tsnode_marker = function()
  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("tsnode-marker-markdown", {}),
    pattern = "markdown",
    callback = function(ctx)
      require("tsnode-marker").set_automark(ctx.buf, {
        target = { "code_fence_content" },
        hl_group = "CursorLine",
      })
    end,
  })
  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("tsnode-marker-syslang", {}),
    pattern = "syslang",
    callback = function(ctx)
      require("tsnode-marker").set_automark(ctx.buf, {
        target = { "code_block" },
        hl_group = "@slang.code_block_fence",
      })
    end,
  })

  vim.api.nvim_exec_autocmds("FileType", {})
end

return lib.module.create({
  name = "language-support/tree-sitter",
  plugins = {
    {
      "nvim-treesitter/nvim-treesitter",
      lazy = false,
      dependencies = {
        "nvim-treesitter/playground",
      },
      build = ":TSUpdate",
      config = setup_treesitter,
    },
    {
      "atusy/tsnode-marker.nvim",
      event = "VeryLazy",
      config = setup_tsnode_marker,
    },
  },
})
