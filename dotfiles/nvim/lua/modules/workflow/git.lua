local setup_git_messenger = function()
  vim.g.git_messenger_no_default_mappings = true
  vim.g.git_messenger_always_into_popup = true
  vim.g.git_messenger_extra_blame_args = "-w"
  vim.g.git_messenger_floating_win_opts = { border = "single" }
  vim.g.git_messenger_popup_content_margins = false
  vim.g.git_messenger_include_diff = "current"

  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("git-messenger", {}),
    pattern = "gitmessengerpopup",
    callback = function()
      lib.map.map("n", "<C-o>", ":normal o<cr>", { buffer = true, desc = "Navigate to the previous commit" })
      lib.map.map("n", "<C-i>", ":normal O<cr>", { buffer = true, desc = "Navigate to the next commit" })
    end,
  })
end

-- TODO https://github.com/lewis6991/gitsigns.nvim#keymaps
local setup_git_signs = function()
  local gitsigns = require("gitsigns")

  if not lib.path.cwd_is_git_repo() then return end

  gitsigns.setup({
    signcolumn = true,
    numhl = false,
    signs = {
      add = {
        hl = "GitSignsAdd",
        text = "│",
        numhl = "GitSignsAddNr",
        linehl = "GitSignsAddLn",
      },
      change = {
        hl = "GitSignsChange",
        text = "│",
        numhl = "GitSignsChangeNr",
        linehl = "GitSignsChangeLn",
      },
      delete = {
        hl = "GitSignsDelete",
        text = "_",
        numhl = "GitSignsDeleteNr",
        linehl = "GitSignsDeleteLn",
      },
      topdelete = {
        hl = "GitSignsDelete",
        text = "‾",
        numhl = "GitSignsDeleteNr",
        linehl = "GitSignsDeleteLn",
      },
      changedelete = {
        hl = "GitSignsChange",
        text = "~",
        numhl = "GitSignsChangeNr",
        linehl = "GitSignsChangeLn",
      },
    },
    on_attach = function(bufnr)
      -- disable for syslang ft
      if vim.api.nvim_buf_get_option(bufnr, "ft") == "syslang" then return false end

      -- keymaps
      -- vim.api.nvim_buf_set_keymap(bufnr, "n", "hs", '<cmd>lua require"gitsigns".stage_hunk()<CR>', {})
    end,
  })
end

local setup_diffview = function()
  local actions = require("diffview.actions")

  require("diffview").setup({
    diff_binaries = false, -- Show diffs for binaries
    enhanced_diff_hl = true, -- See ':h diffview-config-enhanced_diff_hl'
    git_cmd = { "git" }, -- The git executable followed by default args.
    use_icons = true, -- Requires nvim-web-devicons
    watch_index = true, -- Update views and index buffers when the git index changes.
    icons = { -- Only applies when use_icons is true.
      folder_closed = "",
      folder_open = "",
    },
    signs = {
      fold_closed = "",
      fold_open = "",
      done = "✓",
    },
    view = {
      -- Configure the layout and behavior of different types of views.
      -- Available layouts:
      --  'diff1_plain'
      --    |'diff2_horizontal'
      --    |'diff2_vertical'
      --    |'diff3_horizontal'
      --    |'diff3_vertical'
      --    |'diff3_mixed'
      --    |'diff4_mixed'
      -- For more info, see ':h diffview-config-view.x.layout'.
      default = {
        -- Config for changed files, and staged files in diff views.
        layout = "diff2_horizontal",
      },
      merge_tool = {
        -- Config for conflicted files in diff views during a merge or rebase.
        layout = "diff3_horizontal",
        disable_diagnostics = true, -- Temporarily disable diagnostics for conflict buffers while in the view.
      },
      file_history = {
        -- Config for changed files in file history views.
        layout = "diff2_horizontal",
      },
    },
    file_panel = {
      listing_style = "tree", -- One of 'list' or 'tree'
      tree_options = { -- Only applies when listing_style is 'tree'
        flatten_dirs = true, -- Flatten dirs that only contain one single dir
        folder_statuses = "only_folded", -- One of 'never', 'only_folded' or 'always'.
      },
      win_config = { -- See ':h diffview-config-win_config'
        position = "left",
        width = 35,
        win_opts = {},
      },
    },
    file_history_panel = {
      -- log_options = { -- See ':h diffview-config-log_options'
      --   single_file = {
      --     diff_merges = "combined",
      --   },
      --   multi_file = {
      --     diff_merges = "first-parent",
      --   },
      -- },
      win_config = { -- See ':h diffview-config-win_config'
        position = "bottom",
        height = 16,
        win_opts = {},
      },
    },
    commit_log_panel = {
      win_config = { -- See ':h diffview-config-win_config'
        win_opts = {},
      },
    },
    default_args = { -- Default args prepended to the arg-list for the listed commands
      DiffviewOpen = {},
      DiffviewFileHistory = {},
    },
    hooks = {}, -- See ':h diffview-config-hooks'
    keymaps = {
      disable_defaults = false, -- Disable the default keymaps
      view = {
        -- The `view` bindings are active in the diff buffers, only when the current
        -- tabpage is a Diffview.
        ["<tab>"] = actions.select_next_entry, -- Open the diff for the next file
        ["<s-tab>"] = actions.select_prev_entry, -- Open the diff for the previous file
        ["gf"] = actions.goto_file, -- Open the file in a new split in the previous tabpage
        ["<C-w><C-f>"] = actions.goto_file_split, -- Open the file in a new split
        ["<C-w>gf"] = actions.goto_file_tab, -- Open the file in a new tabpage
        ["<leader>e"] = actions.focus_files, -- Bring focus to the file panel
        ["<leader>b"] = actions.toggle_files, -- Toggle the file panel.
        ["g<C-x>"] = actions.cycle_layout, -- Cycle through available layouts.
        ["[x"] = actions.prev_conflict, -- In the merge_tool: jump to the previous conflict
        ["]x"] = actions.next_conflict, -- In the merge_tool: jump to the next conflict
        ["<leader>co"] = actions.conflict_choose("ours"), -- Choose the OURS version of a conflict
        ["<leader>ct"] = actions.conflict_choose("theirs"), -- Choose the THEIRS version of a conflict
        ["<leader>cb"] = actions.conflict_choose("base"), -- Choose the BASE version of a conflict
        ["<leader>ca"] = actions.conflict_choose("all"), -- Choose all the versions of a conflict
        ["dx"] = actions.conflict_choose("none"), -- Delete the conflict region
      },
      diff1 = { --[[ Mappings in single window diff layouts ]]
      },
      diff2 = { --[[ Mappings in 2-way diff layouts ]]
      },
      diff3 = {
        -- Mappings in 3-way diff layouts
        { { "n", "x" }, "2do", actions.diffget("ours") }, -- Obtain the diff hunk from the OURS version of the file
        { { "n", "x" }, "3do", actions.diffget("theirs") }, -- Obtain the diff hunk from the THEIRS version of the file
      },
      diff4 = {
        -- Mappings in 4-way diff layouts
        { { "n", "x" }, "1do", actions.diffget("base") }, -- Obtain the diff hunk from the BASE version of the file
        { { "n", "x" }, "2do", actions.diffget("ours") }, -- Obtain the diff hunk from the OURS version of the file
        { { "n", "x" }, "3do", actions.diffget("theirs") }, -- Obtain the diff hunk from the THEIRS version of the file
      },
      file_panel = {
        ["j"] = actions.next_entry, -- Bring the cursor to the next file entry
        ["<down>"] = actions.next_entry,
        ["k"] = actions.prev_entry, -- Bring the cursor to the previous file entry.
        ["<up>"] = actions.prev_entry,
        ["<cr>"] = actions.select_entry, -- Open the diff for the selected entry.
        ["o"] = actions.select_entry,
        ["<2-LeftMouse>"] = actions.select_entry,
        ["-"] = actions.toggle_stage_entry, -- Stage / unstage the selected entry.
        ["S"] = actions.stage_all, -- Stage all entries.
        ["U"] = actions.unstage_all, -- Unstage all entries.
        ["X"] = actions.restore_entry, -- Restore entry to the state on the left side.
        ["L"] = actions.open_commit_log, -- Open the commit log panel.
        ["<c-b>"] = actions.scroll_view(-0.25), -- Scroll the view up
        ["<c-f>"] = actions.scroll_view(0.25), -- Scroll the view down
        ["<tab>"] = actions.select_next_entry,
        ["<s-tab>"] = actions.select_prev_entry,
        ["gf"] = actions.goto_file,
        ["<C-w><C-f>"] = actions.goto_file_split,
        ["<C-w>gf"] = actions.goto_file_tab,
        ["i"] = actions.listing_style, -- Toggle between 'list' and 'tree' views
        ["f"] = actions.toggle_flatten_dirs, -- Flatten empty subdirectories in tree listing style.
        ["R"] = actions.refresh_files, -- Update stats and entries in the file list.
        ["<leader>e"] = actions.focus_files,
        ["<leader>b"] = actions.toggle_files,
        ["g<C-x>"] = actions.cycle_layout,
        ["[x"] = actions.prev_conflict,
        ["]x"] = actions.next_conflict,
      },
      file_history_panel = {
        ["g!"] = actions.options, -- Open the option panel
        ["<C-A-d>"] = actions.open_in_diffview, -- Open the entry under the cursor in a diffview
        ["y"] = actions.copy_hash, -- Copy the commit hash of the entry under the cursor
        ["L"] = actions.open_commit_log,
        ["zR"] = actions.open_all_folds,
        ["zM"] = actions.close_all_folds,
        ["j"] = actions.next_entry,
        ["<down>"] = actions.next_entry,
        ["k"] = actions.prev_entry,
        ["<up>"] = actions.prev_entry,
        ["<cr>"] = actions.select_entry,
        ["o"] = actions.select_entry,
        ["<2-LeftMouse>"] = actions.select_entry,
        ["<c-b>"] = actions.scroll_view(-0.25),
        ["<c-f>"] = actions.scroll_view(0.25),
        ["<tab>"] = actions.select_next_entry,
        ["<s-tab>"] = actions.select_prev_entry,
        ["gf"] = actions.goto_file,
        ["<C-w><C-f>"] = actions.goto_file_split,
        ["<C-w>gf"] = actions.goto_file_tab,
        ["<leader>e"] = actions.focus_files,
        ["<leader>b"] = actions.toggle_files,
        ["g<C-x>"] = actions.cycle_layout,
      },
      option_panel = {
        ["<tab>"] = actions.select_entry,
        ["q"] = actions.close,
      },
    },
  })
end

return lib.module.create({
  name = "workflow/git",
  hosts = "*",
  plugins = {
    {
      "rhysd/git-messenger.vim",
      config = setup_git_messenger,
      cmd = { "GitMessenger" },
    },
    {
      "lewis6991/gitsigns.nvim",
      commit = "017c924e20e52096796fe8bb89b9718acb5a067c",
      event = { "BufReadPre", "BufNewFile" },
      dependencies = { "nvim-lua/plenary.nvim" },
      config = setup_git_signs,
    },
    {
      "NeogitOrg/neogit",
      dependencies = "nvim-lua/plenary.nvim",
      cmd = { "Neogit" },
    },
    {
      "sindrets/diffview.nvim",
      cmd = { "DiffviewOpen", "DiffviewFileHistory" },
      dependencies = { "nvim-lua/plenary.nvim" },
      config = setup_diffview,
    },
  },
  mappings = {
    { "n", "<leader>b", ":GitMessenger<cr>", { desc = "Blame line" } },
    -- { "n", "<leader>g", ":DiffviewOpen<cr>", { desc = "Open diff view " } },
  },
})
