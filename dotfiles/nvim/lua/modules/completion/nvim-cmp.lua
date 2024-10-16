-- thanks https://github.com/hrsh7th/nvim-cmp/issues/1797#issue-2079222950
local function fast_cmp_visible(cmp)
  if not (cmp.core.view and cmp.core.view.custom_entries_view) then return false end
  return cmp.core.view.custom_entries_view:visible()
end

local cmp_sources = {
  { name = "luasnip", keyword_length = 1 },
  { name = "path", keyword_length = 1 },
  {
    name = "nvim_lsp",
    max_item_count = 150,
    entry_filter = function(entry)
      local banned_kinds = { "Text" }
      local kind = require("cmp.types").lsp.CompletionItemKind[entry:get_kind()]
      if vim.tbl_contains(banned_kinds, kind) then return false end
      return true
    end,
  },
  -- {
  --   name = "treesitter",
  --   keyword_length = 1,
  --   group_index = 1,
  --   entry_filter = function(entry)
  --     local banned_kinds = { "Error", "Comment" }
  --     local kind = require("cmp.types").lsp.CompletionItemKind[entry:get_kind()]
  --     if vim.tbl_contains(banned_kinds, kind) then return false end
  --     return true
  --   end,
  -- },
  -- { name = "buffer", keyword_length = 1, group_index = 1 },
  { name = "lazydev", group_index = 0 },
  { name = "nvim_lsp_signature_help" },
}

-- disable treesitter source for syslang buffers
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("cmp-syslang", {}),
  pattern = "syslang",
  callback = function()
    local ok, cmp = pcall(require, "cmp")
    if not ok then return end

    local filtered_sources = {
      { name = "syslang", keyword_length = 1 },
    }
    for _, source in ipairs(cmp_sources) do
      if source.name ~= "treesitter" then table.insert(filtered_sources, source) end
    end

    local syslang_source = require("modules/wiki/cmp")
    cmp.register_source("syslang", syslang_source.new())

    cmp.setup.buffer({ sources = filtered_sources })
  end,
})

-- better context - ty ditsuke
local get_lsp_completion_context = function(completion, source)
  local source_name = (
    source.source
    and source.source.client
    and source.source.client.config
    and source.source.client.config.name
  ) or nil
  if not source_name then return nil end
  if source_name == "tsserver" then
    return completion.detail
  elseif source_name == "vtsls" then
    if completion.labelDetails ~= nil then return completion.labelDetails.description end
  elseif source_name == "gopls" then
    return completion.detail
  end
  return nil
end

local setup = function()
  local cmp = require("cmp")
  local luasnip = require("luasnip")

  local kind_icons = {
    -- base
    Class = "󰠱",
    Color = "󰏘",
    Constant = "",
    Constructor = "",
    Enum = "",
    EnumMember = "",
    Event = "",
    Field = "󰅩",
    File = "󰈙",
    Folder = "󰉋",
    Function = "󰊕",
    Interface = "",
    Keyword = "󰌋",
    Method = "󰆧",
    Module = "",
    Operator = "󰆕",
    Property = "󰜢",
    Reference = "󰈇",
    Snippet = "",
    Struct = "󰙅",
    Text = "󰉿",
    TypeParameter = "󰊄",
    Unit = "",
    Value = "󰎠",
    Variable = "󰆧",
    -- tree-sitter
    String = "󰉿",
  }

  local compare = require("cmp.config.compare")
  compare.lsp_scores = function(entry1, entry2)
    local diff
    if entry1.completion_item.score and entry2.completion_item.score then
      diff = (entry2.completion_item.score * entry2.score) - (entry1.completion_item.score * entry1.score)
    else
      diff = entry2.score - entry1.score
    end
    return (diff < 0)
  end

  local config = {
    -- enabled = function()
    --   -- disable completion in comments
    --   local context = require("cmp.config.context")
    --   return not context.in_treesitter_capture("comment") and not context.in_syntax_group("Comment")
    -- end,
    auto_select = false,
    formatting = {
      format = function(entry, vim_item)
        if entry.source.name == "path" then
          local icon, hl_group = require("nvim-web-devicons").get_icon(entry:get_completion_item().label)
          if icon then
            vim_item.kind = icon
            vim_item.kind_hl_group = hl_group
            return vim_item
          end
        end

        if entry.source.name == "nvim_lsp_signature_help" then
          local parts = vim.split(vim_item.abbr, " ", {})
          local argument = parts[1]
          argument = argument:gsub(":$", "")
          local type = table.concat(parts, " ", 2)
          vim_item.abbr = argument
          vim_item.kind = type
          vim_item.kind_hl_group = "Type"
          return vim_item
        end

        -- vim_item.dup = ({ nvim_lsp = 0, buffer = 0, treesitter = 0, })[entry.source.name] or 0
        vim_item.dup = 0

        local context = ""
        local completion_context = get_lsp_completion_context(entry.completion_item, entry.source)
        if completion_context ~= nil and completion_context ~= "" then
          local truncated_context = string.sub(completion_context, 1, 30)
          if truncated_context ~= completion_context then truncated_context = truncated_context .. "..." end
          context = truncated_context .. " "
        end

        vim_item.menu = ({
          luasnip = "[snip]",
          nvim_lsp = "[lsp]",
          path = "[path]",
          treesitter = "[tree]",
        })[entry.source.name] or ""

        if #context > 0 then vim_item.menu = vim_item.menu .. " " .. context end

        local icon = kind_icons[vim_item.kind] or "§"
        vim_item.abbr = icon .. " " .. vim_item.abbr
        if vim_item.kind then vim_item.abbr_hl_group = "CmpItemKind" .. vim_item.kind end
        vim_item.kind = ""

        return vim_item
      end,
    },
    -- matching = {
    --   disallow_fuzzy_matching = true,
    --   disallow_fullfuzzy_matching = true,
    -- },
    completion = {
      keyword_length = 1,
      max_item_count = 150,
      autocomplete = { require("cmp.types").cmp.TriggerEvent.TextChanged },
    },
    snippet = {
      expand = function(args)
        luasnip.lsp_expand(args.body)
      end,
    },
    preselect = cmp.PreselectMode.None,
    mapping = {
      ["<CR>"] = cmp.mapping.confirm({ select = false }),
      ["<Tab>"] = cmp.mapping(function(fallback)
        if fast_cmp_visible(cmp) then
          cmp.select_next_item({ behavior = cmp.SelectBehavior.Insert, select = false })
        elseif luasnip.jumpable(1) then
          luasnip.jump(1)
        else
          fallback()
        end
      end, { "i", "s" }),
      ["<S-Tab>"] = cmp.mapping(function(fallback)
        if fast_cmp_visible(cmp) then
          cmp.select_prev_item({ behavior = cmp.SelectBehavior.Insert, select = false })
        elseif luasnip.jumpable(-1) then
          luasnip.jump(-1)
        else
          return fallback()
        end
      end, { "i", "s" }),
      ["<C-Space>"] = cmp.mapping(cmp.mapping.complete(), { "i", "c" }),
      ["<C-d>"] = cmp.mapping(cmp.mapping.scroll_docs(4), { "i", "c" }),
      ["<C-u>"] = cmp.mapping(cmp.mapping.scroll_docs(-4), { "i", "c" }),
    },
    sources = cmp.config.sources(cmp_sources),
    window = {
      completion = {
        -- border = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" },
        border = nil,
        -- winhighlight = "NormalFloat:NormalFloat,FloatBorder:FloatBorder",
        scrollbar = "║",
        autocomplete = {
          require("cmp.types").cmp.TriggerEvent.InsertEnter,
          require("cmp.types").cmp.TriggerEvent.TextChanged,
        },
      },
      documentation = {
        border = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" },
        -- winhighlight = "NormalFloat:NormalFloat,FloatBorder:FloatBorder",
        scrollbar = "║",
      },
    },
    -- style = { winhighlight = "NormalFloat:NormalFloat,FloatBorder:FloatBorder" },
    experimental = { ghost_text = true },
    performance = {
      throttle = 10,
      debounce = 0,
      fetching_timeout = 500,
    },
    sorting = {
      priority_weight = 1,
      comparators = {
        cmp.config.compare.score,
        cmp.config.compare.locality,
        cmp.config.compare.offset,
        cmp.config.compare.order,
        cmp.config.compare.kind,
      },
    },
  }

  cmp.setup(config)

  vim.api.nvim_set_hl(0, "CmpBorderedWindow_FloatBorder", { fg = "#565c64" })
end

return lib.module.create({
  name = "completion/nvim-cmp",
  enabled = false,
  hosts = "*",
  plugins = {
    {
      -- "hrsh7th/nvim-cmp",
      -- "yioneko/nvim-cmp",
      -- branch = "perf-up",
      "iguanacucumber/magazine.nvim",
      event = { "InsertEnter" },
      dependencies = {
        "hrsh7th/cmp-buffer",
        "hrsh7th/cmp-nvim-lsp",
        "hrsh7th/cmp-nvim-lsp-signature-help",
        "hrsh7th/cmp-nvim-lua",
        "hrsh7th/cmp-path",
        "saadparwaiz1/cmp_luasnip",
        "nvim-web-devicons",
        -- "ray-x/cmp-treesitter",
      },
      config = setup,
    },
  },
  hooks = {
    lsp = {
      capabilities = function(capabilities)
        return vim.tbl_deep_extend("force", capabilities or {}, require("cmp_nvim_lsp").default_capabilities())
      end,
      on_attach_call = function(client)
        -- change trigger chars for tailwind
        if client.name == "tailwindcss" then
          client.server_capabilities.completionProvider.triggerCharacters =
            { '"', "'", "`", ".", "(", "[", "!", "/", ":" }
        end

        -- disable the tree-sitter source when a language server is attached
        -- local ok, cmp = pcall(require, "cmp")
        -- if not ok then return end
        -- local filtered_sources = {}
        -- for _, source in ipairs(cmp_sources) do
        --   if source.name ~= "treesitter" then table.insert(filtered_sources, source) end
        -- end
        -- cmp.setup.buffer({ sources = filtered_sources })
      end,
    },
  },
})
