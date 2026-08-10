local colors = require("config/colors-hex")

local repeat_syslang_guides_on_wrapped_lines = function()
  local indent_mod = require("hlchunk.mods.indent")
  local setmark = indent_mod.setmark

  indent_mod.setmark = function(self, bufnr, render_info)
    setmark(self, bufnr, render_info)
    if vim.bo[bufnr].filetype ~= "syslang" then return end

    for _, render in pairs(render_info) do
      local extmarks = vim.api.nvim_buf_get_extmarks(
        bufnr,
        self.meta.ns_id,
        { render.lnum, 0 },
        { render.lnum, -1 },
        { details = true }
      )

      for _, extmark in ipairs(extmarks) do
        local details = extmark[4]
        if details.virt_text_win_col == render.virt_text_win_col and not details.virt_text_repeat_linebreak then
          vim.api.nvim_buf_set_extmark(bufnr, self.meta.ns_id, render.lnum, 0, {
            id = extmark[1],
            virt_text = render.virt_text,
            virt_text_pos = "overlay",
            virt_text_win_col = render.virt_text_win_col,
            virt_text_repeat_linebreak = true,
            hl_mode = "combine",
            priority = self.conf.priority,
          })
          break
        end
      end
    end
  end

  local chunk_mod = require("hlchunk.mods.chunk")
  local render = chunk_mod.render

  chunk_mod.render = function(self, range, opts)
    local render_opts = opts or { error = false, lazy = false }
    if self.conf.delay > 0 and self.conf.duration == 0 and render_opts.lazy then
      render_opts = { error = render_opts.error, lazy = false }
    end
    render(self, range, render_opts)
    if vim.bo[range.bufnr].filetype ~= "syslang" then return end

    local extmarks = vim.api.nvim_buf_get_extmarks(range.bufnr, self.meta.ns_id, 0, -1, { details = true })
    for _, extmark in ipairs(extmarks) do
      local details = extmark[4]
      local virt_text = details.virt_text
      if virt_text and virt_text[1][1] == self.conf.chars.vertical_line and not details.virt_text_repeat_linebreak then
        vim.api.nvim_buf_set_extmark(range.bufnr, self.meta.ns_id, extmark[2], extmark[3], {
          id = extmark[1],
          virt_text = virt_text,
          virt_text_pos = "overlay",
          virt_text_win_col = details.virt_text_win_col,
          virt_text_repeat_linebreak = true,
          hl_mode = "combine",
          priority = details.priority,
        })
      end
    end
  end
end

return lib.module.create({
  name = "indent-guides",
  hosts = "*",
  plugins = {
    {
      "shellRaining/hlchunk.nvim",
      -- "3rd/hlchunk.nvim",
      event = "CursorHold",
      -- dir = lib.path.resolve(lib.env.dirs.vim.config, "plugins", "hlchunk.nvim"),
      -- https://github.com/shellRaining/hlchunk.nvim/blob/main/docs/en/indent.md
      config = function()
        repeat_syslang_guides_on_wrapped_lines()

        local exclude_filetypes = require("hlchunk/utils/filetype").exclude_filetypes

        -- exclude
        local additional_excludes = {
          "bufferize",
          "fzf",
          "gitignore",
          "gitmessengerpopup",
          "snippets",
          "text",
          "tsplayground",
          "conf",
          "gitcommit",
          -- "syslang",
        }

        for _, filetype in ipairs(additional_excludes) do
          exclude_filetypes[filetype] = true
        end

        local opts = {
          indent = {
            enable = true,
            use_treesitter = false,
            exclude_filetypes = exclude_filetypes,
            chars = { "│", "¦", "┆", "┊", "┊", "┊", "┊", "┊", "┊", "┊", "┊", "┊", "┊" }, -- │
            style = colors.plugins.indent_guides.indent,
            delay = 200,
          },
          chunk = {
            enable = true,
            notify = false,
            exclude_filetypes = exclude_filetypes,
            use_treesitter = true,
            chars = {
              horizontal_line = "╴",
              vertical_line = "│",
              left_top = "╭",
              left_bottom = "╰",
              right_arrow = "▶",
            },
            style = colors.plugins.indent_guides.chunk,
            duration = 0,
            delay = 40,
          },
          blank = { enable = false },
          line_num = { enable = false },
        }

        require("hlchunk").setup(opts)
      end,
    },
  },
})
