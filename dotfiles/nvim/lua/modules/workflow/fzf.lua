local setup_fzf_lua = function()
  local fzf = require("fzf-lua")

  local fd_command = "rg --files --hidden --glob '!.git' --glob '!*[-\\.]lock\\.*' --smart-case"
  do
    local prox = vim.fn.exepath("proximity-sort")
    if prox ~= nil and #prox > 0 then
      local libuv = require("fzf-lua.libuv")
      fd_command = fd_command .. " | " .. libuv.shellescape(prox) .. " " .. libuv.shellescape(vim.fn.expand("%:."))
    end
  end

  local config = {
    -- defaults = {
    --   formatter = { "path.filename_first", 2 },
    -- },
    fzf_opts = {
      ["--layout"] = "default",
      ["--highlight-line"] = true,
    },
    rg_opts = { ["--column"] = "" },
    winopts = {
      split = "botright new",
      fullscreen = true,
      preview = {
        default = "bat",
        delay = 0,
        layout = "horizontal",
        horizontal = "right:40%",
        wrap = true,
      },
      on_create = function()
        vim.api.nvim_buf_set_keymap(0, "t", "<C-j>", "<Down>", { silent = true })
        vim.api.nvim_buf_set_keymap(0, "t", "<C-k>", "<Up>", { silent = true })
      end,
      backdrop = 100,
    },
    previewers = {
      bat = {
        cmd = "bat",
        args = "--color always --style=numbers,changes --wrap=auto",
        theme = "OneHalfDark",
        config = nil,
      },
    },
    files = {
      cmd = fd_command,
      -- path_shorten = 4,
      git_icons = false,
      fzf_opts = {
        ["--tiebreak"] = "index",
      },
    },
    buffers = {
      -- path_shorten = 4,
    },
    grep = {
      rg_opts = "--hidden --glob '!.git' --glob '!*[-\\.]lock\\.*' --glob '!LICENSE' --column --line-number --no-heading --color=always --smart-case --max-columns=4096 -e",
      -- path_shorten = 4,
      git_icons = false,
      fzf_opts = { ["--layout"] = "default", ["--no-hscroll"] = "" },
      -- rg_opts = "--hidden",
    },
    tags = { git_icons = false },
    btags = { git_icons = false },
    keymap = { builtin = {} },
  }
  fzf.setup(config)

  lib.map.map("n", "<c-p>", function()
    -- local opts = vim.deepcopy(config)
    -- opts.cmd = "rg --files --hidden --glob '!.git' --glob '!*[-\\.]lock\\.*' --smart-case"
    -- if vim.fn.expand("%:p:h") ~= vim.loop.cwd() then
    --   opts.cmd = opts.cmd .. (" | proximity-sort %s"):format(lib.shell.escape(vim.fn.expand("%")))
    -- end
    -- opts.prompt = "> "
    -- opts.fzf_opts = {
    --   ["--info"] = "inline",
    --   ["--tiebreak"] = "index",
    -- }
    fzf.files()
  end, "Find file in project")

  lib.map.map("n", ";", "<cmd>lua require('fzf-lua').buffers()<CR>", "Find buffer")

  lib.map.map("n", "<c-f>", function()
    local opts = {}

    -- nvim-tree search
    if vim.bo.filetype == "NvimTree" then
      local ok, api = pcall(require, "nvim-tree.api")
      if ok then
        local node = api.tree.get_node_under_cursor()
        if node and node.absolute_path and #node.absolute_path > 0 then
          if node.type == "directory" then
            opts.search_paths = { node.absolute_path }
          else
            opts.filename = node.absolute_path
          end
          local prox = vim.fn.exepath("proximity-sort")
          if prox and #prox > 0 then
            local libuv = require("fzf-lua.libuv")
            local ctx = vim.fn.fnamemodify(node.absolute_path, ":.")
            opts.filter = string.format("%s %s", libuv.shellescape(prox), libuv.shellescape(ctx))
          end
        end
      end
    end

    -- regular search
    if not opts.filter then
      local prox = vim.fn.exepath("proximity-sort")
      if prox and #prox > 0 then
        local ctx = vim.fn.expand("%:.")
        if ctx and #ctx > 0 then
          local libuv = require("fzf-lua.libuv")
          opts.filter = string.format("%s %s", libuv.shellescape(prox), libuv.shellescape(ctx))
        end
      end
    end

    fzf.grep_project(opts)
  end, "Find text in project")

  lib.map.map("n", "<leader>l", "<cmd>lua require('fzf-lua').blines()<CR>", "Find line in buffer")
  lib.map.map("n", "<leader>L", "<cmd>lua require('fzf-lua').lines()<CR>", "Find line in project")
  lib.map.map("n", "<leader>;", "<cmd>lua require('fzf-lua').resume()<CR>", "Resume last fzf-lua command")

  -- visual
  lib.map.map("v", "<c-f>", function()
    local opts = {}
    if type(config) == "table" and type(config.grep) == "table" and type(config.grep.rg_opts) == "string" then
      opts.rg_opts = (config.grep.rg_opts:gsub("%-%-color=always", "--color=never"))
    end
    local prox = vim.fn.exepath("proximity-sort")
    if prox and #prox > 0 then
      local ctx = vim.fn.expand("%:.")
      if ctx and #ctx > 0 then
        local libuv = require("fzf-lua.libuv")
        opts.filter = string.format("%s %s", libuv.shellescape(prox), libuv.shellescape(ctx))
      end
    end
    require("fzf-lua").grep_visual(opts)
  end, "Find selected text in project")
end

return lib.module.create({
  name = "workflow/fzf",
  hosts = "*",
  plugins = {
    {
      "ibhagwan/fzf-lua",
      -- commit = "a1a2d0f42eaec400cc6918a8e898fc1f9c4dbc5f", -- issues introduced by https://github.com/ibhagwan/fzf-lua/commit/b3b05f9d438736bb1f88aa373476753ddf83f481
      -- commit = "60428a8dc931639ee5e88756b2d7bc896cdc20c7",
      -- dir = lib.path.resolve(lib.env.dirs.vim.config, "plugins", "fzf"),
      event = "VeryLazy",
      dependencies = { "nvim-tree/nvim-web-devicons" },
      config = setup_fzf_lua,
    },
    { "vijaymarupudi/nvim-fzf", event = "VeryLazy" },
  },
})
