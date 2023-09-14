local api = {
  get = function(id)
    local command = string.format("WIKI_ROOT=$HOME/brain/wiki TASK_ROOT=$HOME/brain/wiki core wiki resolve '%s'", id)
    return lib.shell.exec(command)
  end,
  list = function()
    local command = "WIKI_ROOT=$HOME/brain/wiki TASK_ROOT=$HOME/brain/wiki core wiki ls | sort"
    local entries = string.split(lib.shell.exec(command), "\n")
    return entries
  end,
}

local handle_select = function()
  local entries = api.list()

  local fzf = require("fzf")
  coroutine.wrap(function()
    local win_options = { height = 10, relative = "win" }
    vim.cmd([[20 new]])
    local result =
      fzf.provided_win_fzf(entries, "--print-query --nth 1 --print-query --expect=ctrl-s,ctrl-v,ctrl-x", win_options)
    if not result then return end

    local target = result[3]

    local command = "e %s"
    if result[2] == "ctrl-s" then
      command = "sp %s"
    elseif result[2] == "ctrl-v" then
      command = "vs %s"
    elseif result[2] == "ctrl-x" then
      target = result[1]
    end

    local path = api.get(target)
    local vim_command = string.format(command, path)
    vim.cmd(vim_command)
  end)()
end

local handle_search = function()
  require("fzf-lua").grep_project({
    cwd = vim.env.HOME .. "/brain/wiki",
  })
end

local handle_navigate_to_symbol = function()
  local parser = vim.treesitter.get_parser()
  local root = parser:parse()[1]:root()

  local kinds = {
    "heading_1",
    "heading_2",
    "heading_3",
    "heading_4",
    "heading_5",
    "heading_6",
  }
  local symbols = lib.ts.find_children(root, kinds, true)

  local entries = {}
  for _, symbol in ipairs(symbols) do
    local text = vim.treesitter.get_node_text(symbol, 0)
    local first_line = string.split(text, "\n")[1]
    local row = symbol:start()
    table.insert(entries, string.format("%s: %s", row, first_line))
  end

  local fzf = require("fzf")

  coroutine.wrap(function()
    local win_options = { height = 10, relative = "win" }
    vim.cmd([[20 new]])
    local result = fzf.provided_win_fzf(entries, "--print-query --nth 3", win_options)
    if not result then return end

    local target = result[2]
    local row = string.split(target, ":")[1]

    vim.schedule(function()
      vim.api.nvim_win_set_cursor(0, { row + 1, 0 })
    end)
  end)()
end

local setup_autolist = function()
  require("autolist").setup({
    list_cap = 50,
    colon = {
      indent = true,
      indent_raw = false,
      preferred = "-",
    },
    lists = {
      preloaded = {
        generic = {
          "[-+]",
          "*+",
          "%d+[.)]",
          "%a[.)]",
        },
      },
      filetypes = {
        generic = {
          "markdown",
          "text",
          "syslang",
        },
      },
    },
    recal_function_hooks = {
      "new",
    },
    insert_mappings = {
      new = {
        -- "<CR>"
      },
      tab = { "<c-t>" },
      detab = { "<c-d>" },
      recal = { "<c-z>" },
      indent = {
        "<tab>+[catch]('>>')",
        "<s-tab>+[catch]('<<')",
      },
    },
    normal_mappings = {
      new = {
        -- "o",
        -- "O+(true)",
      },
      tab = { ">" },
      detab = { "<" },
      recal = { "dd" },
    },
  })
end

return lib.module.create({
  name = "wiki",
  plugins = {
    -- { "gaoDean/autolist.nvim", ft = { "syslang" }, config = setup_autolist },
    -- {
    --   "jmbuhr/otter.nvim",
    --   dependencies = {
    --     "hrsh7th/nvim-cmp",
    --     -- "yioneko/nvim-cmp",
    --     "neovim/nvim-lspconfig",
    --     "nvim-treesitter/nvim-treesitter",
    --   },
    --   init = function()
    --     vim.api.nvim_create_autocmd("FileType", {
    --       group = vim.api.nvim_create_augroup("syslang-otter", {}),
    --       pattern = "syslang",
    --       callback = function()
    --         local otter = require("otter")
    --         otter.activate({ "lua", "go", "typescript", "typescriptreact" }, true, {
    --           syslang = [[
    --             (code_block
    --               (code_block_start
    --                 (code_block_language) @lang
    --               )
    --               (code_block_content
    --                 (text) @code
    --               )
    --             )
    --           ]],
    --         })
    --         lib.map.map("n", "gd", ":lua require'otter'.ask_definition()<cr>", { buffer = true })
    --         lib.map.map("n", "K", ":lua require'otter'.ask_hover()<cr>", { silent = true })
    --       end,
    --     })
    --   end,
    -- },
  },
  mappings = {
    { "n", "<M-n>", handle_select },
    { "n", "<M-m>", handle_search },
    --  TODO: only in slang buffers
    { "n", "<leader>r", handle_navigate_to_symbol },
  },
})
