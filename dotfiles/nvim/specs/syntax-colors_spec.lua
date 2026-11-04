require("lib")
vim.opt.runtimepath:append(vim.fn.stdpath("data") .. "/lazy/lush.nvim")

local syntax_colors = {
  Normal = 0xCDCDD9,
  Function = 0x67BBFF,
  ["@builtin"] = 0xE67A7F,
  Keyword = 0x757589,
  Type = 0x5BD5E0,
  ["@lsp.type.parameter"] = 0x63E3C7,
  Number = 0xEEAF5D,
  SpecialKeyword = 0xDE94D0,
  Conditional = 0xF79065,
}

for _, colorscheme in ipairs({ "static", "dynamic" }) do
  vim.cmd.colorscheme(colorscheme)

  for name, expected in pairs(syntax_colors) do
    local highlight = vim.api.nvim_get_hl(0, { name = name, link = false })
    assert(highlight.fg == expected, colorscheme .. " has the wrong " .. name .. " syntax color")
  end
end

print("ok: exact shared syntax colors in both themes")
