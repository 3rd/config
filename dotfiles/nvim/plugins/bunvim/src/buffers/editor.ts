import type { BufferSnapshot, InvocationContext } from "../types";
import { isRecord, requireInteger, requireStringArray } from "../rpc/protocol";

export const readBuffer = async (
  context: InvocationContext,
  options: { start?: number; end?: number } = {},
) => {
  context.signal.throwIfAborted();
  const value: unknown = await context.nvim.executeLua("return require('bunvim.editor').read(...)", [
    context.buffer,
    options.start ?? 0,
    options.end ?? -1,
  ]);
  if (!isRecord(value)) {
    throw new Error("Invalid buffer snapshot");
  }

  return {
    buffer: requireInteger(value.buffer, "buffer"),
    changedtick: requireInteger(value.changedtick, "changedtick"),
    start: requireInteger(value.start, "start"),
    end: requireInteger(value.end, "end"),
    lines: requireStringArray(value.lines, "lines"),
  } satisfies BufferSnapshot;
};

export const replaceBuffer = async (
  context: InvocationContext,
  snapshot: BufferSnapshot,
  lines: string[],
) => {
  context.signal.throwIfAborted();
  await context.nvim.executeLua("return require('bunvim.editor').replace(...)", [snapshot, lines]);
};
