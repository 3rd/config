local lush = require("lush")
local colors = require("config/colors")

---@diagnostic disable: undefined-global
local theme = lush(function(injected)
  local sym = injected.sym
  return {
    -- Normal({ bg = colors.background, fg = colors.foreground }), -- Normal text
    Normal({ fg = colors.foreground }), -- Normal text
    NormalFloat({}),
    NormalNC({}),
    NonText({ fg = colors.foreground.darken(20) }),
    EndOfBuffer({ fg = colors.background }),

    VertSplit({ fg = colors.background.lighten(10) }),
    FoldColumn({}),
    ColorColumn({}),
    Cursor({ bg = colors.foreground, fg = colors.background }),
    lCursor({}),
    CursorIM({}),
    CursorColumn({}),

    Visual({ bg = colors.background.lighten(20) }),
    Conceal({ fg = colors.foreground.darken(10) }),
    Folded({}),
    Whitespace({ fg = colors.foreground.darken(40).desaturate(80) }),
    SpecialKey({ Whitespace }),

    Directory({ fg = colors.blue }),
    ErrorMsg({ fg = colors.red.saturate(20) }),

    DiffAdd({ fg = colors.green }),
    DiffChange({ fg = colors.yellow }),
    DiffDelete({ fg = colors.red }),
    DiffText({ fg = colors.blue }),
    diffAdded({ DiffAdd }),
    diffRemoved({ DiffDelete }),
    diffChanged({ DiffChange }),

    TermCursor({}), -- Cursor in a focused terminal
    TermCursorNC({}), -- Cursor in an unfocused terminal

    LineNr({ fg = colors.background.lighten(25).saturate(5) }),
    SignColumn({}),
    CursorLine({ bg = colors.background.lighten(10) }),
    CursorLineNr({ bg = colors.background.lighten(10), fg = colors.background.lighten(50) }),
    CursorLineSign({ bg = colors.background.lighten(10), fg = colors.orange }),

    IncSearch({ bg = colors.yellow, fg = colors.background }),
    Search({ bg = colors.yellow.darken(20), fg = colors.background }),
    Substitute({ Search }),

    Pmenu({ bg = colors.background.lighten(10), fg = colors.foreground }),
    PmenuSel({ bg = colors.blue, fg = colors.background }),
    PmenuSbar({ bg = colors.background.lighten(20) }),
    PmenuThumb({ bg = colors.background.lighten(40) }),

    Title({ fg = colors.magenta }),
    MatchParen({ bg = colors.background.lighten(20) }),

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
    -- TabLine      { }, -- Tab pages line, not active tab page label
    -- TabLineFill  { }, -- Tab pages line, where there are no labels
    -- TabLineSel   { }, -- Tab pages line, active tab page label
    -- VisualNOS    { }, -- Visual mode selection when vim is "Not Owning the Selection".
    -- WarningMsg   { }, -- Warning messages
    -- Winseparator { }, -- Separator between window splits. Inherts from |hl-VertSplit| by default, which it will replace eventually.
    -- WildMenu     { }, -- Current match in 'wildmenu' completion

    -- common
    Identifier({ fg = colors.common.identifier }),
    Statement({ fg = colors.common.keyword }),
    Conditional({ fg = colors.common.keyword }),
    Repeat({ fg = colors.common.keyword }),
    Label({ fg = colors.common.keyword }),
    Keyword({ fg = colors.common.keyword }),
    Exception({ fg = colors.common.keyword }),
    Operator({ fg = colors.common.operator }),
    Function({ fg = colors.common["function"] }),
    Type({ fg = colors.common.type }),
    Comment({ fg = colors.common.comment }),
    Constructor({ fg = colors.common.constructor }),
    Field({ fg = colors.common.field }),
    -- blue
    Constant({ fg = colors.blue }),
    Boolean({ fg = colors.blue }),
    Number({ fg = colors.blue }),
    Float({ Number }),
    -- cyan
    StorageClass({ Type }),
    Structure({ Type }),
    Typedef({ Type }),
    -- green
    String({ fg = colors.green }),
    Character({ fg = colors.green }),
    -- red
    Debug({ fg = colors.red }),
    Error({ fg = colors.red }),
    -- yellow
    Todo({ fg = colors.yellow, gui = "bold,italic" }),
    -- magenta
    PreProc({ fg = colors.magenta }),
    Include({ PreProc }),
    Define({ PreProc }),
    Macro({ PreProc }),
    PreCondit({ PreProc }),
    -- orange
    Special({ fg = colors.orange }),
    SpecialChar({ Special }),
    Tag({ Special }),
    -- extra
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

    -- Diagnostics
    DiagnosticError({ fg = colors.red }),
    DiagnosticWarn({ fg = colors.orange }),
    DiagnosticInfo({ fg = colors.blue }),
    DiagnosticHint({ fg = colors.cyan }),
    DiagnosticVirtualTextError({ fg = colors.red }),
    DiagnosticVirtualTextWarn({ fg = colors.orange.darken(40) }),
    DiagnosticVirtualTextInfo({ fg = colors.blue }),
    DiagnosticVirtualTextHint({ fg = colors.cyan }),
    DiagnosticUnderlineError({ gui = "undercurl", sp = colors.red }),
    DiagnosticUnderlineWarn({ gui = "undercurl", sp = colors.orange }),
    DiagnosticUnderlineInfo({ gui = "undercurl", sp = colors.blue }),
    DiagnosticUnderlineHint({ gui = "undercurl", sp = colors.cyan }),
    DiagnosticFloatingError({ fg = colors.red }),
    DiagnosticFloatingWarn({ fg = colors.orange }),
    DiagnosticFloatingInfo({ fg = colors.blue }),
    DiagnosticFloatingHint({ fg = colors.cyan }),
    DiagnosticSignError({ fg = colors.red }),
    DiagnosticSignWarn({ fg = colors.orange }),
    DiagnosticSignInfo({ fg = colors.blue }),
    DiagnosticSignHint({ fg = colors.cyan }),

    -- Tree-sitter
    sym("@text.literal")({ Comment }),
    sym("@text.reference")({ Tag }),
    sym("@text.title")({ Title }),
    sym("@text.uri")({ Underlined }),
    sym("@text.underline")({ Underlined }),
    sym("@text.todo")({ Todo }),
    sym("@comment")({ Comment }),
    sym("@punctuation")({ Delimiter }),
    sym("@punctuation.bracket")({ Delimiter }),
    sym("@constant")({ Constant }),
    sym("@constant.builtin")({ Special }),
    sym("@constant.macro")({ Macro }),
    sym("@define")({ Define }),
    sym("@macro")({ Macro }),
    sym("@string")({ String }),
    sym("@string.escape")({ SpecialChar }),
    sym("@string.special")({ SpecialChar }),
    sym("@character")({ Character }),
    sym("@character.special")({ SpecialChar }),
    sym("@number")({ Number }),
    sym("@boolean")({ Boolean }),
    sym("@float")({ Float }),
    sym("@function")({ Function }),
    sym("@function.builtin")({ Special }),
    sym("@function.macro")({ Macro }),
    sym("@parameter")({ Special }),
    sym("@method")({ Function }),
    sym("@field")({ Field }),
    sym("@property")({ Field }),
    sym("@constructor")({ Constructor }),
    sym("@conditional")({ Conditional }),
    sym("@repeat")({ Repeat }),
    sym("@label")({ Label }),
    sym("@operator")({ Operator }),
    sym("@keyword")({ Keyword }),
    sym("@exception")({ Exception }),
    sym("@variable")({ Identifier }),
    sym("@variable.builtin")({ PreProc }),
    sym("@type")({ Type }),
    sym("@type.definition")({ Typedef }),
    sym("@storageclass")({ StorageClass }),
    sym("@structure")({ Structure }),
    sym("@namespace")({ Structure }),
    sym("@include")({ Include }),
    sym("@preproc")({ PreProc }),
    sym("@debug")({ Debug }),
    sym("@tag")({ Tag }),

    -- semantic tokens
    -- https://gist.github.com/swarn/fb37d9eefe1bc616c2a7e476c0bc0316
    sym("@lsp.type.class")({ sym("@constructor") }),
    sym("@lsp.type.decorator")({ sym("@parameter") }),
    sym("@lsp.type.enum")({ sym("@type") }),
    sym("@lsp.type.enumMember")({ sym("@constant") }),
    sym("@lsp.type.function")({ sym("@function") }),
    sym("@lsp.type.interface")({ sym("@keyword") }),
    sym("@lsp.type.macro")({ sym("@macro") }),
    sym("@lsp.type.method")({ sym("@method") }),
    sym("@lsp.type.namespace")({ sym("@namespace") }),
    sym("@lsp.type.parameter")({ sym("@parameter") }),
    sym("@lsp.type.property")({ sym("@property") }),
    sym("@lsp.type.struct")({ sym("@constructor") }),
    sym("@lsp.type.type")({ sym("@type") }),
    sym("@lsp.type.typeParameter")({ sym("@type.definition") }),
    sym("@lsp.type.variable")({ sym("@variable") }),
    -- sym("@lsp.type.keyword")({ sym("@keyword") }),

    -- nvim-cmp
    CmpItemAbbr({ fg = colors.foreground }),
    CmpItemAbbrDeprecated({ fg = colors.common.comment, gui = "strikethrough" }),
    CmpItemKind({ fg = colors.blue }),
    CmpItemMenu({ fg = colors.common.comment }),
    CmpItemAbbrMatch({ fg = colors.blue }),
    CmpItemAbbrMatchFuzzy({ fg = colors.blue, gui = "bold" }),

    -- lspkind-nvim
    CmpItemKindSnippet({ fg = colors.purple }),
    CmpItemKindKeyword({ fg = colors.red }),
    CmpItemKindText({ fg = colors.foreground }),
    CmpItemKindMethod({ fg = colors.blue }),
    CmpItemKindConstructor({ fg = colors.cyan }),
    CmpItemKindFunction({ fg = colors.blue }),
    CmpItemKindFolder({ fg = colors.blue }),
    CmpItemKindModule({ fg = colors.yellow }),
    CmpItemKindConstant({ fg = colors.cyan }),
    CmpItemKindField({ fg = colors.orange }),
    CmpItemKindProperty({ fg = colors.orange }),
    CmpItemKindEnum({ fg = colors.cyan }),
    CmpItemKindUnit({ fg = colors.cyan }),
    CmpItemKindClass({ fg = colors.blue }),
    CmpItemKindVariable({ fg = colors.foreground }),
    CmpItemKindFile({ fg = colors.blue }),
    CmpItemKindInterface({ fg = colors.cyan }),
    CmpItemKindColor({ fg = colors.purple }),
    CmpItemKindReference({ fg = colors.purple }),
    CmpItemKindEnumMember({ fg = colors.cyan }),
    CmpItemKindStruct({ fg = colors.cyan }),
    CmpItemKindValue({ fg = colors.purple }),
    CmpItemKindEvent({ fg = colors.yellow }),
    CmpItemKindOperator({ fg = colors.foreground }),
    CmpItemKindTypeParameter({ fg = colors.purple }),
    CmpItemKindCopilot({ fg = colors.pink }),

    -- indent-blankline
    IndentBlanklineChar({ fg = colors.common.comment.darken(40).desaturate(20) }),
    IndentBlanklineIndent1({ fg = colors.common.comment.darken(40).desaturate(20) }),
    IndentBlanklineIndent2({ fg = colors.common.comment.darken(45).desaturate(20) }),
    IndentBlanklineIndent3({ fg = colors.common.comment.darken(50).desaturate(20) }),
    IndentBlanklineIndent4({ fg = colors.common.comment.darken(55).desaturate(20) }),
    IndentBlanklineIndent5({ fg = colors.common.comment.darken(60).desaturate(20) }),
    IndentBlanklineIndent6({ fg = colors.common.comment.darken(65).desaturate(20) }),

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

    -- gitsigns
    GitSignsAdd({ fg = colors.green.darken(20) }),
    GitSignsChange({ fg = colors.yellow.darken(20) }),
    GitSignsDelete({ fg = colors.red.darken(20) }),
    GitSignsAddPreview({ link = "DiffAdd" }),
    GitSignsDeletePreview({ link = "DiffDelete" }),

    -- ts-rainbow
    TSRainbowRed({ fg = colors.rainbow.one }),
    TSRainbowYellow({ fg = colors.rainbow.two }),
    TSRainbowBlue({ fg = colors.rainbow.three }),
    TSRainbowOrange({ fg = colors.rainbow.four }),
    TSRainbowGreen({ fg = colors.rainbow.five }),
    TSRainbowViolet({ fg = colors.rainbow.six }),
    TSRainbowCyan({ fg = colors.rainbow.seven }),

    -- syslang
    sym("@slang.error")({ bg = "#7a2633", fg = "#ffffff" }),
    sym("@slang.document.title")({ fg = colors.slang.document.title, gui = "bold" }),
    sym("@slang.document.meta")({ fg = colors.slang.document.meta }),
    sym("@slang.document.meta.field")({ fg = colors.slang.document.meta_field }),
    sym("@slang.document.meta.field.key")({ fg = colors.slang.document.meta_field_key }),
    sym("@slang.bold")({ fg = colors.slang.bold, gui = "bold" }),
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
    sym("@slang.heading_1.marker")({ fg = colors.slang.heading.one }),
    sym("@slang.heading_1.text")({ fg = colors.slang.heading.one, gui = "bold" }),
    sym("@slang.heading_2.marker")({ fg = colors.slang.heading.two }),
    sym("@slang.heading_2.text")({ fg = colors.slang.heading.two, gui = "bold" }),
    sym("@slang.heading_3.marker")({ fg = colors.slang.heading.three }),
    sym("@slang.heading_3.text")({ fg = colors.slang.heading.three, gui = "bold" }),
    sym("@slang.heading_4.marker")({ fg = colors.slang.heading.four }),
    sym("@slang.heading_4.text")({ fg = colors.slang.heading.four, gui = "bold" }),
    sym("@slang.heading_5.marker")({ fg = colors.slang.heading.five }),
    sym("@slang.heading_5.text")({ fg = colors.slang.heading.five, gui = "bold" }),
    sym("@slang.heading_6.marker")({ fg = colors.slang.heading.six }),
    sym("@slang.heading_6.text")({ fg = colors.slang.heading.six, gui = "bold" }),
    sym("@slang.heading_done")({ fg = colors.slang.task.done, gui = "bold" }),
    sym("@slang.section")({ fg = colors.slang.section }),
    sym("@slang.banner")({ bg = colors.slang.banner.bg, fg = colors.slang.banner.fg }),
    sym("@slang.task_default")({}),
    sym("@slang.task_active")({ fg = colors.slang.task.active }),
    sym("@slang.task_done")({ fg = colors.slang.task.done }),
    sym("@slang.task_cancelled")({ fg = colors.slang.task.cancelled }),
    sym("@slang.task_session")({ fg = colors.slang.task.session }),
    sym("@slang.task_schedule")({ fg = colors.slang.task.schedule }),
    sym("@slang.tag.hash")({ fg = colors.slang.tag.hash }),
    sym("@slang.tag.positive")({ fg = colors.slang.tag.positive }),
    sym("@slang.tag.negative")({ fg = colors.slang.tag.negative }),
    sym("@slang.tag.context")({ fg = colors.slang.tag.context }),
    sym("@slang.tag.danger")({ bg = colors.slang.tag.danger.bg, fg = colors.slang.tag.danger.fg }),
    sym("@slang.tag.identifier")({ fg = colors.slang.tag.identifier }),
    sym("@slang.link")({ fg = colors.slang.link.internal, gui = "italic, undercurl" }),
    sym("@slang.external_link")({ fg = colors.slang.link.external, gui = "italic, undercurl" }),
    sym("@slang.inline_code")({ fg = colors.slang.code.inline }),
    sym("@slang.code_block_start")({ fg = colors.slang.code.block.marker, gui = "italic" }),
    sym("@slang.code_block_language")({ fg = colors.slang.code.block.language, gui = "italic" }),
    sym("@slang.code_block_fence")({ bg = colors.slang.code.block.background }),
    sym("@slang.code_block_content")({ fg = colors.slang.code.block.content }),
    sym("@slang.code_block_end")({ fg = colors.slang.code.block.marker, gui = "italic" }),
    sym("@slang.label")({ fg = colors.slang.label }),
    sym("@slang.list_item")({ fg = colors.slang.list_item.item }),
    sym("@slang.list_item_marker")({ fg = colors.slang.list_item.marker }),
    -- sym("@slang.list_item_label")({ fg = colors.slang.list_item.label, gui = "bold" }),
    sym("@slang.list_item_label")({ fg = colors.slang.list_item.label, gui = "italic" }),
    sym("@slang.list_item_label_marker")({ fg = colors.slang.list_item.label_marker }),
  }
end)

return theme
