-- https://github.com/nvim-neorg/neorg/blob/main/lua/neorg/modules/core/concealer/module.lua#L1257
local namespace = vim.api.nvim_create_namespace("test")

---@param buf number
---@param options { text: string, highlight: string, row: number, col: number }
local decorate = function(buf, options)
  local opts = {
    virt_text = { { options.text, options.highlight } },
    virt_text_pos = "inline",
    virt_text_win_col = nil,
    hl_group = nil,
    conceal = nil,
    id = nil,
    end_row = options.row,
    end_col = options.col,
    hl_eol = nil,
    virt_text_hide = nil,
    hl_mode = "combine",
    virt_lines = nil,
    virt_lines_above = nil,
    virt_lines_leftcol = nil,
    ephemeral = nil,
    right_gravity = nil,
    end_right_gravity = nil,
    priority = nil,
    strict = nil, -- default true
    sign_text = nil,
    sign_hl_group = nil,
    number_hl_group = nil,
    line_hl_group = nil,
    cursorline_hl_group = nil,
    spell = nil,
    ui_watched = nil,
  }
  vim.api.nvim_buf_set_extmark(buf, namespace, options.row, options.col, opts)
end

-- local buf = vim.api.nvim_get_current_buf()
-- vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
