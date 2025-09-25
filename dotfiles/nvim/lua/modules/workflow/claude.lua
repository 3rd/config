local claude_pane_exists = function()
  local pane_pids = vim.fn.system("tmux list-panes -F '#{pane_pid}'")
  for pid in pane_pids:gmatch("[^\r\n]+") do
    local ps_output = vim.fn.system(
      "pgrep -P " .. pid .. " -f '.bun/bin/ccc' 2>/dev/null || pgrep -P " .. pid .. " -f 'ccc' 2>/dev/null"
    )
    if ps_output ~= "" then return true end
  end
  return false
end

return lib.module.create({
  name = "claude",
  hosts = "*",
  plugins = {
    {
      "coder/claudecode.nvim",
      opts = {
        port_range = { min = 10000, max = 65535 },
        auto_start = true,
        log_level = "info", -- "trace", "debug", "info", "warn", "error"
        terminal_cmd = "ccc --ide",
        focus_after_send = true,
        track_selection = true,
        visual_demotion_delay_ms = 50,
        terminal = {
          split_side = "right", -- "left" or "right"
          split_width_percentage = 0.30,
          provider = {
            setup = function(config) end,
            open = function(cmd_string, env_table, effective_config, focus)
              if focus == nil then focus = true end
              if claude_pane_exists() then return end
              local tmux_cmd = string.format(
                "tmux split-window -h -p %d -c %s %s",
                math.floor(effective_config.split_width_percentage * 100),
                vim.fn.shellescape(vim.fn.getcwd()),
                vim.fn.shellescape(cmd_string)
              )
              vim.fn.system(tmux_cmd)
              vim.fn.system("tmux select-pane -t '{top-right}'")
            end,
            close = function()
              vim.fn.system("tmux kill-pane -t '{top-right}'")
            end,
            simple_toggle = function(cmd_string, env_table, effective_config)
              local tmux_cmd = string.format(
                "tmux split-window -h -p %d -c %s %s",
                math.floor(effective_config.split_width_percentage * 100),
                vim.fn.shellescape(vim.fn.getcwd()),
                vim.fn.shellescape(cmd_string)
              )
              vim.fn.system(tmux_cmd)
              vim.fn.system("tmux select-pane -t '{top-right}'")
            end,
            focus_toggle = function(cmd_string, env_table, effective_config)
              vim.fn.system("tmux select-pane -t '{top-right}' || tmux select-pane -t '{left-of}'")
            end,
            get_active_bufnr = function()
              return nil
            end,
            is_available = function()
              -- local ok = vim.fn.system("tmux list-sessions 2>/dev/null")
              -- return vim.v.shell_error == 0
              return true
            end,
          },
          auto_close = true,
          snacks_win_opts = {},
          provider_opts = {
            external_terminal_cmd = nil,
          },
        },
        diff_opts = {
          auto_close_on_accept = true,
          vertical_split = true,
          open_in_current_tab = true,
          keep_terminal_focus = false,
        },
      },
      config = function(_, opts)
        require("claudecode").setup(opts)

        vim.api.nvim_create_user_command("ClaudeCodeCustomOpen", function()
          if claude_pane_exists() then
            vim.cmd("ClaudeCodeFocus")
          else
            vim.cmd("ClaudeCode")
            vim.defer_fn(function()
              vim.fn.system("tmux select-pane -t '{top-right}'")
            end, 100)
          end
        end, { desc = "Focus Claude if open, otherwise launch it" })

        vim.api.nvim_create_user_command("ClaudeCodeCustomOpenContinue", function()
          if claude_pane_exists() then
            vim.cmd("ClaudeCodeFocus")
          else
            vim.cmd("ClaudeCode --continue")
            vim.defer_fn(function()
              vim.fn.system("tmux select-pane -t '{top-right}'")
            end, 100)
          end
        end, { desc = "Focus Claude if open, otherwise launch it" })

        vim.api.nvim_create_user_command("ClaudeCodeSendWithFocus", function(_opts)
          vim.cmd("ClaudeCodeSend")
          vim.defer_fn(function()
            vim.fn.system("tmux select-pane -t '{top-right}'")
          end, 100)
        end, { range = true, desc = "Send to Claude and focus" })
      end,
      keys = {
        -- normal
        { "<leader>c", "<cmd>ClaudeCodeCustomOpen<cr>", desc = "Launch/focus Claude" },
        { "<leader>C", "<cmd>ClaudeCodeCustomOpenContinue<cr>", desc = "Launch/focus Claude (--continue)" },
        -- visual
        { "<leader>c", "<cmd>ClaudeCodeSendWithFocus<cr>", mode = "v", desc = "Send to Claude and focus" },
        { "<leader>C", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Send to Claude" },
        -- tree
        {
          "<leader>aa",
          "<cmd>ClaudeCodeTreeAdd<cr>",
          desc = "Add file to Claude",
          ft = { "NvimTree", "neo-tree", "oil", "minifiles" },
        },

        -- { "<leader>a", nil, desc = "AI/Claude Code" },
        -- { "<leader>ac", "<cmd>ClaudeCode<cr>", desc = "Toggle Claude" },
        -- { "<leader>af", "<cmd>ClaudeCodeFocus<cr>", desc = "Focus Claude" },
        -- { "<leader>ar", "<cmd>ClaudeCode --resume<cr>", desc = "Resume Claude" },
        -- { "<leader>aC", "<cmd>ClaudeCode --continue<cr>", desc = "Continue Claude" },
        -- { "<leader>am", "<cmd>ClaudeCodeSelectModel<cr>", desc = "Select Claude model" },
        -- { "<leader>ab", "<cmd>ClaudeCodeAdd %<cr>", desc = "Add current buffer" },
        -- { "<leader>aa", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Accept diff" },
        -- { "<leader>ad", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Deny diff" },
      },
    },
  },
})
