local lib = require("lib")

local config = {
  -- base
  clipboard = "unnamed,unnamedplus",
  fileformat = "unix",
  hidden = true,
  lazyredraw = true,
  modeline = false,
  mouse = "nv",
  secure = true,
  shell = "bash",
  shortmess = "filnxtToOFcs",
  termguicolors = true,
  timeout = false,
  title = true,
  ttimeout = false,
  visualbell = true,
  wrap = false,
  linebreak = true,
  updatetime = 50,
  laststatus = 3,
  sidescrolloff = 4,
  -- history and persistence
  backup = false,
  history = 10000,
  swapfile = false,
  undodir = vim.fn.stdpath("config") .. "/.undo/",
  viewdir = vim.fn.stdpath("config") .. "/.view/",
  undofile = true,
  undolevels = 10000,
  writebackup = false,
  -- sessions
  viewoptions = "cursor,folds",
  -- windows
  splitbelow = true,
  splitright = true,
  -- text editing
  autoindent = true,
  backspace = [[indent,eol,start]],
  formatoptions = "cqrt", -- "cront",
  joinspaces = false,
  -- completion
  complete = ".",
  completeopt = [[menuone,noselect]],
  -- search
  gdefault = true,
  ignorecase = true,
  inccommand = "split",
  magic = true,
  smartcase = true,
  -- folds
  -- foldcolumn = "1",
  foldenable = true,
  foldlevelstart = -1,
  foldlevel = 999,
  foldmethod = "expr",
  foldexpr = "nvim_treesitter#foldexpr()",
  -- foldnestmax = 1,
  -- code style
  expandtab = true,
  shiftround = true,
  shiftwidth = 2,
  tabstop = 2,
  -- visual
  cmdheight = 1,
  concealcursor = "nc",
  conceallevel = 2,
  cursorline = true,
  fillchars = {
    eob = " ",
    horiz = "━",
    horizup = "┻",
    horizdown = "┳",
    vert = "┃",
    vertleft = "┫",
    vertright = "┣",
    verthoriz = "╋",
    fold = " ",
  },
  list = true,
  ruler = false,
  listchars = {
    space = " ",
    tab = "  ",
    trail = "·",
    nbsp = "␣",
    extends = "›",
    precedes = "‹",
  },
  number = true,
  pumblend = 0,
  pumheight = 12,
  showmode = false,
  signcolumn = "yes",
  synmaxcol = 200,
  -- diff
  diffopt = [[hiddenoff,iwhiteall,algorithm:patience]],
}

return {
  setup = function()
    lib.options.set_bulk(config)
  end,
}
