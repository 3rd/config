vim.g["$FZF_DEFAULT_OPTS"] = [[--layout=reverse --info=inline --color gutter:-1]]
vim.g.fzf_action = {
  ["ctrl-s"] = "split",
  ["ctrl-v"] = "vsplit",
}
vim.g.fzf_layout = { down = "~45%" }
vim.g.fzf_options =
  [[--tiebreak=index -m --color 16 --color gutter:-1 --preview "bat --color always --style=numbers,changes {}"]]

local setup_fzf = function()
  vim.cmd([[
    let $FZF_DEFAULT_COMMAND = 'rg --files --follow --smart-case --hidden -g "!{.git,.cache,.st*,package-lock.json,yarn.lock,node_modules,local_modules}"'
    let $FZF_DEFAULT_OPTS = '--bind ctrl-a:select-all,ctrl-d:deselect-all --color gutter:-1'
  ]])

  vim.cmd([[
    command! -nargs=* -bang RgNoMatchFilenames call fzf#vim#grep(
      \ "rg --column --line-number --no-heading --color=always --smart-case -- ".shellescape(<q-args>), 1,
      \ fzf#vim#with_preview({'options': '--delimiter : --nth 4..'}), <bang>0)
  ]])
end

local setup_nvim_fzf = function()
  require("fzf").default_options = {
    window_on_create = function() vim.cmd("set winhl=Normal:Normal") end,
  }
end

local setup_trouble = function()
  local trouble = require("trouble")
  trouble.setup({
    action_keys = {
      open_split = { "<c-s>" },
      open_vsplit = { "<c-v>" },
    },
  })
end

local setup_fzf_lua = function()
  local fzf = require("fzf-lua")

  local default_opts = {
    fzf_opts = { ["--layout"] = "default" },
    winopts = {
      split = "botright new",
      fullscreen = true,
      preview = {
        default = "bat",
        delay = 0,
        layout = "horizontal",
        horizontal = "right:40%",
      },
      on_create = function()
        vim.api.nvim_buf_set_keymap(0, "t", "<C-j>", "<Down>", { silent = true })
        vim.api.nvim_buf_set_keymap(0, "t", "<C-k>", "<Up>", { silent = true })
      end,
    },
    previewers = {
      bat = {
        cmd = "bat",
        args = "--color always --style=numbers,changes",
        theme = "OneHalfDark",
        config = nil,
      },
    },
    files = {
      git_icons = false,
    },
    grep = {
      git_icons = false,
    },
    tags = {
      git_icons = false,
    },
    btags = {
      git_icons = false,
    },
  }

  fzf.setup(default_opts)

  vim.keymap.set("n", "<c-p>", function()
    local opts = vim.deepcopy(default_opts)
    opts.cmd = "rg --files --hidden --glob=!.git/ --smart-case"
    if vim.fn.expand("%:p:h") ~= vim.loop.cwd() then
      opts.cmd = opts.cmd .. (" | proximity-sort %s"):format(vim.fn.expand("%"))
    end
    opts.prompt = "> "
    opts.fzf_opts = {
      ["--info"] = "inline",
      ["--tiebreak"] = "index",
    }
    fzf.files(opts)
  end)
  vim.keymap.set("n", ";", "<cmd>lua require('fzf-lua').buffers()<CR>")
  vim.keymap.set("n", "<c-f>", "<cmd>lua require('fzf-lua').grep_project()<CR>")
  vim.keymap.set("n", "<leader>l", "<cmd>lua require('fzf-lua').blines()<CR>")
  vim.keymap.set("n", "<leader>L", "<cmd>lua require('fzf-lua').lines()<CR>")
  vim.keymap.set("n", "<leader><leader>", "<cmd>lua require('fzf-lua').resume()<CR>")
end

return require("lib").module.create({
  name = "workflow/navigation",
  plugins = {
    {
      "junegunn/fzf.vim",
      requires = { "junegunn/fzf" },
      config = setup_fzf,
    },
    { "vijaymarupudi/nvim-fzf", after = { "fzf.vim" }, config = setup_nvim_fzf },
    {
      "ibhagwan/fzf-lua",
      requires = { "kyazdani42/nvim-web-devicons" },
      config = setup_fzf_lua,
    },
    {
      "folke/trouble.nvim",
      requires = { "kyazdani42/nvim-web-devicons" },
      config = setup_trouble,
    },
  },
  mappings = {
    { "n", "<leader>t", ":TroubleToggle<cr>" },
  },
})
