local lush = require("lush")
local colors = require("config/colors")

-- https://github.com/search?q=language%3Alua+%22%40text.strong%22&type=code
-- https://github.com/RRethy/nvim-base16/blob/4f3aa29f49b38edb6db1c52cea57e64ce3de2373/lua/base16-colorscheme.lua#L383
-- https://github.com/ray-x/nvim/blob/8147b4d90361782d43d8a841d09868ef17d0a4c8/lua/modules/ui/galaxy.lua#L425

---@diagnostic disable: undefined-global
local theme = lush(function(injected)
  local sym = injected.sym
  return {
    Normal({ bg = colors.background, fg = colors.foreground }), -- Normal text
    -- Normal({ fg = colors.foreground }), -- Normal text
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

    LineNr({ fg = colors.background.lighten(20) }),
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
    -- VisualNOS    { }, -- Visual mode selection when vim is "Not Owning the Selection".
    -- Winseparator { }, -- Separator between window splits. Inherts from |hl-VertSplit| by default, which it will replace eventually.
    -- WildMenu     { }, -- Current match in 'wildmenu' completion
    TabLine({ bg = colors.ui.surface1 }), -- Tab pages line, not active tab page label
    TabLineFill({ bg = colors.ui.surface0 }), -- Tab pages line, where there are no labels
    TabLineSel({ bg = colors.ui.surface2 }), -- Tab pages line, active tab page label
    WarningMsg({}), -- Warning messages

    -- common
    Identifier({ fg = colors.common.identifier }),
    Statement({ fg = colors.common.keyword }),
    Conditional({ fg = colors.common.conditional }),
    Repeat({ fg = colors.common["repeat"] }),
    Label({ fg = colors.common.keyword }),
    Keyword({ fg = colors.common.keyword }),
    SpecialKeyword({ fg = colors.common.special_keyword }),
    Exception({ fg = colors.common.builtin }),
    Operator({ fg = colors.common.operator }),
    Function({ fg = colors.common["function"] }),
    Type({ fg = colors.common.type }),
    Comment({ fg = colors.common.comment, gui = "italic" }),
    Constructor({ fg = colors.common.constructor }),
    Field({ fg = colors.common.field }),
    Property({ fg = colors.common.property }),
    -- blue
    Constant({ fg = colors.common.constant }),
    Boolean({ fg = colors.common.boolean }),
    Number({ fg = colors.common.number }),
    Float({ Number }),
    -- cyan
    StorageClass({ Type }),
    Structure({ Type }),
    Typedef({ Type }),
    -- green
    String({ fg = colors.common.string }),
    Character({ fg = colors.green }),
    -- red
    Debug({ fg = colors.red }),
    Error({ fg = colors.red }),
    -- yellow
    Todo({ fg = colors.yellow, gui = "bold,italic" }),
    -- magenta
    PreProc({ fg = colors.common.keyword }),
    Macro({ fg = colors.common.macro }),
    Parameter({ fg = colors.common.parameter }),
    Include({ SpecialKeyword }),
    Define({ SpecialKeyword }),
    PreCondit({ SpecialKeyword }),
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
    DiagnosticUnderlineError({ gui = "undercurl" }),
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
    sym("@constant.builtin")({ sym("@boolean") }),
    sym("@constant.macro")({ Define }),
    sym("@constructor")({ Constructor }),
    sym("@debug")({ Debug }),
    sym("@define")({ Define }),
    sym("@error")({ Error }),
    sym("@exception")({ Exception }),
    sym("@field")({ Field }),
    sym("@float")({ Float }),
    sym("@function")({ Function }),
    sym("@function.builtin")({ sym("@builtin") }),
    sym("@function.call")({ Function }),
    sym("@function.macro")({ Macro }),
    sym("@include")({ Include }),
    sym("@keyword")({ Keyword }),
    sym("@keyword.function")({ Keyword }),
    sym("@keyword.operator")({ Macro }),
    sym("@keyword.return")({ sym("@builtin") }),
    sym("@keyword.coroutine")({ SpecialKeyword }),
    sym("@label")({ Label }),
    sym("@macro")({ Macro }),
    sym("@method")({ Function }),
    sym("@method.call")({ Function }),
    sym("@namespace")({ Function }),
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
    sym("@text.reference")({ Constant }),
    sym("@text.strike")({ gui = "strikethrough" }),
    sym("@text.strong")({ gui = "bold" }),
    sym("@text.title")({ Title }),
    sym("@text.todo")({ Todo }),
    sym("@text.todo.checked")({ Comment }),
    sym("@text.todo.unchecked")({ Todo }),
    sym("@text.underline")({ Underlined }),
    sym("@text.uri")({ Underlined }),
    sym("@text.uri")({ Underlined }),
    sym("@text.warning")({ WarningMsg }),
    sym("@type")({ Type }),
    sym("@type.builtin")({ sym("@type") }),
    sym("@type.definition")({ Typedef }),
    sym("@type.qualifier")({ Type }),
    sym("@variable")({ Identifier }),
    sym("@variable.builtin")({ sym("@boolean") }),

    -- semantic tokens
    -- https://gist.github.com/swarn/fb37d9eefe1bc616c2a7e476c0bc0316
    -- https://github.com/Iron-E/nvim-highlite/blob/master-v4/lua/highlite/groups/default.lua#L240
    sym("@lsp.type.boolean")({ sym("@boolean") }),
    sym("@lsp.type.character")({ sym("@character") }),
    sym("@lsp.type.class")({ sym("@constructor") }),
    sym("@lsp.type.decorator")({ sym("@parameter") }),
    sym("@lsp.type.enum")({ sym("@type") }),
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
    sym("@lsp.type.namespace")({ sym("@namespace") }),
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
    sym("@lsp.mod.interpolation")({ sym("@string.special") }),
    sym("@lsp.mod.static")({ gui = "italic" }),
    sym("@lsp.mod.constant")({}),
    sym("@lsp.mod.readonly")({}),

    sym("@lsp.typemod.deriveHelper.attribute")({ sym("@attribute") }),
    sym("@lsp.typemod.interface")({ sym("@type") }),
    sym("@lsp.typemod.property.declaration")({ sym("@field") }),
    sym("@lsp.typemod.string.constant")({}),
    sym("@lsp.typemod.string.readonly")({}),
    sym("@lsp.typemod.string.static")({}),
    sym("@lsp.typemod.type.readonly")({ sym("@type") }),
    sym("@lsp.typemod.typeParameter")({ sym("@type") }),

    sym("@lsp.typemod.function")({}),

    sym("@lsp.typemod.class.defaultLibrary")({ sym("@macro") }),
    sym("@lsp.typemod.function.defaultLibrary")({ sym("@macro") }),
    sym("@lsp.typemod.type.defaultLibrary")({ sym("@type") }),
    sym("@lsp.typemod.variable.defaultLibrary")({ sym("@macro") }),

    -- to move
    sym("@namespace")({ sym("@type") }),

    -- lua
    sym("@constructor.lua")({ Delimiter }),

    -- tsx
    sym("@constructor.tsx")({}),
    sym("@tag.tsx")({ SpecialKeyword }),
    sym("@tag.attribute.tsx")({ sym("Special") }),

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

    -- indent-blankline
    IndentBlanklineIndent1({ fg = colors.background.lighten(21).desaturate(20) }),
    IndentBlanklineIndent2({ fg = colors.background.lighten(18).desaturate(20) }),
    IndentBlanklineIndent3({ fg = colors.background.lighten(15).desaturate(20) }),
    IndentBlanklineIndent4({ fg = colors.background.lighten(12).desaturate(20) }),
    IndentBlanklineIndent5({ fg = colors.background.lighten(9).desaturate(20) }),
    IndentBlanklineIndent6({ fg = colors.background.lighten(6).desaturate(20) }),

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
    RainbowRed({ fg = colors.rainbow.red }),
    RainbowYellow({ fg = colors.rainbow.yellow }),
    RainbowBlue({ fg = colors.rainbow.blue }),
    RainbowOrange({ fg = colors.rainbow.orange }),
    RainbowGreen({ fg = colors.rainbow.green }),
    RainbowViolet({ fg = colors.rainbow.violet }),
    RainbowCyan({ fg = colors.rainbow.cyan }),

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
    sym("@slang.list_item_label")({ fg = colors.slang.list_item.label, gui = "italic" }),
    sym("@slang.list_item_label_marker")({ fg = colors.slang.list_item.label_marker }),
    sym("@slang.image")({ fg = colors.slang.label }),
    sym("@text.literal.syslang")({ fg = colors.foreground }),
    sym("@slang.internal_link")({ fg = colors.slang.link.internal, gui = "undercurl" }),
  }
end)

return theme
