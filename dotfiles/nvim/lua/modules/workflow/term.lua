return lib.module.create({
  name = "workflow/term",
  hosts = "*",
  setup = function()
    -- options
    vim.g.terminal_scrollback_buffer_size = 100000

    -- auto-commands
    vim.api.nvim_command("autocmd TermOpen * startinsert")
    vim.api.nvim_command("autocmd TermOpen * setlocal nonumber")
    vim.api.nvim_command("autocmd TermEnter * setlocal signcolumn=no")

    -- binds
    vim.keymap.set("t", "<C-X>", "<C-\\><C-n>")

    -- claude
    vim.api.nvim_create_autocmd("BufEnter", {
      pattern = "*",
      callback = function()
        local buffer = vim.api.nvim_get_current_buf()
        local buftype = vim.api.nvim_buf_get_option(buffer, "buftype")
        local name = vim.api.nvim_buf_get_name(buffer)
        if buftype == "terminal" and name:match(".bun/bin/ccc") then
          vim.keymap.set("t", "<C-h>", '<cmd>lua require("tmux").move_left()<cr>', { buffer = buffer })
          vim.keymap.set("t", "<C-j>", '<cmd>lua require("tmux").move_bottom()<cr>', { buffer = buffer })
          vim.keymap.set("t", "<C-k>", '<cmd>lua require("tmux").move_top()<cr>', { buffer = buffer })
          vim.keymap.set("t", "<C-l>", '<cmd>lua require("tmux").move_right()<cr>', { buffer = buffer })

          vim.cmd("startinsert")
        end
      end,
    })
  end,
})
