local setup_tree = function()
  local nvim_tree = require("nvim-tree")
  nvim_tree.setup({
    auto_reload_on_write = true,
    disable_netrw = true,
    hijack_netrw = true,
    open_on_tab = false,
    hijack_cursor = true,
    update_cwd = false,
    notify = {
      threshold = vim.log.levels.WARN,
    },
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
      enable = false,
      ignore = false,
      timeout = 500,
    },
    view = {
      width = 50,
      side = "left",
      number = false,
      relativenumber = false,
      signcolumn = "yes",
    },
    trash = {
      cmd = "trash",
      require_confirm = true,
    },
    on_attach = function(bufnr)
      local api = require("nvim-tree.api")

      local function opts(desc)
        return { desc = "nvim-tree: " .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true }
      end

      vim.keymap.set("n", "<CR>", api.node.open.edit, opts("Open"))
      vim.keymap.set("n", "o", api.node.open.edit, opts("Open"))
      vim.keymap.set("n", "<2-LeftMouse>", api.node.open.edit, opts("Open"))
      vim.keymap.set("n", "O", api.node.open.no_window_picker, opts("Open: No Window Picker"))
      vim.keymap.set("n", "<2-RightMouse>", api.tree.change_root_to_node, opts("CD"))
      vim.keymap.set("n", "<C-]>", api.tree.change_root_to_node, opts("CD"))
      vim.keymap.set("n", "<C-v>", api.node.open.vertical, opts("Open: Vertical Split"))
      vim.keymap.set("n", "<C-x>", api.node.open.horizontal, opts("Open: Horizontal Split"))
      vim.keymap.set("n", "<C-t>", api.node.open.tab, opts("Open: New Tab"))
      vim.keymap.set("n", "<", api.node.navigate.sibling.prev, opts("Previous Sibling"))
      vim.keymap.set("n", ">", api.node.navigate.sibling.next, opts("Next Sibling"))
      vim.keymap.set("n", "P", api.node.navigate.parent, opts("Parent Directory"))
      vim.keymap.set("n", "<bs>", api.node.navigate.parent_close, opts("Close Directory"))
      vim.keymap.set("n", "<Tab>", api.node.open.preview, opts("Open Preview"))
      vim.keymap.set("n", "K", api.node.navigate.sibling.first, opts("First Sibling"))
      vim.keymap.set("n", "J", api.node.navigate.sibling.last, opts("Last Sibling"))
      vim.keymap.set("n", "I", api.tree.toggle_gitignore_filter, opts("Toggle Git Ignore"))
      vim.keymap.set("n", "H", api.tree.toggle_hidden_filter, opts("Toggle Dotfiles"))
      vim.keymap.set("n", "R", api.tree.reload, opts("Refresh"))
      vim.keymap.set("n", "a", api.fs.create, opts("Create"))
      vim.keymap.set("n", "d", api.fs.remove, opts("Delete"))
      vim.keymap.set("n", "D", api.fs.trash, opts("Trash"))
      vim.keymap.set("n", "r", api.fs.rename, opts("Rename"))
      vim.keymap.set("n", "<C-r>", api.fs.rename_sub, opts("Rename: Omit Filename"))
      vim.keymap.set("n", "x", api.fs.cut, opts("Cut"))
      vim.keymap.set("n", "c", api.fs.copy.node, opts("Copy"))
      vim.keymap.set("n", "p", api.fs.paste, opts("Paste"))
      vim.keymap.set("n", "y", api.fs.copy.filename, opts("Copy Name"))
      vim.keymap.set("n", "Y", api.fs.copy.relative_path, opts("Copy Relative Path"))
      vim.keymap.set("n", "gY", api.fs.copy.absolute_path, opts("Copy Absolute Path"))
      vim.keymap.set("n", "[c", api.node.navigate.git.prev, opts("Prev Git"))
      vim.keymap.set("n", "]c", api.node.navigate.git.next, opts("Next Git"))
      vim.keymap.set("n", "s", api.node.run.system, opts("Run System"))
      vim.keymap.set("n", "q", api.tree.close, opts("Close"))
      vim.keymap.set("n", "?", api.tree.toggle_help, opts("Help"))

      vim.keymap.set("n", "<leader>g", function()
        local tree_item = require("nvim-tree.api").tree.get_node_under_cursor()
        if tree_item.type ~= "directory" then
          log("Not a directory")
          return
        end
        local absolute_path = tree_item.absolute_path
        local relative_path = vim.fn.fnamemodify(absolute_path, ":.")
        log(relative_path)

        vim.ui.input({ prompt = "Component name:" }, function(input)
          if not input or input == "" then return end
          vim.cmd("!auto run react-component --path=" .. vim.fn.shellescape(relative_path .. "/" .. input))
        end)
      end, opts("Generate component"))
    end,
  })
end

local toggle_or_focus_file_tree = function()
  local api = require("nvim-tree.api")
  if lib.buffer.current.get_filetype() == "NvimTree" then
    vim.cmd([[wincmd w]])
  else
    if api.tree.is_visible() then
      api.tree.focus()
    else
      api.tree.toggle(true)
    end
  end
end

return lib.module.create({
  name = "workflow/file-management",
  hosts = "*",
  plugins = {
    {
      "nvim-tree/nvim-tree.lua",
      dependencies = {
        "nvim-tree/nvim-web-devicons",
        {
          "antosha417/nvim-lsp-file-operations",
          opts = {},
        },
      },
      config = setup_tree,
    },
    {
      "tpope/vim-eunuch",
      cmd = {
        "Remove",
        "Delete",
        "Move",
        "Mkdir",
      },
    },
  },
  mappings = {
    { "n", "-", toggle_or_focus_file_tree },
  },
})
