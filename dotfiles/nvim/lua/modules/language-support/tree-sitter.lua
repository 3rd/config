local syslang_parser_path = lib.path.resolve(lib.env.dirs.home, "brain", "core", "syslang", "tree-sitter-syslang")
local install_dir = vim.fn.stdpath("data") .. "/site"

local managed_languages = {
  "astro",
  "bash",
  "c",
  "cpp",
  "css",
  "c_sharp",
  "dockerfile",
  "fish",
  "go",
  "gomod",
  "graphql",
  "html",
  "javascript",
  "json",
  "json5",
  "lua",
  "make",
  "markdown",
  "markdown_inline",
  "nix",
  "php",
  "prisma",
  "python",
  "query",
  "rust",
  "scss",
  "sql",
  "svelte",
  "syslang",
  "toml",
  "tsx",
  "typescript",
  "v",
  "vim",
  "vimdoc",
  "vue",
  "xml",
  "yaml",
  "zig",
}

local textobjects = {
  select = {
    lookahead = true,
    selection_modes = {},
    include_surrounding_whitespace = false,
    keymaps = {
      ["if"] = "@function.inner",
      ["af"] = "@function.outer",
      ["ic"] = "@call.inner",
      ["ac"] = "@call.outer",
      ["iC"] = "@class.inner",
      ["aC"] = "@class.outer",
      ["ib"] = "@block.inner",
      ["ab"] = "@block.outer",
      ["is"] = "@statement.inner",
      ["as"] = "@statement.outer",
    },
  },
  move = {
    set_jumps = true,
    goto_next_start = {
      ["]f"] = "@function.outer",
      ["]c"] = "@class.outer",
      ["]s"] = "@statement.outer",
      ["]b"] = "@block.outer",
      ["]r"] = "@return.outer",
    },
    goto_next_end = {},
    goto_previous_start = {
      ["[f"] = "@function.outer",
      ["[c"] = "@class.outer",
      ["[s"] = "@statement.outer",
      ["[b"] = "@block.outer",
      ["[r"] = "@return.outer",
    },
    goto_previous_end = {},
  },
  lsp_interop = {
    border = "single",
    floating_preview_opts = {},
    peek_definition_code = {
      ["<leader>k"] = "@function.outer",
      ["<leader>K"] = "@class.outer",
    },
  },
}

local fold_query_whitelist = {
  markdown = true,
  syslang = true,
}

local is_list = vim.islist or vim.tbl_islist
local floating_preview_win

local get_ts_range = function()
  return vim.treesitter._range or require("nvim-treesitter-textobjects._range")
end

local is_treesitter_highlight_disabled = function(lang, buf)
  -- bash injections are still broken upstream
  if lang == "bash" then return true end

  local max_filesize = 1024 * 1024
  local ok, stats = pcall(vim.uv.fs_stat, vim.api.nvim_buf_get_name(buf))
  if ok and stats and stats.size > max_filesize then
    log("tree-sitter disabled due to large file")
    return true
  end

  -- only check lush sources for lua buffers
  if vim.bo[buf].filetype == "lua" then
    local text = lib.buffer.get_text(buf)
    if string.includes(text, "lush%(function") then return true end
  end

  return false
end

local register_syslang_parser = function()
  require("nvim-treesitter.parsers").syslang = {
    install_info = {
      path = syslang_parser_path,
      queries = "queries",
    },
  }
end

local register_language_aliases = function()
  vim.treesitter.language.register("json", "jsonc")
end

local await_treesitter_task = function(task)
  local ok, result = pcall(function()
    return task:wait(300000)
  end)

  if not ok then return false, result end
  return result ~= false, result
end

local get_missing_languages = function()
  local installed = require("nvim-treesitter").get_installed()
  return vim.tbl_filter(function(lang)
    return not vim.tbl_contains(installed, lang)
  end, managed_languages)
end

local sync_treesitter_parsers = function()
  local treesitter = require("nvim-treesitter")

  treesitter.setup({
    install_dir = install_dir,
  })
  register_syslang_parser()

  local missing_languages = get_missing_languages()
  if #missing_languages > 0 then
    local ok = await_treesitter_task(treesitter.install(missing_languages, { summary = true }))
    if not ok then return end
  end

  local ok = await_treesitter_task(treesitter.update(nil, { summary = true }))
  if ok then return end

  await_treesitter_task(treesitter.install(managed_languages, {
    force = true,
    summary = true,
  }))
end

local preview_location = function(location, context_range)
  local uri = location.targetUri or location.uri
  if uri == nil then return end

  local bufnr = vim.uri_to_bufnr(uri)
  if not vim.api.nvim_buf_is_loaded(bufnr) then vim.fn.bufload(bufnr) end

  local range = vim.deepcopy(location.targetRange or location.range)
  if range == nil then return end

  if range["end"].character == 0 then range["end"].line = range["end"].line - 1 end

  if context_range ~= nil then
    local ts_range = get_ts_range()
    local start_row, _, end_row = ts_range.unpack4(context_range)
    range.start.line = math.min(range.start.line, start_row)
    range["end"].line = math.max(range["end"].line, end_row)
  end

  local opts = vim.deepcopy(textobjects.lsp_interop.floating_preview_opts)
  if textobjects.lsp_interop.border ~= "none" then opts.border = textobjects.lsp_interop.border end

  local contents = vim.api.nvim_buf_get_lines(bufnr, range.start.line, range["end"].line + 1, false)
  local filetype = vim.bo[bufnr].filetype
  local preview_buf, preview_win = vim.lsp.util.open_floating_preview(contents, filetype, opts)
  vim.bo[preview_buf].filetype = filetype
  floating_preview_win = preview_win
  return preview_buf, preview_win
end

local make_preview_location_callback = function(query_string, query_group)
  return vim.schedule_wrap(function(err, result)
    if err then
      vim.notify(tostring(err), vim.log.levels.ERROR)
      return
    end

    if result == nil or vim.tbl_isempty(result) then
      vim.notify("No location found", vim.log.levels.INFO)
      return
    end

    if is_list(result) then result = result[1] end

    local uri = result.uri or result.targetUri
    local range = result.range or result.targetRange
    if not uri or not range then return end

    local bufnr = vim.uri_to_bufnr(uri)
    vim.fn.bufload(bufnr)

    local context_range = require("nvim-treesitter-textobjects.shared").textobject_at_point(
      query_string,
      query_group,
      bufnr,
      { range.start.line + 1, range.start.character }
    )

    preview_location(result, context_range)
  end)
end

local peek_definition_code = function(query_string, query_group, lsp_request)
  query_group = query_group or "textobjects"
  lsp_request = lsp_request or "textDocument/definition"

  if floating_preview_win and vim.api.nvim_win_is_valid(floating_preview_win) then
    vim.api.nvim_set_current_win(floating_preview_win)
    return
  end

  return vim.lsp.buf_request(
    0,
    lsp_request,
    vim.lsp.util.make_position_params(),
    make_preview_location_callback(query_string, query_group)
  )
end

local map_textobject_select = function()
  local select = require("nvim-treesitter-textobjects.select")

  for lhs, query_string in pairs(textobjects.select.keymaps) do
    vim.keymap.set({ "x", "o" }, lhs, function()
      select.select_textobject(query_string, "textobjects")
    end)
  end
end

local map_textobject_move = function()
  local move = require("nvim-treesitter-textobjects.move")
  local methods = {
    goto_next_start = move.goto_next_start,
    goto_next_end = move.goto_next_end,
    goto_previous_start = move.goto_previous_start,
    goto_previous_end = move.goto_previous_end,
  }

  for method, query_strings in pairs(textobjects.move) do
    local handler = methods[method]
    if handler ~= nil then
      for lhs, query_string in pairs(query_strings) do
        vim.keymap.set({ "n", "x", "o" }, lhs, function()
          handler(query_string, "textobjects")
        end)
      end
    end
  end
end

local map_textobject_peek = function()
  for lhs, query_string in pairs(textobjects.lsp_interop.peek_definition_code) do
    vim.keymap.set({ "n", "x" }, lhs, function()
      peek_definition_code(query_string, "textobjects")
    end, { silent = true })
  end
end

local setup_textobjects = function()
  require("nvim-treesitter-textobjects.init").setup({
    select = {
      lookahead = textobjects.select.lookahead,
      selection_modes = textobjects.select.selection_modes,
      include_surrounding_whitespace = textobjects.select.include_surrounding_whitespace,
    },
    move = {
      set_jumps = textobjects.move.set_jumps,
    },
  })

  map_textobject_select()
  map_textobject_move()
  map_textobject_peek()
end

local maybe_start_treesitter = function(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) or not vim.api.nvim_buf_is_loaded(bufnr) then return end

  local filetype = vim.bo[bufnr].filetype
  if filetype == "" then return end

  local lang = vim.treesitter.language.get_lang(filetype)
  if lang == nil then return end

  if is_treesitter_highlight_disabled(lang, bufnr) then
    pcall(vim.treesitter.stop, bufnr)
    return
  end

  pcall(vim.treesitter.start, bufnr, lang)
end

local install_missing_languages = function()
  local treesitter = require("nvim-treesitter")
  local missing_languages = get_missing_languages()
  if #missing_languages == 0 then return end

  treesitter.install(missing_languages, { summary = true }):await(function(err, ok)
    if err ~= nil or not ok then
      vim.schedule(function()
        vim.notify_once("Tree-sitter parser install failed; see :TSLog", vim.log.levels.WARN)
      end)
      return
    end

    vim.schedule(function()
      for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        maybe_start_treesitter(bufnr)
      end
    end)
  end)
end

local setup_filetype_autocmds = function()
  local group = vim.api.nvim_create_augroup("config:treesitter", { clear = true })

  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "TSUpdate",
    callback = register_syslang_parser,
  })

  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "*",
    callback = function(ev)
      maybe_start_treesitter(ev.buf)
    end,
  })

  vim.api.nvim_create_autocmd("VimEnter", {
    group = group,
    once = true,
    callback = install_missing_languages,
  })

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    maybe_start_treesitter(bufnr)
  end
end

local disable_unwanted_fold_queries = function()
  for grammar in pairs(require("nvim-treesitter.parsers")) do
    if not fold_query_whitelist[grammar] then pcall(vim.treesitter.query.set, grammar, "folds", "") end
  end
end

local setup_treesitter = function()
  require("nvim-treesitter").setup({
    install_dir = install_dir,
  })

  register_language_aliases()
  register_syslang_parser()

  vim.g.query_lint_on = { "BufWrite" }

  setup_textobjects()
  setup_filetype_autocmds()
  disable_unwanted_fold_queries()
end

return lib.module.create({
  name = "language-support/tree-sitter",
  hosts = "*",
  plugins = {
    {
      "nvim-treesitter/nvim-treesitter",
      lazy = false,
      branch = "main",
      dependencies = {
        { "nvim-treesitter/nvim-treesitter-textobjects", branch = "main" },
        {
          "nvim-treesitter/nvim-treesitter-context",
          opts = {
            enable = true,
            max_lines = 3,
            min_window_height = 0,
            line_numbers = true,
            multiline_threshold = 1,
            trim_scope = "outer",
            mode = "cursor",
            zindex = 20,
            on_attach = function()
              return vim.bo.filetype ~= "help"
            end,
          },
        },
      },
      build = sync_treesitter_parsers,
      config = setup_treesitter,
    },
    {
      "sustech-data/wildfire.nvim",
      event = "VeryLazy",
      dependencies = { "nvim-treesitter/nvim-treesitter" },
      config = function()
        require("wildfire").setup({
          surrounds = {
            { "(", ")" },
            { "{", "}" },
            { "<", ">" },
            { "[", "]" },
          },
          keymaps = {
            init_selection = "<CR>",
            node_incremental = "<CR>",
            node_decremental = "<BS>",
          },
          filetype_exclude = { "qf" },
        })
      end,
    },
  },
})
