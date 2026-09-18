local cancel_exit = function()
  local window = vim.api.nvim_get_current_win()
  local view = vim.fn.winsaveview()
  vim.cmd.split()
  vim.api.nvim_win_close(window, true)
  vim.fn.winrestview(view)
end

local confirm_exit = function()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    local original_lines = vim.b[bufnr].agents_rfc_original_lines
    if original_lines and vim.api.nvim_buf_is_loaded(bufnr) then
      local ok, err = pcall(vim.api.nvim_buf_call, bufnr, function()
        if require("modules/workflow/annotations").exports.burn() then vim.b.agents_rfc_pending_save = true end
        if vim.b.agents_rfc_pending_save then
          vim.cmd.write()
          vim.b.agents_rfc_pending_save = nil
        end
      end)
      if not ok then
        cancel_exit()
        vim.notify(err, vim.log.levels.ERROR)
        return
      end
    end
    if
      original_lines
      and vim.api.nvim_buf_is_loaded(bufnr)
      and vim.deep_equal(original_lines, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false))
    then
      local answer = vim.fn.confirm(
        "No changes made to " .. vim.api.nvim_buf_get_name(bufnr) .. ". Exit without changing it?",
        "&Yes\n&No",
        2
      )
      if answer ~= 1 then
        cancel_exit()
        return
      end
    end
  end

  if require("modules/workflow/annotations").exports.count() > 0 then
    local answer = vim.fn.confirm("Annotations have not been burned. Exit and discard them?", "&Yes\n&No", 2)
    if answer ~= 1 then cancel_exit() end
  end
end

local setup = function()
  local group = vim.api.nvim_create_augroup("agents-rfc", { clear = true })

  vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
    group = group,
    pattern = "/tmp/agents-rfc/*.md",
    callback = function(args)
      if not vim.api.nvim_buf_get_name(args.buf):match("^/tmp/agents%-rfc/[^/]+%.md$") then return end
      if vim.b[args.buf].agents_rfc_original_lines then return end
      vim.b[args.buf].agents_rfc_original_lines = vim.api.nvim_buf_get_lines(args.buf, 0, -1, false)
    end,
  })

  vim.api.nvim_create_autocmd("ExitPre", {
    group = group,
    nested = true,
    callback = confirm_exit,
  })
end

return lib.module.create({
  name = "agents/rfc",
  hosts = "*",
  setup = setup,
})
