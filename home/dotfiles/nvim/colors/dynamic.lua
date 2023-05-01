vim.opt.background = "dark"
vim.g.colors_name = "dynamic"
vim.cmd.highlight("clear")

package.loaded["config/theme"] = nil
require("lush")(require("config/theme"))
