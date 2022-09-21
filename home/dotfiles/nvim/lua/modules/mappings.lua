local lib = require("lib")

local config = {
  leader = "<space>",
  mappings = {
    -- meta
    { "n", "<leader>q", ":qa<cr>" },
    { "n", "<ESC>", "<esc>:noh<cr><esc>" },
    { "n", "Y", "y$" },
    { "n", "n", "nzzzv" },
    { "n", "N", "Nzzzv" },
    { "n", "J", "mzJ`z" },
    { "n", "c", '"_c' },
    { "n", "C", '"_C' },
    { "n", "cc", '"_cc' },
    { "n", "cL", "S" },
    { "n", "Q", "@q" },
    { "v", "/", [[<esc>/\%V\v]] },
    -- emacsy
    { "i", "<C-a>", "<home>" },
    { "i", "<C-e>", "<end>" },
    { "i", "<C-d>", "<delete>" },
    { "c", "<C-a>", "<home>" },
    { "c", "<C-e>", "<end>" },
    { "c", "<C-d>", "<delete>" },
    -- extend undo
    { "i", ".", ".<c-g>u" },
    { "i", ";", ";<c-g>u" },
    { "i", ",", ",<c-g>u" },
    { "i", "(", "(<c-g>u" },
    { "i", "{", "{<c-g>u" },
    { "i", "[", "[<c-g>u" },
    -- indent
    { "n", "<", "<<" },
    { "n", ">", ">>" },
    { "v", "<", "<gv" },
    { "v", ">", ">gv" },
    -- move lines
    { "n", "<A-j>", "mz:m+<cr>`z" },
    { "n", "<A-k>", "mz:m-2<cr>`z" },
    { "v", "<A-j>", ":m'>+<cr>`<my`>mzgv`yo`z" },
    { "v", "<A-k>", ":m'<-2<cr>`>my`<mzgv`yo`z" },
    -- navigate wrapped text
    { "n", "k", "v:count == 0 ? 'gk' : 'k'", { noremap = true, expr = true, silent = true } },
    { "n", "j", "v:count == 0 ? 'gj' : 'j'", { noremap = true, expr = true, silent = true } },
    -- buffer
    { "n", "<C-s>", "<ESC>:w<CR>" },
    { "i", "<C-s>", "<ESC>:w<CR>" },
    -- navigation
    { "n", ";", ":Buffers<cr>" },
    { "n", "<BS>", "<c-^>" },
    { "n", "<C-p>", ":Files<cr>" },
    { "n", "<C-f>", ":RgNoMatchFilenames<cr>" },
    { "n", "<leader>l", ":Lines<cr>" },
    { "n", "-", ":lua require('modules/workflow/file-manager').export.toggle_or_focus_file_tree()<cr>" },
    -- comments
    { "n", "<c-_>", "gcc", { noremap = false } },
    { "v", "<c-_>", "gc", { noremap = false } },
    { "n", "<c-/>", "gcc", { noremap = false } },
    { "v", "<c-/>", "gc", { noremap = false } },
    -- fix https://github.com/neovim/neovim/issues/14090#issuecomment-1113090354
    { "n", "<C-I>", "<C-I>" },
    { "n", "<Tab>", "za" },
    { "n", "<S-Tab>", "zc" },
  },
}

local setup = function()
  local mapleader_key = config.leader == "<space>" and " " or config.leader
  vim.api.nvim_set_keymap("", config.leader, "<nop>", { noremap = true, silent = true })
  vim.g.mapleader = mapleader_key
  vim.g.maplocalleader = mapleader_key

  lib.map.bulk(config.mappings)

  local modules = lib.module.get_enabled_modules()
  for _, module in ipairs(modules) do
    if module.mappings then
      lib.map.bulk(module.mappings)
    end
  end
end

return {
  setup = setup,
}
