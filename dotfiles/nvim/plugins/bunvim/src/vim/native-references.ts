import type { VimFunctionMetadata, VimNativeClassMetadata } from "./metadata";
import type { NativeBatch, NativeBatchOptions } from "./native-types";
import { isRecord } from "../rpc/protocol";
import { decodeRpcValue, encodeRpcValue, RpcEncodingError, type RpcReference } from "../rpc/value-codec";

export interface NativeMethodTarget {
  reference: RpcReference;
  method: string;
}

interface NativeReferencesOptions {
  owner: string;
  scope: string;
  signal: AbortSignal;
  nativeClasses: ReadonlyMap<string, VimNativeClassMetadata>;
  callNative(operation: string, args: unknown[]): Promise<unknown>;
  callFunction(target: NativeMethodTarget, args: unknown[], metadata: VimFunctionMetadata): Promise<unknown>;
  disposeReference(reference: RpcReference): Promise<void>;
}

interface NativeHandleState {
  owner: string;
  reference: RpcReference;
  signal: AbortSignal;
  isDisposed: boolean;
}

class NativeHandle {
  constructor(readonly state: NativeHandleState) {}
}

const isNativeBatch = (value: unknown): value is NativeBatch<unknown> =>
  isRecord(value) && Array.isArray(value.items) && typeof value.isDone === "boolean";

export const createNativeReferences = ({
  owner,
  scope,
  signal,
  nativeClasses,
  callNative,
  callFunction,
  disposeReference,
}: NativeReferencesOptions) => {
  const handles = new Set<NativeHandle>();

  const encodeValue = (value: unknown) => {
    try {
      return encodeRpcValue(value, {
        undefinedValues: "normalize",
        encodeReference(item) {
          if (!(item instanceof NativeHandle)) return undefined;
          if (item.state.owner !== owner) {
            throw new Error("Native reference belongs to another plugin");
          }

          item.state.signal.throwIfAborted();
          if (item.state.isDisposed) {
            throw new Error("Native reference is disposed");
          }

          return item.state.reference;
        },
      });
    } catch (error) {
      if (error instanceof RpcEncodingError) {
        throw new TypeError("Vim arguments must be RPC values");
      }

      throw error;
    }
  };

  const createNativeProxy = (reference: RpcReference) => {
    if (reference.scope !== scope) {
      throw new Error("Native reference scope mismatch");
    }

    const metadata = nativeClasses.get(reference.type);
    const isUnknownReference = reference.type !== "iterator" && !metadata;
    if (isUnknownReference) {
      throw new Error(`Unknown native reference type: ${  reference.type}`);
    }

    const handle = new NativeHandle({
      owner,
      reference,
      signal,
      isDisposed: false,
    });
    handles.add(handle);

    let disposal: Promise<void> | undefined;
    const dispose = () => {
      disposal ??= (async () => {
        handle.state.isDisposed = true;
        handles.delete(handle);
        await disposeReference(reference);
      })();
      return disposal;
    };

    const checkActive = () => {
      signal.throwIfAborted();

      if (handle.state.isDisposed) {
        throw new Error("Native reference is disposed");
      }
    };

    const nextBatch = async (options: NativeBatchOptions = {}) => {
      checkActive();
      const value = await callNative("next_batch", [reference, options]);
      if (!isNativeBatch(value)) {
        throw new Error("Invalid native iterator batch");
      }

      return { items: value.items, isDone: value.isDone };
    };

    const iterate = async function* () {
      try {
        let isDone = false;

        while (!isDone) {
          const batch = await nextBatch();
          isDone = batch.isDone;
          yield* batch.items;
        }
      } finally {
        await dispose();
      }
    };

    return new Proxy(handle, {
      get(target, key) {
        if (key === "state") return target.state;
        if (key === "dispose") return dispose;
        if (key === "then") return undefined;
        if (reference.type === "iterator") {
          if (key === "nextBatch") return nextBatch;
          if (key === Symbol.asyncIterator) return iterate;
          return undefined;
        }

        if (key === "get") {
          return (field: string) => {
            checkActive();

            const canReadField = metadata !== undefined && Object.hasOwn(metadata.fields, field);
            if (!canReadField) {
              throw new Error(`Unknown native field: ${  reference.type  }.${  field}`);
            }

            return callNative("get_field", [reference, field, metadata.fields[field]]);
          };
        }

        const isNodeWalk = reference.type === "TSNode" && key === "walk";
        if (isNodeWalk) {
          return (options: unknown) => {
            checkActive();
            return callNative("start_walk", [reference, options]);
          };
        }

        const isCaptureSnapshot = reference.type === "vim.treesitter.Query" && key === "captureSnapshots";
        if (isCaptureSnapshot) {
          return (...args: unknown[]) => {
            checkActive();
            return callNative("start_captures", [reference, encodeValue(args)]);
          };
        }

        if (typeof key !== "string") return undefined;

        const method = metadata?.methods[key];
        if (!method) return undefined;

        return (...args: unknown[]) => {
          checkActive();
          return callFunction({ reference, method: key }, args, method);
        };
      },
    });
  };

  const decodeValue = (value: unknown) => decodeRpcValue(value, { decodeReference: createNativeProxy });

  const invalidate = () => {
    for (const handle of handles) {
      handle.state.isDisposed = true;
    }

    handles.clear();
  };

  return { encodeValue, decodeValue, invalidate };
};
