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
    local options = {
      height = 10,
      relative = "win",
    }

    vim.cmd([[20 new]])
    local result =
      fzf.provided_win_fzf(entries, "--print-query --nth 1 --print-query --expect=ctrl-s,ctrl-v,ctrl-x", options)
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

local setup_autolist = function()
  require("autolist").setup({
    -- enabled = false,
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
      tab = {},
      detab = {},
      recal = { "dd" },
    },
  })

  -- patch recal() to adjust star outline markers
  -- local start_line_number = fn.line(".")
  -- local start_line = fn.getline(start_line_number)
  -- local start_line_indent = utils.get_indent_lvl(start_line)
  -- if start_line:match("^%s*%*+%s") then
  --   local stars = ""
  --   local indent_level = start_line_indent / config.tabstop + 1
  --   for i = 1, indent_level do
  --     stars = stars .. "*"
  --   end
  --   utils.set_line_marker(start_line_number, stars, types)
  --   for i = start_line_number + 1, fn.line("$") do
  --     local current_line_before = fn.getline(i)
  --     if current_line_before:match("^%s*%*+%s") then
  --       break
  --     end
  --     local current_indent_level = utils.get_indent_lvl(current_line_before) / config.tabstop + 1
  --     local current_line_without_indent = current_line_before:gsub("^%s*", "", 1)
  --     if current_indent_level >= indent_level then
  --       local indented_line = string.rep(" ", config.tabstop * indent_level) .. current_line_without_indent
  --       -- log({ indent_level = indent_level, indented_line = indented_line })
  --       fn.setline(i, indented_line)
  --     end
  --   end
  --   return
  -- end
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
  },
})
