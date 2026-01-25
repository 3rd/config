-- state
local job_id = nil
local current_path = nil

local is_markdown = function()
  return vim.bo.filetype == "markdown"
end

local get_current_path = function()
  return vim.api.nvim_buf_get_name(0)
end

local stop_preview = function()
  if job_id then
    vim.fn.jobstop(job_id)
    job_id = nil
    current_path = nil
    vim.notify("Markdown preview stopped", vim.log.levels.INFO)
  end
end

local start_preview = function()
  if not is_markdown() then
    vim.notify("Not a markdown file", vim.log.levels.WARN)
    return
  end

  if job_id then
    vim.notify("Markdown preview already running", vim.log.levels.INFO)
    return
  end

  local path = get_current_path()
  if path == "" then
    vim.notify("Buffer has no file path", vim.log.levels.WARN)
    return
  end

  current_path = path
  local cmd = { "gh", "markdown-preview", path }

  job_id = vim.fn.jobstart(cmd, {
    on_exit = function()
      job_id = nil
      current_path = nil
    end,
  })

  if job_id <= 0 then
    vim.notify("Failed to start markdown preview", vim.log.levels.ERROR)
    job_id = nil
    current_path = nil
    return
  end

  vim.notify("Markdown preview started", vim.log.levels.INFO)
end

local setup = function()
  -- auto-restart when navigating to different markdown file
  vim.api.nvim_create_autocmd("BufEnter", {
    pattern = "*.md",
    callback = function()
      if not job_id then return end

      local new_path = get_current_path()
      if new_path ~= current_path and new_path ~= "" then
        stop_preview()
        vim.defer_fn(function()
          start_preview()
        end, 100)
      end
    end,
  })

  -- auto-stop on neovim exit
  vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = function()
      if job_id then vim.fn.jobstop(job_id) end
    end,
  })

  -- commands
  vim.api.nvim_create_user_command("MarkdownPreviewStart", start_preview, {})
  vim.api.nvim_create_user_command("MarkdownPreviewStop", stop_preview, {})
end

return lib.module.create({
  name = "workflow/markdown-preview",
  hosts = "*",
  setup = setup,
  actions = {
    { "n", "Markdown: Preview Start", start_preview },
    { "n", "Markdown: Preview Stop", stop_preview },
  },
})
