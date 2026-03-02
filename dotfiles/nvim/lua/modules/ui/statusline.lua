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
    tabs = {
      "tabs",
      mode = 2, -- tab nr + tab name
      path = 0,
      tab_max_length = 32,
      component_separators = { left = "", right = "" },
      section_separators = { left = "", right = "" },
      max_length = function()
        return math.floor(vim.o.columns * 0.9)
      end,
      show_modified_status = true,
      symbols = { modified = " ●" },
      tabs_color = {
        active = colors.ui.tabs.active,
        inactive = colors.ui.tabs.inactive,
      },
    },
  }

  -- vim.api.nvim_create_augroup("lualine_augroup", { clear = true })
  -- vim.api.nvim_create_autocmd("User", {
  --   group = "lualine_augroup",
  --   pattern = "LspProgressStatusUpdated",
  --   callback = require("lualine").refresh,
  -- })

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

  local cursor_module = nil
  local has_cursor_module = false
  local cursor_module_checked = false
  local get_cursor_module = function()
    if not cursor_module_checked then
      cursor_module_checked = true
      local ok, module = pcall(require, "cursor")
      if ok then
        has_cursor_module = true
        cursor_module = module
      end
    end

    if has_cursor_module then return cursor_module end
    return nil
  end

  local cursor_status = function()
    local cursor = get_cursor_module()
    if not cursor then return "" end
    return cursor.status_icon()
  end

  local sections = {
    lualine_a = { components.git_branch },
    lualine_b = { components.filename },
    lualine_c = { components.git_diff, components.diagnostics },
    lualine_x = {
      cursor_status,
      copilot_status,
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
      always_show_tabline = false,
    },
    sections = vim.deepcopy(sections),
    inactive_sections = vim.deepcopy(sections),
    tabline = {
      lualine_a = { components.tabs },
    },
    extensions = { "nvim-tree" },
  })
end

return lib.module.create({
  name = "ui/statusline",
  hosts = "*",
  plugins = {
    {
      "nvim-lualine/lualine.nvim",
      lazy = false,
      dependencies = { "nvim-tree/nvim-web-devicons" },
      config = setup,
    },
  },
})
