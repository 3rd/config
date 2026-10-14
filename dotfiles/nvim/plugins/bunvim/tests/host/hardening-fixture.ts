import type { PluginSetup, Registration } from "../../src";
import { requireInteger } from "../../src/rpc/protocol";

const setup: PluginSetup = async (plugin) => {
  if (plugin.options === "hang-setup") {
    await new Promise(() => {});
  }

  if (plugin.options === "block-setup") {
    while (true) {
      Math.sqrt(17);
    }
  }

  if (plugin.options === "hang-unload") {
    plugin.onDispose(async () => {
      await plugin.nvim.setVar("bunvim_unloading", true);
      await new Promise(() => {});
    });
  }

  const releases: (() => void)[] = [];
  const runtime = new Map<number, Registration[]>();
  plugin.registerFunction("echo", (input) => (typeof input === "string" ? input : null));
  plugin.registerFunction("hold", async (input, context) => {
    const value = requireInteger(input, "input");
    const gate = Promise.withResolvers<void>();
    releases.push(gate.resolve);
    await context.nvim.setVar(`bunvim_held_${  plugin.name}`, releases.length);
    await gate.promise;
    return value;
  });
  plugin.registerFunction("release", () => {
    const pending = releases.splice(0);
    for (const release of pending) {
      release();
    }

    return pending.length;
  });
  plugin.registerFunction("create", async (input) => {
    const buffer = requireInteger(input, "buffer");
    const handles = [
      plugin.registerKeymap({ mode: "n", keys: "<Plug>(BunvimRuntime)", buffer }, async (context) => {
        await context.nvim.setVar("bunvim_runtime_key", context.buffer);
      }),
      plugin.registerAutocmd({ event: "User", pattern: `BunvimRuntime${  buffer}` }, async (context) => {
        await context.nvim.setVar("bunvim_runtime_event", context.buffer);
      }),
      plugin.registerCommand({ name: `BunvimRuntime${  buffer}` }, async (context) => {
        await context.nvim.setVar("bunvim_runtime_command", context.buffer);
      }),
    ];
    runtime.set(buffer, handles);
    await Promise.all(handles.map((handle) => handle.ready));
    return handles.length;
  });
  plugin.registerFunction("remove", async (input) => {
    const buffer = requireInteger(input, "buffer");
    const handles = runtime.get(buffer);
    if (!handles) {
      throw new Error("Missing runtime registrations");
    }

    await Promise.all(handles.map((handle) => handle.dispose()));
    runtime.delete(buffer);
    return true;
  });
  plugin.registerFunction("replace-function", async () => {
    const old = plugin.registerFunction("dynamic", () => "old");
    await old.ready;
    await old.dispose();
    await plugin.registerFunction("dynamic", () => "new").ready;
    await old.dispose();
  });
  plugin.registerFunction("nested", async (_input, context) => {
    const result: unknown = await context.nvim.executeLua("return require('bunvim').call_sync(...)", [
      plugin.name,
      "echo",
      { input: "nested" },
    ]);
    if (typeof result !== "string") {
      throw new TypeError("Invalid nested result");
    }

    return result;
  });
  plugin.registerFunction("block", () => {
    while (true) {
      Math.sqrt(23);
    }
  });
  plugin.registerFunction("fail", () => {
    throw new Error("hardening failure");
  });
  plugin.registerFunction("log", async () => {
    await plugin.nvim.call("getcwd");
    console.log("attributed log");
    return true;
  });
  plugin.registerKeymap(
    { mode: "n", keys: `<Plug>(BunvimExpr${  plugin.name  })`, expr: true },
    async (context) => {
      const line: unknown = await context.nvim.request("nvim_get_current_line");
      if (typeof line !== "string") {
        throw new TypeError("Invalid current line");
      }

      return `A${  line.length  }\u001b`;
    },
  );
  plugin.registerCommand(
    {
      name: `BunvimComplete${  plugin.name}`,
      nargs: "*",
      complete: async (context) => {
        await context.nvim.call("getcwd");
        return ["alpha", "amber", "beta"].filter((item) => item.startsWith(context.argLead));
      },
    },
    () => null,
  );
  plugin.registerAutocmd(
    { event: "BufWritePre", pattern: "*.bunvim-test", execution: "sync" },
    async (context) => {
      if (plugin.options === "fail-write") {
        throw new Error("Cannot prepare this write");
      }

      await context.nvim.request("nvim_buf_set_lines", [
        context.buffer,
        0,
        -1,
        false,
        ["saved from TypeScript"],
      ]);
    },
  );
};

export default setup;
