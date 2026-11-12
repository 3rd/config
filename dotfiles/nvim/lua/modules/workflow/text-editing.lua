local function should_skip_double_quote_pair(ctx)
  local char_under_cursor = ctx.char_under_cursor
  local char_after_cursor = ctx:text_after_cursor(1)

  return (char_under_cursor ~= "" and not char_under_cursor:match("%s"))
    or (char_after_cursor ~= "" and not char_after_cursor:match("%s"))
end

local function can_create_pair(ctx)
  if ctx.mode == "c" then return true end

  local char_after_cursor = ctx:text_after_cursor(1)
  return char_after_cursor == "" or char_after_cursor:match("%s") ~= nil
end

local function restrict_pair_creation(condition, closing)
  return function(ctx)
    local is_closing_pair = closing ~= nil and ctx:is_after_cursor(closing)
    if not can_create_pair(ctx) and not is_closing_pair then return false end
    if type(condition) == "function" then return condition(ctx) end
    return condition ~= false
  end
end

return lib.module.create({
  name = "workflow/text-editing",
  hosts = "*",
  plugins = {
    {
      "christoomey/vim-sort-motion", -- gs
      keys = {
        { "gs", mode = "v", desc = "Sort lines" },
      },
    },
    {
      "tommcdo/vim-lion", -- gl
      keys = {
        { "gl", mode = "v", desc = "Align lines" },
      },
    },
    {
      "kylechui/nvim-surround",
      opts = {
        keymaps = {
          insert = "<C-g>s",
          insert_line = "<C-g>S",
          normal = "ys",
          normal_cur = "yss",
          normal_line = "yS",
          normal_cur_line = "ySS",
          visual = "S",
          visual_line = "gS",
          delete = "ds",
          change = "cs",
        },
      },
      keys = {
        { "ys", mode = "n", desc = "Surround + motion" },
        { "yss", mode = "n", desc = "Surround line" },
        { "yS", mode = "n", desc = "Surround + motion + line" },
        { "ySS", mode = "n", desc = "Surround line + line" },
        { "S", mode = "v", desc = "Surround" },
        { "gS", mode = "v", desc = "Surround + line" },
        { "ds", mode = "n", desc = "Delete surround" },
        { "cs", mode = "n", desc = "Change surround" },
      },
    },
    {
      "saghen/blink.pairs",
      event = { "InsertEnter", "CmdlineEnter" },
      version = "*",
      build = function()
        require("blink.pairs").download():pwait(60000)
      end,
      dependencies = { "saghen/blink.lib" },
      opts = function(_, opts)
        opts = opts or {}

        local default_pairs = require("blink.pairs.config.mappings").pairs[1]
        local default_quote_pairs = vim.deepcopy(default_pairs['"'])
        for _, quote_pair in ipairs(default_quote_pairs) do
          local default_when = quote_pair.when
          quote_pair.when = function(ctx)
            if should_skip_double_quote_pair(ctx) then return false end

            return default_when == nil or default_when(ctx)
          end
        end

        local configured_pairs =
          vim.tbl_deep_extend("force", default_pairs, opts.mappings and opts.mappings.pairs or {}, {
            ["$"] = {},
            ['"'] = default_quote_pairs,
          })
        local pairs_by_key = {}
        for key, definitions in pairs(configured_pairs) do
          if type(definitions) == "string" then definitions = { { definitions } } end

          local guarded_pairs = {}
          for _, definition in ipairs(definitions) do
            local guarded_pair = vim.deepcopy(definition)
            guarded_pair.open = restrict_pair_creation(definition.open)
            guarded_pair.open_or_close =
              restrict_pair_creation(definition.open_or_close, definition[2] or definition[1])
            table.insert(guarded_pairs, guarded_pair)
          end

          pairs_by_key[key] = guarded_pairs
        end

        return vim.tbl_deep_extend("force", opts, {
          mappings = {
            enabled = true,
            cmdline = true,
            pairs = pairs_by_key,
          },
          highlights = {
            enabled = true,
            cmdline = false,
            groups = {
              "RainbowRed",
              "RainbowYellow",
              "RainbowBlue",
              "RainbowOrange",
              "RainbowGreen",
              "RainbowViolet",
              "RainbowCyan",
            },
            matchparen = {
              enabled = true,
              include_surrounding = true,
            },
          },
        })
      end,
    },
    {
      "Wansmer/sibling-swap.nvim",
      -- enabled = false,
      dependencies = { "nvim-treesitter" },
      config = function()
        require("sibling-swap").setup({
          keymaps = {
            ["<a-l>"] = "swap_with_right",
            ["<a-h>"] = "swap_with_left",
          },
          allowed_separators = {
            ",",
            ";",
            "and",
            "or",
            "&&",
            "&",
            "||",
            "|",
            "==",
            "===",
            "!=",
            "!==",
            "-",
            "+",
            ["<"] = ">",
            ["<="] = ">=",
            [">"] = "<",
            [">="] = "<=",
          },
          use_default_keymaps = false,
          highlight_node_at_cursor = false,
          ignore_injected_langs = false,
          allow_interline_swaps = true,
          interline_swaps_without_separator = false,
        })
      end,
      keys = {
        {
          "<a-l>",
          function()
            require("sibling-swap").swap_with_right()
          end,
          { desc = "Swap with right" },
        },
        {
          "<a-h>",
          function()
            require("sibling-swap").swap_with_left()
          end,
          { desc = "Swap with left" },
        },
      },
    },
  },
})
