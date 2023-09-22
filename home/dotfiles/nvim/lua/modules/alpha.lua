-- taken from https://github.com/dtr2300/nvim/blob/main/lua/config/plugins/alpha.lua

local function layout()
  local function button(sc, txt, keybind, keybind_opts, opts)
    local def_opts = {
      cursor = 3,
      align_shortcut = "right",
      hl = "Function",
      hl_shortcut = "Boolean",
      width = 35,
      position = "center",
    }
    opts = opts and vim.tbl_extend("force", def_opts, opts) or def_opts
    opts.shortcut = sc
    local sc_ = sc:gsub("%s", ""):gsub("SPC", "<Leader>")
    local on_press = function()
      local key = vim.api.nvim_replace_termcodes(keybind or sc_ .. "<Ignore>", true, false, true)
      vim.api.nvim_feedkeys(key, "t", false)
    end
    if keybind then
      keybind_opts = vim.F.if_nil(keybind_opts, { noremap = true, silent = true, nowait = true })
      opts.keymap = { "n", sc_, keybind, keybind_opts }
    end
    return { type = "button", val = txt, on_press = on_press, opts = opts }
  end

  -- https://github.com/goolord/alpha-nvim/issues/105
  local lazycache = setmetatable({}, {
    __newindex = function(table, index, fn)
      assert(type(fn) == "function")
      getmetatable(table)[index] = fn
    end,
    __call = function(table, index)
      return function()
        return table[index]
      end
    end,
    __index = function(table, index)
      local fn = getmetatable(table)[index]
      if fn then
        local value = fn()
        rawset(table, index, value)
        return value
      end
    end,
  })

  lazycache.info = function()
    local plugins = #vim.tbl_keys(require("lazy").plugins())
    local v = vim.version()
    local datetime = os.date(" %d-%m-%Y   %H:%M:%S")
    local platform = vim.fn.has("win32") == 1 and "" or ""
    return string.format("󰂖 %d  %s %d.%d.%d  %s", plugins, platform, v.major, v.minor, v.patch, datetime)
  end

  lazycache.fortune = function()
    return require("alpha.fortune")()
  end

  ---@return table
  lazycache.menu = function()
    return {
      button("r", "󰈢 Recent files", "<Cmd>FzfLua oldfiles<CR>"),
      button("n", " New file", "<Cmd>ene<CR>"),
      button("p", "󰂖 Plugins", "<Cmd>Lazy<CR>"),
      button("q", "󰅚 Quit", "<Cmd>qa<CR>"),
    }
  end

  return {
    { type = "padding", val = 1 },
    {
      type = "text",
      val = { "<image>" },
      opts = { hl = "EndOfBuffer", position = "center" },
    },
    { type = "padding", val = 1 },
    {
      type = "text",
      val = lazycache("info"),
      opts = { hl = "Special", position = "center" },
    },
    { type = "padding", val = 2 },
    {
      type = "group",
      val = lazycache("menu"),
      opts = { spacing = 0 },
    },
    { type = "padding", val = 1 },
    {
      type = "text",
      val = lazycache("fortune"),
      opts = { hl = "Comment", position = "center" },
    },
  }
end

return lib.module.create({
  name = "alpha",
  plugins = {
    {
      "goolord/alpha-nvim",
      event = "VimEnter",
      dependencies = { "nvim-tree/nvim-web-devicons" },
      config = function()
        require("alpha").setup({
          layout = layout(),
          opts = {
            setup = function()
              local image = nil

              vim.api.nvim_create_autocmd("User", {
                pattern = "AlphaReady",
                desc = "Disable status and tabline for alpha",
                callback = function()
                  vim.go.laststatus = 0
                  vim.opt.showtabline = 0

                  -- sample image.nvim integration
                  local image_path = "~/.config/nvim/dashboard.png"
                  local image_width = 20

                  local buf = vim.api.nvim_get_current_buf()
                  local win = vim.api.nvim_get_current_win()
                  local win_width = vim.api.nvim_win_get_width(win)

                  local text = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
                  local row = nil
                  local col = nil
                  for i, line in ipairs(text) do
                    local start = string.find(line, "<image>")
                    if start then
                      row = i
                      col = start
                      break
                    end
                  end
                  if not row or not col then error("Couldn't find <image> in the buffer") end
                  col = math.floor(win_width / 2) - math.floor(image_width / 2)

                  -- delayed here, you must pick your poison:
                  -- 1. delay and start up instantly when restoring a session, the image will be rendered after the dashboard
                  -- 2. don't relay, the image will be rendered at the same time as the dashboard, but the startup will be delayed
                  local with_delay = false
                  local handler = with_delay
                      and function(fn)
                        vim.defer_fn(fn, 0)
                      end
                    or function(fn)
                      return fn()
                    end
                  handler(function()
                    if vim.api.nvim_get_current_buf() ~= buf then return end
                    image = require("image").from_file(image_path, {
                      window = win,
                      buffer = buf,
                      width = image_width,
                      x = col,
                      y = row,
                      with_virtual_padding = true,
                    })
                    image:render()
                  end)
                end,
              })

              vim.api.nvim_create_autocmd("BufUnload", {
                buffer = 0,
                desc = "Enable status and tabline after alpha",
                callback = function()
                  vim.go.laststatus = 3
                  vim.opt.showtabline = 2
                  if image then image:clear() end
                end,
              })
            end,
            margin = 5,
          },
        })
      end,
    },
  },
})
