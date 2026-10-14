import { isRecord, requireInteger, requireString, requireStringArray } from "../rpc/protocol";

export interface VimCallbackMetadata {
  index: number;
  returns: number;
  result: "error-first" | "uv" | "values";
  cancel?: "client-request" | "close" | "function" | "process" | "request";
  discard?: "close-fd";
  hasErrorReturn?: boolean;
  resourceIndex?: number;
  immediateResult?: number;
  rejectOnFalse?: string;
  dictionaries?: number[];
  prerequisite?: {
    path: string[];
    options: Record<string, number>;
    message: string;
  };
}

export interface VimIteratorMetadata {
  returns: number;
  resultTypes: VimValueDescriptor[];
}

export type VimValueDescriptor =
  | "bytes"
  | { array: VimValueDescriptor }
  | { dictionary: VimValueDescriptor }
  | { fields: Record<string, VimValueDescriptor> }
  | { iterator: VimIteratorMetadata }
  | { native: string }
  | { tuple: VimValueDescriptor[] }
  | null;

export interface VimFunctionMetadata {
  returns: "all" | number;
  callback?: VimCallbackMetadata;
  resultTypes?: VimValueDescriptor[];
  unsupported?: string;
}

export interface VimNativeClassMetadata {
  methods: Record<string, VimFunctionMetadata>;
  fields: Record<string, VimValueDescriptor>;
}

const parseVimValueDescriptor = (value: unknown): VimValueDescriptor => {
  if (value === null || value === "bytes") return value;

  if (!isRecord(value)) {
    throw new Error("Invalid Vim value descriptor");
  }

  if (typeof value.native === "string") return { native: value.native };
  if ("array" in value) return { array: parseVimValueDescriptor(value.array) };

  if ("dictionary" in value) {
    return { dictionary: parseVimValueDescriptor(value.dictionary) };
  }

  if (Array.isArray(value.tuple)) {
    return { tuple: value.tuple.map(parseVimValueDescriptor) };
  }

  if (isRecord(value.fields)) {
    return {
      fields: Object.fromEntries(
        Object.entries(value.fields).map(([name, descriptor]) => [name, parseVimValueDescriptor(descriptor)]),
      ),
    };
  }

  if (isRecord(value.iterator) && Array.isArray(value.iterator.resultTypes)) {
    return {
      iterator: {
        returns: requireInteger(value.iterator.returns, "Vim iterator return count"),
        resultTypes: value.iterator.resultTypes.map(parseVimValueDescriptor),
      },
    };
  }

  throw new Error("Invalid Vim value descriptor");
};

export const parseVimFunctionMetadata = (value: unknown) => {
  if (!isRecord(value) || (typeof value.returns !== "number" && value.returns !== "all")) {
    throw new Error("Invalid Vim function metadata");
  }

  const metadata: VimFunctionMetadata = { returns: value.returns };
  if (value.unsupported !== undefined) {
    metadata.unsupported = requireString(value.unsupported, "Unsupported Vim function reason");
  }

  if (value.resultTypes !== undefined) {
    if (!Array.isArray(value.resultTypes)) {
      throw new TypeError("Invalid Vim result metadata");
    }

    metadata.resultTypes = value.resultTypes.map(parseVimValueDescriptor);
  }

  if (value.callback !== undefined) {
    const callback = value.callback;
    if (
      !isRecord(callback) ||
      (callback.result !== "values" && callback.result !== "uv" && callback.result !== "error-first") ||
      (callback.cancel !== undefined &&
        callback.cancel !== "close" &&
        callback.cancel !== "request" &&
        callback.cancel !== "function" &&
        callback.cancel !== "process" &&
        callback.cancel !== "client-request") ||
      (callback.discard !== undefined && callback.discard !== "close-fd") ||
      (callback.hasErrorReturn !== undefined && typeof callback.hasErrorReturn !== "boolean") ||
      (callback.dictionaries !== undefined && !Array.isArray(callback.dictionaries))
    ) {
      throw new Error("Invalid Vim callback metadata");
    }

    metadata.callback = {
      index: requireInteger(callback.index, "Vim callback index"),
      returns: requireInteger(callback.returns, "Vim callback return count"),
      result: callback.result,
      ...(callback.cancel === undefined ? {} : { cancel: callback.cancel }),
      ...(callback.discard === undefined ? {} : { discard: callback.discard }),
      ...(callback.hasErrorReturn === undefined ? {} : { hasErrorReturn: callback.hasErrorReturn }),
      ...(callback.dictionaries === undefined ?
        {}
      : {
          dictionaries: callback.dictionaries.map((index) =>
            requireInteger(index, "Vim callback dictionary index"),
          ),
        }),
    };

    if (callback.resourceIndex !== undefined) {
      metadata.callback.resourceIndex = requireInteger(callback.resourceIndex, "Vim callback resource index");
    }

    if (callback.immediateResult !== undefined) {
      metadata.callback.immediateResult = requireInteger(
        callback.immediateResult,
        "Vim callback immediate result index",
      );
    }

    if (callback.rejectOnFalse !== undefined) {
      metadata.callback.rejectOnFalse = requireString(callback.rejectOnFalse, "Vim callback start failure");
    }

    if (callback.prerequisite !== undefined) {
      const prerequisite = callback.prerequisite;
      if (!isRecord(prerequisite) || !isRecord(prerequisite.options)) {
        throw new Error("Invalid Vim callback prerequisite");
      }

      metadata.callback.prerequisite = {
        path: requireStringArray(prerequisite.path, "Vim callback prerequisite path"),
        options: Object.fromEntries(
          Object.entries(prerequisite.options).map(([key, index]) => [
            key,
            requireInteger(index, "Vim callback prerequisite argument index"),
          ]),
        ),
        message: requireString(prerequisite.message, "Vim callback prerequisite failure"),
      };
    }
  }

  return metadata;
};

export const parseVimNativeClasses = (manifest: unknown) => {
  const nativeClasses = new Map<string, VimNativeClassMetadata>();
  if (!isRecord(manifest) || !isRecord(manifest.nativeClasses)) {
    return nativeClasses;
  }

  for (const [name, value] of Object.entries(manifest.nativeClasses)) {
    if (!isRecord(value) || !isRecord(value.methods) || !isRecord(value.fields)) {
      throw new Error("Invalid Vim native class metadata");
    }

    nativeClasses.set(name, {
      methods: Object.fromEntries(
        Object.entries(value.methods).map(([method, metadata]) => [
          method,
          parseVimFunctionMetadata(metadata),
        ]),
      ),
      fields: Object.fromEntries(
        Object.entries(value.fields).map(([field, descriptor]) => [
          field,
          parseVimValueDescriptor(descriptor),
        ]),
      ),
    });
  }

  return nativeClasses;
};
