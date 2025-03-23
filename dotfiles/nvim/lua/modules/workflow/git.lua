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
      "NeogitOrg/neogit",
      cmd = { "Neogit" },
      dependencies = {
        "nvim-lua/plenary.nvim",
        "sindrets/diffview.nvim",
      },
      opts = {
        -- Hides the hints at the top of the status buffer
        disable_hint = false,
        -- Disables changing the buffer highlights based on where the cursor is.
        disable_context_highlighting = false,
        -- Disables signs for sections/items/hunks
        disable_signs = false,
        -- Changes what mode the Commit Editor starts in. `true` will leave nvim in normal mode, `false` will change nvim to
        -- insert mode, and `"auto"` will change nvim to insert mode IF the commit message is empty, otherwise leaving it in
        -- normal mode.
        disable_insert_on_commit = "auto",
        -- When enabled, will watch the `.git/` directory for changes and refresh the status buffer in response to filesystem
        -- events.
        filewatcher = {
          interval = 1000,
          enabled = true,
        },
        -- "ascii"   is the graph the git CLI generates
        -- "unicode" is the graph like https://github.com/rbong/vim-flog
        graph_style = "kitty",
        -- Used to generate URL's for branch popup action "pull request".
        git_services = {
          ["github.com"] = "https://github.com/${owner}/${repository}/compare/${branch_name}?expand=1",
          ["bitbucket.org"] = "https://bitbucket.org/${owner}/${repository}/pull-requests/new?source=${branch_name}&t=1",
          ["gitlab.com"] = "https://gitlab.com/${owner}/${repository}/merge_requests/new?merge_request[source_branch]=${branch_name}",
          ["azure.com"] = "https://dev.azure.com/${owner}/_git/${repository}/pullrequestcreate?sourceRef=${branch_name}&targetRef=${target}",
        },
        -- Allows a different telescope sorter. Defaults to 'fuzzy_with_index_bias'. The example below will use the native fzf
        -- sorter instead. By default, this function returns `nil`.
        telescope_sorter = function()
          return require("telescope").extensions.fzf.native_fzf_sorter()
        end,
        -- Persist the values of switches/options within and across sessions
        remember_settings = true,
        -- Scope persisted settings on a per-project basis
        use_per_project_settings = true,
        -- Table of settings to never persist. Uses format "Filetype--cli-value"
        ignored_settings = {
          "NeogitPushPopup--force-with-lease",
          "NeogitPushPopup--force",
          "NeogitPullPopup--rebase",
          "NeogitCommitPopup--allow-empty",
          "NeogitRevertPopup--no-edit",
        },
        -- Configure highlight group features
        highlight = {
          italic = true,
          bold = true,
          underline = true,
        },
        -- Set to false if you want to be responsible for creating _ALL_ keymappings
        use_default_keymaps = true,
        -- Neogit refreshes its internal state after specific events, which can be expensive depending on the repository size.
        -- Disabling `auto_refresh` will make it so you have to manually refresh the status after you open it.
        auto_refresh = true,
        -- Value used for `--sort` option for `git branch` command
        -- By default, branches will be sorted by commit date descending
        -- Flag description: https://git-scm.com/docs/git-branch#Documentation/git-branch.txt---sortltkeygt
        -- Sorting keys: https://git-scm.com/docs/git-for-each-ref#_options
        sort_branches = "-committerdate",
        -- Default for new branch name prompts
        initial_branch_name = "",
        -- Change the default way of opening neogit
        kind = "tab",
        -- Disable line numbers and relative line numbers
        disable_line_numbers = true,
        -- The time after which an output console is shown for slow running commands
        console_timeout = 2000,
        -- Automatically show console if a command takes more than console_timeout milliseconds
        auto_show_console = true,
        -- Automatically close the console if the process exits with a 0 (success) status
        auto_close_console = true,
        status = {
          show_head_commit_hash = true,
          recent_commit_count = 10,
          HEAD_padding = 10,
          HEAD_folded = false,
          mode_padding = 3,
          mode_text = {
            M = "modified",
            N = "new file",
            A = "added",
            D = "deleted",
            C = "copied",
            U = "updated",
            R = "renamed",
            DD = "unmerged",
            AU = "unmerged",
            UD = "unmerged",
            UA = "unmerged",
            DU = "unmerged",
            AA = "unmerged",
            UU = "unmerged",
            ["?"] = "",
          },
        },
        commit_editor = {
          kind = "tab",
          show_staged_diff = true,
          -- Accepted values:
          -- "split" to show the staged diff below the commit editor
          -- "vsplit" to show it to the right
          -- "split_above" Like :top split
          -- "vsplit_left" like :vsplit, but open to the left
          -- "auto" "vsplit" if window would have 80 cols, otherwise "split"
          staged_diff_split_kind = "split",
          spell_check = true,
        },
        commit_select_view = {
          kind = "tab",
        },
        commit_view = {
          kind = "vsplit",
          verify_commit = vim.fn.executable("gpg") == 1, -- Can be set to true or false, otherwise we try to find the binary
        },
        log_view = {
          kind = "tab",
        },
        rebase_editor = {
          kind = "auto",
        },
        reflog_view = {
          kind = "tab",
        },
        merge_editor = {
          kind = "auto",
        },
        tag_editor = {
          kind = "auto",
        },
        preview_buffer = {
          kind = "floating",
        },
        popup = {
          kind = "split",
        },
        signs = {
          -- { CLOSED, OPENED }
          hunk = { "", "" },
          item = { ">", "v" },
          section = { ">", "v" },
        },
        integrations = {
          telescope = nil,
          diffview = nil,
          fzf_lua = nil,
          mini_pick = nil,
        },
        sections = {
          -- Reverting/Cherry Picking
          sequencer = {
            folded = false,
            hidden = false,
          },
          untracked = {
            folded = false,
            hidden = false,
          },
          unstaged = {
            folded = false,
            hidden = false,
          },
          staged = {
            folded = false,
            hidden = false,
          },
          stashes = {
            folded = true,
            hidden = false,
          },
          unpulled_upstream = {
            folded = true,
            hidden = false,
          },
          unmerged_upstream = {
            folded = false,
            hidden = false,
          },
          unpulled_pushRemote = {
            folded = true,
            hidden = false,
          },
          unmerged_pushRemote = {
            folded = false,
            hidden = false,
          },
          recent = {
            folded = true,
            hidden = false,
          },
          rebase = {
            folded = true,
            hidden = false,
          },
        },
        mappings = {
          commit_editor = {
            ["q"] = "Close",
            ["<c-c><c-c>"] = "Submit",
            ["<c-c><c-k>"] = "Abort",
          },
          commit_editor_I = {
            ["<c-c><c-c>"] = "Submit",
            ["<c-c><c-k>"] = "Abort",
          },
          rebase_editor = {
            ["p"] = "Pick",
            ["r"] = "Reword",
            ["e"] = "Edit",
            ["s"] = "Squash",
            ["f"] = "Fixup",
            ["x"] = "Execute",
            ["d"] = "Drop",
            ["b"] = "Break",
            ["q"] = "Close",
            ["<cr>"] = "OpenCommit",
            ["gk"] = "MoveUp",
            ["gj"] = "MoveDown",
            ["<c-c><c-c>"] = "Submit",
            ["<c-c><c-k>"] = "Abort",
            ["[c"] = "OpenOrScrollUp",
            ["]c"] = "OpenOrScrollDown",
          },
          rebase_editor_I = {
            ["<c-c><c-c>"] = "Submit",
            ["<c-c><c-k>"] = "Abort",
          },
          finder = {
            ["<cr>"] = "Select",
            ["<c-c>"] = "Close",
            ["<esc>"] = "Close",
            ["<c-n>"] = "Next",
            ["<c-p>"] = "Previous",
            ["<down>"] = "Next",
            ["<up>"] = "Previous",
            ["<tab>"] = "MultiselectToggleNext",
            ["<s-tab>"] = "MultiselectTogglePrevious",
            ["<c-j>"] = "NOP",
          },
          -- Setting any of these to `false` will disable the mapping.
          popup = {
            ["?"] = "HelpPopup",
            ["A"] = "CherryPickPopup",
            ["D"] = "DiffPopup",
            ["M"] = "RemotePopup",
            ["P"] = "PushPopup",
            ["X"] = "ResetPopup",
            ["Z"] = "StashPopup",
            ["b"] = "BranchPopup",
            ["B"] = "BisectPopup",
            ["c"] = "CommitPopup",
            ["f"] = "FetchPopup",
            ["l"] = "LogPopup",
            ["m"] = "MergePopup",
            ["p"] = "PullPopup",
            ["r"] = "RebasePopup",
            ["v"] = "RevertPopup",
            ["w"] = "WorktreePopup",
          },
          status = {
            ["k"] = "MoveUp",
            ["j"] = "MoveDown",
            ["q"] = "Close",
            ["o"] = "OpenTree",
            ["I"] = "InitRepo",
            ["1"] = "Depth1",
            ["2"] = "Depth2",
            ["3"] = "Depth3",
            ["4"] = "Depth4",
            ["<tab>"] = "Toggle",
            ["x"] = "Discard",
            ["s"] = "Stage",
            ["S"] = "StageUnstaged",
            ["<c-s>"] = "StageAll",
            ["K"] = "Untrack",
            ["u"] = "Unstage",
            ["U"] = "UnstageStaged",
            ["$"] = "CommandHistory",
            ["Y"] = "YankSelected",
            ["<c-r>"] = "RefreshBuffer",
            ["<cr>"] = "GoToFile",
            ["<s-cr>"] = "PeekFile",
            ["<c-v>"] = "VSplitOpen",
            ["<c-x>"] = "SplitOpen",
            ["<c-t>"] = "TabOpen",
            ["{"] = "GoToPreviousHunkHeader",
            ["}"] = "GoToNextHunkHeader",
            ["[c"] = "OpenOrScrollUp",
            ["]c"] = "OpenOrScrollDown",
            ["<c-k>"] = "PeekUp",
            ["<c-j>"] = "PeekDown",
          },
        },
      },
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
