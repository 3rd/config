return lib.module.create({
  name = "workflow/trim-line-trailing-space",
  hosts = "*",
  setup = function()
    -- https://stackoverflow.com/questions/77747363/remove-white-spaces-added-in-nvim-on-save
    local group = vim.api.nvim_create_augroup("trim_whitespaces", { clear = true })
    vim.api.nvim_create_autocmd("FileType", {
      group = group,
      desc = "Trim trailing white spaces",
      -- pattern = "bash,c,cpp,lua,java,go,php,javascript,make,python,rust,perl,sql,markdown",
      callback = function(ev)
        vim.api.nvim_clear_autocmds({
          group = group,
          event = "BufWritePre",
          buffer = ev.buf,
        })
        vim.api.nvim_create_autocmd("BufWritePre", {
          group = group,
          buffer = ev.buf,
          callback = function()
            local curpos = vim.api.nvim_win_get_cursor(0)
            vim.cmd([[keeppatterns %s/\s\+$//e]])
            vim.api.nvim_win_set_cursor(0, curpos)
          end,
        })
      end,
    })
  end,
})
