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
    disable = function(_lang, buf)
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
  incremental_selection = {
    enable = true,
    keymaps = {
      init_selection = "<cr>",
      node_incremental = "<cr>",
      node_decremental = "<bs>",
      scope_incremental = "<nop>",
    },
  },
  rainbow = {
    enable = true,
    -- disable = { "jsx", "cpp" },
    -- query = "rainbow-parens",
    -- strategy = require("ts-rainbow").strategy.global,
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

  vim.api.nvim_set_option_value("foldmethod", "expr", {})
  vim.api.nvim_set_option_value("foldexpr", "nvim_treesitter#foldexpr()", {})
end

local setup_tsnode_marker = function()
  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("tsnode-marker-markdown", {}),
    pattern = "markdown",
    callback = function(ctx)
      require("tsnode-marker").set_automark(ctx.buf, {
        target = { "code_fence_content" }, -- list of target node types
        hl_group = "CursorLine", -- highlight group
      })
    end,
  })
  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("tsnode-marker-syslang", {}),
    pattern = "syslang",
    callback = function(ctx)
      require("tsnode-marker").set_automark(ctx.buf, {
        target = { "code_block" }, -- list of target node types
        hl_group = "@slang.code_block_fence", -- highlight group
      })
    end,
  })
end

return lib.module.create({
  name = "language-support/tree-sitter",
  plugins = {
    {
      "nvim-treesitter/nvim-treesitter",
      event = "VimEnter",
      dependencies = {
        "nvim-treesitter/playground",
        "HiPhish/nvim-ts-rainbow2",
      },
      build = ":TSUpdate",
      config = setup_treesitter,
    },
    {
      "nvim-treesitter/playground",
      cmd = { "TSPlaygroundToggle" },
    },
    {
      "atusy/tsnode-marker.nvim",
      event = "VeryLazy",
      config = setup_tsnode_marker,
    },
  },
})
