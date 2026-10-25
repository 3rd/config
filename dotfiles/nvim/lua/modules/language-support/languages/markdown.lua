local prose = require("config/prose")

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

  local has_conceal_lines = false

  for pattern_id, directives in pairs(highlights.info.patterns) do
    for _, directive in ipairs(directives) do
      if directive[1] == "set!" and directive[2] == "conceal_lines" then
        if pattern_id == 17 or pattern_id == 18 then
          highlights.query:disable_pattern(pattern_id)
        else
          has_conceal_lines = true
        end

        break
      end
    end
  end

  highlights.has_conceal_line = has_conceal_lines
end

local setup_touchup = function(_, opts)
  local list_query = vim.treesitter.query.parse(
    "markdown",
    [[
    (list_item [
      (list_marker_minus) (list_marker_plus) (list_marker_star)
      (list_marker_dot) (list_marker_parenthesis)
    ] @marker)
  ]]
  )

  require("touchup.checkboxes").render = function(namespace, bufnr, icons, start_row, end_row, root)
    local lines = vim.api.nvim_buf_get_lines(bufnr, start_row, end_row, false)

    for _, marker in list_query:iter_captures(root, bufnr, start_row, end_row) do
      local row, column, _, marker_end = marker:range()
      local line = lines[row - start_row + 1]
      local _, task_end, state = line:sub(marker_end + 1):find("^%s*%[(.)%]")
      local icon = icons[state]
      if icon then
        local marker_text = vim.treesitter.get_node_text(marker, bufnr)
        local first_column = column + #marker_text:match("^%s*")
        local last_column = marker_end + task_end
        vim.api.nvim_buf_set_extmark(bufnr, namespace, row, first_column, {
          end_col = last_column,
          conceal = icon.text,
          hl_group = icon.hl,
          priority = 150,
          ephemeral = true,
        })

        if state ~= " " then
          vim.api.nvim_buf_set_extmark(bufnr, namespace, row, last_column, {
            end_col = #line,
            hl_group = icon.hl,
            priority = 150,
            ephemeral = true,
          })
        end
      end
    end
  end

  require("touchup").setup(opts)
end

local setup = function()
  lib.ts.register_prose_queries()
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
          icons = { prose.bullet },
        },
        code_blocks = {
          enabled = false,
        },
        comment_blocks = {
          enabled = false,
        },
        checkboxes = {
          enabled = true,
          icons = {
            [" "] = { text = prose.task_default, hl = "@slang.task_marker_default" },
            ["x"] = { text = prose.task_done, hl = "TouchupCheckboxChecked" },
            ["X"] = { text = prose.task_done, hl = "TouchupCheckboxChecked" },
            ["/"] = { text = prose.task_active, hl = "TouchupCheckboxPending" },
            [">"] = { text = "", hl = "TouchupCheckboxCancelled" },
            ["<"] = { text = "󰃖", hl = "TouchupCheckboxCancelled" },
            ["-"] = { text = prose.task_cancelled, hl = "TouchupCheckboxCancelled" },
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
