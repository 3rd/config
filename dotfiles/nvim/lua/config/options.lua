local env = require("lib/env")

return {
  -- base
  clipboard = "unnamed,unnamedplus",
  fileformat = "unix",
  hidden = true,
  lazyredraw = false,
  modeline = false,
  mouse = "nv",
  secure = true,
  shell = vim.fn.exepath("bash"),
  shortmess = "filnxtToOFcs",
  termguicolors = true,
  title = true,
  visualbell = true,
  wrap = false,
  linebreak = true,
  updatetime = 0,
  laststatus = 3,
  scrolloff = 8,
  sidescrolloff = 16,
  timeout = true,
  timeoutlen = 1000,
  ttimeoutlen = 0,
  -- ttimeout = false,

  -- history and persistence
  backup = false,
  backupdir = env.dirs.vim.backup,
  history = 10000,
  swapfile = false,
  undodir = env.dirs.vim.undo,
  viewdir = env.dirs.vim.view,
  undofile = true,
  undolevels = 10000,
  writebackup = false,
  jumpoptions = "view",
  shada = {
    "!",
    "'1000",
    "<100",
    "s100",
    "h",
  },

  -- sessions
  viewoptions = "cursor,folds",
  -- windows
  splitbelow = true,
  splitright = true,
  equalalways = false,
  splitkeep = "screen",
  winborder = "rounded",
  -- text editing
  autoindent = true,
  backspace = [[indent,eol,start]],
  formatoptions = "tcqjn12", -- "cront",
  joinspaces = false,
  textwidth = 999,
  -- completion
  complete = ".",
  completeopt = [[menu,menuone,noselect]],
  -- search
  gdefault = true,
  ignorecase = true,
  inccommand = "split",
  magic = true,
  smartcase = true,
  grepprg = [[rg --glob "!.git" --no-heading --vimgrep --follow $*]],
  -- folds
  -- foldcolumn = "1",
  foldenable = true,
  foldlevel = 999,
  foldlevelstart = 999,
  foldopen = "mark,percent,quickfix,search,tag,undo",
  -- foldmethod = "expr",
  -- foldexpr = "v:lua.vim.treesitter.foldexpr()", -- this fucks up tree-sitter folds
  -- foldexpr = "nvim_treesitter#foldexpr()",
  -- foldnestmax = 1,
  -- code style
  expandtab = true,
  shiftround = true,
  shiftwidth = 2,
  tabstop = 2,
  report = 500,
  -- visual
  showtabline = 1,
  cmdheight = 1,
  concealcursor = "c",
  conceallevel = 2,
  cursorline = true,
  cursorlineopt = "number,screenline",
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
  smoothscroll = true,
  -- diff
  diffopt = [[hiddenoff,iwhiteall,algorithm:patience]],
}
