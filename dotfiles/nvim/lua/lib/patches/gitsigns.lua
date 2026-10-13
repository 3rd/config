local M = {}

local layer_line_highlight = function(signs, bufnr, sign_id)
  local mark = vim.api.nvim_buf_get_extmark_by_id(bufnr, signs.ns, sign_id, { details = true })
  if #mark == 0 then return end
  if mark[1] >= vim.api.nvim_buf_line_count(bufnr) then return end

  local details = mark[3]
  if not details.line_hl_group then return end

  vim.api.nvim_buf_set_extmark(bufnr, signs.ns, mark[1], mark[2], {
    id = sign_id,
    sign_text = details.sign_text,
    sign_hl_group = details.sign_hl_group,
    number_hl_group = details.number_hl_group,
    cursorline_hl_group = details.cursorline_hl_group,
    priority = details.priority,
  })

  signs.line_highlight_namespace = signs.line_highlight_namespace
    or vim.api.nvim_create_namespace(signs.group .. "_line_highlights")
  vim.api.nvim_buf_set_extmark(bufnr, signs.line_highlight_namespace, mark[1], 0, {
    id = sign_id,
    hl_group = details.line_hl_group,
    priority = details.priority,
    end_row = mark[1] + 1,
    end_col = 0,
    hl_eol = true,
  })
end

M.setup = function(opts)
  local signs = require("gitsigns.signs")
  if not signs.has_layered_line_highlights then
    local add_signs = signs.add
    local remove_signs = signs.remove
    local config = require("gitsigns.config").config
    signs.add = function(self, bufnr, buffer_signs, filter)
      add_signs(self, bufnr, buffer_signs, filter)

      if not config.linehl then return end

      for _, sign in ipairs(buffer_signs) do
        layer_line_highlight(self, bufnr, sign.lnum)
      end
    end

    signs.remove = function(self, bufnr, start_lnum, end_lnum)
      remove_signs(self, bufnr, start_lnum, end_lnum)

      if not self.line_highlight_namespace then return end

      vim.api.nvim_buf_clear_namespace(
        bufnr,
        self.line_highlight_namespace,
        start_lnum and start_lnum - 1 or 0,
        end_lnum or start_lnum or -1
      )
    end

    signs.has_layered_line_highlights = true
  end

  require("gitsigns").setup(opts)
end

return M
