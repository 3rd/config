local handle_smart_yank = function()
  local file_path = vim.fn.expand("%:p")
  local start_line, end_line
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, true, true), "n", true)
  if vim.fn.mode() == "v" or vim.fn.mode() == "V" then
    local start_pos = vim.fn.getpos("v")
    local end_pos = vim.fn.getcurpos()
    start_line = start_pos[2]
    end_line = end_pos[2]
  else
    start_line = vim.fn.line(".")
    end_line = start_line
  end
  local git_root = vim.fn.systemlist("git rev-parse --show-toplevel")[1]

  if vim.v.shell_error == 0 and #git_root > 0 then
    local git_remote = vim.fn.systemlist("git config --get remote.origin.url")[1]
    local git_branch = vim.fn.systemlist("git rev-parse --abbrev-ref HEAD")[1]

    if git_remote:find("github") or not git_remote:find("@") then
      local github_path = git_remote:gsub(".*:", ""):gsub(".git", "")
      local permalink = "https://github.com/"
        .. github_path
        .. "/blob/"
        .. git_branch
        .. "/"
        .. file_path:sub(#git_root + 2)
        .. "#L"
        .. start_line
      if start_line ~= end_line then permalink = permalink .. "-L" .. end_line end
      vim.fn.setreg("+", permalink)
      vim.notify("Yanked: " .. permalink)
    else
      vim.fn.setreg("+", file_path)
      vim.notify("Yanked: " .. file_path)
    end
  else
    vim.fn.setreg("+", file_path)
    vim.notify("Yanked: " .. file_path)
  end
end

local handle_path_yank = function()
  local file_path = vim.fn.expand("%:p")
  vim.fn.setreg("+", file_path)
  vim.notify("Yanked: " .. file_path)
end

return lib.module.create({
  name = "workflow/yank-location",
  hosts = "*",
  mappings = {
    { { "n", "v" }, "<leader>y", handle_smart_yank, { desc = "Yank location (smart)" } },
    { { "n", "v" }, "<leader>Y", handle_path_yank, { desc = "Yank location (path)" } },
  },
})
