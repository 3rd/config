import type { NeovimClient } from "neovim";
import type { FunctionHandler, PluginContext } from "../types";
import { parseAutocmd, parseCommand, parseCompletion } from "../rpc/protocol";

interface HandlerEntry {
  invoke: FunctionHandler;
  label: string;
}

interface RegistrationOptions {
  name: string;
  channel: number;
  generation: number;
  nvim: NeovimClient;
  signal: AbortSignal;
}

export const createPluginRegistrations = ({
  name,
  channel,
  generation,
  nvim,
  signal,
}: RegistrationOptions) => {
  const functions = new Map<string, HandlerEntry>();
  const handlers = new Map<number, HandlerEntry>();
  const installations: Promise<void>[] = [];
  let isSettingUp = true;
  let nextHandler = 0;

  const trackInstallation = (ready: Promise<void>) => {
    if (isSettingUp) {
      installations.push(ready);
    }
  };

  const registerHandler = (handler: FunctionHandler, label: string) => {
    signal.throwIfAborted();

    if (typeof handler !== "function") {
      throw new TypeError("Plugin handlers must be functions");
    }

    nextHandler += 1;
    handlers.set(nextHandler, { invoke: handler, label });
    return nextHandler;
  };

  const installRegistration = (entry: Record<string, unknown>, ids: [number, ...number[]]) => {
    const id = ids[0];
    const metadata = Object.fromEntries(Object.entries(entry).filter(([, value]) => value !== undefined));

    const ready = nvim
      .executeLua("require('bunvim')._install(...)", [channel, name, generation, [{ ...metadata, id }]])
      .then(() => {
        signal.throwIfAborted();
      });
    trackInstallation(ready);

    ready.catch((error: unknown) => {
      for (const handler of ids) {
        handlers.delete(handler);
      }

      const shouldReportError = !isSettingUp && !signal.aborted;
      if (shouldReportError) {
        console.error(error);
      }
    });

    let removal: Promise<void> | undefined;

    const dispose = () => {
      removal ??= ready.then(async () => {
        for (const handler of ids) {
          handlers.delete(handler);
        }

        await nvim.executeLua("require('bunvim')._remove(...)", [channel, name, generation, id]);
      });
      return removal;
    };

    return { ready, dispose };
  };

  const api: Pick<
    PluginContext,
    "registerAutocmd" | "registerCommand" | "registerFunction" | "registerKeymap"
  > = {
    registerFunction(functionName, handler) {
      signal.throwIfAborted();

      const isInvalidName = !functionName || functions.has(functionName);
      if (isInvalidName) {
        throw new Error(`Duplicate or empty function name: ${  functionName}`);
      }

      if (typeof handler !== "function") {
        throw new TypeError("Plugin handlers must be functions");
      }

      const entry = { invoke: handler, label: functionName };
      functions.set(functionName, entry);
      return {
        ready: Promise.resolve(),
        dispose: () => {
          if (functions.get(functionName) === entry) {
            functions.delete(functionName);
          }

          return Promise.resolve();
        },
      };
    },
    registerCommand(command, handler) {
      const id = registerHandler(
        (input, invocation) => handler(parseCommand(input, invocation)),
        command.name,
      );

      const { complete, ...settings } = command;
      if (typeof complete === "function") {
        const completion = registerHandler(
          (input, invocation) => complete(parseCompletion(input, invocation)),
          `${command.name  }.complete`,
        );
        return installRegistration({ ...settings, kind: "command", handler: id, completion }, [
          id,
          completion,
        ]);
      }

      return installRegistration({ ...settings, kind: "command", handler: id, complete }, [id]);
    },
    registerAutocmd(autocmd, handler) {
      const id = registerHandler(
        (input, invocation) => handler(parseAutocmd(input, invocation)),
        `autocmd:${  String(autocmd.event)}`,
      );
      return installRegistration({ ...autocmd, kind: "autocmd", handler: id }, [id]);
    },
    registerKeymap(keymap, handler) {
      const id = registerHandler((_input, invocation) => handler(invocation), `keymap:${  keymap.keys}`);
      return installRegistration({ ...keymap, kind: "keymap", handler: id }, [id]);
    },
  };

  const finishSetup = async () => {
    await Promise.all(installations);
    isSettingUp = false;
  };

  const clear = () => {
    functions.clear();
    handlers.clear();
  };

  return { api, functions, handlers, trackInstallation, finishSetup, clear };
};
