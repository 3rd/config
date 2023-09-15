local colors = {
  -- PATCH_OPEN
Normal = {fg = "#A7AABD", bg = "#20212A"},
["@text"] = {link = "Normal"},
["@text.literal.markdown"] = {link = "Normal"},
Boolean = {fg = "#CEA700"},
["@boolean"] = {link = "Boolean"},
Character = {fg = "#8CD147"},
["@character"] = {link = "Character"},
CmpItemAbbr = {fg = "#A7AABD"},
CmpItemAbbrDeprecated = {fg = "#6A6A6A", strikethrough = true},
CmpItemAbbrMatch = {fg = "#3DB8F5"},
CmpItemAbbrMatchFuzzy = {fg = "#3DB8F5", bold = true},
CmpItemKind = {fg = "#3DB8F5"},
CmpItemKindClass = {fg = "#49C5F8"},
CmpItemKindColor = {},
CmpItemKindConstant = {fg = "#A7AABD"},
CmpItemKindConstructor = {fg = "#49C5F8"},
CmpItemKindCopilot = {fg = "#EC79C6"},
CmpItemKindEnum = {fg = "#68A9A7"},
CmpItemKindEnumMember = {fg = "#68A9A7"},
CmpItemKindEvent = {fg = "#68A9A7"},
CmpItemKindField = {fg = "#888FB3"},
CmpItemKindFile = {fg = "#3DB8F5"},
CmpItemKindFolder = {fg = "#3DB8F5"},
CmpItemKindFunction = {fg = "#49C5F8"},
CmpItemKindInterface = {fg = "#68A9A7"},
CmpItemKindKeyword = {fg = "#B18CE7"},
CmpItemKindMethod = {fg = "#49C5F8"},
CmpItemKindModule = {fg = "#FBCB6A"},
CmpItemKindOperator = {fg = "#C4639B"},
CmpItemKindProperty = {fg = "#8D90A2"},
CmpItemKindReference = {},
CmpItemKindSnippet = {fg = "#BF80FF"},
CmpItemKindStruct = {fg = "#68A9A7"},
CmpItemKindText = {fg = "#A7AABD"},
CmpItemKindTypeParameter = {fg = "#68A9A7"},
CmpItemKindUnit = {fg = "#68A9A7"},
CmpItemKindValue = {fg = "#CEA700"},
CmpItemKindVariable = {fg = "#A7AABD"},
CmpItemMenu = {fg = "#6A6A6A"},
ColorColumn = {},
Comment = {fg = "#6A6A6A", italic = true},
SpecialComment = {link = "Comment"},
["@comment"] = {link = "Comment"},
["@text.todo.checked"] = {link = "Comment"},
Conceal = {fg = "#9497AE"},
Conditional = {fg = "#B18CE7"},
["@conditional"] = {link = "Conditional"},
Constant = {fg = "#A7AABD"},
["@constant"] = {link = "Constant"},
["@text.reference"] = {link = "Constant"},
Constructor = {fg = "#49C5F8"},
["@constructor"] = {link = "Constructor"},
Cursor = {fg = "#20212A", bg = "#A7AABD"},
CursorColumn = {},
CursorIM = {},
CursorLine = {bg = "#323440"},
CursorLineNr = {fg = "#85889C", bg = "#323440"},
CursorLineSign = {fg = "#F67E55", bg = "#323440"},
Debug = {fg = "#D65C66"},
["@debug"] = {link = "Debug"},
["@constant.macro"] = {link = "Define"},
["@define"] = {link = "Define"},
Delimiter = {fg = "#5E5E5E"},
["@constructor.lua"] = {link = "Delimiter"},
["@punctuation"] = {link = "Delimiter"},
["@punctuation.bracket"] = {link = "Delimiter"},
["@punctuation.delimiter"] = {link = "Delimiter"},
["@punctuation.special"] = {link = "Delimiter"},
["@tag.delimiter"] = {link = "Delimiter"},
DiagnosticError = {fg = "#D65C66"},
DiagnosticFloatingError = {fg = "#D65C66"},
DiagnosticFloatingHint = {fg = "#52E0E0"},
DiagnosticFloatingInfo = {fg = "#3DB8F5"},
DiagnosticFloatingWarn = {fg = "#F67E55"},
DiagnosticHint = {fg = "#52E0E0"},
DiagnosticInfo = {fg = "#3DB8F5"},
DiagnosticSignError = {fg = "#D65C66"},
DiagnosticSignHint = {fg = "#52E0E0"},
DiagnosticSignInfo = {fg = "#3DB8F5"},
DiagnosticSignWarn = {fg = "#F67E55"},
DiagnosticUnderlineError = {undercurl = true},
DiagnosticUnderlineHint = {undercurl = true},
DiagnosticUnderlineInfo = {undercurl = true},
DiagnosticUnderlineWarn = {undercurl = true},
DiagnosticUnnecessary = {undercurl = true},
DiagnosticVirtualTextError = {fg = "#D65C66"},
DiagnosticVirtualTextHint = {fg = "#52E0E0"},
DiagnosticVirtualTextInfo = {fg = "#3DB8F5"},
DiagnosticVirtualTextWarn = {fg = "#BD370A"},
DiagnosticWarn = {fg = "#F67E55"},
DiffAdd = {fg = "#8CD147"},
diffAdded = {link = "DiffAdd"},
DiffChange = {fg = "#FBCB6A"},
diffChanged = {link = "DiffChange"},
DiffDelete = {fg = "#D65C66"},
diffRemoved = {link = "DiffDelete"},
DiffText = {fg = "#3DB8F5"},
Directory = {fg = "#3DB8F5"},
EndOfBuffer = {fg = "#20212A"},
Error = {fg = "#D65C66"},
["@error"] = {link = "Error"},
ErrorMsg = {fg = "#DE545F"},
["@text.danger"] = {link = "ErrorMsg"},
Exception = {fg = "#E6687B"},
["@exception"] = {link = "Exception"},
Field = {fg = "#888FB3"},
["@field"] = {link = "Field"},
["@float"] = {link = "Float"},
FoldColumn = {},
Folded = {},
Function = {fg = "#49C5F8"},
["@function"] = {link = "Function"},
["@function.call"] = {link = "Function"},
["@method"] = {link = "Function"},
["@method.call"] = {link = "Function"},
["@namespace"] = {link = "Function"},
GitSignsAdd = {fg = "#70B42D"},
GitSignsAddPreview = {},
GitSignsChange = {fg = "#F9B224"},
GitSignsDelete = {fg = "#C4313D"},
GitSignsDeletePreview = {},
Identifier = {fg = "#A7AABD"},
["@lsp.type.identifier"] = {link = "Identifier"},
["@symbol"] = {link = "Identifier"},
["@tag.attribute"] = {link = "Identifier"},
["@variable"] = {link = "Identifier"},
IncSearch = {fg = "#20212A", bg = "#FBCB6A"},
["@include"] = {link = "Include"},
IndentBlanklineIndent1 = {fg = "#464855"},
IndentBlanklineIndent2 = {fg = "#424450"},
IndentBlanklineIndent3 = {fg = "#3B3D48"},
IndentBlanklineIndent4 = {fg = "#353640"},
IndentBlanklineIndent5 = {fg = "#30323B"},
IndentBlanklineIndent6 = {fg = "#2A2C34"},
Keyword = {fg = "#B18CE7"},
["@keyword"] = {link = "Keyword"},
["@keyword.function"] = {link = "Keyword"},
Label = {fg = "#B18CE7"},
["@label"] = {link = "Label"},
LineNr = {fg = "#434655"},
LspCodeLens = {fg = "#80859F"},
LspCodeLensSeparator = {fg = "#5D627D"},
LspReferenceRead = {bg = "#F9B224"},
LspReferenceText = {bg = "#80859F"},
LspReferenceWrite = {bg = "#C4313D"},
LspSignatureActiveParameter = {fg = "#3DB8F5"},
Macro = {fg = "#BC8EC6"},
["@function.macro"] = {link = "Macro"},
["@keyword.operator"] = {link = "Macro"},
["@macro"] = {link = "Macro"},
["@text.environment"] = {link = "Macro"},
MatchParen = {bg = "#434655"},
NonText = {fg = "#80859F"},
NormalFloat = {},
NormalNC = {},
Number = {fg = "#CEA700"},
Float = {link = "Number"},
["@number"] = {link = "Number"},
NvimTreeFolderIcon = {fg = "#20ADF3"},
NvimTreeFolderName = {fg = "#A7AABD"},
NvimTreeGitDeleted = {fg = "#D65C66"},
NvimTreeGitDirty = {fg = "#F67E55"},
NvimTreeGitNew = {fg = "#8CD147"},
NvimTreeImageFile = {},
NvimTreeIndentMarker = {fg = "#616161"},
NvimTreeNormal = {bg = "#24252E"},
NvimTreeNormalNC = {},
NvimTreeOpenedFile = {fg = "#3DB8F5"},
NvimTreeRootFolder = {fg = "#3DB8F5", bold = true},
NvimTreeSpecialFile = {fg = "#3DB8F5"},
NvimTreeSymlink = {},
NvimTreeWinSeparator = {fg = "#373737", bg = "#24252E"},
Operator = {fg = "#C4639B"},
["@operator"] = {link = "Operator"},
Parameter = {fg = "#CD7C54"},
["@parameter"] = {link = "Parameter"},
Pmenu = {fg = "#A7AABD", bg = "#323440"},
PmenuSbar = {bg = "#434655"},
PmenuSel = {fg = "#20212A", bg = "#3DB8F5"},
PmenuThumb = {bg = "#6D7187"},
PreProc = {fg = "#B18CE7"},
["@attribute"] = {link = "PreProc"},
["@preproc"] = {link = "PreProc"},
Property = {fg = "#8D90A2"},
["@property"] = {link = "Property"},
RainbowBlue = {fg = "#4CA8D6"},
RainbowCyan = {fg = "#5CC7C7"},
RainbowGreen = {fg = "#85B851"},
RainbowOrange = {fg = "#DB8061"},
RainbowRed = {fg = "#BF636B"},
RainbowViolet = {fg = "#DA7CBB"},
RainbowYellow = {fg = "#E3BE72"},
Repeat = {fg = "#B18CE7"},
["@repeat"] = {link = "Repeat"},
Search = {fg = "#20212A", bg = "#F9B224"},
Substitute = {link = "Search"},
SignColumn = {},
Special = {fg = "#F67E55"},
SpecialChar = {link = "Special"},
Tag = {link = "Special"},
["@text.literal.markdown_inline"] = {link = "Special"},
["@text.math"] = {link = "Special"},
["@character.special"] = {link = "SpecialChar"},
["@string.escape"] = {link = "SpecialChar"},
["@string.special"] = {link = "SpecialChar"},
["@text.note"] = {link = "SpecialComment"},
SpecialKeyword = {fg = "#C297FF"},
Define = {link = "SpecialKeyword"},
Include = {link = "SpecialKeyword"},
PreCondit = {link = "SpecialKeyword"},
["@keyword.coroutine"] = {link = "SpecialKeyword"},
["@tag.tsx"] = {link = "SpecialKeyword"},
Statement = {fg = "#B18CE7"},
["@storageclass"] = {link = "StorageClass"},
String = {fg = "#97C75B"},
["@string"] = {link = "String"},
["@string.regex"] = {link = "String"},
["@text.literal"] = {link = "String"},
["@structure"] = {link = "Structure"},
TabLine = {bg = "#434655"},
TabLineFill = {bg = "#323440"},
TabLineSel = {bg = "#585B6E"},
["@tag"] = {link = "Tag"},
TermCursor = {},
TermCursorNC = {},
Title = {fg = "#F075C7"},
["@text.title"] = {link = "Title"},
Todo = {fg = "#FBCB6A", bold = true, italic = true},
["@text.todo"] = {link = "Todo"},
["@text.todo.unchecked"] = {link = "Todo"},
Type = {fg = "#68A9A7"},
StorageClass = {link = "Type"},
Structure = {link = "Type"},
Typedef = {link = "Type"},
["@text.environment.name"] = {link = "Type"},
["@type"] = {link = "Type"},
["@type.qualifier"] = {link = "Type"},
["@type.definition"] = {link = "Typedef"},
Underlined = {undercurl = true},
["@text.underline"] = {link = "Underlined"},
["@text.uri"] = {link = "Underlined"},
VertSplit = {fg = "#323440"},
Visual = {bg = "#434655"},
WarningMsg = {},
["@text.warning"] = {link = "WarningMsg"},
Whitespace = {fg = "#626368"},
SpecialKey = {link = "Whitespace"},
lCursor = {},
["@lsp.typemod.deriveHelper.attribute"] = {link = "@attribute"},
["@constant.builtin"] = {link = "@boolean"},
["@lsp.type.boolean"] = {link = "@boolean"},
["@variable.builtin"] = {link = "@boolean"},
["@builtin"] = {fg = "#E6687B"},
["@function.builtin"] = {link = "@builtin"},
["@keyword.return"] = {link = "@builtin"},
["@lsp.type.character"] = {link = "@character"},
["@lsp.type.enumMember"] = {link = "@constant"},
["@constructor.tsx"] = {},
["@lsp.type.class"] = {link = "@constructor"},
["@lsp.typemod.property.declaration"] = {link = "@field"},
["@lsp.type.float"] = {link = "@float"},
["@lsp.type.keyword"] = {link = "@keyword"},
["@lsp.mod.constant"] = {},
["@lsp.mod.readonly"] = {},
["@lsp.mod.static"] = {italic = true},
["@lsp.type.event"] = {fg = "#F67E55"},
["@lsp.type.function"] = {},
["@lsp.type.lifetime"] = {fg = "#EC79C6"},
["@lsp.typemod.function"] = {},
["@lsp.typemod.string.constant"] = {},
["@lsp.typemod.string.readonly"] = {},
["@lsp.typemod.string.static"] = {},
["@lsp.mod.annotation"] = {link = "@macro"},
["@lsp.type.macro"] = {link = "@macro"},
["@lsp.typemod.class.defaultLibrary"] = {link = "@macro"},
["@lsp.typemod.function.defaultLibrary"] = {link = "@macro"},
["@lsp.typemod.variable.defaultLibrary"] = {link = "@macro"},
["@lsp.type.method"] = {link = "@method"},
["@lsp.type.namespace"] = {link = "@namespace"},
["@none"] = {fg = "NONE", bg = "NONE"},
["@lsp.type.number"] = {link = "@number"},
["@lsp.type.operator"] = {link = "@operator"},
["@lsp.type.decorator"] = {link = "@parameter"},
["@lsp.type.parameter"] = {link = "@parameter"},
["@tag.attribute.tsx"] = {link = "@parameter"},
["@lsp.type.property"] = {link = "@property"},
["@slang.banner"] = {fg = "#A9B9E5", bg = "#38425B"},
["@slang.bold"] = {fg = "#C1D1FF", bold = true},
["@slang.code_block_content"] = {fg = "#BDC7EE"},
["@slang.code_block_end"] = {fg = "#585B6E", italic = true},
["@slang.code_block_fence"] = {bg = "#2A2C36"},
["@slang.code_block_language"] = {fg = "#6D7187", italic = true},
["@slang.code_block_start"] = {fg = "#585B6E", italic = true},
["@slang.comment"] = {fg = "#6A6A6A"},
["@slang.date"] = {fg = "#FC824A"},
["@slang.daterange"] = {fg = "#FC824A"},
["@slang.datetime"] = {fg = "#FC824A"},
["@slang.datetimerange"] = {fg = "#FC824A"},
["@slang.document.meta"] = {fg = "#FBCB6A"},
["@slang.document.meta.field"] = {fg = "#F075C7"},
["@slang.document.meta.field.key"] = {fg = "#EC79C6"},
["@slang.document.title"] = {fg = "#F67E55", bold = true},
["@slang.error"] = {fg = "#ffffff", bg = "#7a2633"},
["@slang.external_link"] = {fg = "#5db4e3", italic = true, undercurl = true},
["@slang.heading_1.marker"] = {fg = "#9999FF"},
["@slang.heading_1.text"] = {fg = "#9999FF", bold = true},
["@slang.heading_2.marker"] = {fg = "#C08FFF"},
["@slang.heading_2.text"] = {fg = "#C08FFF", bold = true},
["@slang.heading_3.marker"] = {fg = "#E38FFF"},
["@slang.heading_3.text"] = {fg = "#E38FFF", bold = true},
["@slang.heading_4.marker"] = {fg = "#FFC78F"},
["@slang.heading_4.text"] = {fg = "#FFC78F", bold = true},
["@slang.heading_5.marker"] = {fg = "#04D3D0"},
["@slang.heading_5.text"] = {fg = "#04D3D0", bold = true},
["@slang.heading_6.marker"] = {fg = "#f0969f"},
["@slang.heading_6.text"] = {fg = "#f0969f", bold = true},
["@slang.heading_done"] = {fg = "#6A6A6A", bold = true},
["@slang.inline_code"] = {fg = "#F09070"},
["@slang.italic"] = {italic = true},
["@slang.label"] = {fg = "#FBCB6A"},
["@slang.link"] = {fg = "#5BC0CD", italic = true, undercurl = true},
["@slang.list_item"] = {},
["@slang.list_item_label"] = {fg = "#FBCB6A", italic = true},
["@slang.list_item_label_marker"] = {fg = "#6A6A6A"},
["@slang.list_item_marker"] = {fg = "#626368"},
["@slang.number"] = {fg = "#CEA700"},
["@slang.section"] = {fg = "#04D3D0"},
["@slang.string"] = {fg = "#97C75B"},
["@slang.tag.context"] = {fg = "#FBCB6A"},
["@slang.tag.danger"] = {fg = "#ffffff", bg = "#C3423F"},
["@slang.tag.hash"] = {fg = "#5BC0EB"},
["@slang.tag.identifier"] = {fg = "#e38fff"},
["@slang.tag.negative"] = {fg = "#FA4224"},
["@slang.tag.positive"] = {fg = "#9BC53D"},
["@slang.task_active"] = {fg = "#52E0E0"},
["@slang.task_cancelled"] = {fg = "#fa4040"},
["@slang.task_default"] = {},
["@slang.task_done"] = {fg = "#6A6A6A"},
["@slang.task_schedule"] = {fg = "#FF8000"},
["@slang.task_session"] = {fg = "#7378a5"},
["@slang.ticket"] = {fg = "#fa89f6"},
["@slang.time"] = {fg = "#FC824A"},
["@slang.timerange"] = {fg = "#FC824A"},
["@slang.underline"] = {underline = true},
["@lsp.mod.interpolation"] = {link = "@string.special"},
["@lsp.type.string"] = {link = "@string"},
["@lsp.type.struct"] = {link = "@structure"},
["@text.emphasis"] = {italic = true},
["@text.strike"] = {strikethrough = true},
["@text.strong"] = {bold = true},
["@lsp.type.typeAlias"] = {link = "@type.definition"},
["@lsp.type.enum"] = {link = "@type"},
["@lsp.type.interface"] = {link = "@type"},
["@lsp.type.type"] = {link = "@type"},
["@lsp.type.typeParameter"] = {link = "@type"},
["@lsp.typemod.interface"] = {link = "@type"},
["@lsp.typemod.type.defaultLibrary"] = {link = "@type"},
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
