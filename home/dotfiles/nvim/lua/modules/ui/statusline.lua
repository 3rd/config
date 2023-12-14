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

  local aw_status = function()
    local has_aw, _ = pcall(require, "aw_watcher")
    if not has_aw then return "noaw" end
    return require("aw_watcher").is_connected() and "aw" or "noaw"
  end

  local sections = {
    lualine_a = { components.git_branch },
    lualine_b = { components.filename },
    lualine_c = { components.git_diff, components.diagnostics },
    lualine_x = {
      copilot_status,
      aw_status,
    },
    lualine_y = { components.filetype },
    lualine_z = { components.location },
  }

  lualine.setup({
    options = {
      theme = theme,
      icons_enabled = true,
      component_separators = { left = "", right = "" },
      section_separators = { left = "", right = "" },
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
  -- enabled = false,
  name = "ui/statusline",
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
