-- local colors = require("config/colors")
local lush = require("lush")
local hsl = lush.hsl

-- https://github.com/search?q=language%3Alua+%22%40text.strong%22&type=code
-- https://github.com/RRethy/nvim-base16/blob/4f3aa29f49b38edb6db1c52cea57e64ce3de2373/lua/base16-colorscheme.lua#L383
-- https://github.com/ray-x/nvim/blob/8147b4d90361782d43d8a841d09868ef17d0a4c8/lua/modules/ui/galaxy.lua#L425

local colors = {
  none = "NONE",
  background = hsl(250, 12, 15),
  foreground = hsl(260, 12, 74),
  blue = hsl(200, 70, 60),
  cyan = hsl(180, 60, 52),
  green = hsl(130, 70, 60),
  indigo = hsl(290, 50, 65),
  magenta = hsl(320, 80, 70),
  orange = hsl(20, 92, 62),
  pink = hsl(310, 60, 70),
  red = hsl(0, 100, 70),
  yellow = hsl(38, 85, 60),
}
colors.plugins = {
  indent_guides = {
    indent = { colors.background.lighten(10) },
    chunk = colors.magenta.darken(40).desaturate(40),
  },
}

local variable = colors.foreground
local property = colors.foreground.saturation(20)
local field = colors.orange.saturation(70)
local keyword = colors.indigo
local control = colors.indigo.lighten(20).saturate(20)
local operator = colors.foreground
local delimiter = colors.foreground.darken(10).desaturate(20)

colors.common = {
  -- lab
  identifier = variable,
  constant = colors.yellow,
  keyword = keyword,
  property = property,
  field = field,
  -- base
  operator = operator,
  ["function"] = colors.blue,
  type = colors.cyan,
  parameter = colors.orange,
  -- comment = colors.orange.desaturate(75).darken(35),
  comment = colors.foreground.desaturate(30).darken(40),
  delimiter = delimiter,
  boolean = colors.red,
  number = colors.red,
  string = colors.green,
  -- control
  conditional = control,
  ["repeat"] = control,
  special_keyword = control.saturate(30).darken(10),
  -- extra
  builtin = colors.yellow,
  macro = keyword.lighten(40).saturate(70),
  ret = colors.red,
  constructor = colors.blue.lighten(10).desaturate(10),
  cword = colors.background.lighten(20),
}
colors.ui = {
  line = {
    line_nr = { fg = colors.background.lighten(20) },
    current_line = { bg = colors.background.lighten(10) },
    current_line_nr = { bg = colors.background.lighten(10), fg = colors.background.lighten(50) },
    current_line_sign = { bg = colors.background.lighten(10), fg = colors.orange },
  },
  split = colors.background.lighten(5),
  status = {
    a = { bg = colors.background.lighten(15), fg = colors.foreground.darken(10).desaturate(20) },
    b = { bg = colors.background.lighten(10), fg = colors.foreground.darken(15).desaturate(20) },
    c = { bg = colors.background.lighten(5), fg = colors.foreground.darken(20).desaturate(30) },
  },
  breadcrumbs = {
    normal = { bg = colors.background.lighten(5), fg = colors.foreground.darken(20).desaturate(30) },
    separator = { fg = colors.foreground.darken(30).desaturate(40) },
  },
}
colors.slang = {
  document = {
    title = colors.green.lighten(20).saturation(70),
    meta = colors.common.comment,
    meta_field = colors.magenta,
    meta_field_key = colors.pink,
  },
  string = colors.orange.desaturate(20),
  number = colors.common.number,
  ticket = "#fa89f6",
  datetime = "#FC824A",
  code = {
    inline = colors.orange.desaturate(10).lighten(10),
    block = {
      background = colors.background.lighten(10),
      marker = colors.background.lighten(20),
      language = colors.background.lighten(30),
      content = colors.foreground,
    },
  },
  link = {
    internal = "#5BC0CD",
    external = colors.blue.darken(10).desaturate(20),
  },
  outline = {
    one = hsl("#9999FF"),
    two = hsl("#C08FFF"),
    three = hsl("#E38FFF"),
    four = hsl("#FFC78F"),
    five = hsl("#04D3D0"),
    six = hsl("#f0969f"),
  },
  headline = {
    marker = colors.foreground.darken(20).desaturate(20),
    one = {
      bg = colors.indigo.rotate(-20).darken(70).saturation(20),
      fg = colors.indigo.rotate(-20).lighten(20).saturation(100),
    },
    two = {
      bg = colors.indigo.rotate(10).darken(70).saturation(20),
      fg = colors.indigo.rotate(10).lighten(20).saturation(100),
    },
    three = {
      bg = colors.indigo.rotate(40).darken(70).saturation(20),
      fg = colors.indigo.rotate(40).lighten(20).saturation(100),
    },
    four = {
      bg = colors.indigo.rotate(70).darken(70).saturation(20),
      fg = colors.indigo.rotate(70).lighten(20).saturation(100),
    },
    five = {
      bg = colors.indigo.rotate(100).darken(70).saturation(20),
      fg = colors.indigo.rotate(100).lighten(20).saturation(100),
    },
    six = {
      bg = colors.indigo.rotate(130).darken(70).saturation(20),
      fg = colors.indigo.rotate(130).lighten(20).saturation(100),
    },
  },
  section = "#8797C2",
  banner = {
    -- bg = "#262C3",
    bg = "#38425B",
    fg = "#A9B9E5", -- #8797C2
  },
  task = {
    default = colors.foreground,
    active = colors.cyan,
    done = colors.common.comment,
    cancelled = "#fa4040",
    session = "#7378a5",
    schedule = "#7378a5",
    recurrence = "#7378a5",
    completion = "#7378a5",
  },
  tag = {
    hash = "#5BC0EB",
    positive = "#9BC53D",
    negative = "#FA4224",
    context = colors.yellow,
    danger = { bg = "#C3423F", fg = "#ffffff" },
    identifier = "#e38fff",
  },
  list_item = {
    -- item = colors.foreground.desaturate(20).darken(10),
    marker = colors.foreground.desaturate(80).darken(40),
    label = colors.indigo.lighten(10).saturate(20), -- "#c881de",
    label_marker = colors.common.comment.darken(30),
  },
  label = colors.pink.darken(10).desaturate(20),
  label_line = colors.cyan.desaturate(10),
}

---@diagnostic disable: undefined-global
local theme = lush(function(injected)
  local sym = injected.sym
  return {
    -- base
    Normal({ bg = colors.background, fg = colors.foreground }), -- Normal text
    -- Normal({ fg = colors.foreground }), -- Normal text
    NormalFloat({}),
    NormalNC({}),
    NonText({ fg = colors.foreground.darken(20) }),
    EndOfBuffer({ fg = colors.background }),
    Visual({ bg = colors.background.lighten(20) }),
    Conceal({ fg = colors.foreground.darken(10) }),
    Folded({}),
    Whitespace({ fg = colors.foreground.darken(40).desaturate(80) }),
    SpecialKey({ Whitespace }),
    Directory({ fg = colors.blue }),
    ErrorMsg({ fg = colors.red.saturate(20) }),
    Title({ fg = colors.magenta }),
    MatchParen({ bg = colors.background.lighten(20) }),

    -- ui
    VertSplit({ fg = colors.ui.split }),
    FoldColumn({}),
    ColorColumn({}),
    Cursor({ bg = colors.foreground, fg = colors.background }),
    TermCursor({ Cursor }),
    TermCursorNC({ Cursor }),
    lCursor({}),
    CursorIM({}),
    CursorColumn({}),
    SignColumn({}),
    LineNr(colors.ui.line.line_nr),
    CursorLine(colors.ui.line.current_line),
    CursorLineNr(colors.ui.line.current_line_nr),
    CursorLineSign(colors.ui.line.current_line_sign),
    Pmenu({ bg = colors.background.lighten(10), fg = colors.foreground }),
    PmenuSel({ bg = colors.blue, fg = colors.background }),
    PmenuSbar({ bg = colors.background.lighten(20) }),
    PmenuThumb({ bg = colors.background.lighten(40) }),
    Winseparator({ VertSplit }), -- Separator between window splits. Inherts from |hl-VertSplit| by default, which it will replace eventually.
    TabLine({ bg = colors.background }), -- Tab pages line, not active tab page label
    TabLineFill({ bg = colors.background }), -- Tab pages line, where there are no labels
    TabLineSel({ bg = colors.background }), -- Tab pages line, active tab page label
    WarningMsg({}),
    WinBar({
      bg = colors.background.lighten(10).saturation(20),
      fg = colors.cyan.saturation(60),
      gui = "bold",
    }),
    WinBarNC({ WinBar }),
    -- ModeMsg      { }, -- 'showmode' message (e.g., "-- INSERT -- ")
    -- MsgArea      { }, -- Area for messages and cmdline
    -- MsgSeparator { }, -- Separator for scrolled messages, `msgsep` flag of 'display'
    -- MoreMsg      { }, -- |more-prompt|
    -- Question     { }, -- |hit-enter| prompt and yes/no questions
    -- QuickFixLine { }, -- Current |quickfix| item in the quickfix window. Combined with |hl-CursorLine| when the cursor is there.
    -- SpellBad     { }, -- Word that is not recognized by the spellchecker. |spell| Combined with the highlighting used otherwise.
    -- SpellCap     { }, -- Word that should start with a capital. |spell| Combined with the highlighting used otherwise.
    -- SpellLocal   { }, -- Word that is recognized by the spellchecker as one that is used in another region. |spell| Combined with the highlighting used otherwise.
    -- SpellRare    { }, -- Word that is recognized by the spellchecker as one that is hardly ever used. |spell| Combined with the highlighting used otherwise.
    -- StatusLine   { }, -- Status line of current window
    -- StatusLineNC { }, -- Status lines of not-current windows. Note: If this is equal to "StatusLine" Vim will use "^^^" in the status line of the current window.
    -- VisualNOS    { }, -- Visual mode selection when vim is "Not Owning the Selection".
    -- WildMenu     { }, -- Current match in 'wildmenu' completion

    -- search
    IncSearch({ bg = colors.yellow, fg = colors.background }),
    Search({ bg = colors.yellow.darken(20), fg = colors.background }),
    Substitute({ Search }),

    -- common
    Identifier({ fg = colors.common.identifier }),
    Statement({ fg = colors.common.keyword }),
    Conditional({ fg = colors.common.conditional }),
    Repeat({ fg = colors.common["repeat"] }),
    Label({ fg = colors.common.keyword }),
    Keyword({ fg = colors.common.keyword }),
    SpecialKeyword({ fg = colors.common.special_keyword }),
    Exception({ fg = colors.common.ret }),
    Operator({ fg = colors.common.operator }),
    Function({ fg = colors.common["function"] }),
    Type({ fg = colors.common.type }),
    Comment({ fg = colors.common.comment, gui = "italic" }),
    Constructor({ fg = colors.common.constructor }),
    Field({ fg = colors.common.field }),
    Property({ fg = colors.common.property }),
    Constant({ fg = colors.common.constant }),
    Boolean({ fg = colors.common.boolean }),
    Number({ fg = colors.common.number }),
    Float({ Number }),
    StorageClass({ Type }),
    Structure({ Type }),
    Typedef({ Type }),
    String({ fg = colors.common.string }),
    Character({ fg = colors.green }),
    Debug({ fg = colors.red }),
    Error({ fg = colors.red }),
    Todo({ fg = colors.yellow, gui = "bold,italic" }),
    PreProc({ fg = colors.common.keyword }),
    Macro({ fg = colors.common.macro }),
    Parameter({ fg = colors.common.parameter }),
    Include({ SpecialKeyword }),
    Define({ SpecialKeyword }),
    PreCondit({ SpecialKeyword }),
    Special({ fg = colors.orange.rotate(20) }),
    SpecialChar({ Special }),
    Tag({ Special }),
    Delimiter({ fg = colors.common.delimiter }),
    SpecialComment({ Comment }),
    Underlined({ gui = "undercurl" }),
    -- Ignore({}),

    -- LSP
    LspReferenceText({ bg = colors.foreground.darken(20) }),
    LspReferenceRead({ bg = colors.yellow.darken(20) }),
    LspReferenceWrite({ bg = colors.red.darken(20) }),
    LspCodeLens({ fg = colors.foreground.darken(20) }),
    LspCodeLensSeparator({ fg = colors.foreground.darken(40) }),
    LspSignatureActiveParameter({ fg = colors.blue }),

    -- diagnostics
    DiagnosticError({ fg = colors.red }),
    DiagnosticWarn({ fg = colors.orange }),
    DiagnosticInfo({ fg = colors.blue }),
    DiagnosticHint({ fg = colors.cyan }),
    DiagnosticVirtualTextError({ fg = colors.red }),
    DiagnosticVirtualTextWarn({ fg = colors.orange }),
    DiagnosticVirtualTextInfo({ fg = colors.blue }),
    DiagnosticVirtualTextHint({ fg = colors.cyan }),
    DiagnosticUnderlineError({ bg = colors.red.darken(70).desaturate(80), gui = "none" }),
    DiagnosticUnderlineWarn({ gui = "undercurl" }),
    DiagnosticUnderlineInfo({ gui = "undercurl" }),
    DiagnosticUnderlineHint({ gui = "undercurl" }),
    DiagnosticUnnecessary({ gui = "undercurl" }),
    DiagnosticFloatingError({ fg = colors.red }),
    DiagnosticFloatingWarn({ fg = colors.orange }),
    DiagnosticFloatingInfo({ fg = colors.blue }),
    DiagnosticFloatingHint({ fg = colors.cyan }),
    DiagnosticSignError({ fg = colors.red }),
    DiagnosticSignWarn({ fg = colors.orange }),
    DiagnosticSignInfo({ fg = colors.blue }),
    DiagnosticSignHint({ fg = colors.cyan }),

    -- diff
    DiffAdd({ fg = colors.green }),
    DiffChange({ fg = colors.yellow }),
    DiffDelete({ fg = colors.red }),
    DiffText({ fg = colors.blue }),
    diffAdded({ DiffAdd }),
    diffRemoved({ DiffDelete }),
    diffChanged({ DiffChange }),

    -- Tree-sitter
    sym("@none")({ bg = "NONE", fg = "NONE" }),
    sym("@attribute")({ PreProc }),
    sym("@boolean")({ Boolean }),
    sym("@character")({ Character }),
    sym("@character.special")({ SpecialChar }),
    sym("@comment")({ Comment }),
    sym("@conditional")({ Conditional }),
    sym("@constant")({ Constant }),
    sym("@builtin")({ fg = colors.common.builtin }),
    sym("@break")({ fg = colors.common.ret }),
    sym("@constant.builtin")({ sym("@boolean") }),
    sym("@constant.macro")({ Define }),
    sym("@constructor")({ Constructor }),
    sym("@debug")({ Debug }),
    sym("@define")({ Define }),
    sym("@error")({ Error }),
    sym("@exception")({ Exception }),
    sym("@field")({ Field }),
    sym("@float")({ Float }),
    sym("@function")({ Type }),
    sym("@function.builtin")({ sym("@builtin") }),
    sym("@function.call")({ Function }),
    sym("@function.method.call")({ Function }),
    sym("@function.macro")({ Macro }),
    sym("@include")({ Include }),
    sym("@keyword")({ Keyword }),
    sym("@keyword.function")({ Keyword }), -- or SpecialKeyword
    sym("@keyword.operator")({ SpecialKeyword }),
    sym("@keyword.coroutine")({ SpecialKeyword }),
    sym("@keyword.return")({ sym("@break") }),
    sym("@label")({ Label }),
    sym("@macro")({ Macro }),
    sym("@method")({ Function }),
    sym("@method.call")({ Function }),
    sym("@namespace")({ Type }),
    sym("@number")({ Number }),
    sym("@operator")({ Operator }),
    sym("@parameter")({ Parameter }),
    sym("@preproc")({ PreProc }),
    sym("@property")({ Property }),
    sym("@punctuation")({ Delimiter }),
    sym("@punctuation.bracket")({ Delimiter }),
    sym("@punctuation.delimiter")({ Delimiter }),
    sym("@punctuation.special")({ Delimiter }),
    sym("@repeat")({ Repeat }),
    sym("@storageclass")({ StorageClass }),
    sym("@string")({ String }),
    sym("@string.escape")({ SpecialChar }),
    sym("@string.regex")({ String }),
    sym("@string.special")({ SpecialChar }),
    sym("@structure")({ Structure }),
    sym("@symbol")({ Identifier }),
    sym("@tag")({ Tag }),
    sym("@tag.attribute")({ Identifier }),
    sym("@tag.delimiter")({ Delimiter }),
    sym("@text")({ Normal }),
    sym("@text.danger")({ ErrorMsg }),
    sym("@text.emphasis")({ gui = "italic" }),
    sym("@text.environment")({ Macro }),
    sym("@text.environment.name")({ Type }),
    sym("@text.literal")({ String }),
    sym("@text.literal.markdown")({ Normal }),
    sym("@text.literal.markdown_inline")({ Special }),
    sym("@text.math")({ Special }),
    sym("@text.note")({ SpecialComment }),
    sym("@text.reference")({ Underlined }),
    sym("@text.strike")({ gui = "strikethrough" }),
    sym("@text.strong")({ gui = "bold" }),
    sym("@text.title")({ Title }),
    sym("@text.todo")({ Todo }),
    sym("@text.todo.checked")({ Comment }),
    sym("@text.todo.unchecked")({ Todo }),
    sym("@text.underline")({ Underlined }),
    sym("@text.uri")({ Underlined }),
    sym("@text.warning")({ WarningMsg }),
    sym("@type")({ Type }),
    sym("@type.builtin")({ sym("@type") }),
    sym("@type.definition")({ Typedef }),
    sym("@type.qualifier")({ Type }),
    sym("@variable")({ Identifier }),
    sym("@variable.builtin")({ sym("@builtin") }),

    -- semantic tokens
    -- https://gist.github.com/swarn/fb37d9eefe1bc616c2a7e476c0bc0316
    -- https://github.com/Iron-E/nvim-highlite/blob/master-v4/lua/highlite/groups/default.lua#L240
    sym("@lsp.type.boolean")({ sym("@boolean") }),
    sym("@lsp.type.character")({ sym("@character") }),
    sym("@lsp.type.class")({ sym("@constructor") }),
    sym("@lsp.type.decorator")({ sym("@parameter") }),
    sym("@lsp.type.enum")({ sym("@constant") }),
    sym("@lsp.type.enumMember")({ sym("@constant") }),
    sym("@lsp.type.event")({ fg = colors.orange }),
    sym("@lsp.type.float")({ sym("@float") }),
    sym("@lsp.type.function")({}),
    sym("@lsp.type.identifier")({ Identifier }),
    sym("@lsp.type.interface")({ sym("@type") }),
    sym("@lsp.type.keyword")({ sym("@keyword") }),
    sym("@lsp.type.lifetime")({ fg = colors.pink }),
    sym("@lsp.type.macro")({ sym("@macro") }),
    sym("@lsp.type.method")({ sym("@method") }),
    sym("@lsp.type.namespace")({ sym("@constant") }),
    sym("@lsp.type.number")({ sym("@number") }),
    sym("@lsp.type.operator")({ sym("@operator") }),
    sym("@lsp.type.parameter")({ sym("@parameter") }),
    sym("@lsp.type.property")({ sym("@property") }),
    sym("@lsp.type.string")({ sym("@string") }),
    sym("@lsp.type.struct")({ sym("@structure") }),
    sym("@lsp.type.type")({ sym("@type") }),
    sym("@lsp.type.typeAlias")({ sym("@type.definition") }),
    sym("@lsp.type.typeParameter")({ sym("@type") }),
    sym("@lsp.type.variable")({ sym("@variable") }),
    sym("@lsp.mod.annotation")({ sym("@macro") }),
    sym("@lsp.mod.constant")({ Constant }),
    sym("@lsp.mod.interpolation")({ sym("@string.special") }),
    sym("@lsp.mod.readonly")({}),
    sym("@lsp.mod.static")({ gui = "italic" }),
    sym("@lsp.typemod.deriveHelper.attribute")({ sym("@attribute") }),
    sym("@lsp.typemod.function")({}),
    sym("@lsp.typemod.function.declaration")({ Identifier }),
    sym("@lsp.typemod.interface")({ sym("@type") }),
    sym("@lsp.typemod.property.declaration")({ sym("@field") }),
    sym("@lsp.typemod.string.constant")({}),
    sym("@lsp.typemod.string.readonly")({}),
    sym("@lsp.typemod.string.static")({}),
    sym("@lsp.typemod.type.readonly")({ sym("@type") }),
    sym("@lsp.typemod.typeParameter")({ sym("@type") }),
    sym("@lsp.typemod.variable")({ Identifier }),
    sym("@lsp.typemod.class.defaultLibrary")({ sym("@builtin") }),
    sym("@lsp.typemod.function.defaultLibrary")({ sym("@builtin") }),
    sym("@lsp.typemod.type.defaultLibrary")({ sym("@builtin") }),
    sym("@lsp.typemod.variable.defaultLibrary")({ sym("@builtin") }),

    -- lua
    sym("@constructor.lua")({ Delimiter }),
    sym("@namespace.builtin.lua")({ sym("@builtin") }),
    sym("@keyword.function.lua")({ Keyword }),
    sym("@keyword.conditional.lua")({ sym("@conditional") }),

    -- tsx
    sym("@constructor.tsx")({}),
    sym("@tag.tsx")({ SpecialKeyword }),
    sym("@tag.attribute.tsx")({ sym("Special") }),

    -- misc
    sym("@namespace")({ sym("@type") }),

    -- nvim-cmp
    CmpItemAbbr({ fg = colors.foreground }),
    CmpItemAbbrDeprecated({ fg = colors.common.comment, gui = "strikethrough" }),
    CmpItemKind({ fg = colors.blue }),
    CmpItemMenu({ fg = colors.common.comment }),
    CmpItemAbbrMatch({ fg = colors.blue }),
    CmpItemAbbrMatchFuzzy({ fg = colors.blue, gui = "bold" }),

    -- lspkind-nvim
    CmpItemKindSnippet({ fg = colors.indigo }),
    CmpItemKindKeyword({ fg = colors.common.keyword }),
    CmpItemKindText({ fg = colors.foreground }),
    CmpItemKindMethod({ fg = colors.common["function"] }),
    CmpItemKindConstructor({ fg = colors.common.constructor }),
    CmpItemKindFunction({ fg = colors.common["function"] }),
    CmpItemKindFolder({ fg = colors.blue }),
    CmpItemKindModule({ fg = colors.yellow }),
    CmpItemKindConstant({ fg = colors.common.constant }),
    CmpItemKindField({ fg = colors.common.field }),
    CmpItemKindProperty({ fg = colors.common.property }),
    CmpItemKindEnum({ fg = colors.common.type }),
    CmpItemKindUnit({ fg = colors.common.type }),
    CmpItemKindClass({ fg = colors.common.constructor }),
    CmpItemKindVariable({ fg = colors.common.identifier }),
    CmpItemKindFile({ fg = colors.blue }),
    CmpItemKindInterface({ fg = colors.common.type }),
    CmpItemKindColor({ fg = colors.purple }),
    CmpItemKindReference({ fg = colors.purple }),
    CmpItemKindEnumMember({ fg = colors.common.type }),
    CmpItemKindStruct({ fg = colors.common.type }),
    CmpItemKindValue({ fg = colors.common.boolean }),
    CmpItemKindEvent({ fg = colors.common.type }),
    CmpItemKindOperator({ fg = colors.common.operator }),
    CmpItemKindTypeParameter({ fg = colors.common.type }),
    CmpItemKindCopilot({ fg = colors.pink }),

    -- nvim-tree
    NvimTreeNormal({ bg = colors.background.lighten(2) }),
    NvimTreeWinSeparator({
      fg = colors.common.comment.darken(50),
      bg = colors.background.lighten(2),
    }),
    NvimTreeNormalNC({}),
    NvimTreeRootFolder({ fg = colors.blue, gui = "bold" }),
    NvimTreeGitDirty({ fg = colors.orange }),
    NvimTreeGitNew({ fg = colors.green }),
    NvimTreeGitDeleted({ fg = colors.red }),
    NvimTreeOpenedFile({ fg = colors.blue }),
    NvimTreeSpecialFile({ fg = colors.blue }),
    NvimTreeIndentMarker({ fg = colors.common.comment.darken(10) }),
    NvimTreeImageFile({}),
    NvimTreeSymlink({ fg = colors.purple }),
    NvimTreeFolderIcon({ fg = colors.blue.darken(10) }),
    NvimTreeFolderName({ fg = colors.foreground }),
    -- NvimTreeFileIcon({ fg = colors.orange }),

    -- gitsigns
    GitSignsAdd({ fg = colors.green.darken(20) }),
    GitSignsChange({ fg = colors.yellow.darken(20) }),
    GitSignsDelete({ fg = colors.red.darken(20) }),
    GitSignsAddPreview({ link = "DiffAdd" }),
    GitSignsDeletePreview({ link = "DiffDelete" }),

    -- ts-rainbow
    RainbowRed({ fg = colors.red.desaturate(25).darken(20) }),
    RainbowYellow({ fg = colors.yellow.desaturate(25).darken(20) }),
    RainbowBlue({ fg = colors.blue.desaturate(25).darken(20) }),
    RainbowOrange({ fg = colors.orange.desaturate(25).darken(20).darken(20) }),
    RainbowGreen({ fg = colors.green.rotate(50).desaturate(25) }),
    RainbowViolet({ fg = colors.magenta.desaturate(25).darken(20) }),
    RainbowCyan({ fg = colors.cyan.desaturate(25).darken(20) }),

    -- syslang
    sym("@slang.error")({ bg = "#7a2633", fg = "#ffffff" }),
    sym("@slang.document.title")({ fg = colors.slang.document.title, gui = "bold" }),
    sym("@slang.document.meta")({ fg = colors.slang.document.meta }),
    sym("@slang.document.meta.field")({ fg = colors.slang.document.meta_field }),
    sym("@slang.document.meta.field.key")({ fg = colors.slang.document.meta_field_key }),
    sym("@slang.bold")({ gui = "bold" }),
    sym("@slang.italic")({ gui = "italic" }),
    sym("@slang.underline")({ gui = "underline" }),
    sym("@slang.comment")({ fg = colors.common.comment }),
    sym("@slang.string")({ fg = colors.slang.string }),
    sym("@slang.number")({ fg = colors.slang.number }),
    sym("@slang.ticket")({ fg = colors.slang.ticket }),
    sym("@slang.time")({ fg = colors.slang.datetime }),
    sym("@slang.timerange")({ fg = colors.slang.datetime }),
    sym("@slang.date")({ fg = colors.slang.datetime }),
    sym("@slang.daterange")({ fg = colors.slang.datetime }),
    sym("@slang.datetime")({ fg = colors.slang.datetime }),
    sym("@slang.datetimerange")({ fg = colors.slang.datetime }),

    sym("@slang.outline_1.marker")({ fg = colors.slang.outline.one }),
    sym("@slang.outline_1.text")({ fg = colors.slang.outline.one, gui = "bold" }),
    sym("@slang.outline_2.marker")({ fg = colors.slang.outline.two }),
    sym("@slang.outline_2.text")({ fg = colors.slang.outline.two, gui = "bold" }),
    sym("@slang.outline_3.marker")({ fg = colors.slang.outline.three }),
    sym("@slang.outline_3.text")({ fg = colors.slang.outline.three, gui = "bold" }),
    sym("@slang.outline_4.marker")({ fg = colors.slang.outline.four }),
    sym("@slang.outline_4.text")({ fg = colors.slang.outline.four, gui = "bold" }),
    sym("@slang.outline_5.marker")({ fg = colors.slang.outline.five }),
    sym("@slang.outline_5.text")({ fg = colors.slang.outline.five, gui = "bold" }),
    sym("@slang.outline_6.marker")({ fg = colors.slang.outline.six }),
    sym("@slang.outline_6.text")({ fg = colors.slang.outline.six, gui = "bold" }),
    sym("@slang.outline_done")({ fg = colors.slang.task.done, gui = "bold" }),

    sym("@slang.heading_1.marker")({ fg = colors.slang.headline.marker }),
    sym("@slang.heading_2.marker")({ fg = colors.slang.headline.marker }),
    sym("@slang.heading_3.marker")({ fg = colors.slang.headline.marker }),
    sym("@slang.heading_4.marker")({ fg = colors.slang.headline.marker }),
    sym("@slang.heading_5.marker")({ fg = colors.slang.headline.marker }),
    sym("@slang.heading_6.marker")({ fg = colors.slang.headline.marker }),

    sym("@slang.heading_1.text")({ fg = colors.slang.headline.one.fg, gui = "bold" }),
    sym("@slang.heading_2.text")({ fg = colors.slang.headline.two.fg, gui = "bold" }),
    sym("@slang.heading_3.text")({ fg = colors.slang.headline.three.fg, gui = "bold" }),
    sym("@slang.heading_4.text")({ fg = colors.slang.headline.four.fg, gui = "bold" }),
    sym("@slang.heading_5.text")({ fg = colors.slang.headline.five.fg, gui = "bold" }),
    sym("@slang.heading_6.text")({ fg = colors.slang.headline.six.fg, gui = "bold" }),

    sym("@slang.section")({ fg = colors.slang.section }),
    sym("@slang.banner")({
      bg = colors.slang.banner.bg,
      fg = colors.slang.banner.fg,
    }),

    sym("@slang.task_default")({}),
    sym("@slang.task_marker_default")({ fg = colors.slang.task.done }),
    sym("@slang.task_active")({ fg = colors.slang.task.active }),
    sym("@slang.task_done")({ fg = colors.slang.task.done }),
    sym("@slang.task_cancelled")({ fg = colors.slang.task.cancelled }),
    sym("@slang.task_session")({ fg = colors.slang.task.session }),
    sym("@slang.task_schedule")({ fg = colors.slang.task.schedule }),
    sym("@slang.task_recurrence")({ fg = colors.slang.task.recurrence }),
    sym("@slang.task_completion")({ fg = colors.slang.task.completion }),
    sym("@slang.tag.hash")({ fg = colors.slang.tag.hash }),
    sym("@slang.tag.positive")({ fg = colors.slang.tag.positive }),
    sym("@slang.tag.negative")({ fg = colors.slang.tag.negative }),
    sym("@slang.tag.context")({ fg = colors.slang.tag.context }),
    sym("@slang.tag.danger")({ bg = colors.slang.tag.danger.bg, fg = colors.slang.tag.danger.fg }),
    sym("@slang.tag.identifier")({ fg = colors.slang.tag.identifier }),
    sym("@slang.link")({ fg = colors.slang.link.internal, gui = "italic" }),
    sym("@slang.external_link")({ fg = colors.slang.link.external, gui = "italic" }),
    sym("@slang.internal_link")({ fg = colors.slang.link.internal, gui = "" }),
    sym("@slang.inline_code")({ fg = colors.slang.code.inline }),
    sym("@slang.code_block_start")({ fg = colors.slang.code.block.marker, gui = "italic" }),
    sym("@slang.code_block_language")({ fg = colors.slang.code.block.language, gui = "italic" }),
    sym("@slang.code_block_fence")({ bg = colors.slang.code.block.background }),
    sym("@slang.code_block_content")({ fg = colors.slang.code.block.content }),
    sym("@slang.code_block_end")({ fg = colors.slang.code.block.marker, gui = "italic" }),
    sym("@slang.label")({ fg = colors.slang.label }),
    sym("@slang.label_line")({ fg = colors.slang.label_line }),
    sym("@slang.list_item")({ fg = colors.slang.list_item.item }),
    sym("@slang.list_item_marker")({ fg = colors.slang.list_item.marker }),
    sym("@slang.list_item_label")({ fg = colors.slang.list_item.label }),
    sym("@slang.list_item_label_marker")({ fg = colors.slang.list_item.label_marker }),
    sym("@slang.image")({ fg = colors.slang.label }),
    sym("@text.literal.syslang")({ fg = colors.foreground }),

    -- headlines
    sym("Headline1")({ bg = colors.slang.headline.one.bg }),
    sym("Headline2")({ bg = colors.slang.headline.two.bg }),
    sym("Headline3")({ bg = colors.slang.headline.three.bg }),
    sym("Headline4")({ bg = colors.slang.headline.four.bg }),
    sym("Headline5")({ bg = colors.slang.headline.five.bg }),
    sym("Headline6")({ bg = colors.slang.headline.six.bg }),
    sym("Quote")({ fg = colors.slang.banner.bg, gui = "bold" }),
    sym("CodeBlock")({ bg = colors.slang.code.block.background }),

    -- local-highlight
    CWordHighlight({ bg = colors.common.cword }),

    -- highlight-undo
    HighlightUndo({ bg = colors.orange.darken(50), fg = colors.orange }),
  }
end)

-- inject colors for shipwright
lib.metatable.decorate_non_enumerable(theme, { colors = colors })

return theme
