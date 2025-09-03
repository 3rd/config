return {
  leader = " ",
  localleader = " ",
  defaultOptions = { silent = true },
  default = {
    -- general
    { "n", "<leader>q", ":qa<cr>", "Quit" },
    { "n", "<ESC>", "<esc>:noh<cr><esc>", "Clear search" },
    -- https://github.com/neovim/neovim/issues/14090#issuecomment-1113090354
    { "n", "<C-I>", "<C-I>" },
    -- buffer
    { { "n", "i" }, "<C-s>", "<ESC>:silent w<CR>", "Save buffer" },
    { "n", "<C-w>", "<ESC>:bd<CR>", "Close buffer" },
    -- text operations
    { "n", "Y", "y$", "Yank to end of line" },
    { "n", "J", "mzJ`z", "Join with the next line" },
    -- search
    {
      "n",
      "n",
      function()
        -- if vim.fn.searchcount() == 0 then
        --   vim.cmd("normal! nzzzv")
        -- else
        --   vim.cmd("normal! *")
        -- end
        vim.cmd("normal! nzzzv")
      end,
      "Next search result",
    },
    {
      "n",
      "N",
      function()
        -- if vim.fn.searchcount() == 0 then
        --   vim.cmd("normal! Nzzzv")
        -- else
        --   vim.cmd("normal! #")
        -- end
        vim.cmd("normal! Nzzzv")
      end,
      "Previous search result",
    },
    -- https://github.com/davidosomething/dotfiles/blob/be22db1fc97d49516f52cef5c2306528e0bf6028/nvim/lua/dko/mappings.lua#L171
    { "n", "*", "m`<Cmd>keepjumps normal! *``<CR>", "Search word under cursor" },
    { "v", "/", [[<esc>/\%V]], "Search in selection" },
    -- wrap
    { "n", "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, desc = "Move down" } },
    { "n", "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, desc = "Move up" } },
    -- folds
    -- { "n", "<tab>", "za", "Toggle fold" },
    -- { "n", "<s-tab>", "zc", "Close fold" },
    -- extend undo
    { "i", ".", ".<c-g>u" },
    { "i", ";", ";<c-g>u" },
    { "i", ",", ",<c-g>u" },
    { "i", "(", "(<c-g>u" },
    { "i", "{", "{<c-g>u" },
    { "i", "[", "[<c-g>u" },
    -- emacsy insert & command mode
    { "i", "<C-a>", "<home>" },
    { "i", "<C-e>", "<end>" },
    { "i", "<C-d>", "<delete>" },
    { "c", "<C-a>", "<home>" },
    { "c", "<C-e>", "<end>" },
    { "c", "<C-d>", "<delete>" },
    -- change indent
    { "n", "<", "<<", "Decrease indent" },
    { "n", ">", ">>", "Increase indent" },
    { "v", "<", "<gv", "Decrease indent" },
    { "v", ">", ">gv", "Increase indent" },
    -- move lines
    { "n", "<a-j>", "<cmd>execute 'move .+' . v:count1<cr>==", "Move line down" },
    { "n", "<a-k>", "<cmd>execute 'move .-' . (v:count1 + 1)<cr>==", "Move line up" },
    { "i", "<a-j>", "<esc><cmd>m .+1<cr>==gi", "Move line down" },
    { "i", "<a-k>", "<esc><cmd>m .-2<cr>==gi", "Move line up" },
    { "v", "<a-j>", ":<C-u>execute \"'<,'>move '>+\" . v:count1<cr>gv=gv", "Move lines down" },
    { "v", "<a-k>", ":<C-u>execute \"'<,'>move '<-\" . (v:count1 + 1)<cr>gv=gv", "Move lines up" },
    -- navigation
    { "n", "<c-h>", "<c-w>h", "Focus left" },
    { "n", "<c-j>", "<c-w>j", "Focus down" },
    { "n", "<c-k>", "<c-w>k", "Focus up" },
    { "n", "<c-l>", "<c-w>l", "Focus right" },
    -- window management
    { "n", "<down>", ":resize +2<cr>", "Resize window down" },
    { "n", "<up>", ":resize -2<cr>", "Resize window up" },
    { "n", "<left>", ":vertical resize -2<cr>", "Resize window left" },
    { "n", "<right>", ":vertical resize +2<cr>", "Resize window right" },
    { "n", "==", ":tabdo wincmd =<cr>" },
    -- comments
    { "n", "<c-_>", "gcc", { remap = true, desc = "Toggle comment" } },
    { "v", "<c-_>", "gc", { remap = true, desc = "Toggle comment" } },
    { "n", "<c-/>", "gcc", { remap = true, desc = "Toggle comment" } },
    { "v", "<c-/>", "gc", { remap = true, desc = "Toggle comment" } },
    -- diagnostics
    { "n", "gp", "<cmd>lua vim.diagnostic.goto_next()<cr>", "LSP: Go to next diagnostic" },
    { "n", "gP", "<cmd>lua vim.diagnostic.goto_prev()<cr>", "LSP: Go to previous diagnostic" },
    -- undo
    { "i", ",", ",<c-g>U" },
    { "i", ".", ".<c-g>U" },
    { "i", ";", ";<c-g>U" },
    { "i", "!", "!<c-g>U" },
    { "i", "?", "?<c-g>U" },
    -- misc
    { "n", "Q", "@q", "Run @q macro" },
    -- experiments
    { "n", "<c-c>", "ciw" },
    { "n", "K", "<cmd>lua vim.lsp.buf.hover()<CR>", "LSP: Show hover" },
    { "n", "gd", "<cmd>lua vim.lsp.buf.definition()<CR>", "LSP: Go to definition" },
    -- {
    --   "n",
    --   "gvd",
    --   function()
    --     vim.lsp.buf.definition({
    --       on_list = function(options)
    --         local item = options.items[1]
    --         local cmd = "vsplit +" .. item.lnum .. " " .. item.filename .. "|" .. "normal " .. item.col .. "|"
    --         vim.cmd(cmd)
    --       end,
    --     })
    --   end,
    --   "LSP: Go to definition (vsplit)",
    -- },
    { "n", "gD", "<cmd>lua vim.lsp.buf.declaration()<CR>", "LSP: Go to declaration" },
    { "n", "gr", "<cmd>lua require('fzf-lua').lsp_references()<CR>", "LSP: Go to references" },
    { "n", "gi", "<cmd>lua vim.lsp.buf.implementation()<CR>", "LSP: Go to implementation" },
    { "n", "gt", "<cmd>lua vim.lsp.buf.type_definition()<CR>", "LSP: Go to type definition" },
    -- { "n", "gs", "<cmd>lua vim.lsp.buf.signature_help()<CR>", "LSP: Show signature help" },
    -- { { "n", "v" }, "<leader>ac", "<cmd>lua vim.lsp.buf.code_action()<cr>", "LSP: Code action" },
    { "n", "<leader>er", "<cmd>lua vim.lsp.buf.rename()<cr>", "LSP: Rename symbol" },
    -- { "n", "<leader>r", "<cmd>lua require('fzf-lua').lsp_document_symbols()<CR>", "LSP: Show document symbols" },
    {
      "n",
      "<leader>R",
      function()
        require("fzf-lua").lsp_workspace_symbols({
          -- async = false,
          file_ignore_patterns = { "node_modules" },
          no_header_i = true,
          previewer = "builtin",
        })
      end,
      "LSP: Show workspace symbols",
    },
  },
  lsp = {},
}

-- todo: neovide tmux
-- { "n", "<C-a>c", ":tabnew<cr>", "New tab" },
-- { "n", "<C-a>h", ":tabprevious<cr>", "Previous tab" },
-- { "n", "<C-a>l", ":tabnext<cr>", "Next tab" },
-- { "n", "<C-a>x", ":tabclose<cr>", "Close tab" },
-- { "n", "<C-a>s", ":new<cr>" },
-- { "n", "<C-a>v", ":vnew<cr>" },
-- { "n", "<C-a>x", ":bwipeout!<cr>" },
-- { "n", "<M-1>", ":tabfirst<cr>" },
-- { "n", "<M-2>", ":tabn 2<cr>" },
-- { "n", "<M-3>", ":tabn 3<cr>" },
-- { "n", "<M-4>", ":tabn 4<cr>" },
-- { "n", "<M-5>", ":tabn 5<cr>" },
-- { "n", "<M-6>", ":tabn 6<cr>" },
