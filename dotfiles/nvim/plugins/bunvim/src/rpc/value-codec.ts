import type { RpcValue } from "../types";
import { isRecord } from "./protocol";

export interface RpcReference {
  scope: string;
  id: number;
  type: string;
}

export class RpcEncodingError extends TypeError {
  constructor() {
    super("Cannot encode RPC value");
    this.name = "RpcEncodingError";
  }
}

interface RpcEncodeOptions {
  undefinedValues?: "normalize";
  encodeReference?: (value: unknown) => RpcReference | undefined;
}

interface RpcDecodeOptions {
  decodeReference?: (reference: RpcReference) => unknown;
}

type RpcScalar = boolean | number | string | null;

const parseReference = (scope: unknown, id: unknown, type: unknown) => {
  if (
    typeof scope !== "string" ||
    scope.length === 0 ||
    typeof id !== "number" ||
    !Number.isSafeInteger(id) ||
    id < 1 ||
    typeof type !== "string" ||
    type.length === 0
  ) {
    throw new TypeError("Invalid RPC reference");
  }

  return { scope, id, type };
};

const isScalar = (value: unknown): value is RpcScalar =>
  value === null ||
  typeof value === "string" ||
  typeof value === "boolean" ||
  (typeof value === "number" && Number.isFinite(value));

export const encodeRpcValue = (value: unknown, options: RpcEncodeOptions = {}) => {
  const parents = new Set<unknown>();

  const encode = (item: unknown): RpcValue => {
    if (item === undefined && options.undefinedValues === "normalize") return null;
    if (isScalar(item)) return item;

    const reference = options.encodeReference?.(item);
    if (reference !== undefined) {
      const token = parseReference(reference.scope, reference.id, reference.type);
      return ["reference", token.scope, token.id, token.type];
    }

    if (item instanceof Uint8Array) {
      return ["bytes", Buffer.from(item.buffer, item.byteOffset, item.byteLength).toString("base64")];
    }

    if (typeof item !== "object" || item === null || parents.has(item)) {
      throw new RpcEncodingError();
    }

    parents.add(item);
    try {
      if (Array.isArray(item)) {
        return ["array", Array.from(item, encode)];
      }

      if (
        isRecord(item) &&
        (Object.getPrototypeOf(item) === Object.prototype || Object.getPrototypeOf(item) === null)
      ) {
        const entries = Object.entries(item)
          .filter(([, value]) => value !== undefined || options.undefinedValues !== "normalize")
          .map(([key, value]) => [key, encode(value)]);
        return ["object", entries];
      }

      throw new RpcEncodingError();
    } finally {
      parents.delete(item);
    }
  };

  return encode(value);
};

export const decodeRpcValue = (value: unknown, options: RpcDecodeOptions = {}) => {
  const parents = new Set<unknown>();

  const decode = (item: unknown): unknown => {
    if (isScalar(item)) return item;
    if (!Array.isArray(item) || parents.has(item)) {
      throw new TypeError("Invalid encoded RPC value");
    }

    parents.add(item);
    try {
      const [kind, payload] = item;
      if (kind === "reference" && item.length === 4) {
        const reference = parseReference(payload, item[2], item[3]);
        if (!options.decodeReference) {
          throw new TypeError("RPC references are not supported here");
        }

        return options.decodeReference(reference);
      }

      if (item.length !== 2) {
        throw new TypeError("Invalid encoded RPC value");
      }

      if (kind === "bytes" && typeof payload === "string") {
        const bytes = Buffer.from(payload, "base64");
        if (bytes.toString("base64") !== payload) {
          throw new TypeError("Invalid encoded RPC bytes");
        }

        return new Uint8Array(bytes);
      }

      if (kind === "array" && Array.isArray(payload)) {
        return Array.from(payload, decode);
      }

      if (kind === "object" && Array.isArray(payload)) {
        const keys = new Set<string>();
        const entries = payload.map((entry) => {
          if (
            !Array.isArray(entry) ||
            entry.length !== 2 ||
            typeof entry[0] !== "string" ||
            keys.has(entry[0])
          ) {
            throw new TypeError("Invalid encoded RPC object entry");
          }

          keys.add(entry[0]);
          return [entry[0], decode(entry[1])];
        });
        return Object.fromEntries(entries);
      }

      throw new TypeError("Invalid encoded RPC value");
    } finally {
      parents.delete(item);
    }
  };

  return decode(value);
};
