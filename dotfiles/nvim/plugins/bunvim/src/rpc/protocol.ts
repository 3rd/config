import type { InvocationContext, RpcValue } from "../types";

export const isRecord = (value: unknown): value is Record<string, unknown> => {
  return typeof value === "object" && value !== null && !Array.isArray(value);
};

export const requireString = (value: unknown, name: string) => {
  if (typeof value !== "string") {
    throw new TypeError(`${name  } must be a string`);
  }

  return value;
};

export const requireInteger = (value: unknown, name: string) => {
  if (typeof value !== "number" || !Number.isSafeInteger(value)) {
    throw new TypeError(`${name  } must be an integer`);
  }

  return value;
};

export const requireStringArray = (value: unknown, name: string) => {
  if (!Array.isArray(value) || !value.every((item) => typeof item === "string")) {
    throw new Error(`${name  } must be an array of strings`);
  }

  return value;
};

export const parseOrigin = (value: unknown) => {
  if (!Array.isArray(value) || value.length !== 3) {
    throw new Error("Invalid invocation context");
  }

  return {
    buffer: requireInteger(value[0], "buffer"),
    window: requireInteger(value[1], "window"),
    cwd: requireString(value[2], "cwd"),
  };
};

export const parseCommand = (value: unknown, context: InvocationContext) => {
  if (!isRecord(value) || typeof value.bang !== "boolean") {
    throw new Error("Invalid command arguments");
  }

  return {
    ...context,
    args: requireString(value.args, "args"),
    fargs: requireStringArray(value.fargs, "fargs"),
    bang: value.bang,
    line1: requireInteger(value.line1, "line1"),
    line2: requireInteger(value.line2, "line2"),
    range: requireInteger(value.range, "range"),
    count: requireInteger(value.count, "count"),
    reg: requireString(value.reg, "reg"),
  };
};

export const parseAutocmd = (value: unknown, context: InvocationContext) => {
  if (!isRecord(value)) {
    throw new Error("Invalid autocommand arguments");
  }

  return {
    ...context,
    event: requireString(value.event, "event"),
    match: requireString(value.match, "match"),
    file: requireString(value.file, "file"),
    data: value.data,
  };
};

export const parseCompletion = (value: unknown, context: InvocationContext) => {
  if (!Array.isArray(value) || value.length !== 3) {
    throw new Error("Invalid completion arguments");
  }

  return {
    ...context,
    argLead: requireString(value[0], "argLead"),
    cmdLine: requireString(value[1], "cmdLine"),
    cursorPos: requireInteger(value[2], "cursorPos"),
  };
};

export const isRpcValue = (value: unknown, parents = new Set<unknown>()): value is RpcValue => {
  if (value === null || typeof value === "string" || typeof value === "boolean") return true;
  if (typeof value === "number") return Number.isFinite(value);
  if (value instanceof Uint8Array) return true;
  if (typeof value !== "object" || parents.has(value)) return false;

  parents.add(value);
  let isValid = false;
  if (Array.isArray(value)) {
    isValid = value.every((item) => isRpcValue(item, parents));
  } else if (Object.getPrototypeOf(value) === Object.prototype || Object.getPrototypeOf(value) === null) {
    isValid = Object.values(value).every((item) => isRpcValue(item, parents));
  }

  parents.delete(value);
  return isValid;
};

export const formatError = (error: unknown) => {
  if (!(error instanceof Error)) return String(error);
  if (!error.stack) return error.message;
  return error.stack.includes(error.message) ? error.stack : `${error.message  }\n${  error.stack}`;
};
