local colors = require("config/colors-hex")

local setup = function()
  local lualine = require("lualine")

  local theme = {
    normal = {
      a = colors.ui.status.a,
      b = colors.ui.status.b,
      c = colors.ui.status.c,
    },
  }

  local components = {
    filename = { "filename", path = 1 },
    filetype = { "filetype", path = 1 },
    location = { "location" },
    progress = { "progress" },
    git_branch = { "branch" },
    git_diff = {
      "diff",
      color_added = colors.green,
      color_modified = colors.yellow,
      color_removed = colors.red,
    },
    diagnostics = {
      "diagnostics",
      sources = { "nvim_diagnostic" },
      symbols = { error = " ", warn = " ", info = " ", hint = "󰌶 " },
    },
  }

  local lsp_progress = function()
    return require("lsp-progress").progress()
  end
  vim.api.nvim_create_augroup("lualine_augroup", { clear = true })
  vim.api.nvim_create_autocmd("User", {
    group = "lualine_augroup",
    pattern = "LspProgressStatusUpdated",
    callback = require("lualine").refresh,
  })

  local copilot_status = (function()
    if not require("modules/completion/copilot").enabled then return "" end

    local initialized = false
    local status = ""

    local setup_copilot_status = function()
      initialized = true
      local ok, api = pcall(require, "copilot.api")
      if not ok then return end
      api.register_status_notification_handler(function(data)
        if data.status == "Normal" then
          status = ""
        elseif data.status == "InProgress" then
          status = "…"
        else
          status = data.status or "⦸"
        end
      end)
    end

    return function()
      if not initialized then setup_copilot_status() end
      return status
    end
  end)()

  local codeium_status = (function()
    if not require("modules/completion/codeium").enabled then return "" end

    return function()
      local result = vim.api.nvim_call_function("codeium#GetStatusString", {})
      local status = vim.trim(result)
      return status
    end
  end)()

  local sections = {
    lualine_a = { components.git_branch },
    lualine_b = { components.filename },
    lualine_c = { components.git_diff, components.diagnostics, lsp_progress },
    lualine_x = {
      copilot_status,
      codeium_status,
      -- aw_status,
    },
    lualine_y = { components.filetype },
    lualine_z = { components.location },
  }

  lualine.setup({
    options = {
      theme = theme,
      icons_enabled = true,
      component_separators = { left = "/", right = "/" },
      section_separators = { left = "", right = "" },
      disabled_filetypes = { "NvimTree" },
      globalstatus = true,
    },
    sections = vim.deepcopy(sections),
    inactive_sections = vim.deepcopy(sections),
    tabline = {},
    extensions = { "nvim-tree" },
  })
end

return lib.module.create({
  name = "ui/statusline",
  -- enabled = false,
  hosts = "*",
  plugins = {
    {
      "nvim-lualine/lualine.nvim",
      lazy = false,
      dependencies = { "nvim-tree/nvim-web-devicons" },
      config = setup,
    },
    -- { "tjdevries/express_line.nvim" } -- alternative
  },
})
