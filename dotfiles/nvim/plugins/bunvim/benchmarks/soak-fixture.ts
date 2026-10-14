import { Worker } from "node:worker_threads";
import { type PluginSetup, readBuffer, replaceBuffer } from "../src";

const setup: PluginSetup = (plugin) => {
  if (plugin.name === "documents") {
    plugin.registerAutocmd({ event: "BufWritePre", execution: "sync" }, async (context) => {
      const snapshot = await readBuffer(context);
      await replaceBuffer(
        context,
        snapshot,
        snapshot.lines.map((line) => line.replace(/[\t ]+$/g, "")),
      );
    });
  }

  let events = 0;
  plugin.registerFunction("echo", (input) => {
    if (typeof input !== "string") {
      throw new TypeError("Expected a string");
    }

    return input;
  });
  plugin.registerFunction("memory", () => {
    Bun.gc(true);
    return { ...process.memoryUsage() };
  });
  plugin.registerFunction("events", () => events);
  plugin.registerCommand({ name: `BunvimSoak${  plugin.name}` }, () => null);
  plugin.registerKeymap({ mode: "n", keys: `<Plug>(BunvimSoak${  plugin.name  })` }, () => null);
  plugin.registerAutocmd({ event: "User", pattern: `BunvimSoak${  plugin.name}` }, () => {
    events += 1;
  });
  plugin.registerFunction("work", async (_input, context) => {
    context.signal.throwIfAborted();
    const worker = new Worker(new URL("./cpu-worker.ts", import.meta.url), {
      workerData: 500,
    });
    const completion = Promise.withResolvers<number>();
    const cancel = () => completion.reject(context.signal.reason);
    context.signal.addEventListener("abort", cancel, { once: true });
    worker.on("message", (value: unknown) => {
      if (value === "started") {
        context.nvim.notify("nvim_set_var", ["bunvim_cpu_started", true]);
      } else if (typeof value === "number" && Number.isFinite(value)) {
        completion.resolve(value);
      } else {
        completion.reject(new Error("Invalid CPU worker result"));
      }
    });
    worker.on("error", completion.reject);
    worker.on("exit", (code) => completion.reject(new Error(`CPU worker exited before completion: ${  code}`)));
    try {
      return await completion.promise;
    } finally {
      context.signal.removeEventListener("abort", cancel);
      await worker.terminate();
    }
  });
};

export default setup;
