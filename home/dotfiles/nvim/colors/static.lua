local colors = {
  -- PATCH_OPEN
Normal = {fg = "#C2C9F0", bg = "#1E2029"},
["@text"] = {link = "Normal"},
["@text.literal.markdown"] = {link = "Normal"},
Boolean = {fg = "#EC79C6"},
["@boolean"] = {link = "Boolean"},
Character = {fg = "#99D65C"},
["@character"] = {link = "Character"},
CmpItemAbbr = {fg = "#C2C9F0"},
CmpItemAbbrDeprecated = {fg = "#717AA8", strikethrough = true},
CmpItemAbbrMatch = {fg = "#38B9FA"},
CmpItemAbbrMatchFuzzy = {fg = "#38B9FA", bold = true},
CmpItemKind = {fg = "#38B9FA"},
CmpItemKindClass = {fg = "#54BEF2"},
CmpItemKindColor = {},
CmpItemKindConstant = {fg = "#EC79C6"},
CmpItemKindConstructor = {fg = "#54BEF2"},
CmpItemKindCopilot = {fg = "#EC79C6"},
CmpItemKindEnum = {fg = "#3CDDDD"},
CmpItemKindEnumMember = {fg = "#3CDDDD"},
CmpItemKindEvent = {fg = "#3CDDDD"},
CmpItemKindField = {fg = "#9DA8E2"},
CmpItemKindFile = {fg = "#38B9FA"},
CmpItemKindFolder = {fg = "#38B9FA"},
CmpItemKindFunction = {fg = "#38B9FA"},
CmpItemKindInterface = {fg = "#3CDDDD"},
CmpItemKindKeyword = {fg = "#BF93EC"},
CmpItemKindMethod = {fg = "#38B9FA"},
CmpItemKindModule = {fg = "#EB9947"},
CmpItemKindOperator = {fg = "#6878CA"},
CmpItemKindProperty = {fg = "#9DA8E2"},
CmpItemKindReference = {},
CmpItemKindSnippet = {fg = "#BF80FF"},
CmpItemKindStruct = {fg = "#3CDDDD"},
CmpItemKindText = {fg = "#C2C9F0"},
CmpItemKindTypeParameter = {fg = "#3CDDDD"},
CmpItemKindUnit = {fg = "#3CDDDD"},
CmpItemKindValue = {fg = "#EC79C6"},
CmpItemKindVariable = {fg = "#C2C9F0"},
CmpItemMenu = {fg = "#717AA8"},
ColorColumn = {},
Comment = {fg = "#717AA8", italic = true},
SpecialComment = {link = "Comment"},
["@comment"] = {link = "Comment"},
["@text.todo.checked"] = {link = "Comment"},
Conceal = {fg = "#A1ADE8"},
Conditional = {fg = "#BF93EC"},
["@conditional"] = {link = "Conditional"},
Constant = {fg = "#EC79C6"},
["@constant"] = {link = "Constant"},
["@text.reference"] = {link = "Constant"},
Constructor = {fg = "#54BEF2"},
["@constructor"] = {link = "Constructor"},
Cursor = {fg = "#1E2029", bg = "#C2C9F0"},
CursorColumn = {},
CursorIM = {},
CursorLine = {bg = "#323543"},
CursorLineNr = {fg = "#8186A2", bg = "#323543"},
CursorLineSign = {fg = "#F67E55", bg = "#323543"},
Debug = {fg = "#D65C66"},
["@debug"] = {link = "Debug"},
["@constant.macro"] = {link = "Define"},
["@define"] = {link = "Define"},
Delimiter = {fg = "#68719C"},
["@constructor.lua"] = {link = "Delimiter"},
["@punctuation"] = {link = "Delimiter"},
["@punctuation.bracket"] = {link = "Delimiter"},
["@punctuation.delimiter"] = {link = "Delimiter"},
["@punctuation.special"] = {link = "Delimiter"},
["@tag.delimiter"] = {link = "Delimiter"},
DiagnosticError = {fg = "#D65C66"},
DiagnosticFloatingError = {fg = "#D65C66"},
DiagnosticFloatingHint = {fg = "#3CDDDD"},
DiagnosticFloatingInfo = {fg = "#38B9FA"},
DiagnosticFloatingWarn = {fg = "#F67E55"},
DiagnosticHint = {fg = "#3CDDDD"},
DiagnosticInfo = {fg = "#38B9FA"},
DiagnosticSignError = {fg = "#D65C66"},
DiagnosticSignHint = {fg = "#3CDDDD"},
DiagnosticSignInfo = {fg = "#38B9FA"},
DiagnosticSignWarn = {fg = "#F67E55"},
DiagnosticUnderlineError = {undercurl = true},
DiagnosticUnderlineHint = {undercurl = true},
DiagnosticUnderlineInfo = {undercurl = true},
DiagnosticUnderlineWarn = {undercurl = true},
DiagnosticUnnecessary = {undercurl = true},
DiagnosticVirtualTextError = {fg = "#D65C66"},
DiagnosticVirtualTextHint = {fg = "#3CDDDD"},
DiagnosticVirtualTextInfo = {fg = "#38B9FA"},
DiagnosticVirtualTextWarn = {fg = "#BD370A"},
DiagnosticWarn = {fg = "#F67E55"},
DiffAdd = {fg = "#99D65C"},
diffAdded = {link = "DiffAdd"},
DiffChange = {fg = "#EB9947"},
diffChanged = {link = "DiffChange"},
DiffDelete = {fg = "#D65C66"},
diffRemoved = {link = "DiffDelete"},
DiffText = {fg = "#38B9FA"},
Directory = {fg = "#38B9FA"},
EndOfBuffer = {fg = "#1E2029"},
Error = {fg = "#D65C66"},
["@error"] = {link = "Error"},
ErrorMsg = {fg = "#DE545F"},
["@text.danger"] = {link = "ErrorMsg"},
Exception = {fg = "#D65C66"},
["@exception"] = {link = "Exception"},
Field = {fg = "#9DA8E2"},
["@field"] = {link = "Field"},
["@float"] = {link = "Float"},
FoldColumn = {},
Folded = {},
Function = {fg = "#38B9FA"},
["@function"] = {link = "Function"},
["@function.call"] = {link = "Function"},
["@method"] = {link = "Function"},
["@method.call"] = {link = "Function"},
["@namespace"] = {link = "Function"},
GitSignsAdd = {fg = "#7AC431"},
GitSignsAddPreview = {},
GitSignsChange = {fg = "#DC7A18"},
GitSignsDelete = {fg = "#C4313D"},
GitSignsDeletePreview = {},
Identifier = {fg = "#C2C9F0"},
["@lsp.type.identifier"] = {link = "Identifier"},
["@symbol"] = {link = "Identifier"},
["@tag.attribute"] = {link = "Identifier"},
["@variable"] = {link = "Identifier"},
IncSearch = {fg = "#1E2029", bg = "#EB9947"},
["@include"] = {link = "Include"},
IndentBlanklineIndent1 = {fg = "#484B5B"},
IndentBlanklineIndent2 = {fg = "#414453"},
IndentBlanklineIndent3 = {fg = "#3D3F4D"},
IndentBlanklineIndent4 = {fg = "#363845"},
IndentBlanklineIndent5 = {fg = "#31343F"},
IndentBlanklineIndent6 = {fg = "#2B2D36"},
Keyword = {fg = "#BF93EC"},
["@keyword"] = {link = "Keyword"},
["@keyword.function"] = {link = "Keyword"},
Label = {fg = "#BF93EC"},
["@label"] = {link = "Label"},
LineNr = {fg = "#43475B"},
LspCodeLens = {fg = "#7C8DDE"},
LspCodeLensSeparator = {fg = "#3750CD"},
LspReferenceRead = {bg = "#DC7A18"},
LspReferenceText = {bg = "#7C8DDE"},
LspReferenceWrite = {bg = "#C4313D"},
LspSignatureActiveParameter = {fg = "#38B9FA"},
Macro = {fg = "#BF93EC"},
["@function.macro"] = {link = "Macro"},
["@keyword.operator"] = {link = "Macro"},
["@macro"] = {link = "Macro"},
["@text.environment"] = {link = "Macro"},
MatchParen = {bg = "#43475B"},
NonText = {fg = "#7C8DDE"},
NormalFloat = {},
NormalNC = {},
Number = {fg = "#EC79C6"},
Float = {link = "Number"},
["@number"] = {link = "Number"},
NvimTreeFolderIcon = {fg = "#1AAFF9"},
NvimTreeFolderName = {fg = "#C2C9F0"},
NvimTreeGitDeleted = {fg = "#D65C66"},
NvimTreeGitDirty = {fg = "#F67E55"},
NvimTreeGitNew = {fg = "#99D65C"},
NvimTreeImageFile = {},
NvimTreeIndentMarker = {fg = "#616B9E"},
NvimTreeNormal = {bg = "#23252F"},
NvimTreeNormalNC = {},
NvimTreeOpenedFile = {fg = "#38B9FA"},
NvimTreeRootFolder = {fg = "#38B9FA", bold = true},
NvimTreeSpecialFile = {fg = "#38B9FA"},
NvimTreeSymlink = {},
NvimTreeWinSeparator = {fg = "#363C59", bg = "#23252F"},
Operator = {fg = "#6878CA"},
["@operator"] = {link = "Operator"},
Parameter = {fg = "#EB9947"},
["@parameter"] = {link = "Parameter"},
Pmenu = {fg = "#C2C9F0", bg = "#323543"},
PmenuSbar = {bg = "#43475B"},
PmenuSel = {fg = "#1E2029", bg = "#38B9FA"},
PmenuThumb = {bg = "#686E8D"},
PreProc = {fg = "#BF93EC"},
["@attribute"] = {link = "PreProc"},
["@preproc"] = {link = "PreProc"},
Property = {fg = "#9DA8E2"},
["@property"] = {link = "Property"},
RainbowBlue = {fg = "#47819E"},
RainbowCyan = {fg = "#4B8686"},
RainbowGreen = {fg = "#738E57"},
RainbowOrange = {fg = "#AA6650"},
RainbowRed = {fg = "#8E575C"},
RainbowViolet = {fg = "#AE6194"},
RainbowYellow = {fg = "#97734E"},
Repeat = {fg = "#BF93EC"},
["@repeat"] = {link = "Repeat"},
Search = {fg = "#1E2029", bg = "#DC7A18"},
Substitute = {link = "Search"},
SignColumn = {},
Special = {fg = "#F67E55"},
SpecialChar = {link = "Special"},
Tag = {link = "Special"},
["@tag.attribute.tsx"] = {link = "Special"},
["@text.literal.markdown_inline"] = {link = "Special"},
["@text.math"] = {link = "Special"},
["@character.special"] = {link = "SpecialChar"},
["@string.escape"] = {link = "SpecialChar"},
["@string.special"] = {link = "SpecialChar"},
["@text.note"] = {link = "SpecialComment"},
SpecialKeyword = {fg = "#BF93EC"},
Define = {link = "SpecialKeyword"},
Include = {link = "SpecialKeyword"},
PreCondit = {link = "SpecialKeyword"},
["@keyword.coroutine"] = {link = "SpecialKeyword"},
["@tag.tsx"] = {link = "SpecialKeyword"},
Statement = {fg = "#BF93EC"},
["@storageclass"] = {link = "StorageClass"},
String = {fg = "#99D65C"},
["@string"] = {link = "String"},
["@string.regex"] = {link = "String"},
["@text.literal"] = {link = "String"},
["@structure"] = {link = "Structure"},
TabLine = {bg = "#3B3E4F"},
TabLineFill = {bg = "#323543"},
TabLineSel = {bg = "#43475B"},
["@tag"] = {link = "Tag"},
TermCursor = {},
TermCursorNC = {},
Title = {fg = "#F075C7"},
["@text.title"] = {link = "Title"},
Todo = {fg = "#EB9947", bold = true, italic = true},
["@text.todo"] = {link = "Todo"},
["@text.todo.unchecked"] = {link = "Todo"},
Type = {fg = "#3CDDDD"},
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
VertSplit = {fg = "#323543"},
Visual = {bg = "#43475B"},
WarningMsg = {},
["@text.warning"] = {link = "WarningMsg"},
Whitespace = {fg = "#737891"},
SpecialKey = {link = "Whitespace"},
lCursor = {},
["@lsp.typemod.deriveHelper.attribute"] = {link = "@attribute"},
["@constant.builtin"] = {link = "@boolean"},
["@lsp.type.boolean"] = {link = "@boolean"},
["@variable.builtin"] = {link = "@boolean"},
["@builtin"] = {fg = "#D65C66"},
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
["@lsp.type.property"] = {link = "@property"},
["@slang.banner"] = {fg = "#A9B9E5", bg = "#38425B"},
["@slang.bold"] = {fg = "#C1D1FF", bold = true},
["@slang.code_block_content"] = {fg = "#C2C9F0"},
["@slang.code_block_end"] = {fg = "#43475B", italic = true},
["@slang.code_block_fence"] = {bg = "#272935"},
["@slang.code_block_language"] = {fg = "#575C75", italic = true},
["@slang.code_block_start"] = {fg = "#43475B", italic = true},
["@slang.comment"] = {fg = "#717AA8"},
["@slang.date"] = {fg = "#FC824A"},
["@slang.daterange"] = {fg = "#FC824A"},
["@slang.datetime"] = {fg = "#FC824A"},
["@slang.datetimerange"] = {fg = "#FC824A"},
["@slang.document.meta"] = {fg = "#EB9947"},
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
["@slang.heading_done"] = {fg = "#717AA8", bold = true},
["@slang.image"] = {fg = "#EB9947"},
["@slang.inline_code"] = {fg = "#F09070"},
["@slang.internal_link"] = {fg = "#5BC0CD", undercurl = true},
["@slang.italic"] = {italic = true},
["@slang.label"] = {fg = "#EB9947"},
["@slang.link"] = {fg = "#5BC0CD", italic = true, undercurl = true},
["@slang.list_item"] = {},
["@slang.list_item_label"] = {fg = "#F4AD67", italic = true},
["@slang.list_item_label_marker"] = {fg = "#717AA8"},
["@slang.list_item_marker"] = {fg = "#737891"},
["@slang.number"] = {fg = "#71c9f6"},
["@slang.section"] = {fg = "#04D3D0"},
["@slang.string"] = {fg = "#4efa8e"},
["@slang.tag.context"] = {fg = "#EB9947"},
["@slang.tag.danger"] = {fg = "#ffffff", bg = "#C3423F"},
["@slang.tag.hash"] = {fg = "#5BC0EB"},
["@slang.tag.identifier"] = {fg = "#e38fff"},
["@slang.tag.negative"] = {fg = "#FA4224"},
["@slang.tag.positive"] = {fg = "#9BC53D"},
["@slang.task_active"] = {fg = "#3CDDDD"},
["@slang.task_cancelled"] = {fg = "#fa4040"},
["@slang.task_default"] = {},
["@slang.task_done"] = {fg = "#717AA8"},
["@slang.task_marker_default"] = {fg = "#717AA8"},
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
["@text.literal.syslang"] = {fg = "#C2C9F0"},
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
