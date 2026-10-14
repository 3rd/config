import { Buffer as NeovimBuffer, type NeovimClient } from "neovim";
import type {
  BufferEvent,
  BufferHandler,
  BufferSubscriptionOptions,
  BufferSubscriptionResult,
} from "../types";
import { diagnosticContext, formatPluginError } from "../host/diagnostics";
import { isRecord, requireInteger, requireStringArray } from "../rpc/protocol";
import { createBufferAttachments, requireBuffer, type Subscriber } from "./attachments";

interface SubscriptionOptions {
  options: BufferSubscriptionOptions;
  handler: BufferHandler;
  signal: AbortSignal;
  plugin: string;
}

const parseSnapshot = (value: unknown) => {
  if (!isRecord(value)) {
    throw new Error("Invalid buffer snapshot");
  }

  return {
    type: "snapshot",
    buffer: requireInteger(value.buffer, "buffer"),
    changedtick: requireInteger(value.changedtick, "changedtick"),
    lines: requireStringArray(value.lines, "lines"),
  } satisfies BufferEvent;
};

export const createBufferSubscriptions = (nvim: NeovimClient) => {
  const { attachments, attach } = createBufferAttachments(nvim);
  const drains = new Map<AbortSignal, Set<Promise<void>>>();

  const subscribe = ({ options, handler, signal, plugin }: SubscriptionOptions) => {
    signal.throwIfAborted();
    const bufferId = requireInteger(options.buffer, "buffer");
    if (bufferId < 0) {
      throw new Error("buffer must be nonnegative");
    }

    const maxQueued = requireInteger(options.maxQueued ?? 256, "maxQueued");
    if (maxQueued <= 0) {
      throw new Error("maxQueued must be positive");
    }

    if (typeof handler !== "function") {
      throw new TypeError("Buffer handler must be a function");
    }

    const controller = new AbortController();
    const completion = Promise.withResolvers<BufferSubscriptionResult>();
    const queue: BufferEvent[] = [];
    const identity = { plugin, operation: `buffer:${  bufferId}` };
    let attachment: ReturnType<typeof attach> | undefined;
    let isJoining = true;
    let isStopped = false;
    let running: Promise<void> | undefined;
    let removal: Promise<void> = Promise.resolve();

    const finish = (result: BufferSubscriptionResult) => {
      if (isStopped) return;
      isStopped = true;
      queue.length = 0;
      controller.abort(new Error(`Buffer subscription ${  result.reason}`));
      signal.removeEventListener("abort", disposeOnAbort);
      completion.resolve(result);
      if (attachment) {
        attachment.subscribers.delete(subscriber);
        if (attachment.subscribers.size === 0) {
          removal = attachment.remove();
        }
      }
    };

    const fail = (cause: unknown) => {
      if (isStopped) return;
      const error = cause instanceof Error ? cause : new Error(String(cause));
      console.error(formatPluginError(error, identity));
      finish({ reason: "error", error });
    };

    const deliver = () => {
      if (isJoining || isStopped || running || queue.length === 0) return;
      running = Promise.resolve()
        .then(async () => {
          while (!isStopped && queue.length > 0) {
            const event = queue.shift();
            if (!event) return;

            try {
              await diagnosticContext.run(identity, () => handler(event, { signal: controller.signal }));
            } catch (error) {
              fail(error);
              return;
            }

            if (event.type === "detach") {
              finish({ reason: "detached" });
            }
          }
        })
        .finally(() => {
          running = undefined;
          deliver();
        });
    };

    const subscriber: Subscriber = {
      fail,
      publish(event) {
        if (isStopped) return;
        if (queue.length >= maxQueued) {
          finish({ reason: "overflow" });
          return;
        }

        if (event.type === "snapshot" || event.type === "lines") {
          queue.push({ ...event, lines: [...event.lines] });
        } else {
          queue.push({ ...event });
        }

        deliver();
      },
    };

    const disposeOnAbort = () => finish({ reason: "disposed" });
    signal.addEventListener("abort", disposeOnAbort, { once: true });
    const ready = (async () => {
      let buffer: NeovimBuffer;
      if (bufferId === 0) {
        buffer = requireBuffer(await nvim.request("nvim_get_current_buf"));
      } else {
        buffer = new NeovimBuffer({ client: nvim });
        buffer.data = bufferId;
      }

      controller.signal.throwIfAborted();
      let existing = attachments.get(buffer.id);
      while (existing?.removal) {
        await existing.removal;
        controller.signal.throwIfAborted();
        existing = attachments.get(buffer.id);
      }

      attachment = attachments.get(buffer.id) ?? attach(buffer);
      attachment.subscribers.add(subscriber);
      await attachment.ready;
      controller.signal.throwIfAborted();
      const snapshot = parseSnapshot(
        await nvim.executeLua("return require('bunvim.editor').read(...)", [buffer.id, 0, -1]),
      );
      controller.signal.throwIfAborted();
      if (attachment.isDetached) {
        throw new Error("Buffer detached before subscription became ready");
      }

      const pending = queue.filter(
        (event) => event.type === "detach" || event.changedtick > snapshot.changedtick,
      );
      if (pending.length >= maxQueued) {
        finish({ reason: "overflow" });
        controller.signal.throwIfAborted();
      }

      queue.splice(0, queue.length, snapshot, ...pending);
      isJoining = false;
      deliver();
    })().catch((error: unknown) => {
      fail(error);
      throw error;
    });

    const drained = completion.promise.then(async () => {
      try {
        await ready;
      } catch {
        return;
      } finally {
        await running;
        await removal;
      }
    });
    const owned = drains.get(signal) ?? new Set<Promise<void>>();
    drains.set(signal, owned);
    owned.add(drained);
    drained.then(
      () => {
        owned.delete(drained);
        if (owned.size === 0) {
          drains.delete(signal);
        }
      },
      (error: unknown) => console.error(formatPluginError(error, identity)),
    );

    return {
      ready,
      closed: completion.promise,
      async dispose() {
        finish({ reason: "disposed" });
        await removal;
      },
    };
  };

  const drain = async (signal: AbortSignal) => {
    try {
      await Promise.all(drains.get(signal) ?? []);
    } finally {
      drains.delete(signal);
    }
  };

  return { subscribe, drain };
};

export type BufferSubscriptions = ReturnType<typeof createBufferSubscriptions>;
