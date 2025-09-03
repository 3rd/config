---@diagnostic disable-next-line: unused-function
local setup_cmdheight = function()
  -- https://superuser.com/questions/619765/hiding-vim-command-line-when-its-not-being-used
  local group = vim.api.nvim_create_augroup("MacrosCmdHeight", { clear = true })
  vim.api.nvim_create_autocmd("VimEnter", {
    group = group,
    callback = function()
      vim.opt.cmdheight = 0
    end,
  })
  vim.api.nvim_create_autocmd("RecordingEnter", {
    group = group,
    callback = function()
      vim.opt.cmdheight = 1
    end,
  })
  vim.api.nvim_create_autocmd("RecordingLeave", {
    group = group,
    callback = function()
      vim.defer_fn(function()
        vim.opt.cmdheight = 0
      end, 50)
    end,
  })
end

return lib.module.create({
  name = "builtins/macros",
  hosts = "*",
  setup = function()
    -- disabled due to statusline flickering with cmdheight=0
    -- setup_cmdheight(()
  end,
})
