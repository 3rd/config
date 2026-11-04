require("lib")

for _, plugin in ipairs({ "lualine.nvim", "nvim-web-devicons", "lush.nvim" }) do
  vim.opt.runtimepath:append(vim.fn.stdpath("data") .. "/lazy/" .. plugin)
end

vim.o.laststatus = 3
vim.o.showtabline = 2
vim.api.nvim_buf_set_name(0, vim.fn.tempname() .. ".md")
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "# Palette preview" })
vim.bo.filetype = "markdown"
vim.diagnostic.set(vim.api.nvim_create_namespace("statusline-colors-spec"), 0, {
  { lnum = 0, col = 0, message = "Preview warning", severity = vim.diagnostic.severity.WARN },
  { lnum = 0, col = 0, message = "Preview info", severity = vim.diagnostic.severity.INFO },
  { lnum = 0, col = 0, message = "Preview hint", severity = vim.diagnostic.severity.HINT },
})

local expected_colors = {
  lualine_a_normal = { fg = 0xC4C4D9, bg = 0x3B3945 },
  lualine_b_normal = { fg = 0xB7B7D1, bg = 0x323039 },
  lualine_c_normal = { fg = 0xAAAAC5, bg = 0x2C2A33 },
  lualine_a_tabs_active = { fg = 0xDFDFEC, bg = 0x323039 },
  lualine_a_tabs_inactive = { fg = 0x9292B0, bg = 0x252528 },
  TabLineFill = { fg = 0x7D7D97, bg = 0x222225 },
}

local diagnostic_colors = { warn = 0xEB9147, info = 0x7EBDFC, hint = 0x17CFCF }

for _, colorscheme in ipairs({ "static", "dynamic" }) do
  vim.cmd.colorscheme(colorscheme)
  require("modules/ui/statusline").plugins[1].config()
  require("lualine").refresh({ force = true, place = { "statusline", "tabline" } })

  for name, expected in pairs(expected_colors) do
    local highlight = vim.api.nvim_get_hl(0, { name = name, link = false })
    assert(highlight.fg == expected.fg and highlight.bg == expected.bg, colorscheme .. " changed " .. name)
  end

  local statusline = vim.api.nvim_eval_statusline(vim.o.statusline, { highlights = true, maxwidth = 200 })
  local rendered_diagnostics = {}

  for _, span in ipairs(statusline.highlights) do
    local severity = span.group:match("^lualine_c_diagnostics_(%a+)")
    if severity then
      local highlight = vim.api.nvim_get_hl(0, { name = span.group, link = false })
      assert(
        highlight.fg == diagnostic_colors[severity],
        colorscheme .. " changed the statusline " .. severity .. " color"
      )
      rendered_diagnostics[severity] = true
    end
  end

  for severity in pairs(diagnostic_colors) do
    assert(rendered_diagnostics[severity], colorscheme .. " did not render " .. severity .. " in the statusline")
  end
end

print("statusline colors: ok")
