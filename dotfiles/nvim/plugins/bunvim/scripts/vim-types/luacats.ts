import { isRecord, requireInteger, requireString } from "../../src/rpc/protocol";

export type LuaNode = {
  type: string;
  value?: boolean | number | string;
  optional?: boolean;
  isTuple?: boolean;
  visible?: string;
  description?: string;
  hasInstanceMethods?: boolean;
  isIncomplete?: boolean;
  extends?: LuaNode | LuaNode[];
  types?: LuaNode[];
  fields?: LuaNode[];
  args?: LuaNode[];
  returns?: LuaNode[];
  node?: LuaNode;
  signs?: LuaNode[];
  name?: LuaNode;
  param?: LuaNode;
  field?: LuaNode;
  alias?: LuaNode;
  class?: LuaNode;
  overload?: LuaNode;
  generics?: LuaNode[];
  generic?: LuaNode;
  vararg?: LuaNode;
  items?: LuaNode[];
};

export type LuaDefinition = {
  kind: string;
  path: string;
  names: string[];
  ownerClass?: string;
  docs: LuaNode[];
  args?: LuaNode;
  value?: LuaNode;
  line: number;
  constants: Record<string, number | string>;
};

export type FunctionSignature = {
  args: LuaNode[];
  returns: LuaNode[];
  generics: LuaNode[];
};

const parseNode = (value: unknown): LuaNode => {
  if (!isRecord(value)) {
    throw new Error("Invalid LuaCATS node");
  }

  const type = requireString(value.type, "LuaCATS node type");
  const result: LuaNode = { type };
  if (
    typeof value.value === "string" ||
    typeof value.value === "number" ||
    typeof value.value === "boolean"
  ) {
    result.value = value.value;
  }

  for (const key of ["optional", "isTuple", "hasInstanceMethods", "isIncomplete"] as const) {
    if (value[key] !== undefined) {
      if (typeof value[key] !== "boolean") {
        throw new TypeError(`Invalid LuaCATS flag: ${  key}`);
      }

      result[key] = value[key];
    }
  }

  if (value.visible !== undefined) {
    result.visible = requireString(value.visible, "LuaCATS visibility");
  }

  if (value.description !== undefined) {
    result.description = requireString(value.description, "LuaCATS description");
  }

  for (const key of ["types", "fields", "args", "returns", "signs", "generics", "items"] as const) {
    if (value[key] !== undefined) {
      result[key] = parseNodes(value[key]);
    }
  }

  for (const key of [
    "node",
    "name",
    "param",
    "field",
    "alias",
    "class",
    "overload",
    "generic",
    "vararg",
  ] as const) {
    if (value[key] !== undefined) {
      result[key] = parseNode(value[key]);
    }
  }

  if (value.extends !== undefined) {
    result.extends = Array.isArray(value.extends) ? parseNodes(value.extends) : parseNode(value.extends);
  }

  return result;
};

const parseNodes = (value: unknown) => {
  if (!Array.isArray(value)) {
    throw new TypeError("Invalid LuaCATS node list");
  }

  return value.map(parseNode);
};

export const parseLuaDefinitions = (value: unknown) => {
  if (!Array.isArray(value)) {
    throw new TypeError("Invalid LuaCATS definitions");
  }

  return value.map((item: unknown): LuaDefinition => {
    if (!isRecord(item)) {
      throw new Error("Invalid LuaCATS definition");
    }

    const constants: Record<string, number | string> = {};
    if (item.constants !== undefined) {
      if (!isRecord(item.constants)) {
        throw new Error("Invalid LuaCATS constants");
      }

      for (const [name, value] of Object.entries(item.constants)) {
        if (typeof value !== "string" && typeof value !== "number") {
          throw new TypeError(`Invalid LuaCATS constant: ${  name}`);
        }

        constants[name] = value;
      }
    }

    return {
      kind: requireString(item.kind, "LuaCATS definition kind"),
      path: requireString(item.path, "LuaCATS source path"),
      line: requireInteger(item.line, "LuaCATS source line"),
      constants,
      names: Array.isArray(item.names) ? item.names.map((name) => requireString(name, "LuaCATS name")) : [],
      docs: item.docs === undefined ? [] : parseNodes(item.docs),
      ownerClass:
        item.ownerClass === undefined ? undefined : requireString(item.ownerClass, "LuaCATS owning class"),
      args: item.args === undefined ? undefined : parseNode(item.args),
      value: item.value === undefined ? undefined : parseNode(item.value),
    };
  });
};

export const getLuaName = (node: LuaNode | undefined) => {
  if (typeof node?.value !== "string") {
    throw new TypeError(`Missing LuaCATS name: ${  JSON.stringify(node)}`);
  }

  return node.value;
};

export const getLuaType = (node: LuaNode) => {
  if (Array.isArray(node.extends) || !node.extends) {
    throw new Error(`Missing LuaCATS type: ${  node.type}`);
  }

  return node.extends;
};

export const getLuaTupleFields = (fields: LuaNode[]) => {
  const indexedFields = fields
    .filter((field) => field.visible !== "private" && field.visible !== "protected")
    .map((field) => {
      const key = field.field ?? field.name;
      const literal = key?.type === "doc.type" && key.types?.length === 1 ? key.types[0] : key;
      return {
        field,
        index: literal?.type === "doc.type.integer" ? literal.value : undefined,
      };
    });
  if (
    indexedFields.length === 0 ||
    indexedFields.some(({ index }) => typeof index !== "number" || !Number.isInteger(index) || index < 1)
  ) {
    return;
  }

  indexedFields.sort((left, right) => Number(left.index) - Number(right.index));

  if (indexedFields.every(({ index }, position) => index === position + 1)) {
    return indexedFields.map(({ field }) => field);
  }
};

export const isNullableLuaType = (node: LuaNode): boolean =>
  Boolean(node.optional) ||
  node.value === "nil" ||
  node.value === "vim.NIL" ||
  (node.type === "doc.type" && Boolean(node.types?.some(isNullableLuaType)));

export const isVariadicLuaType = (node: LuaNode): boolean =>
  node.name?.value === "..." ||
  (typeof node.value === "string" && node.value.endsWith("...")) ||
  (node.type === "doc.type" && Boolean(node.types?.some(isVariadicLuaType)));
