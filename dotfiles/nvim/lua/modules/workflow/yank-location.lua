-- builds a github permalink for the current file, returns nil if not in a github repo
local build_github_link = function(start_line, end_line, revision)
  local file_path = vim.fn.expand("%:p")
  local directory = vim.fs.dirname(file_path)
  local git = function(arguments)
    local command = { "git", "-C", directory }
    vim.list_extend(command, arguments)
    local result = vim.system(command, { text = true }):wait()
    if result.code ~= 0 then return nil end
    return vim.trim(result.stdout)
  end
  local git_root = git({ "rev-parse", "--show-toplevel" })
  if not git_root then return nil end
  local git_remote = git({ "config", "--get", "remote.origin.url" })
  if not git_remote then return nil end
  local github_path = git_remote:match("^git@github%.com:(.+)$")
    or git_remote:match("^https?://github%.com/(.+)$")
    or git_remote:match("^ssh://git@github%.com/(.+)$")
  if not github_path then return nil end
  github_path = github_path:gsub("/+$", ""):gsub("%.git$", "")
  local reference = git(revision == "branch" and { "symbolic-ref", "--short", "HEAD" } or { "rev-parse", "HEAD" })
  if not reference then return nil end
  local relative_path = vim.fs.relpath(git_root, file_path)
  if not relative_path then return nil end
  local changed = git({ "status", "--porcelain", "--", relative_path })
  if vim.bo.modified or (changed and changed ~= "") then
    vim.notify("GitHub link refers to committed content; local changes are not included", vim.log.levels.WARN)
  end
  local encode_path = function(path)
    return path:gsub("[^%w%-%._~/]", function(character)
      return string.format("%%%02X", string.byte(character))
    end)
  end
  local link = "https://github.com/"
    .. github_path
    .. "/blob/"
    .. encode_path(reference)
    .. "/"
    .. encode_path(relative_path)
  if start_line then
    if end_line and end_line < start_line then
      start_line, end_line = end_line, start_line
    end
    link = link .. "#L" .. start_line
    if end_line and end_line ~= start_line then link = link .. "-L" .. end_line end
  end
  return link
end

local dedent_code_block = function(content)
  local lines = vim.split(content, "\n", { plain = true, trimempty = false })
  local common_indent

  for _, line in ipairs(lines) do
    if line:find("%S") then
      local line_indent = #line:match("^%s*")
      common_indent = common_indent and math.min(common_indent, line_indent) or line_indent
    end
  end

  if not common_indent or common_indent == 0 then return content end

  for index, line in ipairs(lines) do
    lines[index] = line:sub(common_indent + 1)
  end

  return table.concat(lines, "\n")
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
          vim.fn.setreg("+", dedent_code_block(content))
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

local handle_github_link_yank = function(revision)
  local line = vim.fn.line(".")
  local link = build_github_link(line, line, revision)
  if not link then
    vim.notify("Not in a GitHub repository", vim.log.levels.WARN)
    return
  end
  vim.fn.setreg("+", link)
  vim.notify("Yanked: " .. link)
end

local handle_github_link_visual_yank = function(revision)
  local start_line = vim.fn.line("'<")
  local end_line = vim.fn.line("'>")
  local link = build_github_link(start_line, end_line, revision)
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
  actions = {
    {
      "n",
      "File: Copy GitHub branch link",
      function()
        handle_github_link_yank("branch")
      end,
    },
    {
      "v",
      "File: Copy GitHub branch link to selection",
      function()
        handle_github_link_visual_yank("branch")
      end,
    },
  },
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
