import { type PluginSetup, readBuffer, replaceBuffer } from "../src";

const setup: PluginSetup = async (plugin) => {
  let events = 0;
  const channel = await plugin.nvim.channelId;
  const handleControl = (method: string, args: unknown[]) => {
    if (method !== "bunvim-benchmark-control") return;
    plugin.nvim.notify("nvim_exec_lua", ["_G.bunvim_benchmark_complete(...)", [channel, ...args]]);
  };
  plugin.nvim.on("notification", handleControl);
  plugin.onDispose(() => {
    plugin.nvim.off("notification", handleControl);
  });
  plugin.registerFunction("echo", (input) => {
    if (typeof input !== "string") {
      throw new TypeError("expected string");
    }

    return input;
  });
  plugin.registerFunction("events", () => events);

  plugin.registerCommand({ name: "BunvimBenchmarkUppercase" }, async (context) => {
    const snapshot = await readBuffer(context);
    await replaceBuffer(
      context,
      snapshot,
      snapshot.lines.map((line) => line.toUpperCase()),
    );
  });

  plugin.registerAutocmd({ event: "User", pattern: "BunvimBenchmarkEvent" }, () => {
    events += 1;
  });
};

export default setup;
