import { expect, test } from "bun:test";
import { Buffer as NeovimBuffer, NeovimClient } from "neovim";
import type { BufferEvent, BufferSnapshot } from "../types";
import { createBufferSubscriptions } from "./subscriptions";

test("snapshot joins discard earlier ticks and preserve later multipart changes", async () => {
  const snapshot = Promise.withResolvers<BufferSnapshot>();
  const snapshotRequested = Promise.withResolvers<void>();
  const nvim = new (class extends NeovimClient {
    request(name: string) {
      if (name !== "nvim_buf_attach" && name !== "nvim_buf_detach") {
        throw new Error(`Unexpected request: ${  name}`);
      }

      return Promise.resolve(true);
    }

    executeLua(code: string) {
      expect(code).toBe("return require('bunvim.editor').read(...)");
      snapshotRequested.resolve();
      return snapshot.promise;
    }
  })();
  const buffer = new NeovimBuffer({ client: nvim });
  buffer.data = 1;
  const owner = new AbortController();
  const hub = createBufferSubscriptions(nvim);
  const events: BufferEvent[] = [];
  const delivered = Promise.withResolvers<void>();
  const subscription = hub.subscribe({
    options: { buffer: buffer.id },
    plugin: "snapshot-join",
    signal: owner.signal,
    handler(event) {
      events.push(event);
      if (event.type === "changedtick") {
        delivered.resolve();
      }
    },
  });
  await snapshotRequested.promise;
  nvim.emitNotification("nvim_buf_lines_event", [buffer, 9, 0, 1, ["old"], false]);
  nvim.emitNotification("nvim_buf_lines_event", [buffer, 10, 0, 1, ["first"], true]);
  nvim.emitNotification("nvim_buf_lines_event", [buffer, 10, 1, 1, ["second"], false]);
  snapshot.resolve({
    buffer: 1,
    changedtick: 10,
    start: 0,
    end: 2,
    lines: ["first", "second"],
  });
  nvim.emitNotification("nvim_buf_lines_event", [buffer, 11, 0, 1, ["after"], true]);
  await subscription.ready;
  nvim.emitNotification("nvim_buf_lines_event", [buffer, null, 0, 1, ["preview"], false]);
  nvim.emitNotification("nvim_buf_lines_event", [buffer, 11, 1, 2, [], false]);
  nvim.emitNotification("nvim_buf_changedtick_event", [buffer, 12]);
  await delivered.promise;
  expect(events).toEqual([
    {
      type: "snapshot",
      buffer: 1,
      changedtick: 10,
      lines: ["first", "second"],
    },
    {
      type: "lines",
      buffer: 1,
      changedtick: 11,
      firstLine: 0,
      lastLine: 1,
      lines: ["after"],
      hasMore: true,
    },
    {
      type: "lines",
      buffer: 1,
      changedtick: 11,
      firstLine: 1,
      lastLine: 2,
      lines: [],
      hasMore: false,
    },
    { type: "changedtick", buffer: 1, changedtick: 12 },
  ]);
  await subscription.dispose();
  await hub.drain(owner.signal);
  expect(await subscription.closed).toEqual({ reason: "disposed" });
});

test("disposal during native attachment waits for removal without delivering a snapshot", async () => {
  const attached = Promise.withResolvers<boolean>();
  const detached = Promise.withResolvers<boolean>();
  const detachRequested = Promise.withResolvers<void>();
  const nvim = new (class extends NeovimClient {
    request(name: string) {
      if (name === "nvim_buf_attach") return attached.promise;
      if (name === "nvim_buf_detach") {
        detachRequested.resolve();
        return detached.promise;
      }

      throw new Error(`Unexpected request: ${  name}`);
    }
  })();
  const owner = new AbortController();
  const hub = createBufferSubscriptions(nvim);
  const events: BufferEvent[] = [];
  const subscription = hub.subscribe({
    options: { buffer: 1 },
    plugin: "attachment-cancel",
    signal: owner.signal,
    handler(event) {
      events.push(event);
    },
  });
  let didDispose = false;
  const disposed = subscription.dispose().then(() => {
    didDispose = true;
  });
  expect(await subscription.closed).toEqual({ reason: "disposed" });
  expect(didDispose).toBe(false);
  attached.resolve(true);
  await detachRequested.promise;
  expect(didDispose).toBe(false);
  detached.resolve(true);
  await disposed;
  await expect(subscription.ready).rejects.toThrow("Buffer subscription disposed");
  await hub.drain(owner.signal);
  expect(events).toEqual([]);
});
