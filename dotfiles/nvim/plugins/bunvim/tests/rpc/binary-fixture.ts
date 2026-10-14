import type { PluginSetup } from "../../src";
import { isRpcValue, requireString } from "../../src/rpc/protocol";

const setup: PluginSetup = (plugin) => {
  plugin.registerFunction("echo", (input) => {
    if (!isRpcValue(input)) {
      throw new Error("Invalid binary fixture input");
    }

    return input;
  });
  plugin.registerFunction("options", () => {
    if (!isRpcValue(plugin.options)) {
      throw new Error("Invalid binary fixture options");
    }

    return plugin.options;
  });
  plugin.registerFunction("slice", () => ({
    text: "héllo 🐇",
    bytes: new Uint8Array([1, 0, 128, 192, 255, 2]).subarray(1, 5),
    empty: new Uint8Array(),
    nil: null,
  }));
  plugin.registerFunction("file", async (input, { vim }) => {
    const [fd, error] = await vim.uv.fs_open(requireString(input, "File path"), "w+", 0o600);
    if (fd === null) {
      throw new Error(requireString(error, "File open error"));
    }

    try {
      const written = await vim.uv.fs_write(fd, [new Uint8Array([0, 128, 192, 255]), "hé"], 0);
      const read = await vim.uv.fs_read(fd, 7, 0);
      const eof = await vim.uv.fs_read(fd, 1, 7);
      return { written, read, eof };
    } finally {
      const [hasClosed, closeError] = await vim.uv.fs_close(fd);
      if (!hasClosed) {
        throw new Error(requireString(closeError, "File close error"));
      }
    }
  });
  plugin.registerFunction("readError", (_input, { vim }) => vim.uv.fs_read(-1, 1, 0));
  plugin.registerFunction("random", (_input, { vim }) => vim.uv.random(32));
  plugin.registerFunction("interfaces", (_input, { vim }) => vim.uv.interface_addresses());
  plugin.registerFunction("convert", async (_input, { vim }) => {
    const utf16 = new Uint8Array(new Uint16Array([0xD8_00]).buffer);
    const wtf8 = await vim.uv.utf16_to_wtf8(utf16);
    return {
      utf16,
      wtf8,
      roundTrip: await vim.uv.wtf8_to_utf16(wtf8),
      utf16Length: await vim.uv.wtf8_length_as_utf16(wtf8),
      wtf8Length: await vim.uv.utf16_length_as_wtf8(utf16),
    };
  });
  plugin.registerFunction("barrier", (_input, { vim }) => vim.api.nvim_get_current_buf());
};

export default setup;
