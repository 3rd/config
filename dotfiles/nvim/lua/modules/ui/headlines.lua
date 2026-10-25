local prose = require("config/prose")

local shared_config = {
  headline_highlights = { "Headline1", "Headline2", "Headline3", "Headline4", "Headline5", "Headline6" },
  codeblock_highlight = "CodeBlock",
  dash_highlight = "Dash",
  dash_string = "-",
  doubledash_highlight = "DoubleDash",
  doubledash_string = "=",
  quote_highlight = "Quote",
  quote_string = ">",
  fat_headlines = true,
  fat_headline_upper_string = "▄",
  fat_headline_lower_string = "▀",
}

local heading_highlights = {
  "SyslangHeadline1",
  "SyslangHeadline2",
  "SyslangHeadline3",
  "SyslangHeadline4",
  "SyslangHeadline5",
  "SyslangHeadline6",
}

local syslang_headline_query_text = [[
              [
                (heading_1_marker)
                (heading_2_marker)
                (heading_3_marker)
                (heading_4_marker)
                (heading_5_marker)
                (heading_6_marker)
              ] @headline

              (horizontal_rule) @dash
              (double_horizontal_rule) @doubledash
              (banner) @quote
              (code_block_content) @codeblock
            ]]
local syslang_headline_query = nil
local markdown_block_query = nil
local markdown_reference_query = nil
local markdown_definition_query = nil

local get_syslang_headline_query = function()
  if syslang_headline_query then return syslang_headline_query end

  local ok, query = pcall(vim.treesitter.query.parse, "syslang", syslang_headline_query_text)
  if not ok then return nil end

  syslang_headline_query = query
  return query
end

local get_markdown_block_query = function()
  if markdown_block_query then return markdown_block_query end

  markdown_block_query = vim.treesitter.query.parse(
    "markdown",
    [[
    (atx_heading [
      (atx_h1_marker) (atx_h2_marker) (atx_h3_marker)
      (atx_h4_marker) (atx_h5_marker) (atx_h6_marker)
    ] @headline)
    (setext_heading [(setext_h1_underline) (setext_h2_underline)] @headline)
    (fenced_code_block (code_fence_content) @codeblock)
    (indented_code_block) @codeblock
    [(minus_metadata) (plus_metadata)] @metadata
    (thematic_break) @dash
  ]]
  )
  return markdown_block_query
end

local prose_render_group = vim.api.nvim_create_augroup("prose_render", { clear = true })
local prose_render_namespace = vim.api.nvim_create_namespace("prose_render")
local PROSE_RENDER_DEBOUNCE_MS = 40

local get_query_match_node = function(node)
  if type(node) ~= "table" then return node end
  return node[#node]
end

local get_line = function(bufnr, row)
  return vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
end

local is_blank_line = function(bufnr, row)
  return get_line(bufnr, row) == ""
end

local set_headline_gutter_row = function(bufnr, rows, row, char, hl_group, margin_char, margin_hl_group)
  if row < 0 or row >= vim.api.nvim_buf_line_count(bufnr) then return end

  rows[row + 1] = {
    char = char,
    hl = hl_group,
    margin_char = margin_char,
    margin_hl = margin_hl_group,
  }
end

local set_headline_padding = function(bufnr, row, text, hl_group)
  if row < 0 or row >= vim.api.nvim_buf_line_count(bufnr) then return end

  vim.api.nvim_buf_set_extmark(bufnr, prose_render_namespace, row, 0, {
    virt_text = { { text, hl_group } },
    virt_text_pos = "overlay",
    virt_text_win_col = 0,
    hl_mode = "combine",
  })
end

local render_codeblock = function(bufnr, node, left_offset, ranges)
  local start_row, _, end_row, end_col = node:range()
  if end_col > 0 then end_row = end_row + 1 end

  vim.api.nvim_buf_set_extmark(bufnr, prose_render_namespace, start_row, 0, {
    end_col = 0,
    end_row = end_row,
    hl_group = shared_config.codeblock_highlight,
    hl_eol = true,
  })

  local _, padding = get_line(bufnr, start_row):find("^ +")
  local codeblock_padding = math.max((padding or 0) - left_offset, 0)
  if codeblock_padding == 0 then return end

  for _, range in ipairs(ranges) do
    for row = math.max(start_row, range[1]), math.min(end_row, range[2]) - 1 do
      vim.api.nvim_buf_set_extmark(bufnr, prose_render_namespace, row, 0, {
        virt_text = { { string.rep(" ", codeblock_padding), "Normal" } },
        virt_text_win_col = 0,
        virt_text_repeat_linebreak = true,
        priority = 1,
      })
    end
  end
end

local render_heading_band = function(bufnr, heading, options)
  local index = math.min(options.level, #heading_highlights)
  local hl_group = heading_highlights[index]
  local margin_hl_group = "SyslangHeadlineMargin" .. index
  local start_row, _, end_row, end_col = heading:range()
  local last_row = end_row + (end_col > 0 and 1 or 0)
  local rows = options.rows
  local width = options.width
  local headlines = require("headlines")

  vim.api.nvim_buf_set_extmark(bufnr, prose_render_namespace, start_row, 0, {
    end_row = last_row,
    hl_group = hl_group,
    hl_eol = true,
  })
  local reverse_hl_group = headlines.make_reverse_highlight(hl_group)

  set_headline_gutter_row(bufnr, rows, start_row, " ", hl_group, " ", margin_hl_group)

  if shared_config.fat_headlines then
    if start_row > 0 then
      local upper_row = start_row - 1
      if is_blank_line(bufnr, upper_row) and upper_row ~= options.previous_end_row then
        set_headline_gutter_row(
          bufnr,
          rows,
          upper_row,
          shared_config.fat_headline_upper_string,
          reverse_hl_group,
          shared_config.fat_headline_upper_string,
          reverse_hl_group
        )
        set_headline_padding(bufnr, upper_row, shared_config.fat_headline_upper_string:rep(width), reverse_hl_group)
      end
    end

    if is_blank_line(bufnr, last_row) then
      set_headline_gutter_row(
        bufnr,
        rows,
        last_row,
        shared_config.fat_headline_lower_string,
        reverse_hl_group,
        shared_config.fat_headline_lower_string,
        reverse_hl_group
      )
      set_headline_padding(bufnr, last_row, shared_config.fat_headline_lower_string:rep(width), reverse_hl_group)
    end
  end
end

local render_markdown_metadata = function(bufnr, node, parser)
  local start_row, _, end_row = node:range()
  vim.api.nvim_buf_set_extmark(bufnr, prose_render_namespace, start_row, 0, {
    end_row = end_row,
    hl_group = "MarkdownMetadata",
    priority = 110,
  })

  lib.ts.for_each_tree_in_range(parser, start_row, end_row, function(tree, language_tree)
    local language = language_tree:lang()
    if language ~= "yaml" and language ~= "toml" then return end

    local root = tree:root()
    local tree_start, _, tree_end = root:range()
    if tree_start < start_row or tree_end > end_row then return end

    local query = vim.treesitter.query.get(language, "highlights")
    if not query then return end

    for id, field in query:iter_captures(root, bufnr, start_row, end_row) do
      local capture = query.captures[id]
      local highlight
      if capture == "property" or field:type() == "quoted_key" then
        highlight = "MarkdownMetadataKey"
      elseif
        capture:match("^string")
        or capture:match("^number")
        or capture == "boolean"
        or capture == "constant.builtin"
      then
        highlight = "MarkdownMetadataValue"
      end

      if highlight then
        local row, column, last_row, last_column = field:range()
        vim.api.nvim_buf_set_extmark(bufnr, prose_render_namespace, row, column, {
          end_row = last_row,
          end_col = last_column,
          hl_group = highlight,
          priority = highlight == "MarkdownMetadataKey" and 121 or 120,
        })
      end
    end
  end)
end

local normalize_markdown_link_label = function(node, bufnr)
  local text = vim.treesitter.get_node_text(node, bufnr)
  if node:type() == "link_label" then text = text:sub(2, -2) end

  local label = vim.trim(text):gsub("%s+", " ")
  return vim.fn.tolower(label)
end

local get_markdown_title_row = function(root)
  for section in root:iter_children() do
    if section:type() == "section" then
      local heading = section:named_child(0)
      if heading and (heading:type() == "atx_heading" or heading:type() == "setext_heading") then
        local marker = lib.ts.find_child(heading, "atx_h1_marker") or lib.ts.find_child(heading, "setext_h1_underline")
        if marker then return heading:range() end
      end
    end
  end
end

local get_markdown_references = function(bufnr, root)
  local references = {}

  for row, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
    if line:find("]:", 1, true) then
      markdown_definition_query = markdown_definition_query
        or vim.treesitter.query.parse("markdown", "(link_reference_definition) @reference")

      for _, reference in markdown_definition_query:iter_captures(root, bufnr, row - 1, row) do
        local label = normalize_markdown_link_label(lib.ts.find_child(reference, "link_label"), bufnr)
        if references[label] == nil then
          local destination = vim.treesitter.get_node_text(lib.ts.find_child(reference, "link_destination"), bufnr)
          references[label] = destination:match(prose.external_link_pattern) ~= nil
        end
      end
    end
  end

  return references
end

local render_markdown_reference_links = function(bufnr, parser, references, start_row, end_row)
  if vim.tbl_isempty(references) then return end

  if not markdown_reference_query then
    markdown_reference_query = vim.treesitter.query.parse(
      "markdown_inline",
      "[(full_reference_link) (collapsed_reference_link) (shortcut_link)] @reference"
    )
  end

  lib.ts.for_each_tree_in_range(parser, start_row, end_row, function(tree, language_tree)
    if language_tree:lang() ~= "markdown_inline" then return end

    for _, node in markdown_reference_query:iter_captures(tree:root(), bufnr, start_row, end_row) do
      local text = lib.ts.find_child(node, "link_text")
      local label = lib.ts.find_child(node, "link_label") or text
      if references[normalize_markdown_link_label(label, bufnr)] then
        local start_row, start_col, end_row, end_col = text:range()
        vim.api.nvim_buf_set_extmark(bufnr, prose_render_namespace, start_row, start_col, {
          end_row = end_row,
          end_col = end_col,
          hl_group = "MarkdownExternalLink",
          priority = 110,
        })
      end
    end
  end)
end

local get_prose_view = function(bufnr)
  local view = { width = 0, left_offset = 0, ranges = {} }
  local line_count = vim.api.nvim_buf_line_count(bufnr)

  for _, window in ipairs(vim.fn.win_findbuf(bufnr)) do
    local info = vim.fn.getwininfo(window)[1]
    local last_row = math.max(info.botline, info.topline + vim.api.nvim_win_get_height(window) - 1)
    view.width = math.max(view.width, vim.api.nvim_win_get_width(window))
    view.left_offset = vim.api.nvim_win_call(window, function()
      return vim.fn.winsaveview().leftcol
    end)
    table.insert(view.ranges, { math.max(0, info.topline - 2), math.min(line_count, last_row + 1) })
  end

  table.sort(view.ranges, function(a, b)
    return a[1] < b[1]
  end)

  local ranges = {}

  for _, range in ipairs(view.ranges) do
    local previous = ranges[#ranges]
    if previous and range[1] <= previous[2] then
      previous[2] = math.max(previous[2], range[2])
    else
      ranges[#ranges + 1] = range
    end
  end

  if vim.bo[bufnr].filetype == "syslang" then ranges = { { 0, line_count } } end

  view.ranges = ranges
  return view
end

local render_prose_blocks = function(bufnr, force)
  if not vim.api.nvim_buf_is_valid(bufnr) then return end

  local filetype = vim.bo[bufnr].filetype
  if filetype ~= "syslang" and filetype ~= "markdown" then
    vim.api.nvim_buf_clear_namespace(bufnr, prose_render_namespace, 0, -1)
    vim.b[bufnr].syslang_headline_gutter_rows = {}
    vim.b[bufnr].prose_render_changedtick = nil
    vim.b[bufnr].prose_render_filetype = nil
    vim.b[bufnr].prose_render_view = nil
    vim.b[bufnr].prose_render_references = nil
    vim.b[bufnr].prose_render_title_row = nil
    return
  end

  local changedtick = vim.api.nvim_buf_get_changedtick(bufnr)
  local view = get_prose_view(bufnr)
  if #view.ranges == 0 then return end

  local has_changed = vim.b[bufnr].prose_render_changedtick ~= changedtick
    or vim.b[bufnr].prose_render_filetype ~= filetype
  local view_key = vim.json.encode(view)
  if not force and not has_changed and vim.b[bufnr].prose_render_view == view_key then return end

  pcall(vim.treesitter.start, bufnr, filetype)
  vim.api.nvim_buf_clear_namespace(bufnr, prose_render_namespace, 0, -1)

  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, filetype)
  if not ok or not parser then
    vim.b[bufnr].syslang_headline_gutter_rows = {}
    vim.b[bufnr].prose_render_changedtick = changedtick
    vim.cmd("redrawstatus")
    return
  end

  local trees = parser:parse(filetype == "markdown" and view.ranges or true)
  local tree = trees and trees[1]
  if not tree then
    vim.b[bufnr].syslang_headline_gutter_rows = {}
    vim.b[bufnr].prose_render_changedtick = changedtick
    vim.cmd("redrawstatus")
    return
  end

  local query = filetype == "syslang" and get_syslang_headline_query() or get_markdown_block_query()
  if not query then
    vim.b[bufnr].syslang_headline_gutter_rows = {}
    vim.b[bufnr].prose_render_changedtick = changedtick
    vim.cmd("redrawstatus")
    return
  end

  local rows = {}
  local root = tree:root()
  if filetype == "markdown" and has_changed then
    vim.b[bufnr].prose_render_title_row = get_markdown_title_row(root)
    vim.b[bufnr].prose_render_references = get_markdown_references(bufnr, root)
  end

  local title_row = vim.b[bufnr].prose_render_title_row
  local previous_heading_end_row
  local rendered_nodes = {}

  for _, range in ipairs(view.ranges) do
    for _, match in query:iter_matches(root, bufnr, range[1], range[2]) do
      for id, node in pairs(match) do
        node = get_query_match_node(node)
        if rendered_nodes[node:id()] then goto continue end

        rendered_nodes[node:id()] = true
        local capture = query.captures[id]
        if capture == "headline" then
          local headline_node = get_query_match_node(node)
          if not headline_node then goto continue end

          local headline_text = vim.trim(vim.treesitter.get_node_text(headline_node, bufnr))
          if headline_text == "" then goto continue end

          local level = #headline_text
          local marker_type = headline_node:type()
          if marker_type == "setext_h1_underline" then
            level = 1
          elseif marker_type == "setext_h2_underline" then
            level = 2
          end

          local heading = headline_node:parent()
          local start_row, _, end_row, end_col = heading:range()
          local last_row = end_row + (end_col > 0 and 1 or 0)
          local is_markdown_title = filetype == "markdown" and start_row == title_row
          if is_markdown_title then
            vim.api.nvim_buf_set_extmark(bufnr, prose_render_namespace, start_row, 0, {
              end_row = last_row,
              hl_group = "MarkdownTitle",
              priority = 120,
            })
            goto continue
          end

          render_heading_band(bufnr, heading, {
            level = level,
            rows = rows,
            width = view.width,
            previous_end_row = previous_heading_end_row,
          })
          previous_heading_end_row = last_row
        elseif capture == "codeblock" then
          local codeblock_node = get_query_match_node(node)
          if codeblock_node then render_codeblock(bufnr, codeblock_node, view.left_offset, view.ranges) end
        elseif capture == "metadata" then
          render_markdown_metadata(bufnr, get_query_match_node(node), parser)
        elseif capture == "dash" and filetype == "markdown" then
          local row = node:range()
          vim.api.nvim_buf_set_extmark(bufnr, prose_render_namespace, row, 0, {
            virt_text = { { shared_config.dash_string:rep(view.width), shared_config.dash_highlight } },
            virt_text_pos = "overlay",
            hl_mode = "combine",
          })
        elseif capture == "quote" and filetype == "syslang" then
          local start_row, _, end_row, end_col = get_query_match_node(node):range()
          vim.api.nvim_buf_set_extmark(bufnr, prose_render_namespace, start_row, 0, {
            end_row = end_row + (end_col > 0 and 1 or 0),
            hl_group = "@slang.banner",
            hl_eol = true,
          })
        end
        ::continue::
      end
    end

    if filetype == "markdown" then
      render_markdown_reference_links(bufnr, parser, vim.b[bufnr].prose_render_references, range[1], range[2])
    end
  end

  vim.b[bufnr].syslang_headline_gutter_rows = rows
  vim.b[bufnr].prose_render_changedtick = changedtick
  vim.b[bufnr].prose_render_filetype = filetype
  vim.b[bufnr].prose_render_view = view_key
  vim.cmd("redrawstatus")
end

local request_prose_render = function(bufnr, debounce_ms)
  if not vim.api.nvim_buf_is_valid(bufnr) then return end

  local filetype = vim.bo[bufnr].filetype
  if filetype ~= "syslang" and filetype ~= "markdown" then return end
  if vim.b[bufnr].prose_render_changedtick == vim.api.nvim_buf_get_changedtick(bufnr) then return end

  local generation = (vim.b[bufnr].prose_render_generation or 0) + 1
  vim.b[bufnr].prose_render_generation = generation
  vim.b[bufnr].is_prose_render_scheduled = true
  vim.defer_fn(function()
    if not vim.api.nvim_buf_is_valid(bufnr) then return end
    if vim.b[bufnr].prose_render_generation ~= generation then return end

    vim.b[bufnr].is_prose_render_scheduled = nil
    render_prose_blocks(bufnr, false)
  end, debounce_ms)
end

local render_prose_blocks_now = function(bufnr, force)
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.b[bufnr].prose_render_generation = (vim.b[bufnr].prose_render_generation or 0) + 1
    vim.b[bufnr].is_prose_render_scheduled = nil
  end

  render_prose_blocks(bufnr, force)
end

local attach_prose_render = function(bufnr)
  if vim.b[bufnr].is_prose_render_attached then
    -- Buffer reloads fire FileType before tree-sitter discards the tree of the previous file contents.
    vim.schedule(function()
      render_prose_blocks_now(bufnr, true)
    end)
    return
  end

  vim.b[bufnr].is_prose_render_attached = true

  vim.api.nvim_create_autocmd("FileType", {
    group = prose_render_group,
    buffer = bufnr,
    callback = function()
      local filetype = vim.bo[bufnr].filetype
      if filetype ~= "markdown" and filetype ~= "syslang" then render_prose_blocks_now(bufnr, true) end
    end,
  })

  vim.api.nvim_create_autocmd("BufEnter", {
    group = prose_render_group,
    buffer = bufnr,
    callback = function()
      render_prose_blocks_now(bufnr, true)
    end,
  })

  vim.api.nvim_create_autocmd("InsertLeave", {
    group = prose_render_group,
    buffer = bufnr,
    callback = function()
      render_prose_blocks_now(bufnr, false)
    end,
  })

  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = prose_render_group,
    buffer = bufnr,
    callback = function(args)
      local debounce_ms = args.event == "TextChangedI" and PROSE_RENDER_DEBOUNCE_MS or 0
      request_prose_render(bufnr, debounce_ms)
    end,
  })

  render_prose_blocks_now(bufnr, true)
end

return lib.module.create({
  name = "headlines",
  -- enabled = false,
  hosts = "*",
  plugins = {
    {
      "lukas-reineke/headlines.nvim",
      ft = {
        "syslang",
        "markdown",
      },
      dependencies = { "nvim-treesitter/nvim-treesitter" },
      config = function()
        lib.ts.register_prose_queries()
        local headlines = require("headlines")
        local query = get_syslang_headline_query()
        if not query then return end

        headlines.setup({
          markdown = vim.tbl_extend("force", shared_config, {
            query = false,
            headline_highlights = false,
            codeblock_highlight = false,
            quote_highlight = false,
          }),
          rmd = { query = false },
          norg = { query = false },
          org = { query = false },
          syslang = vim.tbl_extend("force", shared_config, {
            fat_headlines = false,
            headline_highlights = false,
            bullet_highlights = {},
            codeblock_highlight = false,
            query = query,
          }),
        })

        local bufnr = vim.api.nvim_get_current_buf()
        if vim.bo[bufnr].filetype == "syslang" or vim.bo[bufnr].filetype == "markdown" then
          attach_prose_render(bufnr)
        end

        vim.api.nvim_create_autocmd("FileType", {
          group = prose_render_group,
          pattern = { "syslang", "markdown" },
          callback = function(args)
            attach_prose_render(args.buf)
          end,
        })

        vim.api.nvim_create_autocmd({ "WinResized", "WinScrolled" }, {
          group = prose_render_group,
          callback = function(args)
            local windows = vim.v.event.windows or vim.tbl_keys(vim.v.event)
            windows[#windows + 1] = args.match
            local rendered_buffers = {}

            for _, window in ipairs(windows) do
              window = tonumber(window)
              if not window or not vim.api.nvim_win_is_valid(window) then goto continue end

              local buffer = vim.api.nvim_win_get_buf(window)
              local filetype = vim.bo[buffer].filetype
              local should_render = filetype == "markdown" or (filetype == "syslang" and args.event == "WinResized")
              if should_render and not rendered_buffers[buffer] then
                rendered_buffers[buffer] = true
                render_prose_blocks_now(buffer, false)
              end
              ::continue::
            end
          end,
        })
      end,
    },
  },
})
