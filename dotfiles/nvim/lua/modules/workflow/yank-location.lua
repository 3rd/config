-- builds a github permalink for the current file, returns nil if not in a github repo
local build_github_link = function(start_line, end_line)
  local file_path = vim.fn.expand("%:p")
  local git_root = vim.fn.systemlist("git rev-parse --show-toplevel")[1]
  if vim.v.shell_error ~= 0 or #git_root == 0 then return nil end

  local git_remote = vim.fn.systemlist("git config --get remote.origin.url")[1]
  local git_branch = vim.fn.systemlist("git rev-parse --abbrev-ref HEAD")[1]
  if not (git_remote:find("github") or not git_remote:find("@")) then return nil end

  local github_path = git_remote:gsub(".*:", ""):gsub(".git", "")
  local link = "https://github.com/"
    .. github_path
    .. "/blob/"
    .. git_branch
    .. "/"
    .. file_path:sub(#git_root + 2)
  if start_line then
    link = link .. "#L" .. start_line
    if end_line and end_line ~= start_line then link = link .. "-L" .. end_line end
  end
  return link
end

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

  -- syslang code block support
  if vim.bo.filetype == "syslang" then
    local parser = vim.treesitter.get_parser()
    if parser then
      local root = parser:parse()[1]:root()
      local position = vim.api.nvim_win_get_cursor(0)
      local node = root:named_descendant_for_range(position[1] - 1, position[2], position[1] - 1, position[2])

      -- find code_block ancestor
      local code_block = lib.ts.find_parent(node, "code_block")
      if code_block then
        local code_block_content = lib.ts.find_child(code_block, "code_block_content", true)
        if code_block_content then
          local content = vim.treesitter.get_node_text(code_block_content, 0)
          vim.fn.setreg("+", content)
          vim.notify("Yanked code block content")
          return
        end
      end
    end
  end

  local link = build_github_link(start_line, end_line)
  local result = link or file_path
  vim.fn.setreg("+", result)
  vim.notify("Yanked: " .. result)
end

local handle_path_yank = function()
  local file_path = vim.fn.expand("%:p")
  vim.fn.setreg("+", file_path)
  vim.notify("Yanked: " .. file_path)
end

local handle_relative_path_yank = function()
  local file_path = vim.fn.expand("%:.")
  vim.fn.setreg("+", file_path)
  vim.notify("Yanked: " .. file_path)
end

local handle_github_link_yank = function()
  local line = vim.fn.line(".")
  local link = build_github_link(line, line)
  if not link then
    vim.notify("Not in a GitHub repository", vim.log.levels.WARN)
    return
  end
  vim.fn.setreg("+", link)
  vim.notify("Yanked: " .. link)
end

local handle_github_link_visual_yank = function()
  local start_line = vim.fn.line("'<")
  local end_line = vim.fn.line("'>")
  local link = build_github_link(start_line, end_line)
  if not link then
    vim.notify("Not in a GitHub repository", vim.log.levels.WARN)
    return
  end
  vim.fn.setreg("+", link)
  vim.notify("Yanked: " .. link)
end

return lib.module.create({
  name = "workflow/yank-location",
  hosts = "*",
  mappings = {
    { { "n", "v" }, "<leader>y", handle_smart_yank, { desc = "Yank location (smart)" } },
    { { "n", "v" }, "<leader>Y", handle_path_yank, { desc = "Yank location (path)" } },
  },
  exports = {
    copy_absolute_path = handle_path_yank,
    copy_relative_path = handle_relative_path_yank,
    copy_github_link = handle_github_link_yank,
    copy_github_link_visual = handle_github_link_visual_yank,
  },
})
