local toggle_venn = function()
  local venn_enabled = vim.inspect(vim.b.venn_enabled)
  if venn_enabled == "nil" then
    vim.b.venn_enabled = true
    vim.opt_local.virtualedit = "all"

    -- draw a line with HJKL
    vim.keymap.set("n", "J", "<C-v>j:VBox<CR>", { noremap = true, buffer = 0 })
    vim.keymap.set("n", "K", "<C-v>k:VBox<CR>", { noremap = true, buffer = 0 })
    vim.keymap.set("n", "L", "<C-v>l:VBox<CR>", { noremap = true, buffer = 0 })
    vim.keymap.set("n", "H", "<C-v>h:VBox<CR>", { noremap = true, buffer = 0 })

    -- draw a box around the visual selection with f
    vim.api.nvim_buf_set_keymap(0, "v", "f", ":VBox<CR>", { noremap = true })

    print("venn enabled")
  else
    vim.b.venn_enabled = nil
    vim.opt_local.virtualedit = ""

    vim.keymap.del("n", "J", { buffer = 0 })
    vim.keymap.del("n", "K", { buffer = 0 })
    vim.keymap.del("n", "L", { buffer = 0 })
    vim.keymap.del("n", "H", { buffer = 0 })
    vim.keymap.del("v", "f", { buffer = 0 })

    print("venn disabled")
  end
end

return lib.module.create({
  name = "misc/diagrams",
  enabled = false,
  hosts = { "spaceship", "death" },
  plugins = {
    { "jbyuki/venn.nvim", cmd = { "VBox" } },
    { "superhawk610/ascii-blocks.nvim", cmd = { "AsciiBlockify" } },
    {
      "3rd/diagram.nvim",
      ft = { "markdown", "syslang" },
      dir = lib.path.resolve(lib.env.dirs.vim.config, "plugins", "diagram.nvim"),
      opts = {
        renderer_options = {
          mermaid = {
            background = "transparent",
            theme = "dark",
          },
        },
        -- conceal_enable = true,
      },
    },
  },
  actions = {
    { "n", "Diagrams: ASCII Blockify", "AsciiBlockify" },
    { "n", "Diagrams: venn", toggle_venn },
  },
  mappings = {
    { "n", "<leader>v", toggle_venn, { desc = "Toggle venn", noremap = true } },
  },
})
