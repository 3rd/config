import { NvimPlugin } from "neovim";

const plugin = {} as NvimPlugin;

plugin.registerCommand(
  "EchoMessage",
  async () => {
    try {
      await plugin.nvim.outWrite("Dayman (ah-ah-ah) \n");
    } catch (error) {
      console.error(error);
    }
  },
  { sync: false }
);

plugin.registerAutocmd(
  "BufEnter",
  async (fileName) => {
    await plugin.nvim.buffer.append("BufEnter for a JS File?");
  },
  { sync: false, pattern: "*.js", eval: 'expand("<afile>")' }
);
