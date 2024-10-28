local colors = {
  -- PATCH_OPEN
Normal = {fg = "#E0DEED", bg = "#23212B"},
["@text"] = {link = "Normal"},
["@text.literal.markdown"] = {link = "Normal"},
Boolean = {fg = "#FC8F79"},
["@boolean"] = {link = "Boolean"},
CWordHighlight = {bg = "#4B475C"},
Character = {fg = "#B3E87D"},
["@character"] = {link = "Character"},
CmpItemAbbr = {fg = "#E0DEED"},
CmpItemAbbrDeprecated = {fg = "#7C759F", strikethrough = true},
CmpItemAbbrMatch = {fg = "#83D3FC"},
CmpItemAbbrMatchFuzzy = {fg = "#83D3FC", bold = true},
CmpItemKind = {fg = "#83D3FC"},
CmpItemKindClass = {fg = "#17CFCF"},
CmpItemKindColor = {},
CmpItemKindConstant = {fg = "#FC8F79"},
CmpItemKindConstructor = {fg = "#17CFCF"},
CmpItemKindCopilot = {fg = "#EC93D6"},
CmpItemKindEnum = {fg = "#17CFCF"},
CmpItemKindEnumMember = {fg = "#17CFCF"},
CmpItemKindEvent = {fg = "#17CFCF"},
CmpItemKindField = {fg = "#C6C1DC"},
CmpItemKindFile = {fg = "#83D3FC"},
CmpItemKindFolder = {fg = "#83D3FC"},
CmpItemKindFunction = {fg = "#83D3FC"},
CmpItemKindInterface = {fg = "#17CFCF"},
CmpItemKindKeyword = {fg = "#BBB6D2"},
CmpItemKindMethod = {fg = "#83D3FC"},
CmpItemKindModule = {fg = "#EDBE5E"},
CmpItemKindOperator = {fg = "#A49FBC"},
CmpItemKindProperty = {fg = "#C6C1DC"},
CmpItemKindReference = {},
CmpItemKindSnippet = {fg = "#9485E0"},
CmpItemKindStruct = {fg = "#17CFCF"},
CmpItemKindText = {fg = "#E0DEED"},
CmpItemKindTypeParameter = {fg = "#17CFCF"},
CmpItemKindUnit = {fg = "#17CFCF"},
CmpItemKindValue = {fg = "#FC8F79"},
CmpItemKindVariable = {fg = "#E0DEED"},
CmpItemMenu = {fg = "#7C759F"},
CodeBlock = {bg = "#383545"},
ColorColumn = {},
Comment = {fg = "#7C759F", italic = true},
SpecialComment = {link = "Comment"},
["@comment"] = {link = "Comment"},
["@text.todo.checked"] = {link = "Comment"},
Conceal = {fg = "#C5C0DD"},
Conditional = {fg = "#CBC8DA"},
["@conditional"] = {link = "Conditional"},
Constant = {fg = "#FC8F79"},
["@constant"] = {link = "Constant"},
["@lsp.mod.constant"] = {link = "Constant"},
Constructor = {fg = "#17CFCF"},
["@constructor"] = {link = "Constructor"},
Cursor = {fg = "#23212B", bg = "#E0DEED"},
TermCursor = {link = "Cursor"},
TermCursorNC = {link = "Cursor"},
CursorColumn = {},
CursorIM = {},
CursorLine = {bg = "#383545"},
CursorLineNr = {fg = "#8C86A2", bg = "#383545"},
CursorLineSign = {fg = "#ED9A5E", bg = "#383545"},
Debug = {fg = "#E02A06"},
["@debug"] = {link = "Debug"},
["@constant.macro"] = {link = "Define"},
["@define"] = {link = "Define"},
Delimiter = {fg = "#7C759F"},
["@constructor.lua"] = {link = "Delimiter"},
["@punctuation"] = {link = "Delimiter"},
["@punctuation.bracket"] = {link = "Delimiter"},
["@punctuation.delimiter"] = {link = "Delimiter"},
["@punctuation.special"] = {link = "Delimiter"},
["@tag.delimiter"] = {link = "Delimiter"},
DiagnosticError = {fg = "#E02A06"},
DiagnosticFloatingError = {fg = "#E02A06"},
DiagnosticFloatingHint = {fg = "#17CFCF"},
DiagnosticFloatingInfo = {fg = "#83D3FC"},
DiagnosticFloatingWarn = {fg = "#ED9A5E"},
DiagnosticHint = {fg = "#17CFCF"},
DiagnosticInfo = {fg = "#83D3FC"},
DiagnosticSignError = {fg = "#E02A06"},
DiagnosticSignHint = {fg = "#17CFCF"},
DiagnosticSignInfo = {fg = "#83D3FC"},
DiagnosticSignWarn = {fg = "#ED9A5E"},
DiagnosticUnderlineError = {bg = "#803323"},
DiagnosticUnderlineHint = {undercurl = true},
DiagnosticUnderlineInfo = {undercurl = true},
DiagnosticUnderlineWarn = {undercurl = true},
DiagnosticUnnecessary = {undercurl = true},
DiagnosticVirtualTextError = {fg = "#E02A06"},
DiagnosticVirtualTextHint = {fg = "#17CFCF"},
DiagnosticVirtualTextInfo = {fg = "#83D3FC"},
DiagnosticVirtualTextWarn = {fg = "#ED9A5E"},
DiagnosticWarn = {fg = "#ED9A5E"},
DiffAdd = {fg = "#B3E87D"},
diffAdded = {link = "DiffAdd"},
DiffChange = {fg = "#EDBE5E"},
diffChanged = {link = "DiffChange"},
DiffDelete = {fg = "#E02A06"},
diffRemoved = {link = "DiffDelete"},
DiffText = {fg = "#83D3FC"},
Directory = {fg = "#83D3FC"},
EndOfBuffer = {fg = "#23212B"},
Error = {fg = "#E02A06"},
["@error"] = {link = "Error"},
ErrorMsg = {fg = "#E12905"},
["@text.danger"] = {link = "ErrorMsg"},
Exception = {fg = "#EB806B"},
["@exception"] = {link = "Exception"},
["@keyword.exception"] = {link = "Exception"},
Field = {fg = "#C6C1DC"},
["@field"] = {link = "Field"},
["@float"] = {link = "Float"},
FoldColumn = {},
Folded = {},
Function = {fg = "#83D3FC"},
["@function.call"] = {link = "Function"},
["@function.method.call"] = {link = "Function"},
["@method"] = {link = "Function"},
["@method.call"] = {link = "Function"},
GitSignsAdd = {fg = "#8FDD40"},
GitSignsAddPreview = {},
GitSignsChange = {fg = "#E7A523"},
GitSignsDelete = {fg = "#B32205"},
GitSignsDeletePreview = {},
Headline1 = {bg = "#2B2E40"},
Headline2 = {bg = "#322B40"},
Headline3 = {bg = "#3D2B40"},
Headline4 = {bg = "#402B39"},
Headline5 = {bg = "#402B2E"},
Headline6 = {bg = "#40322B"},
HighlightUndo = {fg = "#ED9A5E", bg = "#974911"},
Identifier = {fg = "#E0DEED"},
["@lsp.type.identifier"] = {link = "Identifier"},
["@lsp.typemod.function.declaration"] = {link = "Identifier"},
["@lsp.typemod.variable"] = {link = "Identifier"},
["@symbol"] = {link = "Identifier"},
["@tag.attribute"] = {link = "Identifier"},
["@variable"] = {link = "Identifier"},
IncSearch = {fg = "#23212B", bg = "#EDBE5E"},
["@include"] = {link = "Include"},
Keyword = {fg = "#BBB6D2"},
["@keyword"] = {link = "Keyword"},
["@keyword.function"] = {link = "Keyword"},
["@keyword.function.lua"] = {link = "Keyword"},
Label = {fg = "#BBB6D2"},
["@label"] = {link = "Label"},
LeapLabelPrimary = {fg = "#F1AE7E", bg = "#974911"},
LineNr = {fg = "#4B475C"},
LspCodeLens = {fg = "#A9A2CD"},
LspCodeLensSeparator = {fg = "#7267AD"},
LspInlayHint = {fg = "#6B677E"},
LspReferenceRead = {bg = "#E7A523"},
LspReferenceText = {bg = "#A9A2CD"},
LspReferenceWrite = {bg = "#B32205"},
LspSignatureActiveParameter = {fg = "#83D3FC"},
Macro = {fg = "#C9C0F7"},
["@function.macro"] = {link = "Macro"},
["@macro"] = {link = "Macro"},
["@text.environment"] = {link = "Macro"},
MatchParen = {bg = "#4B475C"},
NonText = {fg = "#A9A2CD"},
NormalFloat = {},
NormalNC = {},
Number = {fg = "#FC8F79"},
Float = {link = "Number"},
["@number"] = {link = "Number"},
NvimTreeFolderIcon = {fg = "#60C7FB"},
NvimTreeFolderName = {fg = "#E0DEED"},
NvimTreeGitDeleted = {fg = "#E02A06"},
NvimTreeGitDirty = {fg = "#ED9A5E"},
NvimTreeGitNew = {fg = "#B3E87D"},
NvimTreeImageFile = {},
NvimTreeIndentMarker = {fg = "#6E6693"},
NvimTreeNormal = {bg = "#282631"},
NvimTreeNormalNC = {},
NvimTreeOpenedFile = {fg = "#83D3FC"},
NvimTreeRootFolder = {fg = "#83D3FC", bold = true},
NvimTreeSpecialFile = {fg = "#83D3FC"},
NvimTreeSymlink = {},
NvimTreeWinSeparator = {fg = "#3D3851", bg = "#282631"},
Operator = {fg = "#A49FBC"},
["@operator"] = {link = "Operator"},
Parameter = {fg = "#EAA06C"},
["@parameter"] = {link = "Parameter"},
Pmenu = {fg = "#E0DEED", bg = "#383545"},
PmenuSbar = {bg = "#4B475C"},
PmenuSel = {fg = "#23212B", bg = "#83D3FC"},
PmenuThumb = {bg = "#736D8D"},
PreProc = {fg = "#BBB6D2"},
["@attribute"] = {link = "PreProc"},
["@preproc"] = {link = "PreProc"},
Property = {fg = "#C6C1DC"},
["@property"] = {link = "Property"},
Quote = {fg = "#38425B", bold = true},
RainbowBlue = {fg = "#9CB9F2"},
RainbowCyan = {fg = "#2CC9C9"},
RainbowGreen = {fg = "#A0E4A5"},
RainbowOrange = {fg = "#F1906F"},
RainbowRed = {fg = "#E67F90"},
RainbowViolet = {fg = "#E382CB"},
RainbowYellow = {fg = "#E17AC7"},
Repeat = {fg = "#CBC8DA"},
["@repeat"] = {link = "Repeat"},
Search = {fg = "#23212B", bg = "#E7A523"},
Substitute = {link = "Search"},
SignColumn = {},
Special = {fg = "#E8B37D"},
SpecialChar = {link = "Special"},
Tag = {link = "Special"},
["@tag.attribute.tsx"] = {link = "Special"},
["@text.literal.markdown_inline"] = {link = "Special"},
["@text.math"] = {link = "Special"},
["@character.special"] = {link = "SpecialChar"},
["@string.escape"] = {link = "SpecialChar"},
["@string.special"] = {link = "SpecialChar"},
["@text.note"] = {link = "SpecialComment"},
SpecialKeyword = {fg = "#E8B37D"},
Define = {link = "SpecialKeyword"},
Include = {link = "SpecialKeyword"},
PreCondit = {link = "SpecialKeyword"},
["@keyword.coroutine"] = {link = "SpecialKeyword"},
["@keyword.operator"] = {link = "SpecialKeyword"},
["@tag.tsx"] = {link = "SpecialKeyword"},
Statement = {fg = "#BBB6D2"},
["@storageclass"] = {link = "StorageClass"},
String = {fg = "#B3E87D"},
["@string"] = {link = "String"},
["@string.regex"] = {link = "String"},
["@text.literal"] = {link = "String"},
["@structure"] = {link = "Structure"},
TabLine = {bg = "#23212B"},
TabLineFill = {bg = "#23212B"},
TabLineSel = {bg = "#23212B"},
["@tag"] = {link = "Tag"},
Title = {fg = "#F075D1"},
["@text.title"] = {link = "Title"},
Todo = {fg = "#EDBE5E", bold = true, italic = true},
["@text.todo"] = {link = "Todo"},
["@text.todo.unchecked"] = {link = "Todo"},
Type = {fg = "#17CFCF"},
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
VertSplit = {fg = "#2D2A37"},
Winseparator = {link = "VertSplit"},
Visual = {bg = "#4B475C"},
WarningMsg = {},
["@text.warning"] = {link = "WarningMsg"},
Whitespace = {fg = "#858391"},
SpecialKey = {link = "Whitespace"},
WinBar = {fg = "#2EB8B8", bg = "#363149", bold = true},
WinBarNC = {link = "WinBar"},
lCursor = {},
["@lsp.typemod.deriveHelper.attribute"] = {link = "@attribute"},
["@constant.builtin"] = {link = "@boolean"},
["@lsp.type.boolean"] = {link = "@boolean"},
["@break"] = {fg = "#EB806B"},
["@keyword.return"] = {link = "@break"},
["@builtin"] = {fg = "#EB806B"},
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
["@slang.code_block_content"] = {fg = "#E0DEED"},
["@slang.code_block_end"] = {fg = "#4B475C", italic = true},
["@slang.code_block_fence"] = {bg = "#383545"},
["@slang.code_block_language"] = {fg = "#605B76", italic = true},
["@slang.code_block_start"] = {fg = "#4B475C", italic = true},
["@slang.comment"] = {fg = "#7C759F"},
["@slang.date"] = {fg = "#FC824A"},
["@slang.daterange"] = {fg = "#FC824A"},
["@slang.datetime"] = {fg = "#FC824A"},
["@slang.datetimerange"] = {fg = "#FC824A"},
["@slang.document.meta"] = {fg = "#7C759F"},
["@slang.document.meta.field"] = {fg = "#F075D1"},
["@slang.document.meta.field.key"] = {fg = "#EC93D6"},
["@slang.document.title"] = {fg = "#C2ED97", bold = true},
["@slang.error"] = {fg = "#ffffff", bg = "#7a2633"},
["@slang.external_link"] = {fg = "#6FC2EB", italic = true},
["@slang.heading_1.marker"] = {fg = "#ACA6C9"},
["@slang.heading_1.text"] = {fg = "#8599FF", bold = true},
["@slang.heading_2.marker"] = {fg = "#ACA6C9"},
["@slang.heading_2.text"] = {fg = "#AD85FF", bold = true},
["@slang.heading_3.marker"] = {fg = "#ACA6C9"},
["@slang.heading_3.text"] = {fg = "#EB85FF", bold = true},
["@slang.heading_4.marker"] = {fg = "#ACA6C9"},
["@slang.heading_4.text"] = {fg = "#FF85D6", bold = true},
["@slang.heading_5.marker"] = {fg = "#ACA6C9"},
["@slang.heading_5.text"] = {fg = "#FF8599", bold = true},
["@slang.heading_6.marker"] = {fg = "#ACA6C9"},
["@slang.heading_6.text"] = {fg = "#FFAD85", bold = true},
["@slang.image"] = {fg = "#E486CC"},
["@slang.inline_code"] = {fg = "#E9A677"},
["@slang.internal_link"] = {fg = "#5BC0CD"},
["@slang.italic"] = {italic = true},
["@slang.label"] = {fg = "#E486CC"},
["@slang.label_line"] = {fg = "#20C5C5"},
["@slang.link"] = {fg = "#5BC0CD", italic = true},
["@slang.list_item"] = {},
["@slang.list_item_label"] = {fg = "#A294EB"},
["@slang.list_item_label_marker"] = {fg = "#7C759F"},
["@slang.list_item_marker"] = {fg = "#858391"},
["@slang.number"] = {fg = "#FC8F79"},
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
["@slang.outline_done"] = {fg = "#7C759F", bold = true},
["@slang.section"] = {fg = "#8797C2"},
["@slang.string"] = {fg = "#B3E87D"},
["@slang.tag.context"] = {fg = "#EDBE5E"},
["@slang.tag.danger"] = {fg = "#ffffff", bg = "#C3423F"},
["@slang.tag.hash"] = {fg = "#5BC0EB"},
["@slang.tag.identifier"] = {fg = "#e38fff"},
["@slang.tag.negative"] = {fg = "#FA4224"},
["@slang.tag.positive"] = {fg = "#9BC53D"},
["@slang.task_active"] = {fg = "#17CFCF"},
["@slang.task_cancelled"] = {fg = "#fa4040"},
["@slang.task_completion"] = {fg = "#7378a5"},
["@slang.task_default"] = {},
["@slang.task_done"] = {fg = "#7C759F"},
["@slang.task_marker_default"] = {fg = "#7C759F"},
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
["@text.literal.syslang"] = {fg = "#E0DEED"},
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
