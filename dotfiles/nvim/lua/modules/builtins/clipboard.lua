return lib.module.create({
  name = "clipboard",
  setup = function()
    -- https://discourse.nixos.org/t/problem-with-the-neovim-clipboard/55770
    vim.g.clipboard = {
      name = "xclip",
      copy = {
        ["+"] = { "xclip", "-quiet", "-i", "-selection", "clipboard" },
        ["*"] = { "xclip", "-quiet", "-i", "-selection", "primary" },
      },
      paste = {
        ["+"] = { "xclip", "-o", "-selection", "clipboard" },
        ["*"] = { "xclip", "-o", "-selection", "primary" },
      },
      cache_enabled = 1,
    }
  end,
})
