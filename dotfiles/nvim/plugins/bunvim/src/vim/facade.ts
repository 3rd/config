import type { InvocationContext } from "../types";
import type { Vim } from "./generated/vim-types";
import functionMetadata from "./generated/vim-functions.json";
import { parseVimFunctionMetadata, parseVimNativeClasses, type VimFunctionMetadata } from "./metadata";
import { createNativeReferences, type NativeMethodTarget } from "./native-references";
import { createScopedState } from "./scoped-state";

const functions = new Map(
  Object.entries(functionMetadata.functions).map(([name, value]) => [name, parseVimFunctionMetadata(value)]),
);
const constants: Record<string, number | string> = functionMetadata.constants;
const CALLBACK_REPLY = "bunvim.vim.callback";
const nativeClasses = parseVimNativeClasses(functionMetadata);

type VimTarget = NativeMethodTarget | { path: string[] };
type CreateVimOptions = Pick<InvocationContext, "nvim" | "signal"> & {
  owner: string;
};

export const createVim = ({ nvim, signal: parentSignal, owner }: CreateVimOptions) => {
  const lifetime = new AbortController();
  const signal = AbortSignal.any([parentSignal, lifetime.signal]);
  const scope = crypto.randomUUID();
  let hasNativeScope = false;
  const getContext = async () => ({
    owner,
    scope,
    channel: await nvim.channelId,
  });

  const callNative = async (operation: string, args: unknown[]) => {
    signal.throwIfAborted();
    const context = await getContext();
    signal.throwIfAborted();
    hasNativeScope = true;
    const result: unknown = await nvim.request("nvim_exec_lua", [
      `return require('bunvim')._vim.${  operation  }(...)`,
      [context, ...args],
    ]);
    signal.throwIfAborted();
    return nativeReferences.decodeValue(result);
  };

  const callFunction = async (target: VimTarget, args: unknown[], metadata: VimFunctionMetadata) => {
    signal.throwIfAborted();
    if (metadata.unsupported) {
      const name =
        "path" in target ? `vim.${  target.path.join(".")}` : `${target.reference.type  }.${  target.method}`;
      throw new TypeError(`Unsupported Vim function: ${  name  }. ${  metadata.unsupported}`);
    }

    const values = nativeReferences.encodeValue(args);
    if (!metadata.callback) return callNative("call", [target, values, metadata]);

    const context = await getContext();
    signal.throwIfAborted();
    const channel = context.channel;

    const id = crypto.randomUUID();
    const response = Promise.withResolvers<unknown>();
    const receive = (method: string, args: unknown[]) => {
      if (method === CALLBACK_REPLY && args[0] === id) {
        if (args[1] !== null) {
          response.reject(new Error(String(args[1])));
        } else {
          response.resolve(args[2]);
        }
      }
    };

    const cancel = () => response.reject(signal.reason);
    nvim.on("notification", receive);
    signal.addEventListener("abort", cancel, { once: true });

    let isAccepted = false;
    hasNativeScope = true;

    try {
      const [, value] = await Promise.all([
        nvim.request("nvim_exec_lua", [
          "require('bunvim')._vim.call_async(...)",
          [context, target, values, metadata, id, CALLBACK_REPLY],
        ]),
        response.promise,
      ]);
      signal.throwIfAborted();
      const decoded = nativeReferences.decodeValue(value);
      isAccepted = true;
      return decoded;
    } finally {
      nvim.removeListener("notification", receive);
      signal.removeEventListener("abort", cancel);
      nvim.notify("nvim_exec_lua", ["require('bunvim')._vim.finish(...)", [channel, id, isAccepted]]);
    }
  };

  const nativeReferences = createNativeReferences({
    owner,
    scope,
    signal,
    nativeClasses,
    callNative,
    callFunction,
    async disposeReference(reference) {
      await nvim.executeLua("require('bunvim')._vim.dispose_reference(...)", [await getContext(), reference]);
    },
  });

  const scopedState = new Map(Object.entries(createScopedState({ nvim, signal })));
  const createProxy = (path: string[]): object =>
    new Proxy(
      (...args: unknown[]) => callFunction({ path }, args, functions.get(path.join(".")) ?? { returns: 1 }),
      {
        get(_target, key) {
          if (typeof key !== "string" || key === "then") return undefined;
          if (path.length === 0 && scopedState.has(key)) return scopedState.get(key);

          const child = [...path, key];
          const constant = constants[child.join(".")];
          return constant === undefined ? createProxy(child) : constant;
        },
      },
    );

  let disposal: Promise<void> | undefined;
  const dispose = () => {
    disposal ??= (async () => {
      lifetime.abort(new Error("Vim facade is disposed"));
      nativeReferences.invalidate();
      if (!hasNativeScope) return;

      await nvim.executeLua("require('bunvim')._vim.release_scope(...)", [await getContext()]);
    })();
    return disposal;
  };

  return { vim: createProxy([]) as Vim, dispose };
};
