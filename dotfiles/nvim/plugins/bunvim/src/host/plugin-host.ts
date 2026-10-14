import type { NeovimClient } from "neovim";
import { createBufferSubscriptions } from "../buffers/subscriptions";
import { formatError, isRpcValue, parseOrigin, requireInteger, requireString } from "../rpc/protocol";
import { decodeRpcValue, encodeRpcValue } from "../rpc/value-codec";
import { createVim } from "../vim/facade";
import { diagnosticContext, formatPluginError } from "./diagnostics";
import { activatePlugin, type PluginActivation } from "./plugin-activation";

interface LoadedPlugin {
  controller: AbortController;
  ready: Promise<PluginActivation>;
  generation: number;
  isUnloading: boolean;
  owner: string;
}

interface RunningCall {
  plugin: string;
  controller: AbortController;
  settled: Promise<void>;
}

export const createHost = (nvim: NeovimClient, channel: number) => {
  const plugins = new Map<string, LoadedPlugin>();
  const calls = new Map<number, RunningCall>();
  const bufferSubscriptions = createBufferSubscriptions(nvim);

  const complete = (id: number, error: string | null, result: unknown = null) => {
    nvim.notify("nvim_exec_lua", [
      "require('bunvim')._complete(...)",
      [channel, id, error, error === null ? encodeRpcValue(result ?? null) : null],
    ]);
  };

  const abortPluginCalls = (name: string) => {
    for (const call of calls.values()) {
      if (call.plugin !== name) continue;
      call.controller.abort(new Error("Plugin unloaded"));
    }
  };

  const unload = async (name: string) => {
    const plugin = plugins.get(name);
    if (!plugin) {
      throw new Error(`Plugin is not loaded: ${  name}`);
    }

    if (plugin.isUnloading) {
      throw new Error(`Plugin is already unloading: ${  name}`);
    }

    plugin.isUnloading = true;
    plugin.controller.abort(new Error("Plugin unloaded"));
    abortPluginCalls(name);

    try {
      const activation = await plugin.ready;
      await Promise.all(
        [...calls.values()].filter((call) => call.plugin === name).map((call) => call.settled),
      );
      await activation.dispose();
    } catch (error) {
      throw new Error(formatPluginError(error, { plugin: name, operation: "unload" }));
    } finally {
      if (plugins.get(name) === plugin) {
        plugins.delete(name);
      }
    }
  };

  const invoke = async (values: unknown[]) => {
    const id = requireInteger(values[0], "request id");
    const name = requireString(values[1], "plugin name");
    const plugin = plugins.get(name);
    if (!plugin || plugin.isUnloading || plugin.controller.signal.aborted) {
      throw new Error(`Plugin is not active: ${  name}`);
    }

    if (typeof values[5] === "number" && values[5] !== plugin.generation) {
      throw new Error(`Plugin activation is no longer active: ${  name}`);
    }

    const controller = new AbortController();
    const completion = Promise.withResolvers<void>();
    calls.set(id, { plugin: name, controller, settled: completion.promise });
    let operation = String(values[2]);
    let facade: ReturnType<typeof createVim> | undefined;

    try {
      const activation = await plugin.ready;
      controller.signal.throwIfAborted();
      plugin.controller.signal.throwIfAborted();
      const key = values[2];
      let handler;
      if (typeof key === "string") {
        handler = activation.functions.get(key);
      } else if (typeof key === "number") {
        handler = activation.handlers.get(key);
      }

      if (!handler) {
        throw new Error(`Unknown plugin function: ${  name  }.${  String(key)}`);
      }

      operation = handler.label;
      facade = createVim({
        nvim,
        signal: controller.signal,
        owner: plugin.owner,
      });
      const context = {
        ...parseOrigin(values[4]),
        nvim,
        vim: facade.vim,
        signal: controller.signal,
      };
      const result = await diagnosticContext.run({ plugin: name, operation }, () =>
        handler.invoke(decodeRpcValue(values[3]), context),
      );
      controller.signal.throwIfAborted();
      plugin.controller.signal.throwIfAborted();
      if (result !== undefined && !isRpcValue(result)) {
        throw new Error(
          "Plugin results must be finite numbers, strings, booleans, null, Uint8Array, arrays, or plain objects",
        );
      }

      const completedFacade = facade;
      facade = undefined;
      await completedFacade.dispose();
      return result ?? null;
    } catch (error) {
      const errors = [formatPluginError(error, { plugin: name, operation })];

      try {
        await facade?.dispose();
      } catch (cleanupError) {
        errors.push(
          formatPluginError(cleanupError, {
            plugin: name,
            operation: `${operation  }.cleanup`,
          }),
        );
      }

      throw new Error(errors.join("; "));
    } finally {
      calls.delete(id);
      completion.resolve();
    }
  };

  const loadPlugin = async (id: number, name: string, values: unknown[]) => {
    if (plugins.has(name)) {
      throw new Error(`Plugin is already loaded: ${  name}`);
    }

    const path = requireString(values[2], "plugin path");
    const controller = new AbortController();
    const generation = requireInteger(values[4], "activation generation");
    const owner = crypto.randomUUID();
    const ready = diagnosticContext.run({ plugin: name, operation: "setup" }, () =>
      activatePlugin({
        name,
        path,
        options: decodeRpcValue(values[3]),
        channel,
        nvim,
        controller,
        generation,
        owner,
        bufferSubscriptions,
      }),
    );
    const plugin = {
      controller,
      ready,
      generation,
      owner,
      isUnloading: false,
    };
    plugins.set(name, plugin);

    try {
      const activation = await ready;
      complete(id, null, { functions: [...activation.functions.keys()] });
    } catch (error) {
      if (plugins.get(name) === plugin) {
        plugins.delete(name);
      }

      throw new Error(formatPluginError(error, { plugin: name, operation: "setup" }));
    }
  };

  const dispatch = async (method: string, values: unknown[]) => {
    let id: number | undefined;

    try {
      id = requireInteger(values[0], "request id");
      if (method === "bunvim:cancel") {
        const call = calls.get(id);
        call?.controller.abort(new Error("Request canceled"));
        return;
      }

      const name = requireString(values[1], "plugin name");
      if (method === "bunvim:load") {
        await loadPlugin(id, name, values);
        return;
      }

      if (method === "bunvim:unload") {
        await diagnosticContext.run({ plugin: name, operation: "unload" }, () => unload(name));
        complete(id, null);
        return;
      }

      if (method !== "bunvim:call") {
        throw new Error(`Unknown host operation: ${  method}`);
      }

      complete(id, null, await invoke(values));
    } catch (error) {
      if (id !== undefined) {
        complete(id, formatError(error));
      } else {
        process.stderr.write(`Bunvim: ${  formatError(error)  }\n`);
      }
    }
  };

  const shutdown = async () => {
    const errors: string[] = [];
    for (const name of plugins.keys()) {
      try {
        await diagnosticContext.run({ plugin: name, operation: "unload" }, () => unload(name));
      } catch (error) {
        errors.push(formatError(error));
      }
    }

    if (errors.length > 0) {
      process.stderr.write(`Bunvim: ${  errors.join("; ")  }\n`);
    }
  };

  return { dispatch, invoke, shutdown };
};
