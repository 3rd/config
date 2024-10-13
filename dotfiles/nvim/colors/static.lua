local colors = {
  -- PATCH_OPEN
Normal = {fg = "#C7C2D6", bg = "#24222A"},
["@text"] = {link = "Normal"},
["@text.literal.markdown"] = {link = "Normal"},
Boolean = {fg = "#F17E7E"},
["@boolean"] = {link = "Boolean"},
CWordHighlight = {bg = "#4D495B"},
Character = {fg = "#69D38C"},
["@character"] = {link = "Character"},
CmpItemAbbr = {fg = "#C7C2D6"},
CmpItemAbbrDeprecated = {fg = "#736C89", strikethrough = true},
CmpItemAbbrMatch = {fg = "#83BFFC"},
CmpItemAbbrMatchFuzzy = {fg = "#83BFFC", bold = true},
CmpItemKind = {fg = "#83BFFC"},
CmpItemKindClass = {fg = "#40BFBF"},
CmpItemKindColor = {},
CmpItemKindConstant = {fg = "#F17E7E"},
CmpItemKindConstructor = {fg = "#40BFBF"},
CmpItemKindCopilot = {fg = "#EC93D6"},
CmpItemKindEnum = {fg = "#40BFBF"},
CmpItemKindEnumMember = {fg = "#40BFBF"},
CmpItemKindEvent = {fg = "#40BFBF"},
CmpItemKindField = {fg = "#B1ABC4"},
CmpItemKindFile = {fg = "#83BFFC"},
CmpItemKindFolder = {fg = "#83BFFC"},
CmpItemKindFunction = {fg = "#83BFFC"},
CmpItemKindInterface = {fg = "#40BFBF"},
CmpItemKindKeyword = {fg = "#9C95B2"},
CmpItemKindMethod = {fg = "#83BFFC"},
CmpItemKindModule = {fg = "#FADB9E"},
CmpItemKindOperator = {fg = "#938DA5"},
CmpItemKindProperty = {fg = "#B1ABC4"},
CmpItemKindReference = {},
CmpItemKindSnippet = {fg = "#9485E0"},
CmpItemKindStruct = {fg = "#40BFBF"},
CmpItemKindText = {fg = "#C7C2D6"},
CmpItemKindTypeParameter = {fg = "#40BFBF"},
CmpItemKindUnit = {fg = "#40BFBF"},
CmpItemKindValue = {fg = "#F17E7E"},
CmpItemKindVariable = {fg = "#C7C2D6"},
CmpItemMenu = {fg = "#736C89"},
CodeBlock = {bg = "#3A3644"},
ColorColumn = {},
Comment = {fg = "#736C89", italic = true},
SpecialComment = {link = "Comment"},
["@comment"] = {link = "Comment"},
["@text.todo.checked"] = {link = "Comment"},
Conceal = {fg = "#B0A9C6"},
Conditional = {fg = "#AEA6C4"},
["@conditional"] = {link = "Conditional"},
Constant = {fg = "#F17E7E"},
["@constant"] = {link = "Constant"},
["@lsp.mod.constant"] = {link = "Constant"},
Constructor = {fg = "#40BFBF"},
["@constructor"] = {link = "Constructor"},
Cursor = {fg = "#24222A", bg = "#C7C2D6"},
TermCursor = {link = "Cursor"},
TermCursorNC = {link = "Cursor"},
CursorColumn = {},
CursorIM = {},
CursorLine = {bg = "#3A3644"},
CursorLineNr = {fg = "#8E88A0", bg = "#3A3644"},
CursorLineSign = {fg = "#ED9A5E", bg = "#3A3644"},
Debug = {fg = "#ED5E5E"},
["@debug"] = {link = "Debug"},
["@constant.macro"] = {link = "Define"},
["@define"] = {link = "Define"},
Delimiter = {fg = "#736C89"},
["@constructor.lua"] = {link = "Delimiter"},
["@punctuation"] = {link = "Delimiter"},
["@punctuation.bracket"] = {link = "Delimiter"},
["@punctuation.delimiter"] = {link = "Delimiter"},
["@punctuation.special"] = {link = "Delimiter"},
["@tag.delimiter"] = {link = "Delimiter"},
DiagnosticError = {fg = "#ED5E5E"},
DiagnosticFloatingError = {fg = "#ED5E5E"},
DiagnosticFloatingHint = {fg = "#40BFBF"},
DiagnosticFloatingInfo = {fg = "#83BFFC"},
DiagnosticFloatingWarn = {fg = "#ED9A5E"},
DiagnosticHint = {fg = "#40BFBF"},
DiagnosticInfo = {fg = "#83BFFC"},
DiagnosticSignError = {fg = "#ED5E5E"},
DiagnosticSignHint = {fg = "#40BFBF"},
DiagnosticSignInfo = {fg = "#83BFFC"},
DiagnosticSignWarn = {fg = "#ED9A5E"},
DiagnosticUnderlineError = {bg = "#3B2B2B"},
DiagnosticUnderlineHint = {undercurl = true},
DiagnosticUnderlineInfo = {undercurl = true},
DiagnosticUnderlineWarn = {undercurl = true},
DiagnosticUnnecessary = {undercurl = true},
DiagnosticVirtualTextError = {fg = "#ED5E5E"},
DiagnosticVirtualTextHint = {fg = "#40BFBF"},
DiagnosticVirtualTextInfo = {fg = "#83BFFC"},
DiagnosticVirtualTextWarn = {fg = "#ED9A5E"},
DiagnosticWarn = {fg = "#ED9A5E"},
DiffAdd = {fg = "#69D38C"},
diffAdded = {link = "DiffAdd"},
DiffChange = {fg = "#FADB9E"},
diffChanged = {link = "DiffChange"},
DiffDelete = {fg = "#ED5E5E"},
diffRemoved = {link = "DiffDelete"},
DiffText = {fg = "#83BFFC"},
Directory = {fg = "#83BFFC"},
EndOfBuffer = {fg = "#24222A"},
Error = {fg = "#ED5E5E"},
["@error"] = {link = "Error"},
ErrorMsg = {fg = "#F15B5B"},
["@text.danger"] = {link = "ErrorMsg"},
Exception = {fg = "#E06C6C"},
["@exception"] = {link = "Exception"},
["@keyword.exception"] = {link = "Exception"},
Field = {fg = "#B1ABC4"},
["@field"] = {link = "Field"},
["@float"] = {link = "Float"},
FoldColumn = {},
Folded = {},
Function = {fg = "#83BFFC"},
["@function.call"] = {link = "Function"},
["@function.method.call"] = {link = "Function"},
["@method"] = {link = "Function"},
["@method.call"] = {link = "Function"},
GitSignsAdd = {fg = "#39C668"},
GitSignsAddPreview = {},
GitSignsChange = {fg = "#F6BF51"},
GitSignsDelete = {fg = "#E72323"},
GitSignsDeletePreview = {},
Headline1 = {bg = "#2B2E40"},
Headline2 = {bg = "#322B40"},
Headline3 = {bg = "#3D2B40"},
Headline4 = {bg = "#402B39"},
Headline5 = {bg = "#402B2E"},
Headline6 = {bg = "#40322B"},
HighlightUndo = {fg = "#ED9A5E", bg = "#974911"},
Identifier = {fg = "#C7C2D6"},
["@lsp.type.identifier"] = {link = "Identifier"},
["@lsp.typemod.function.declaration"] = {link = "Identifier"},
["@lsp.typemod.variable"] = {link = "Identifier"},
["@symbol"] = {link = "Identifier"},
["@tag.attribute"] = {link = "Identifier"},
["@variable"] = {link = "Identifier"},
IncSearch = {fg = "#24222A", bg = "#FADB9E"},
["@include"] = {link = "Include"},
Keyword = {fg = "#9C95B2"},
["@keyword"] = {link = "Keyword"},
["@keyword.function"] = {link = "Keyword"},
["@keyword.function.lua"] = {link = "Keyword"},
Label = {fg = "#9C95B2"},
["@label"] = {link = "Label"},
LeapLabelPrimary = {fg = "#F1AE7E", bg = "#974911"},
LineNr = {fg = "#4D495B"},
LspCodeLens = {fg = "#9A91B6"},
LspCodeLensSeparator = {fg = "#6E6293"},
LspInlayHint = {fg = "#615C70"},
LspReferenceRead = {bg = "#F6BF51"},
LspReferenceText = {bg = "#9A91B6"},
LspReferenceWrite = {bg = "#E72323"},
LspSignatureActiveParameter = {fg = "#83BFFC"},
Macro = {fg = "#B29DF1"},
["@function.macro"] = {link = "Macro"},
["@macro"] = {link = "Macro"},
["@text.environment"] = {link = "Macro"},
MatchParen = {bg = "#4D495B"},
NonText = {fg = "#9A91B6"},
NormalFloat = {},
NormalNC = {},
Number = {fg = "#F17E7E"},
Float = {link = "Number"},
["@number"] = {link = "Number"},
NvimTreeFolderIcon = {fg = "#60ADFB"},
NvimTreeFolderName = {fg = "#C7C2D6"},
NvimTreeGitDeleted = {fg = "#ED5E5E"},
NvimTreeGitDirty = {fg = "#ED9A5E"},
NvimTreeGitNew = {fg = "#69D38C"},
NvimTreeImageFile = {},
NvimTreeIndentMarker = {fg = "#67607B"},
NvimTreeNormal = {bg = "#292730"},
NvimTreeNormalNC = {},
NvimTreeOpenedFile = {fg = "#83BFFC"},
NvimTreeRootFolder = {fg = "#83BFFC", bold = true},
NvimTreeSpecialFile = {fg = "#83BFFC"},
NvimTreeSymlink = {},
NvimTreeWinSeparator = {fg = "#3A3645", bg = "#292730"},
Operator = {fg = "#938DA5"},
["@operator"] = {link = "Operator"},
Parameter = {fg = "#E2B069"},
["@parameter"] = {link = "Parameter"},
Pmenu = {fg = "#C7C2D6", bg = "#3A3644"},
PmenuSbar = {bg = "#4D495B"},
PmenuSel = {fg = "#24222A", bg = "#83BFFC"},
PmenuThumb = {bg = "#766F8B"},
PreProc = {fg = "#9C95B2"},
["@attribute"] = {link = "PreProc"},
["@preproc"] = {link = "PreProc"},
Property = {fg = "#B1ABC4"},
["@property"] = {link = "Property"},
Quote = {fg = "#38425B", bold = true},
RainbowBlue = {fg = "#9CAAF2"},
RainbowCyan = {fg = "#45A1A1"},
RainbowGreen = {fg = "#6FAEA9"},
RainbowOrange = {fg = "#D98B54"},
RainbowRed = {fg = "#C06D6D"},
RainbowViolet = {fg = "#CE73B7"},
RainbowYellow = {fg = "#D585C1"},
Repeat = {fg = "#AEA6C4"},
["@repeat"] = {link = "Repeat"},
Search = {fg = "#24222A", bg = "#F6BF51"},
Substitute = {link = "Search"},
SignColumn = {},
Special = {fg = "#A99AF4"},
SpecialChar = {link = "Special"},
Tag = {link = "Special"},
["@tag.attribute.tsx"] = {link = "Special"},
["@text.literal.markdown_inline"] = {link = "Special"},
["@text.math"] = {link = "Special"},
["@character.special"] = {link = "SpecialChar"},
["@string.escape"] = {link = "SpecialChar"},
["@string.special"] = {link = "SpecialChar"},
["@text.note"] = {link = "SpecialComment"},
SpecialKeyword = {fg = "#A99AF4"},
Define = {link = "SpecialKeyword"},
Include = {link = "SpecialKeyword"},
PreCondit = {link = "SpecialKeyword"},
["@keyword.coroutine"] = {link = "SpecialKeyword"},
["@keyword.operator"] = {link = "SpecialKeyword"},
["@tag.tsx"] = {link = "SpecialKeyword"},
Statement = {fg = "#9C95B2"},
["@storageclass"] = {link = "StorageClass"},
String = {fg = "#69D38C"},
["@string"] = {link = "String"},
["@string.regex"] = {link = "String"},
["@text.literal"] = {link = "String"},
["@structure"] = {link = "Structure"},
TabLine = {bg = "#24222A"},
TabLineFill = {bg = "#24222A"},
TabLineSel = {bg = "#24222A"},
["@tag"] = {link = "Tag"},
Title = {fg = "#F075D1"},
["@text.title"] = {link = "Title"},
Todo = {fg = "#FADB9E", bold = true, italic = true},
["@text.todo"] = {link = "Todo"},
["@text.todo.unchecked"] = {link = "Todo"},
Type = {fg = "#40BFBF"},
StorageClass = {link = "Type"},
Structure = {link = "Type"},
Typedef = {link = "Type"},
["@function"] = {link = "Type"},
["@namespace"] = {link = "Type"},
["@text.environment.name"] = {link = "Type"},
["@type"] = {link = "Type"},
["@type.qualifier"] = {link = "Type"},
["@type.definition"] = {link = "Typedef"},
Underlined = {undercurl = true},
["@text.reference"] = {link = "Underlined"},
["@text.underline"] = {link = "Underlined"},
["@text.uri"] = {link = "Underlined"},
VertSplit = {fg = "#2E2B36"},
Winseparator = {link = "VertSplit"},
Visual = {bg = "#4D495B"},
WarningMsg = {},
["@text.warning"] = {link = "WarningMsg"},
Whitespace = {fg = "#78767F"},
SpecialKey = {link = "Whitespace"},
WinBar = {fg = "#33CCCC", bg = "#373149", bold = true},
WinBarNC = {link = "WinBar"},
lCursor = {},
["@lsp.typemod.deriveHelper.attribute"] = {link = "@attribute"},
["@constant.builtin"] = {link = "@boolean"},
["@lsp.type.boolean"] = {link = "@boolean"},
["@break"] = {fg = "#E06C6C"},
["@keyword.return"] = {link = "@break"},
["@builtin"] = {fg = "#DB7070"},
["@function.builtin"] = {link = "@builtin"},
["@lsp.typemod.class.defaultLibrary"] = {link = "@builtin"},
["@lsp.typemod.function.defaultLibrary"] = {link = "@builtin"},
["@lsp.typemod.type.defaultLibrary"] = {link = "@builtin"},
["@lsp.typemod.variable.defaultLibrary"] = {link = "@builtin"},
["@namespace.builtin.lua"] = {link = "@builtin"},
["@variable.builtin"] = {link = "@builtin"},
["@lsp.type.character"] = {link = "@character"},
["@keyword.conditional.lua"] = {link = "@conditional"},
["@lsp.type.enumMember"] = {link = "@constant"},
["@lsp.type.namespace"] = {link = "@constant"},
["@constructor.tsx"] = {},
["@lsp.type.class"] = {link = "@constructor"},
["@lsp.typemod.property.declaration"] = {link = "@field"},
["@lsp.type.float"] = {link = "@float"},
["@lsp.mod.readonly"] = {},
["@lsp.mod.static"] = {italic = true},
["@lsp.type.event"] = {fg = "#ED9A5E"},
["@lsp.type.function"] = {},
["@lsp.type.keyword"] = {},
["@lsp.type.lifetime"] = {fg = "#EC93D6"},
["@lsp.typemod.function"] = {},
["@lsp.typemod.string.constant"] = {},
["@lsp.typemod.string.readonly"] = {},
["@lsp.typemod.string.static"] = {},
["@lsp.mod.annotation"] = {link = "@macro"},
["@lsp.type.macro"] = {link = "@macro"},
["@lsp.type.method"] = {link = "@method"},
["@none"] = {fg = "NONE", bg = "NONE"},
["@lsp.type.number"] = {link = "@number"},
["@lsp.type.operator"] = {link = "@operator"},
["@lsp.type.decorator"] = {link = "@parameter"},
["@lsp.type.parameter"] = {link = "@parameter"},
["@lsp.type.property"] = {link = "@property"},
["@slang.banner"] = {fg = "#A9B9E5", bg = "#38425B"},
["@slang.bold"] = {bold = true},
["@slang.code_block_content"] = {fg = "#C7C2D6"},
["@slang.code_block_end"] = {fg = "#4D495B", italic = true},
["@slang.code_block_fence"] = {bg = "#3A3644"},
["@slang.code_block_language"] = {fg = "#635D74", italic = true},
["@slang.code_block_start"] = {fg = "#4D495B", italic = true},
["@slang.comment"] = {fg = "#736C89"},
["@slang.date"] = {fg = "#FC824A"},
["@slang.daterange"] = {fg = "#FC824A"},
["@slang.datetime"] = {fg = "#FC824A"},
["@slang.datetimerange"] = {fg = "#FC824A"},
["@slang.document.meta"] = {fg = "#736C89"},
["@slang.document.meta.field"] = {fg = "#F075D1"},
["@slang.document.meta.field.key"] = {fg = "#EC93D6"},
["@slang.document.title"] = {fg = "#7DE8A1", bold = true},
["@slang.error"] = {fg = "#ffffff", bg = "#7a2633"},
["@slang.external_link"] = {fg = "#6FADEB", italic = true},
["@slang.heading_1.marker"] = {fg = "#9C95B2"},
["@slang.heading_1.text"] = {fg = "#8599FF", bold = true},
["@slang.heading_2.marker"] = {fg = "#9C95B2"},
["@slang.heading_2.text"] = {fg = "#AD85FF", bold = true},
["@slang.heading_3.marker"] = {fg = "#9C95B2"},
["@slang.heading_3.text"] = {fg = "#EB85FF", bold = true},
["@slang.heading_4.marker"] = {fg = "#9C95B2"},
["@slang.heading_4.text"] = {fg = "#FF85D6", bold = true},
["@slang.heading_5.marker"] = {fg = "#9C95B2"},
["@slang.heading_5.text"] = {fg = "#FF8599", bold = true},
["@slang.heading_6.marker"] = {fg = "#9C95B2"},
["@slang.heading_6.text"] = {fg = "#FFAD85", bold = true},
["@slang.image"] = {fg = "#DB80C4"},
["@slang.inline_code"] = {fg = "#E9A677"},
["@slang.internal_link"] = {fg = "#5BC0CD"},
["@slang.italic"] = {italic = true},
["@slang.label"] = {fg = "#DB80C4"},
["@slang.label_line"] = {fg = "#46B9B9"},
["@slang.link"] = {fg = "#5BC0CD", italic = true},
["@slang.list_item"] = {},
["@slang.list_item_label"] = {fg = "#A294EB"},
["@slang.list_item_label_marker"] = {fg = "#736C89"},
["@slang.list_item_marker"] = {fg = "#78767F"},
["@slang.number"] = {fg = "#F17E7E"},
["@slang.outline_1.marker"] = {fg = "#9999FF"},
["@slang.outline_1.text"] = {fg = "#9999FF", bold = true},
["@slang.outline_2.marker"] = {fg = "#BF8FFF"},
["@slang.outline_2.text"] = {fg = "#BF8FFF", bold = true},
["@slang.outline_3.marker"] = {fg = "#E38FFF"},
["@slang.outline_3.text"] = {fg = "#E38FFF", bold = true},
["@slang.outline_4.marker"] = {fg = "#FFC78F"},
["@slang.outline_4.text"] = {fg = "#FFC78F", bold = true},
["@slang.outline_5.marker"] = {fg = "#04D2CE"},
["@slang.outline_5.text"] = {fg = "#04D2CE", bold = true},
["@slang.outline_6.marker"] = {fg = "#F0949D"},
["@slang.outline_6.text"] = {fg = "#F0949D", bold = true},
["@slang.outline_done"] = {fg = "#736C89", bold = true},
["@slang.section"] = {fg = "#8797C2"},
["@slang.string"] = {fg = "#69D38C"},
["@slang.tag.context"] = {fg = "#FADB9E"},
["@slang.tag.danger"] = {fg = "#ffffff", bg = "#C3423F"},
["@slang.tag.hash"] = {fg = "#5BC0EB"},
["@slang.tag.identifier"] = {fg = "#e38fff"},
["@slang.tag.negative"] = {fg = "#FA4224"},
["@slang.tag.positive"] = {fg = "#9BC53D"},
["@slang.task_active"] = {fg = "#40BFBF"},
["@slang.task_cancelled"] = {fg = "#fa4040"},
["@slang.task_completion"] = {fg = "#7378a5"},
["@slang.task_default"] = {},
["@slang.task_done"] = {fg = "#736C89"},
["@slang.task_marker_default"] = {fg = "#736C89"},
["@slang.task_recurrence"] = {fg = "#7378a5"},
["@slang.task_schedule"] = {fg = "#7378a5"},
["@slang.task_session"] = {fg = "#7378a5"},
["@slang.ticket"] = {fg = "#fa89f6"},
["@slang.time"] = {fg = "#FC824A"},
["@slang.timerange"] = {fg = "#FC824A"},
["@slang.underline"] = {underline = true},
["@lsp.mod.interpolation"] = {link = "@string.special"},
["@lsp.type.string"] = {link = "@string"},
["@lsp.type.struct"] = {link = "@structure"},
["@text.emphasis"] = {italic = true},
["@text.literal.syslang"] = {fg = "#C7C2D6"},
["@text.strike"] = {strikethrough = true},
["@text.strong"] = {bold = true},
["@lsp.type.typeAlias"] = {link = "@type.definition"},
["@lsp.type.enum"] = {link = "@type"},
["@lsp.type.interface"] = {link = "@type"},
["@lsp.type.type"] = {link = "@type"},
["@lsp.type.typeParameter"] = {link = "@type"},
["@lsp.typemod.interface"] = {link = "@type"},
["@lsp.typemod.type.readonly"] = {link = "@type"},
["@lsp.typemod.typeParameter"] = {link = "@type"},
["@type.builtin"] = {link = "@type"},
["@lsp.type.variable"] = {link = "@variable"},
  -- PATCH_CLOSE
}

vim.opt.background = "dark"
vim.g.colors_name = "static"
vim.cmd.highlight("clear")
-- vim.cmd.syntax("reset")

for group, attrs in pairs(colors) do
  vim.api.nvim_set_hl(0, group, attrs)
end
