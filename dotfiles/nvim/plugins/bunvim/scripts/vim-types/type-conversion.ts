import type { VimValueDescriptor } from "../../src/vim/metadata";
import {
  getLuaName,
  getLuaTupleFields,
  getLuaType,
  isNullableLuaType,
  isVariadicLuaType,
  type LuaNode,
} from "./luacats";
import { NATIVE_CLASSES } from "./vim-contracts";

type UnsupportedTypeReason = string | undefined;

const LUA_PRIMITIVE_TYPES = new Map([
  ["integer", "number"],
  ["number", "number"],
  ["string", "string"],
  ["BunvimBytes", "Uint8Array"],
  ["boolean", "boolean"],
  ["true", "true"],
  ["false", "false"],
  ["nil", "null"],
  ["vim.NIL", "null"],
  ["any", "RpcValue"],
  ["unknown", "RpcValue"],
  ["Dict", "{ [key: string]: RpcValue }"],
  ["table", "Record<string, RpcValue> | RpcValue[]"],
  ["function", "never"],
  ["thread", "never"],
  ["userdata", "never"],
  ["lightuserdata", "never"],
]);

export const findNativeClassReason = (
  node: LuaNode,
  classes: Map<string, LuaNode>,
  visited = new Set<string>(),
): UnsupportedTypeReason => {
  if (node.type !== "doc.class") return;

  const name = getLuaName(node.class);
  if (visited.has(name)) return;

  visited.add(name);

  if (Array.isArray(node.extends)) {
    for (const parent of node.extends) {
      const parentName = (parent.node ?? parent).value;
      if (typeof parentName !== "string") continue;

      const definition = classes.get(parentName);
      if (!definition) continue;

      const reason = findNativeClassReason(definition, classes, visited);
      if (reason) return reason;
    }
  }

  const hasPrivateState = node.fields?.some(
    (field) => field.visible === "private" || field.visible === "protected",
  );

  if (hasPrivateState) return `${name  } retains native instance state`;
  if (!node.hasInstanceMethods) return;

  const hasClassShape =
    Boolean(node.fields?.length) || (Array.isArray(node.extends) && node.extends.length > 0);
  if (!hasClassShape) return `${name  } requires native object methods`;
};

export const getLuaTypeName = (name: string) => `Lua_${  name.replaceAll(/[^\w$]/g, "_")}`;

export const getTsParameterName = (name: string) =>
  /^(default|function|var|const|let|new|in|delete|package)$/.test(name) ? `${name  }_` : name;

const renderIndex = (key: string, value: string, presence: "optional" | "required" = "required") =>
  key === "string" || key === "number" ?
    `{ [key: ${key}]: ${value} }`
  : `{ [key in Extract<${key}, string | number>]${presence === "optional" ? "?" : ""}: ${value} }`;

export const renderTypeDocumentation = (docs: LuaNode[], callbackName?: string) => {
  const lines = docs.flatMap((doc) => {
    const description =
      doc.description
        ?.split("\n")
        .filter((line) => !/^\s*@(inlinedoc|nodoc)\s*$/.test(line))
        .map((line) => line.replace(/^\s*@brief\s*/, ""))
        .join("\n")
        .replace(/^\n+|\n+$/g, "") ?? "";

    if (doc.type === "doc.comment") {
      return description.startsWith("@overload ") ? [] : [description];
    }

    if (doc.type === "doc.deprecated") return [`@deprecated ${  description}`];

    if (doc.type === "doc.param") {
      const name = getLuaName(doc.param);
      if (name === callbackName) return [`@returns ${  description}`];

      return [`@param ${getTsParameterName(name)} ${description}`];
    }

    if (doc.type === "doc.return" && description && !callbackName) {
      return [`@returns ${  description}`];
    }

    return [];
  });
  if (!lines.some((line) => line.trim())) return "";

  return (
    `/**\n${
    lines
      .join("\n")
      .replaceAll("*/", "*\\/")
      .split("\n")
      .map((line) => ` * ${  line}`)
      .join("\n")
    }\n */\n`
  );
};

export const createTypeConverter = (classes: Map<string, LuaNode>) => {
  const referencedTypes = new Set<string>();

  const findUnsupportedType = (
    node: LuaNode,
    generics = new Set<string>(),
    visited = new Set<string>(),
  ): UnsupportedTypeReason => {
    if (node.type === "doc.type.function") return "Lua function";

    if (["doc.extends.name", "doc.generic.name", "doc.type.name"].includes(node.type)) {
      const name = getLuaName(node).replace(/\.{3}$/, "");
      if (generics.has(name) || visited.has(name)) return;
      if (NATIVE_CLASSES.has(name)) return;

      const primitive = LUA_PRIMITIVE_TYPES.get(name);
      if (primitive === "never") return name;
      if (primitive !== undefined) return;

      const definition = classes.get(name);
      if (!definition) return;

      visited.add(name);
      const nativeReason = findNativeClassReason(definition, classes);
      if (nativeReason) return nativeReason;

      const unsupported = findUnsupportedType(definition, generics, visited);
      return unsupported ? `${name  }: ${  unsupported}` : undefined;
    }

    const extensions: LuaNode[] = [];
    if (Array.isArray(node.extends)) {
      extensions.push(...node.extends);
    } else if (node.extends) {
      extensions.push(node.extends);
    }

    const children = [
      ...(node.types ?? []),
      ...(node.fields ?? [])
        .filter((field) => !field.optional && !isNullableLuaType(getLuaType(field)))
        .map(getLuaType),
      ...(node.signs ?? []),
      ...(node.node ? [node.node] : []),
      ...extensions,
    ];

    for (const child of children) {
      const unsupported = findUnsupportedType(child, generics, new Set(visited));
      if (unsupported) return unsupported;
    }
  };

  const findUnsupportedArgument = (
    node: LuaNode,
    generics: Set<string>,
    visited = new Set<string>(),
  ): UnsupportedTypeReason => {
    if (node.type === "doc.type.function") return "Lua function";

    if (node.type === "doc.type") {
      const reasons = (node.types ?? []).map((member) =>
        findUnsupportedArgument(member, generics, new Set(visited)),
      );
      return reasons.length > 0 && reasons.every(Boolean) ? reasons[0] : undefined;
    }

    if (!["doc.extends.name", "doc.generic.name", "doc.type.name", "doc.type.sign"].includes(node.type)) {
      return;
    }

    const name = getLuaName(node.node ?? node);
    if (generics.has(name) || visited.has(name)) return;
    if (NATIVE_CLASSES.has(name)) return;
    if (LUA_PRIMITIVE_TYPES.get(name) === "never") return name;

    const definition = classes.get(name);
    if (!definition) return;

    visited.add(name);
    const nativeReason = findNativeClassReason(definition, classes);
    if (nativeReason) return nativeReason;

    if (definition.type === "doc.alias") {
      return findUnsupportedArgument(getLuaType(definition), generics, visited);
    }

    if (Array.isArray(definition.extends)) {
      return definition.extends
        .map((parent) => findUnsupportedArgument(parent, generics, new Set(visited)))
        .find(Boolean);
    }
  };

  const getValueDescriptor = (
    node: LuaNode,
    visited = new Set<string>(),
    mode: "native" | "ordinary" = "ordinary",
  ): VimValueDescriptor => {
    if (node.type === "doc.type") {
      const members = (node.types ?? []).filter(
        (member) => member.type !== "doc.type.name" || member.value !== "nil",
      );
      const memberMode = members.length > 1 ? "ordinary" : mode;
      const descriptor_ = members
        .map((member) => getValueDescriptor(member, new Set(visited), memberMode))
        .find((descriptor) => descriptor !== null);
      return descriptor_ ?? null;
    }

    if (node.type === "doc.type.array" && node.node) {
      const item = getValueDescriptor(node.node, visited, mode);
      return item === null ? null : { array: item };
    }

    if (node.type === "doc.type.sign" && node.node?.value === "table") {
      const item = node.signs?.[1];
      const descriptor = item ? getValueDescriptor(item, visited, mode) : null;
      return descriptor === null && mode === "ordinary" ? null : { dictionary: descriptor };
    }

    const tupleFields =
      node.type === "doc.type.table" && node.isTuple ?
        (node.fields ?? [])
      : getLuaTupleFields(node.fields ?? []);
    if (tupleFields) {
      const tuple = tupleFields.map((field) => getValueDescriptor(getLuaType(field), new Set(visited), mode));
      return tuple.some((descriptor) => descriptor !== null) ? { tuple } : null;
    }

    if (["doc.extends.name", "doc.generic.name", "doc.type.name"].includes(node.type)) {
      const name = getLuaName(node);
      if (name === "BunvimBytes") return "bytes";
      if (NATIVE_CLASSES.has(name)) return { native: name };
      if (visited.has(name)) return null;

      const definition = classes.get(name);
      if (!definition) return null;

      visited.add(name);
      return definition.type === "doc.alias" ?
          getValueDescriptor(getLuaType(definition), visited, mode)
        : getValueDescriptor(definition, visited, mode);
    }

    const index = (node.fields ?? []).find((field) => (field.field ?? field.name)?.type !== "doc.field.name");
    if (index && mode === "native") {
      return {
        dictionary: getValueDescriptor(getLuaType(index), new Set(visited), mode),
      };
    }

    const fields: Record<string, VimValueDescriptor> = {};

    for (const field of node.fields ?? []) {
      const key = field.field ?? field.name;
      if (key?.type !== "doc.field.name" || field.visible === "private" || field.visible === "protected") {
        continue;
      }

      const descriptor = getValueDescriptor(getLuaType(field), new Set(visited), mode);
      if (descriptor !== null) {
        fields[getLuaName(key)] = descriptor;
      }
    }

    return Object.keys(fields).length > 0 ? { fields } : null;
  };

  const renderType = (node: LuaNode, generics: Set<string>): string => {
    const render = (value: LuaNode) => renderType(value, generics);
    let result: string;

    switch (node.type) {
      case "doc.type": {
        result = [...new Set((node.types ?? []).map(render))].join(" | ") || "never";
        break;
      }
      case "doc.type.intersection": {
        result = (node.types ?? []).map((member) => `(${render(member)})`).join(" & ");
        break;
      }
      case "doc.type.keyof": {
        if (!node.node) {
          throw new Error("Missing keyof target");
        }

        result = `keyof ${render(node.node)}`;
        break;
      }
      case "doc.type.array": {
        if (!node.node) {
          throw new Error("Missing array element");
        }

        result = `(${render(node.node)})[]`;
        break;
      }
      case "doc.type.string":
      case "doc.type.integer":
      case "doc.type.boolean": {
        result = JSON.stringify(node.value);
        break;
      }
      case "doc.type.function": {
        result = "never";
        break;
      }
      case "doc.type.mapped": {
        const key = getLuaName(node.name);
        const base = getLuaName(node.node);
        result = `{ [${key} in keyof ${base}]?: ${base}[${key}] | null }`;
        break;
      }
      case "doc.type.table": {
        const fields = node.fields ?? [];
        result =
          node.isTuple ?
            `[${fields.map((field) => `(${render(getLuaType(field))})${field.optional ? "?" : ""}`).join(", ")}]`
          : renderFields(fields, generics);
        break;
      }
      case "doc.type.sign": {
        const name = getLuaName(node.node);
        const values = (node.signs ?? []).map(render);
        if (name === "table") {
          result = renderIndex(values[0] ?? "string", values[1] ?? "RpcValue");
        } else {
          referencedTypes.add(name);
          result = `${getLuaTypeName(name)}<${values.join(", ")}>`;
        }

        break;
      }
      case "doc.type.name":
      case "doc.extends.name":
      case "doc.generic.name": {
        const originalName = getLuaName(node);
        const name = originalName.replace(/\.{3}$/, "");
        const primitive = LUA_PRIMITIVE_TYPES.get(name);
        if (generics.has(name)) {
          result = name;
        } else if (primitive !== undefined) {
          result = primitive;
        } else {
          referencedTypes.add(name);
          result = getLuaTypeName(name);
        }

        if (originalName.endsWith("...") && !generics.has(name)) {
          result = `(${result})[]`;
        }

        break;
      }
      default: {
        throw new Error(`Unsupported LuaCATS type: ${  node.type}`);
      }
    }

    if (node.optional) {
      result = `(${result}) | null`;
    }

    const hasRepeatedScalar =
      node.name?.value === "..." &&
      node.types?.every(
        (type) =>
          type.type === "doc.type.name" && !generics.has(getLuaName(type)) && !isVariadicLuaType(type),
      );
    return hasRepeatedScalar ? `(${result})[]` : result;
  };

  const renderFields = (
    fields: LuaNode[],
    generics: Set<string>,
    indexPresence: "optional" | "required" = "required",
  ): string => {
    const tupleFields = getLuaTupleFields(fields);
    if (tupleFields) {
      const entries = tupleFields.map((field, index) => {
        const canOmit =
          (field.optional || isNullableLuaType(getLuaType(field))) &&
          tupleFields
            .slice(index + 1)
            .every((following) => following.optional || isNullableLuaType(getLuaType(following)));
        const documentation = renderTypeDocumentation(
          field.description ? [{ type: "doc.comment", description: field.description }] : [],
        );
        return `${documentation}(${renderType(getLuaType(field), generics)})${canOmit ? "?" : ""}`;
      });
      return `[\n${entries.join(",\n")}\n]`;
    }

    const properties = new Map<string, string>();
    const indexes = [];

    for (const field of fields) {
      if (field.visible === "private" || field.visible === "protected") {
        continue;
      }

      const key = field.field ?? field.name;
      if (!key) {
        throw new Error("Missing field name");
      }

      const value = field.isIncomplete ? "never" : renderType(getLuaType(field), generics);

      if (key.type === "doc.field.name") {
        properties.set(
          getLuaName(key),
          `${renderTypeDocumentation(field.description ? [{ type: "doc.comment", description: field.description }] : [])}${JSON.stringify(getLuaName(key))}${field.optional || isNullableLuaType(getLuaType(field)) ? "?" : ""}: ${value};`,
        );
      } else {
        const index = renderType(key, generics);
        indexes.push(renderIndex(index, value, indexPresence));
      }
    }

    const object = properties.size > 0 ? `{\n${[...properties.values()].join("\n")}\n}` : "{}";
    return [object, ...indexes].join(" & ");
  };

  return {
    referencedTypes,
    findUnsupportedType,
    findUnsupportedArgument,
    getValueDescriptor,
    renderType,
    renderFields,
  };
};
