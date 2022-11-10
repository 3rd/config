local handle_new_tab = function()
  vim.cmd("tabnew")
  local job = vim.fn.termopen("$SHELL", {
    on_exit = function()
      vim.cmd("q")
    end,
  })
  -- vim.api.nvim_chan_send(job, "cd " .. cwd .. "\n")
end

local handle_split = function()
  vim.cmd("new")
  local job = vim.fn.termopen("$SHELL", {
    on_exit = function()
      vim.cmd("q")
    end,
  })
  -- vim.api.nvim_chan_send(job, "cd " .. cwd .. "\n")
end

local handle_vsplit = function()
  vim.cmd("vertical new")
  local job = vim.fn.termopen("$SHELL", {
    on_exit = function()
      vim.cmd("q")
    end,
  })
  -- vim.api.nvim_chan_send(job, "cd " .. cwd .. "\n")
end

local handle_close = function()
  vim.cmd("q")
end

local handle_new_terminal = function()
  local job = vim.fn.termopen("$SHELL", {
    on_exit = function()
      log("exit")
    end,
  })
end

local setup = function()
  vim.api.nvim_create_autocmd("TermOpen", {
    pattern = "term://*",
    callback = function()
      -- configure
      vim.opt.number = false
      vim.opt.relativenumber = false
      vim.opt.signcolumn = "no"

      -- setup keymaps
      local opts = { buffer = 0, noremap = true, silent = true }
      -- directional navigation <c-direction>
      vim.keymap.set("t", "<c-h>", "<c-\\><c-n><c-w>h", opts)
      vim.keymap.set("t", "<c-j>", "<c-\\><c-n><c-w>j", opts)
      vim.keymap.set("t", "<c-k>", "<c-\\><c-n><c-w>k", opts)
      vim.keymap.set("t", "<c-l>", "<c-\\><c-n><c-w>l", opts)
      -- tab switch <m-index>
      vim.keymap.set("t", "<m-1>", "<c-\\><c-n>:tabfirst<cr>", opts)
      vim.keymap.set("t", "<m-2>", "<c-\\><c-n>:tabn 2<cr>", opts)
      vim.keymap.set("t", "<m-3>", "<c-\\><c-n>:tabn 3<cr>", opts)
      vim.keymap.set("t", "<m-4>", "<c-\\><c-n>:tabn 4<cr>", opts)
      vim.keymap.set("t", "<m-5>", "<c-\\><c-n>:tabn 5<cr>", opts)
      vim.keymap.set("t", "<m-6>", "<c-\\><c-n>:tabn 6<cr>", opts)
      -- new tab - <c-a>c
      vim.keymap.set("t", "<c-a>c", handle_new_tab, opts)
      -- split - <c-a>s, vsplit - <c-a>v
      vim.keymap.set("t", "<c-a>s", handle_split, opts)
      vim.keymap.set("t", "<c-a>v", handle_vsplit, opts)
      -- close split - <c-a>x
      vim.keymap.set("t", "<c-a>x", handle_close, opts)
      -- quit - <c-a>q
      vim.keymap.set("t", "<c-a>q", "<c-\\><c-n>:qa<cr>", opts)
      -- exit insert mode
      vim.keymap.set("t", "<c-a><esc>", "<c-\\><c-n>", opts)
    end,
  })

  vim.api.nvim_create_autocmd(
    { "TermOpen", "TermEnter", "BufWinEnter", "WinEnter", "BufEnter" },
    {
      callback = function()
        if vim.bo.buftype == "terminal" then
          vim.cmd("startinsert")
        end
      end,
    }
  )

  vim.api.nvim_create_autocmd("TermClose", {
    callback = function()
      local is_terminal = vim.fn.getbufvar(vim.fn.bufnr(), "&buftype")
        == "terminal"
    end,
  })
end

return require("lib").module.create({
  enabled = false,
  name = "terminal",
  setup = setup,
  actions = {
    { "n", "Terminal: Open a new terminal", handle_new_terminal },
  },
})
