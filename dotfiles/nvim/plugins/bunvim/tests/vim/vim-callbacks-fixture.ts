import type { PluginSetup } from "../../src";
import { requireInteger, requireString } from "../../src/rpc/protocol";

const setup: PluginSetup = (plugin) => {
  plugin.registerFunction("barrier", (_input, { vim }) => vim.api.nvim_get_current_buf());
  plugin.registerFunction("schedule", (_input, { vim }) => vim.schedule());
  plugin.registerFunction("delay", (input, { vim }) => vim.defer_fn(requireInteger(input, "Delay")));
  plugin.registerFunction("open", (input, { vim }) =>
    vim.uv.fs_open(requireString(input, "File path"), "r", 0),
  );
  plugin.registerFunction("temporaryFile", async (input, { vim }) => {
    const result = await vim.uv.fs_mkstemp(requireString(input, "File template"));
    const [fd] = result;
    if (fd !== null) {
      const [hasClosed, error] = await vim.uv.fs_close(fd);
      if (!hasClosed) {
        throw new Error(requireString(error, "File close error"));
      }
    }

    return result;
  });
  plugin.registerFunction("resolveAddress", async (_input, { vim }) => ({
    addresses: await vim.uv.getaddrinfo("127.0.0.1"),
    names: await vim.uv.getnameinfo({ ip: "127.0.0.1", port: 80 }),
  }));
  plugin.registerFunction("spawn", (input, { vim }) =>
    vim.uv.spawn("sh", { args: ["-c", requireString(input, "Command")] }),
  );
  plugin.registerFunction("spawnMissing", (_input, { vim }) =>
    vim.uv.spawn("/bunvim-fixture-missing-executable", {}),
  );
  plugin.registerFunction("requestAll", (_input, { vim }) =>
    vim.lsp.buf_request_all(0, "textDocument/hover", {}),
  );
  plugin.registerFunction("input", (_input, { vim }) => vim.ui.input({}));
};

export default setup;
