vim.g["$FZF_DEFAULT_OPTS"] = [[--layout=reverse --info=inline --color gutter:-1]]
vim.g.fzf_action = {
  ["ctrl-s"] = "split",
  ["ctrl-v"] = "vsplit",
}
vim.g.fzf_layout = { down = "~40%" }
vim.g.fzf_options = [[--tiebreak=index -m --color 16 --color gutter:-1 --preview "bat --color always --style=numbers,changes {}"]]

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

local setup_telescope = function()
  local telescope = require("telescope")
  telescope.setup({
    defaults = {
      border = true,
      layout_strategy = "bottom_pane",
      layout_config = {
        height = 0.5,
        width = 1.0,
        prompt_position = "bottom",
      },
      sorting_strategy = "descending",
      winblend = 0,
      mappings = {
        i = {
          ["<Esc>"] = require("telescope.actions").close,
        },
      },
    },
  })
end

local setup_nvim_fzf = function()
  require("fzf").default_options = {
    window_on_create = function()
      vim.cmd("set winhl=Normal:Normal")
    end,
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

return require("lib").module.create({
  name = "workflow/navigation",
  plugins = {
    {
      "junegunn/fzf.vim",
      requires = { "junegunn/fzf" },
      config = setup_fzf,
    },
    { "vijaymarupudi/nvim-fzf", after = { "fzf.vim" }, config = setup_nvim_fzf },
    { "nvim-telescope/telescope.nvim", requires = { { "nvim-lua/plenary.nvim" } }, config = setup_telescope },
    { "folke/trouble.nvim", requires = { "kyazdani42/nvim-web-devicons" }, config = setup_trouble },
  },
  mappings = {
    { "n", "<leader>t", ":TroubleToggle<cr>" },
  },
})
