local directory = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h")
vim.opt.runtimepath:prepend(directory .. "/../..")
local bunvim = require("bunvim")

local await = function(start)
  local is_done, failure = false, nil
  start(function(err)
    failure, is_done = err, true
  end)
  assert(
    vim.wait(5000, function()
      return is_done
    end),
    "Colorscheme callback missing"
  )
  assert(not failure, failure)
end

local run = function()
  local errors = {}
  vim.notify = function(message, level)
    assert(level == vim.log.levels.ERROR)
    table.insert(errors, message)
  end
  await(function(done)
    bunvim.load("colorscheme-picker", { path = directory .. "/index.ts", on_complete = done })
  end)
  local expected = vim.fn.getcompletion("", "color")
  local source = vim.api.nvim_get_current_win()
  local window, buffer

  local open_picker = function()
    vim.cmd("PickColorscheme")
    assert(vim.wait(5000, function()
      return vim.api.nvim_get_current_win() ~= source and bunvim.status().pending == 0
    end))
    window = vim.api.nvim_get_current_win()
    buffer = vim.api.nvim_get_current_buf()
    assert(vim.deep_equal(vim.api.nvim_buf_get_lines(buffer, 0, -1, true), expected))
    assert(vim.api.nvim_win_get_config(window).relative == "win")
    assert(vim.wo[window].cursorline and not vim.bo[buffer].modifiable)
  end

  local move_to = function(name)
    local row = vim.fn.index(expected, name) + 1
    assert(row > 0)
    vim.api.nvim_win_set_cursor(window, { row, 0 })
    vim.api.nvim_exec_autocmds("CursorMoved", { buffer = buffer })
    assert(vim.wait(5000, function()
      return vim.g.colors_name == name and bunvim.status().pending == 0
    end))
    assert(vim.api.nvim_win_is_valid(window), "Preview closed the picker")
  end

  local press = function(key)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(key, true, false, true), "xt", false)
    assert(vim.wait(5000, function()
      return not vim.api.nvim_win_is_valid(window) and bunvim.status().pending == 0
    end))
    assert(not vim.api.nvim_buf_is_valid(buffer))
    assert(vim.api.nvim_get_current_win() == source)
  end

  vim.cmd.colorscheme("default")
  open_picker()
  move_to("habamax")
  press("<CR>")
  assert(vim.g.colors_name == "habamax")

  vim.api.nvim_set_hl(0, "Normal", { fg = "#abcdef", bg = "#123456" })
  vim.api.nvim_set_hl(0, "BunvimTestLink", { link = "Normal" })
  vim.g.terminal_color_0 = "#123456"
  local normal = vim.api.nvim_get_hl(0, { name = "Normal" })
  local background = vim.o.background
  local notified_theme
  vim.api.nvim_create_autocmd("ColorScheme", {
    callback = function(event)
      notified_theme = event.match
    end,
  })

  local assert_restored = function()
    assert(vim.g.colors_name == "habamax")
    assert(vim.o.background == background)
    assert(vim.deep_equal(vim.api.nvim_get_hl(0, { name = "Normal" }), normal))
    assert(vim.deep_equal(vim.api.nvim_get_hl(0, { name = "BunvimTestLink" }), { link = "Normal" }))
    assert(vim.g.terminal_color_0 == "#123456")
  end

  open_picker()
  assert_restored()
  vim.cmd("PickColorscheme")
  assert(vim.wait(5000, function()
    return bunvim.status().pending == 0
  end))
  assert(vim.api.nvim_get_current_win() == window and #vim.api.nvim_list_wins() == 2)
  move_to("blue")
  move_to("morning")
  press("<Esc>")
  assert_restored()
  assert(notified_theme == "habamax")

  open_picker()
  move_to("blue")
  vim.api.nvim_win_close(window, true)
  assert(vim.wait(5000, function()
    return not vim.api.nvim_buf_is_valid(buffer) and bunvim.status().pending == 0
  end))
  assert_restored()

  open_picker()
  vim.api.nvim_create_autocmd("ColorSchemePre", {
    pattern = "blue",
    once = true,
    callback = function()
      vim.api.nvim_set_hl(0, "Normal", { fg = "#ff0000" })
      error("Broken theme fixture")
    end,
  })
  vim.api.nvim_win_set_cursor(window, { vim.fn.index(expected, "blue") + 1, 0 })
  vim.api.nvim_exec_autocmds("CursorMoved", { buffer = buffer })
  assert(vim.wait(5000, function()
    return not vim.api.nvim_win_is_valid(window) and bunvim.status().pending == 0
  end))
  assert(#errors == 1 and errors[1]:find("Broken theme fixture", 1, true))
  assert_restored()

  vim.g.colors_name = nil
  open_picker()
  move_to("habamax")
  press("q")
  assert(vim.g.colors_name == nil)
  assert(vim.deep_equal(vim.api.nvim_get_hl(0, { name = "Normal" }), normal))

  vim.g.colors_name = "habamax"
  open_picker()
  move_to("blue")
  await(function(done)
    bunvim.unload("colorscheme-picker", { on_complete = done })
  end)
  assert(vim.fn.exists(":PickColorscheme") == 0)
  assert(not vim.api.nvim_win_is_valid(window) and not vim.api.nvim_buf_is_valid(buffer))
  assert_restored()
  await(function(done)
    bunvim.stop({ on_complete = done })
  end)
end

local ok, failure = xpcall(run, debug.traceback)
bunvim.stop()
if not ok then
  io.stderr:write(tostring(failure) .. "\n" .. table.concat(bunvim.logs(), "\n") .. "\n")
  vim.cmd("cquit 1")
end

print("Colorscheme picker passed")
vim.cmd("qa!")
