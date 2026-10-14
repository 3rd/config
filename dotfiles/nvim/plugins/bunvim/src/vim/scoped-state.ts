import type { NeovimClient } from "neovim";
import type { RpcValue } from "../types";
import { isRecord, isRpcValue, requireInteger, requireString } from "../rpc/protocol";
import { decodeRpcValue, encodeRpcValue } from "../rpc/value-codec";

export type OptionValue = Record<string, boolean | string> | string[] | boolean | number | string;

interface ScopedStateContext {
  nvim: Pick<NeovimClient, "request">;
  signal: AbortSignal;
}

interface StateRequest {
  namespace: string;
  operation: "append" | "delete" | "get" | "prepend" | "remove" | "set";
  name: string;
  target: number;
  scope: "local" | null;
  value: RpcValue;
}

interface OptionTarget {
  target?: number;
  scope?: "local";
}

const isOptionValue = (value: unknown): value is OptionValue => {
  if (
    typeof value === "boolean" ||
    typeof value === "string" ||
    (typeof value === "number" && Number.isFinite(value))
  ) {
    return true;
  }

  if (Array.isArray(value) && value.every((item) => typeof item === "string")) {
    return true;
  }

  return (
    isRecord(value) &&
    !(value instanceof Uint8Array) &&
    Object.values(value).every((item) => typeof item === "string" || typeof item === "boolean")
  );
};

export const createScopedState = ({ nvim, signal }: ScopedStateContext) => {
  const call = async (request: StateRequest) => {
    signal.throwIfAborted();
    requireString(request.name, "State name");
    const result: unknown = await nvim.request("nvim_exec_lua", [
      "return require('bunvim.vim.scoped-state').call(...)",
      [encodeRpcValue(request)],
    ]);
    signal.throwIfAborted();
    const value = decodeRpcValue(result);
    if (!isRpcValue(value)) {
      throw new TypeError("Scoped state returned a non-RPC value");
    }

    return value;
  };

  const createVariables = (namespace: string, target = 0) => ({
    get: (name: string) =>
      call({
        namespace,
        operation: "get",
        name,
        target,
        scope: null,
        value: null,
      }),
    set: async (name: string, value: RpcValue) => {
      await call({
        namespace,
        operation: "set",
        name,
        target,
        scope: null,
        value,
      });
    },
    delete: async (name: string) => {
      await call({
        namespace,
        operation: "delete",
        name,
        target,
        scope: null,
        value: null,
      });
    },
  });

  const createScopedVariables = (namespace: "b" | "t" | "w") => ({
    ...createVariables(namespace),
    at: (target: number) => createVariables(namespace, requireInteger(target, "State target")),
  });

  const createOptions = (namespace: "bo" | "go" | "o" | "wo", { target = 0, scope }: OptionTarget = {}) => ({
    get: async (name: string) => {
      const value = await call({
        namespace,
        operation: "get",
        name,
        target,
        scope: scope ?? null,
        value: null,
      });
      if (typeof value !== "string" && typeof value !== "number" && typeof value !== "boolean") {
        throw new TypeError("Invalid option value");
      }

      return value;
    },
    set: async (name: string, value: OptionValue) => {
      await call({
        namespace,
        operation: "set",
        name,
        target,
        scope: scope ?? null,
        value,
      });
    },
  });

  const createWindowOptions = (target = 0) => ({
    ...createOptions("wo", { target }),
    local: createOptions("wo", { target, scope: "local" }),
  });

  const createStructuredOptions = (namespace: "opt_global" | "opt_local" | "opt") => {
    const change = async (
      operation: "append" | "prepend" | "remove" | "set",
      name: string,
      value: OptionValue,
    ) => {
      await call({ namespace, operation, name, target: 0, scope: null, value });
    };

    return {
      get: async (name: string) => {
        const value = await call({
          namespace,
          operation: "get",
          name,
          target: 0,
          scope: null,
          value: null,
        });
        if (!isOptionValue(value)) {
          throw new TypeError("Invalid structured option value");
        }

        return value;
      },
      set: (name: string, value: OptionValue) => change("set", name, value),
      append: (name: string, value: OptionValue) => change("append", name, value),
      prepend: (name: string, value: OptionValue) => change("prepend", name, value),
      remove: (name: string, value: OptionValue) => change("remove", name, value),
    };
  };

  const environment = createVariables("env");
  return {
    g: createVariables("g"),
    b: createScopedVariables("b"),
    w: createScopedVariables("w"),
    t: createScopedVariables("t"),
    v: createVariables("v"),
    env: {
      get: async (name: string) => {
        const value = await environment.get(name);
        if (value !== null && typeof value !== "string") {
          throw new TypeError("Invalid environment value");
        }

        return value;
      },
      set: (name: string, value: string) => environment.set(name, value),
      delete: environment.delete,
    },
    o: createOptions("o"),
    go: createOptions("go"),
    bo: {
      ...createOptions("bo"),
      at: (target: number) => createOptions("bo", { target: requireInteger(target, "State target") }),
    },
    wo: {
      ...createWindowOptions(),
      at: (target: number) => createWindowOptions(requireInteger(target, "State target")),
    },
    opt: createStructuredOptions("opt"),
    opt_local: createStructuredOptions("opt_local"),
    opt_global: createStructuredOptions("opt_global"),
  };
};

export type ScopedState = ReturnType<typeof createScopedState>;
