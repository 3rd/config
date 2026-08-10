local handle_toggle_task = function()
  local line = vim.fn.getline(".")
  local col = vim.fn.col(".")

  if line:match("%[[ ]%]") then
    vim.cmd([[s/\[ \]/[-]/e]])
  elseif line:match("%[%-%]") then
    vim.cmd([[s/\[-\]/[x]/e]])
  elseif line:match("%[[xX]%]") then
    vim.cmd([[s/\[[xX]\]/[ ]/e]])
  elseif line:match("%[_%]") then
    vim.cmd([[s/\[_\]/[ ]/e]])
  else
    -- create checkbox: preserve indent, add "- [ ] " prefix
    vim.cmd([[s/\v^(\s*)\S/\1- [ ] \0/e]])
  end

  vim.cmd("nohl")
  vim.fn.cursor(vim.fn.line("."), col)
end

local disable_fenced_code_conceal = function()
  local highlights = vim.treesitter.query.get("markdown", "highlights")
  if not highlights or not highlights.query.disable_pattern then return end

  for _, pattern_id in ipairs({ 17, 18 }) do
    for _, directive in ipairs(highlights.info.patterns[pattern_id] or {}) do
      if directive[1] == "set!" and directive[2] == "conceal_lines" then
        highlights.query:disable_pattern(pattern_id)
        break
      end
    end
  end
end

local setup_touchup = function(_, opts)
  local codeblocks = require("touchup.codeblocks")
  local block_query = vim.treesitter.query.parse("markdown", "(fenced_code_block) @block")
  local fence_query = vim.treesitter.query.parse("markdown", "(fenced_code_block_delimiter) @fence")

  codeblocks.render = function(namespace, bufnr, start_row, end_row, root)
    local fence_rows = {}

    for _, node in fence_query:iter_captures(root, bufnr, start_row, end_row) do
      local row = node:range()
      fence_rows[row] = true
      vim.api.nvim_buf_set_extmark(bufnr, namespace, row, 0, {
        end_row = row + 1,
        hl_group = "TouchupCodeFence",
        hl_eol = true,
        ephemeral = true,
      })
    end

    for _, node in block_query:iter_captures(root, bufnr, start_row, end_row) do
      local block_start, _, block_end = node:range()
      local body_start = block_start + 1
      local body_end = fence_rows[block_end - 1] and block_end - 1 or block_end

      if body_start < body_end then
        vim.api.nvim_buf_set_extmark(bufnr, namespace, body_start, 0, {
          end_row = body_end,
          hl_group = "TouchupCodeBlock",
          hl_eol = true,
          ephemeral = true,
        })
      end
    end
  end

  require("touchup").setup(opts)
end

local setup = function()
  disable_fenced_code_conceal()

  vim.g.markdown_fenced_languages = {
    "ts=typescript",
    "tsx=typescriptreact",
    "js=javascript",
    "jsx=javascriptreact",
  }

  -- auto-enable text wrapping for markdown files
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "markdown",
    callback = function()
      vim.opt_local.wrap = true
      vim.opt_local.linebreak = true
      vim.opt_local.breakindent = true
      vim.keymap.set("n", "<c-space>", handle_toggle_task, { buffer = true, noremap = true })
    end,
  })
end

return lib.module.create({
  name = "language-support/languages/markdown",
  hosts = "*",
  setup = setup,
  plugins = {
    {
      "MeanderingProgrammer/render-markdown.nvim",
      enabled = false,
      ft = { "markdown" },
      ---@module 'render-markdown'
      ---@type render.md.UserConfig
      opts = {
        -- log_level = "debug",
        preset = "obsidian",
        file_types = { "markdown" },
        restart_highlighter = false,
        overrides = {
          buftype = {
            nofile = {
              render_modes = { "n", "i", "c" },
              -- render_modes = {},
              debounce = 5,
              code = {
                left_pad = 0,
                right_pad = 0,
                language_pad = 0,
              },
            },
          },
          filetype = {},
        },
        anti_conceal = {
          enabled = true,
          ignore = {
            code_background = false,
            sign = false,
          },
          above = 0,
          below = 0,
        },
        win_options = {
          concealcursor = { rendered = "" },
        },
        heading = {
          render_modes = true,
          enabled = true,
          setext = false,
          sign = false,
          position = "inline", -- inline, overlay
          icons = { "# ", "## ", "### ", "#### ", "##### ", "###### " },
          -- icons = function(ctx)
          --   local text = ""
          --   for i = 1, ctx.level do
          --     text = text .. "#"
          --   end
          --   return text .. " "
          -- end,
          -- icons = { "▶ ", "▸ ", "▹ ", "‣ ", "• ", "· " },
          signs = { "󰫎 " },
          width = "full", -- block, full
          left_margin = 0,
          left_pad = 0,
          right_pad = 0,
          min_width = 0,
          border = true,
          border_virtual = false,
          border_prefix = false,
          above = "▄",
          below = "▀",
          backgrounds = {
            "RenderMarkdownH1Bg",
            "RenderMarkdownH2Bg",
            "RenderMarkdownH3Bg",
            "RenderMarkdownH4Bg",
            "RenderMarkdownH5Bg",
            "RenderMarkdownH6Bg",
          },
          foregrounds = {
            "RenderMarkdownH1",
            "RenderMarkdownH2",
            "RenderMarkdownH3",
            "RenderMarkdownH4",
            "RenderMarkdownH5",
            "RenderMarkdownH6",
          },
        },
        bullet = {
          enabled = true,
          icons = { "⯄", "⭘", "🞆", "🞊" },
          ordered_icons = {},
          left_pad = 0,
          right_pad = 0,
          highlight = "RenderMarkdownBullet",
        },
        checkbox = {
          enabled = true,
          unchecked = {
            icon = "󰄱",
            highlight = "RenderMarkdownUnchecked",
            scope_highlight = nil,
          },
          checked = {
            icon = "󰱒",
            highlight = "RenderMarkdownChecked",
            scope_highlight = nil,
          },
          custom = {
            todo = { raw = "[-]", rendered = "󰥔 ", highlight = "RenderMarkdownTodo", scope_highlight = nil },
          },
        },
        code = {
          enabled = true,
          render_modes = false,
          sign = false,
          conceal_delimiters = true,
          language = true,
          position = "left",
          language_icon = true,
          language_name = true,
          language_info = true,
          language_pad = 0,
          disable_background = { "diff" },
          width = "block", -- block, full
          left_margin = 0,
          left_pad = 1,
          right_pad = 1,
          min_width = 0,
          border = "thin", -- none, thick, thin, hide
          language_border = "█",
          language_left = "",
          language_right = "",
          above = "▄",
          below = "▀",
          inline = true,
          inline_left = "",
          inline_right = "",
          inline_pad = 0,
          highlight = "RenderMarkdownCode",
          highlight_info = "RenderMarkdownCodeInfo",
          highlight_language = nil,
          highlight_border = "RenderMarkdownCodeBorder",
          highlight_fallback = "RenderMarkdownCodeFallback",
          highlight_inline = "RenderMarkdownCodeInline",
          style = "full", -- none, normal, language, full
        },
      },
    },
    {
      "noisesfromspace/touchup.nvim",
      ft = { "markdown" },
      opts = {
        filetypes = { "markdown" },
        bullets = {
          enabled = true,
          icons = { "", "", "⬥", "⬦" },
        },
        code_blocks = {
          enabled = true,
        },
        checkboxes = {
          enabled = true,
          icons = {
            ["x"] = { text = "󰗠", hl = "TouchupCheckboxChecked" },
            ["X"] = { text = "󰗠", hl = "TouchupCheckboxChecked" },
            ["/"] = { text = "󱎖", hl = "TouchupCheckboxPending" },
            [">"] = { text = "", hl = "TouchupCheckboxCancelled" },
            ["<"] = { text = "󰃖", hl = "TouchupCheckboxCancelled" },
            ["-"] = { text = "󰍶", hl = "TouchupCheckboxCancelled" },
            ["?"] = { text = "󰋗", hl = "TouchupCheckboxPending" },
            ["!"] = { text = "󰀦", hl = "TouchupCheckboxImportant" },
            ["*"] = { text = "󰓎", hl = "TouchupCheckboxPending" },
            ['"'] = { text = "󰸥", hl = "TouchupCheckboxCancelled" },
            ["l"] = { text = "󰆋", hl = "TouchupCheckboxProgress" },
            ["b"] = { text = "󰃀", hl = "TouchupCheckboxProgress" },
            ["i"] = { text = "󰰄", hl = "TouchupCheckboxChecked" },
            ["S"] = { text = "", hl = "TouchupCheckboxChecked" },
            ["I"] = { text = "󰛨", hl = "TouchupCheckboxPending" },
            ["p"] = { text = "", hl = "TouchupCheckboxChecked" },
            ["c"] = { text = "", hl = "TouchupCheckboxUnchecked" },
            ["f"] = { text = "󱠇", hl = "TouchupCheckboxUnchecked" },
            ["k"] = { text = "", hl = "TouchupCheckboxPending" },
            ["w"] = { text = "", hl = "TouchupCheckboxProgress" },
            ["u"] = { text = "󰔵", hl = "TouchupCheckboxChecked" },
            ["d"] = { text = "󰔳", hl = "TouchupCheckboxUnchecked" },
          },
        },
        markers = {
          enabled = true,
        },
        quotes = {
          enabled = true,
        },
        admonitions = {
          enabled = true,
        },
        links = {
          enabled = true,
        },
        enter = {
          enabled = true,
        },
      },
      config = setup_touchup,
    },
  },
})
