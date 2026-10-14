import { pathToFileURL } from "node:url";
import type { NeovimClient } from "neovim";
import type { BufferSubscriptions } from "../buffers/subscriptions";
import type { Dispose, PluginContext } from "../types";
import { formatError, isRecord } from "../rpc/protocol";
import { createVim } from "../vim/facade";
import { createPluginRegistrations } from "./plugin-registrations";

interface ActivationOptions {
  name: string;
  path: string;
  options: unknown;
  channel: number;
  nvim: NeovimClient;
  controller: AbortController;
  generation: number;
  owner: string;
  bufferSubscriptions: BufferSubscriptions;
}

export const activatePlugin = async (options: ActivationOptions) => {
  const { name, nvim, channel, controller, generation } = options;
  const registrations = createPluginRegistrations({
    name,
    nvim,
    channel,
    generation,
    signal: controller.signal,
  });
  const disposals: Dispose[] = [];
  const facade = createVim({
    nvim,
    signal: controller.signal,
    owner: options.owner,
  });
  let isDisposed = false;

  const dispose = async () => {
    if (isDisposed) return;
    isDisposed = true;
    controller.abort(new Error("Plugin unloaded"));
    const errors: string[] = [];

    try {
      await nvim.executeLua("require('bunvim')._remove(...)", [channel, name, generation]);
    } catch (error) {
      errors.push(formatError(error));
    }

    try {
      await options.bufferSubscriptions.drain(controller.signal);
    } catch (error) {
      errors.push(formatError(error));
    }

    for (const cleanup of disposals.reverse()) {
      try {
        await cleanup();
      } catch (error) {
        errors.push(formatError(error));
      }
    }

    try {
      await facade.dispose();
    } catch (error) {
      errors.push(formatError(error));
    }

    registrations.clear();

    if (errors.length > 0) {
      throw new Error(`Plugin cleanup failed: ${  errors.join("; ")}`);
    }
  };

  const context: PluginContext = {
    name,
    nvim,
    vim: facade.vim,
    options: options.options,
    signal: controller.signal,
    ...registrations.api,
    subscribeBuffer(subscriptionOptions, handler) {
      const subscription = options.bufferSubscriptions.subscribe({
        options: subscriptionOptions,
        handler,
        signal: controller.signal,
        plugin: name,
      });
      registrations.trackInstallation(subscription.ready);
      return subscription;
    },
    onDispose(cleanup) {
      controller.signal.throwIfAborted();
      disposals.push(cleanup);
    },
  };

  try {
    const imported: unknown = await import(pathToFileURL(options.path).href);
    if (!isRecord(imported) || typeof imported.default !== "function") {
      throw new Error(`Plugin must default-export a setup function: ${  options.path}`);
    }

    await imported.default(context);
    controller.signal.throwIfAborted();
    await registrations.finishSetup();
    controller.signal.throwIfAborted();
    return {
      functions: registrations.functions,
      handlers: registrations.handlers,
      dispose,
    };
  } catch (error) {
    try {
      await dispose();
    } catch (cleanupError) {
      throw new Error(`${formatError(error)  }; ${  formatError(cleanupError)}`);
    }

    throw error;
  }
};

export type PluginActivation = Awaited<ReturnType<typeof activatePlugin>>;
