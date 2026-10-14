import { type PluginSetup, readBuffer, replaceBuffer } from "../../src";

const setup: PluginSetup = async (plugin) => {
  let count = 0;
  let releaseWork: (() => void) | undefined;
  const options = plugin.options;
  plugin.onDispose(async () => {
    await plugin.nvim.setVar("bunvim_disposed", true);
  });
  plugin.registerCommand({ name: `BunvimFixturePartial${  plugin.name}` }, () => null);
  if (options === "fail") {
    throw new Error("fixture setup failure");
  }

  plugin.registerCommand(
    { name: "BunvimFixture", nargs: "*", bang: true, desc: undefined },
    async (context) => {
      await context.nvim.setVar("bunvim_command", {
        args: context.args,
        bang: context.bang,
        buffer: context.buffer,
      });
    },
  );
  plugin.registerKeymap({ mode: "n", keys: "<Plug>(BunvimFixture)" }, async (context) => {
    await context.nvim.setVar("bunvim_key", context.buffer);
  });
  plugin.registerKeymap({ mode: "n", keys: "<Plug>(BunvimLocal)", buffer: 0 }, () => null);
  plugin.registerAutocmd({ event: "User", pattern: "BunvimFixtureEvent" }, async (context) => {
    count += 1;
    await context.nvim.setVar("bunvim_event", {
      count,
      data: context.data,
      buffer: context.buffer,
    });
  });
  plugin.registerFunction("echo", (input) => {
    if (typeof input !== "string" && typeof input !== "boolean") {
      throw new TypeError("expected string or boolean");
    }

    return input;
  });
  plugin.registerFunction("count", () => ++count);
  plugin.registerFunction("invalid", () => Number.NaN);
  plugin.registerFunction("fail", () => {
    throw new Error("fixture handler failure");
  });
  plugin.registerFunction(
    "wait",
    (_input, context) =>
      new Promise((_resolve, reject) => {
        context.signal.addEventListener("abort", () => reject(context.signal.reason), { once: true });
        context.nvim.setVar("bunvim_waiting", true);
      }),
  );
  plugin.registerFunction("edit", async (_input, context) => {
    const snapshot = await readBuffer(context);
    const gate = new Promise<void>((resolve) => {
      releaseWork = resolve;
    });
    await context.nvim.setVar("bunvim_snapshot", true);
    await gate;
    await replaceBuffer(context, snapshot, ["plugin edit"]);
  });
  plugin.registerFunction("release", () => {
    releaseWork?.();
  });
  plugin.registerFunction("exit", () => process.exit(23));
  plugin.registerFunction("log", () => {
    console.log("fixture log");
    console.dir({ log: true });
    return true;
  });
};

export default setup;
