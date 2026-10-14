import type { InvocationContext } from "bunvim";
import { parseSchedule } from "./schedule";

const SCHEDULE_PREFIX = "Schedule: ";

const isRecord = (value: unknown): value is Record<string, unknown> => {
  return typeof value === "object" && value !== null && !Array.isArray(value);
};

const requireInteger = (value: unknown, name: string) => {
  const isInteger = typeof value === "number" && Number.isSafeInteger(value);
  if (!isInteger) {
    throw new TypeError(`${name} must be an integer`);
  }

  return value;
};

const requireString = (value: unknown, name: string) => {
  if (typeof value !== "string") {
    throw new TypeError(`${name} must be a string`);
  }

  return value;
};

const parsePosition = (value: unknown) => {
  if (!isRecord(value)) {
    throw new Error("Invalid schedule position");
  }

  return {
    line: requireInteger(value.line, "Schedule line"),
    character: requireInteger(value.character, "Schedule column"),
  };
};

const parseRange = (value: unknown) => {
  if (!isRecord(value)) {
    throw new Error("Invalid schedule range");
  }

  return { start: parsePosition(value.start), end: parsePosition(value.end) };
};

const parseContext = (value: unknown) => {
  if (
    !isRecord(value) ||
    !Array.isArray(value.position) ||
    value.position.length !== 2 ||
    !Array.isArray(value.ancestors)
  ) {
    throw new Error("Invalid schedule target");
  }

  return {
    buffer: requireInteger(value.buffer, "Schedule buffer"),
    window: requireInteger(value.window, "Schedule window"),
    changedtick: requireInteger(value.changedtick, "Schedule changedtick"),
    filetype: requireString(value.filetype, "Schedule filetype"),
    position: [
      requireInteger(value.position[0], "Schedule cursor row"),
      requireInteger(value.position[1], "Schedule cursor column"),
    ] satisfies [number, number],
    shiftwidth: requireInteger(value.shiftwidth, "Schedule shiftwidth"),
    ancestors: value.ancestors.map((item: unknown) => {
      if (!isRecord(item) || typeof item.is_task !== "boolean" || !Array.isArray(item.children)) {
        throw new Error("Invalid schedule node");
      }

      return {
        kind: requireString(item.kind, "Schedule node kind"),
        isTask: item.is_task,
        range: parseRange(item.range),
        children: item.children.map((child: unknown) => {
          if (!isRecord(child)) {
            throw new Error("Invalid schedule child");
          }

          return {
            kind: requireString(child.kind, "Schedule child kind"),
            range: parseRange(child.range),
            indent: requireInteger(child.indent, "Schedule indentation"),
          };
        }),
      };
    }),
  };
};

const createScheduleEdits = (target: ReturnType<typeof parseContext>, date: string) => {
  const edits = [];

  for (const node of target.ancestors) {
    if (node.range.start.line !== target.position[0] - 1) {
      break;
    }

    if (node.kind === "task_schedule") {
      edits.push({ range: node.range, newText: `${SCHEDULE_PREFIX + date  }\n` });
    }

    if (node.isTask) {
      const marker = node.children[0];
      if (!marker) {
        throw new Error("Schedule task has no marker");
      }

      let lastPreNode = marker;

      for (const child of node.children) {
        if (child.range.start.line === node.range.start.line) continue;

        if (child.kind !== "task_schedule" && child.kind !== "task_session") {
          break;
        }

        lastPreNode = child;
      }

      const line = lastPreNode.range.start.line + 1;
      const indent = lastPreNode.indent + (lastPreNode === marker ? target.shiftwidth : 0);
      edits.push({
        range: { start: { line, character: 0 }, end: { line, character: 0 } },
        newText: `${" ".repeat(indent) + SCHEDULE_PREFIX + date  }\n`,
      });
    }
  }

  return edits;
};

export const setSchedule = async (context: InvocationContext) => {
  const { vim } = context;
  const target = parseContext(
    await context.nvim.executeLua("return require('syslang').get_schedule_context()", []),
  );
  if (target.buffer !== context.buffer || target.window !== context.window) {
    return;
  }

  if (target.filetype !== "syslang") return;

  const input = await vim.ui.input({ prompt: SCHEDULE_PREFIX });
  if (input === null || input === "") return;

  const date = parseSchedule(input);
  if (date === null) return;

  const edits = createScheduleEdits(target, date);

  context.signal.throwIfAborted();
  await context.nvim.executeLua("return require('bunvim.editor').apply_text_edits(...)", [
    {
      buffer: target.buffer,
      window: target.window,
      changedtick: target.changedtick,
      position: target.position,
      filetype: target.filetype,
    },
    edits,
  ]);
};
