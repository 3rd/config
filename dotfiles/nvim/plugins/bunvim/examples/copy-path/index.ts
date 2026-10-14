import type { PluginSetup } from "../../src";

const setup: PluginSetup = (plugin) => {
  plugin.registerCommand(
    {
      name: "CopyFilePath",
      desc: "Copy this file's absolute path to the clipboard",
    },
    async ({ vim, buffer }) => {
      const path = await vim.api.nvim_buf_get_name(buffer);
      if (!path) {
        throw new Error("This buffer has no file path");
      }

      const hasClipboard = (await vim.fn.has("clipboard")) === 1;
      if (!hasClipboard) {
        throw new Error("No clipboard provider is available");
      }

      const result = await vim.fn.setreg("+", path, "v");
      if (result !== 0) {
        throw new Error("Could not copy the file path");
      }

      await vim.notify(`Copied ${path}`);
    },
  );
};

export default setup;
