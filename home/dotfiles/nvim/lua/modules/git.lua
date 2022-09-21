local setup_git_messenger = function()
  vim.g.git_messenger_no_default_mappings = true
  vim.g.git_messenger_always_into_popup = true
  vim.g.git_messenger_extra_blame_args = "-w"
  vim.g.git_messenger_floating_win_opts = { border = "single" }
  vim.g.git_messenger_popup_content_margins = false
  vim.g.git_messenger_include_diff = "current"

  local group = vim.api.nvim_create_augroup("git/git-messenger", { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    desc = "Extend git-messenger mappings",
    pattern = "gitmessengerpopup",
    group = group,
    callback = function()
      require("lib.map").maplocal("n", "<C-o>", "o")
      require("lib.map").maplocal("n", "<C-i>", "O")
    end,
  })
end

-- TODO https://github.com/lewis6991/gitsigns.nvim#keymaps
local setup_git_signs = function()
  local gitsigns = require("gitsigns")
  local lib = require("lib")

  if lib.path.cwd_is_git_repo() then
    gitsigns.setup({
      numhl = true,
      signs = {
        add = { hl = "GitSignsAdd", text = "│", numhl = "GitSignsAddNr", linehl = "GitSignsAddLn" },
        change = { hl = "GitSignsChange", text = "│", numhl = "GitSignsChangeNr", linehl = "GitSignsChangeLn" },
        delete = { hl = "GitSignsDelete", text = "_", numhl = "GitSignsDeleteNr", linehl = "GitSignsDeleteLn" },
        topdelete = { hl = "GitSignsDelete", text = "‾", numhl = "GitSignsDeleteNr", linehl = "GitSignsDeleteLn" },
        changedelete = { hl = "GitSignsChange", text = "~", numhl = "GitSignsChangeNr", linehl = "GitSignsChangeLn" },
      },
    })
  end
end

return require("lib").module.create({
  name = "git",
  plugins = {
    { "tpope/vim-fugitive" },
    { "rhysd/git-messenger.vim", config = setup_git_messenger },
    { "lewis6991/gitsigns.nvim", requires = { "nvim-lua/plenary.nvim" }, config = setup_git_signs },
  },
  mappings = {
    { "n", "<leader>b", ":GitMessenger<cr>" },
  },
})
