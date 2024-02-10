return lib.module.create({
  name = "bufferize",
  plugins = {
    {
      "AndrewRadev/bufferize.vim",
      cmd = {
        "Bufferize",
        "Bmessages",
        "Bnotifications",
      },
      config = function()
        vim.g.bufferize_command = "tabnew"
        vim.api.nvim_create_user_command("Bmessages", "Bufferize messages", {
          desc = "Open messages in new buffer",
        })
        vim.api.nvim_create_user_command("Bnotifications", "Bufferize Notifications", {
          desc = "Open notifications in new buffer",
        })
      end,
    },
  },
})
