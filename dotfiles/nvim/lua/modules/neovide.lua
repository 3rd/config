return lib.module.create({
  name = "neovide",
  hosts = { "spaceship" },
  setup = function()
    if not vim.g.neovide then return end

    vim.api.nvim_set_var("neovide_refresh_rate", 240)
    vim.o.guifont = "Berkeley Mono:h12"

    vim.g.neovide_scroll_animation_length = 0.15
    vim.g.neovide_cursor_animation_length = 0.1
    vim.g.neovide_cursor_trail_size = 0.5
    vim.g.neovide_cursor_animate_in_insert_mode = false
    -- vim.g.neovide_cursor_vfx_mode = "railgun"

    vim.g.neovide_scroll_animation_far_lines = 1
    vim.g.neovide_hide_mouse_when_typing = true
    -- vim.g.neovide_profiler = true

    -- zoom
    vim.keymap.set("", "<C-=>", function()
      local _, _, font_size = vim.o.guifont:find(".*:h(%d+)$")
      font_size = tostring(tonumber(font_size) + 1)
      vim.o.guifont = string.gsub(vim.o.guifont, "%d+$", font_size)
    end, { noremap = true })
    vim.keymap.set("", "<C-->", function()
      local _, _, font_size = vim.o.guifont:find(".*:h(%d+)$")
      if tonumber(font_size) > 1 then
        font_size = tostring(tonumber(font_size) - 1)
        vim.o.guifont = string.gsub(vim.o.guifont, "%d+$", font_size)
      end
    end, { noremap = true })

    -- paste with ctrl+shift+v in insert mode
    vim.keymap.set("i", "<C-S-v>", "<C-r>+", { noremap = true })
  end,
})
