require("lib")

for _, plugin in ipairs({ "gitsigns.nvim", "nvim-colorizer.lua" }) do
  vim.opt.runtimepath:append(vim.fn.stdpath("data") .. "/lazy/" .. plugin)
end

vim.o.termguicolors = true
vim.cmd.colorscheme("static")
require("modules/workflow/git").plugins[1].config()
require("gitsigns").toggle_linehl(true)
require("colorizer").setup(require("modules/misc/colorizer").plugins[1].opts)

local project_root = vim.fn.tempname()
vim.fn.mkdir(project_root, "p")

local run_git = function(args)
  local command = { "git", "-c", "user.name=Test", "-c", "user.email=test@example.com", "-c", "commit.gpgsign=false" }
  vim.list_extend(command, args)

  local result = vim
    .system(command, {
      cwd = project_root,
      text = true,
      env = { GIT_CONFIG_NOSYSTEM = "1", GIT_CONFIG_GLOBAL = "/dev/null" },
    })
    :wait()
  assert(result.code == 0, result.stderr)
end

local project_file = project_root .. "/sample.css"
local lines = {
  ".sample {",
  "  --staged: #112244;",
  "",
  "  --unchanged: #4a6c8e;",
  "",
  "  --working: #334455;",
  "}",
}
vim.fn.writefile(lines, project_file)
run_git({ "init", "--quiet", "--template=" })
run_git({ "add", "sample.css" })
run_git({ "commit", "--quiet", "-m", "test: colors" })
lines[2] = "  --staged: #fafafa;"
vim.fn.writefile(lines, project_file)
run_git({ "add", "sample.css" })
lines[6] = "  --working: #101820;"
vim.fn.writefile(lines, project_file)
vim.cmd.edit(project_file)
vim.bo.filetype = "css"
local bufnr = vim.api.nvim_get_current_buf()

local find_highlights = function(line)
  vim.cmd.redraw()
  local marks = vim.api.nvim_buf_get_extmarks(bufnr, -1, { line - 1, 0 }, { line - 1, -1 }, { details = true })
  local preview
  local sign
  local line_tint

  for _, mark in ipairs(marks) do
    local details = mark[4]
    if details.hl_group and details.hl_group:find("^colorizer_") then preview = details end
    if details.hl_group and details.hl_group:find("^GitSigns") then line_tint = details end
    if details.sign_text then sign = details end
  end

  return preview, sign, line_tint
end

for _, case in ipairs({
  { line = 2, background = 0xfafafa, foreground = 0x000000 },
  { line = 6, background = 0x101820, foreground = 0xffffff },
}) do
  assert(
    vim.wait(2000, function()
      local preview, sign, line_tint = find_highlights(case.line)
      return preview ~= nil and sign ~= nil and line_tint ~= nil
    end),
    "color preview and Git line highlighting must both be present"
  )

  local preview, sign, line_tint = find_highlights(case.line)
  assert(sign.line_hl_group == nil, "Git must not use the sign background that overrides color previews")
  assert(line_tint.hl_eol and line_tint.end_row == case.line, "Git line tint must cover the whole screen row")
  assert(sign.end_row == nil, "Git signs must not extend onto the following line")
  local highlight = vim.api.nvim_get_hl(0, { name = preview.hl_group, link = false })
  assert(highlight.bg == case.background and highlight.fg == case.foreground, "color preview must retain its contrast")
  assert(preview.priority > line_tint.priority, "color previews must render above Git whole-line backgrounds")
end

require("gitsigns").detach(bufnr)
local preview, sign, line_tint = find_highlights(2)
assert(preview ~= nil and sign == nil and line_tint == nil, "detaching Git must clear only its highlights")

vim.api.nvim_buf_delete(bufnr, { force = true })
vim.fn.delete(project_root, "rf")
print("ok: light and dark color previews render above staged and unstaged Git line highlights")
