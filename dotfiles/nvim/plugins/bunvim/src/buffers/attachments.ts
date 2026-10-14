import { Buffer as NeovimBuffer, type NeovimClient } from "neovim";
import type { BufferEvent } from "../types";
import { requireInteger, requireStringArray } from "../rpc/protocol";

export interface Subscriber {
  publish(event: BufferEvent): void;
  fail(error: unknown): void;
}

interface BufferAttachment {
  subscribers: Set<Subscriber>;
  ready: Promise<void>;
  isDetached: boolean;
  removal?: Promise<void>;
  remove(): Promise<void>;
}

export const requireBuffer = (value: unknown) => {
  if (!(value instanceof NeovimBuffer)) {
    throw new TypeError("Invalid native buffer");
  }

  requireInteger(value.id, "buffer");
  return value;
};

const parseBufferEvent = (event: string, values: unknown[]) => {
  const buffer = requireBuffer(values[0]).id;

  if (event === "detach") {
    return { type: "detach", buffer } satisfies BufferEvent;
  }

  if (values[1] === null) return;

  const changedtick = requireInteger(values[1], "changedtick");

  if (event === "changedtick") {
    return { type: "changedtick", buffer, changedtick } satisfies BufferEvent;
  }

  if (typeof values[5] !== "boolean") {
    throw new TypeError("Invalid buffer multipart flag");
  }

  return {
    type: "lines",
    buffer,
    changedtick,
    firstLine: requireInteger(values[2], "firstLine"),
    lastLine: requireInteger(values[3], "lastLine"),
    lines: requireStringArray(values[4], "lines"),
    hasMore: values[5],
  } satisfies BufferEvent;
};

export const createBufferAttachments = (nvim: NeovimClient) => {
  const attachments = new Map<number, BufferAttachment>();

  const attach = (buffer: NeovimBuffer) => {
    const subscribers = new Set<Subscriber>();
    const listeners = new Map<string, (...values: unknown[]) => void>();

    const removeListeners = () => {
      let shouldDetach = false;

      for (const [event, callback] of listeners) {
        shouldDetach = nvim.detachBuffer(buffer, event, callback);
      }

      return shouldDetach;
    };

    const attachment: BufferAttachment = {
      subscribers,
      isDetached: false,
      ready: Promise.resolve(),
      remove() {
        attachment.removal ??= (async () => {
          try {
            await attachment.ready.then(async () => {
              const shouldDetach = removeListeners() && !attachment.isDetached;
              if (!shouldDetach) return;

              await nvim.request("nvim_buf_detach", [buffer.id]);
            }, removeListeners);
          } finally {
            removeListeners();

            if (attachments.get(buffer.id) === attachment) {
              attachments.delete(buffer.id);
            }
          }
        })();

        return attachment.removal;
      },
    };

    for (const event of ["lines", "changedtick", "detach"]) {
      const callback = (...values: unknown[]) => {
        try {
          const update = parseBufferEvent(event, values);
          if (!update) return;
          if (update.type === "detach") {
            attachment.isDetached = true;

            if (attachments.get(buffer.id) === attachment) {
              attachments.delete(buffer.id);
            }
          }

          for (const subscriber of subscribers) {
            subscriber.publish(update);
          }
        } catch (error) {
          for (const subscriber of subscribers) {
            subscriber.fail(error);
          }
        }
      };

      listeners.set(event, callback);
      nvim.attachBuffer(buffer, event, callback);
    }

    attachment.ready = nvim.request("nvim_buf_attach", [buffer.id, false, {}]).then((isAttached: unknown) => {
      if (isAttached !== true) {
        throw new Error(`Buffer is not loaded: ${  buffer.id}`);
      }
    });
    attachments.set(buffer.id, attachment);
    return attachment;
  };

  return { attachments, attach };
};
