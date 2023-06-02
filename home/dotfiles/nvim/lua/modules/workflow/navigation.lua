local setup_fzf_lua = function()
  local fzf = require("fzf-lua")

  local config = {
    fzf_opts = { ["--layout"] = "default" },
    rg_opts = { ["--column"] = "" },
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
      -- path_shorten = 4,
      git_icons = false,
    },
    buffers = {
      -- path_shorten = 4,
    },
    grep = {
      -- path_shorten = 4,
      git_icons = false,
      fzf_opts = { ["--layout"] = "default", ["--no-hscroll"] = "" },
    },
    tags = { git_icons = false },
    btags = { git_icons = false },
  }
  fzf.setup(config)

  lib.map.map("n", "<c-p>", function()
    local opts = vim.deepcopy(config)
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
  end, "Find file in project")
  lib.map.map("n", ";", "<cmd>lua require('fzf-lua').buffers()<CR>", "Find buffer")
  lib.map.map("n", "<c-f>", "<cmd>lua require('fzf-lua').grep_project()<CR>", "Find text in project")
  lib.map.map("n", "<leader>l", "<cmd>lua require('fzf-lua').blines()<CR>", "Find line in buffer")
  lib.map.map("n", "<leader>L", "<cmd>lua require('fzf-lua').lines()<CR>", "Find line in project")
  lib.map.map("n", "<leader><leader>", "<cmd>lua require('fzf-lua').resume()<CR>", "Resume last fzf-lua command")
end

-- local setup_spider = function()
--   require("spider").setup({
--     skipInsignificantPunctuation = false,
--   })
-- end

return lib.module.create({
  name = "workflow/navigation",
  plugins = {
    {
      "ibhagwan/fzf-lua",
      dependencies = { "nvim-tree/nvim-web-devicons" },
      config = setup_fzf_lua,
    },
    { "vijaymarupudi/nvim-fzf" },
    -- { "chrisgrieser/nvim-spider", config = setup_spider },
  },
  -- mappings = {
  --   { { "n", "o", "x" }, "w", "<cmd>lua require('spider').motion('w')<CR>", { desc = "Spider-w" } },
  --   { { "n", "o", "x" }, "e", "<cmd>lua require('spider').motion('e')<CR>", { desc = "Spider-e" } },
  --   { { "n", "o", "x" }, "b", "<cmd>lua require('spider').motion('b')<CR>", { desc = "Spider-b" } },
  --   { { "n", "o", "x" }, "ge", "<cmd>lua require('spider').motion('ge')<CR>", { desc = "Spider-ge" } },
  -- },
})
