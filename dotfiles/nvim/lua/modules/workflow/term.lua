return lib.module.create({
  name = "workflow/term",
  hosts = "*",
  setup = function()
    -- options
    vim.g.terminal_scrollback_buffer_size = 100000

    -- auto-commands
    local term_group = vim.api.nvim_create_augroup("workflow_term", { clear = true })
    vim.api.nvim_create_autocmd("TermOpen", {
      group = term_group,
      pattern = "*",
      callback = function()
        vim.cmd("startinsert")
        vim.wo.number = false
      end,
    })
    vim.api.nvim_create_autocmd("TermEnter", {
      group = term_group,
      pattern = "*",
      callback = function()
        vim.wo.signcolumn = "no"
      end,
    })

    -- binds: exit terminal mode, but pass through to fzf buffers
    vim.keymap.set("t", "<C-X>", function()
      if vim.bo.filetype == "fzf" then
        -- send raw ctrl-x to fzf process
        local chan = vim.b.terminal_job_id
        if chan then vim.fn.chansend(chan, "\24") end
      else
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true), "n", true)
      end
    end)

    -- claude
    vim.api.nvim_create_autocmd("BufEnter", {
      pattern = "term://*",
      callback = function()
        local buffer = vim.api.nvim_get_current_buf()
        if vim.b[buffer]._ccc_term_keymaps_set then return end

        local name = vim.api.nvim_buf_get_name(buffer)
        if not name:match("%.bun/bin/ccc") then return end

        vim.b[buffer]._ccc_term_keymaps_set = true
        vim.keymap.set("t", "<C-h>", '<cmd>lua require("tmux").move_left()<cr>', { buffer = buffer })
        vim.keymap.set("t", "<C-j>", '<cmd>lua require("tmux").move_bottom()<cr>', { buffer = buffer })
        vim.keymap.set("t", "<C-k>", '<cmd>lua require("tmux").move_top()<cr>', { buffer = buffer })
        vim.keymap.set("t", "<C-l>", '<cmd>lua require("tmux").move_right()<cr>', { buffer = buffer })

        vim.cmd("startinsert")
      end,
    })
  end,
})
