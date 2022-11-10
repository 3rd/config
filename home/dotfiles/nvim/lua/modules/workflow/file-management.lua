local lib = require("lib")

local setup_nvim_tree = function()
  local nvim_tree = require("nvim-tree")
  nvim_tree.setup({
    disable_netrw = true,
    hijack_netrw = true,
    open_on_setup = false,
    ignore_ft_on_setup = {},
    open_on_tab = false,
    hijack_cursor = false,
    update_cwd = false,
    diagnostics = {
      enable = false,
      icons = {
        hint = "",
        info = "",
        warning = "",
        error = "",
      },
    },
    update_focused_file = {
      enable = false,
      update_cwd = false,
      ignore_list = {},
    },
    system_open = {
      cmd = nil,
      args = {},
    },
    filters = {
      dotfiles = false,
      custom = {},
    },
    git = {
      enable = true,
      ignore = true,
      timeout = 500,
    },
    view = {
      width = 40,
      hide_root_folder = false,
      side = "left",
      mappings = {
        custom_only = true,
        list = {
          { key = { "<CR>", "o", "<2-LeftMouse>" }, action = "edit" },
          { key = { "O" }, action = "edit_no_picker" },
          { key = { "<2-RightMouse>", "<C-]>" }, action = "cd" },
          { key = "<C-v>", action = "vsplit" },
          { key = "<C-x>", action = "split" },
          { key = "<C-t>", action = "tabnew" },
          { key = "<", action = "prev_sibling" },
          { key = ">", action = "next_sibling" },
          { key = "P", action = "parent_node" },
          { key = "<BS>", action = "close_node" },
          { key = "<Tab>", action = "preview" },
          { key = "K", action = "first_sibling" },
          { key = "J", action = "last_sibling" },
          { key = "I", action = "toggle_ignored" },
          { key = "H", action = "toggle_dotfiles" },
          { key = "R", action = "refresh" },
          { key = "a", action = "create" },
          { key = "d", action = "remove" },
          { key = "D", action = "trash" },
          { key = "r", action = "rename" },
          { key = "<C-r>", action = "full_rename" },
          { key = "x", action = "cut" },
          { key = "c", action = "copy" },
          { key = "p", action = "paste" },
          { key = "y", action = "copy_name" },
          { key = "Y", action = "copy_path" },
          { key = "gy", action = "copy_absolute_path" },
          { key = "[c", action = "prev_git_item" },
          { key = "]c", action = "next_git_item" },
          { key = "s", action = "system_open" },
          { key = "q", action = "close" },
          { key = "?", action = "toggle_help" },
          -- { key = "-", action = "dir_up" },
        },
      },
      number = false,
      relativenumber = false,
      signcolumn = "yes",
    },
    trash = {
      cmd = "trash",
      require_confirm = true,
    },
  })
end

return lib.module.create({
  name = "workflow/file-management",
  plugins = {
    { "tpope/vim-eunuch" },
    {
      "kyazdani42/nvim-tree.lua",
      requires = { "kyazdani42/nvim-web-devicons" },
      config = setup_nvim_tree,
      event = "BufEnter",
    },
  },
  export = {
    toggle_or_focus_file_tree = function()
      local tree = require("nvim-tree")
      if lib.buffer.current.get_filetype() == "NvimTree" then
        vim.cmd([[wincmd w]])
      else
        if require("nvim-tree.view").is_visible() then
          tree.focus()
        else
          tree.toggle(true)
        end
      end
    end,
  },
})
