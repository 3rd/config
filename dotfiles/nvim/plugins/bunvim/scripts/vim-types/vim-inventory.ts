import { isRecord, isRpcValue, requireString } from "../../src/rpc/protocol";
import { getLuaSignature, hasUnannotatedParameters, resolveFunctionSignatures } from "./function-signatures";
import { getLuaName, type LuaDefinition, type LuaNode, parseLuaDefinitions } from "./luacats";

export const getFunctionPath = (definition: LuaDefinition) => {
  let names = definition.names;
  if (names[0] !== "vim") {
    const module = definition.path
      .replace(/\.lua$/, "")
      .replace(/\/init$/, "")
      .split("/");
    if (names[0] !== "M" && names[0] !== module.at(-1)) return;

    names = [...module, ...names.slice(1)];
  }

  if (names.some((name) => name.startsWith("_"))) return;

  return names;
};

export const parseVimInventory = (inventory: unknown) => {
  const nativePaths = new Set<string>();
  const nativeOrigins = new Map<string, string[][]>();
  const nativeSources = new Map<string, string>();
  const nativeLocations = new Map<string, string>();
  const callableTables = new Set<string>();

  if (
    !isRecord(inventory) ||
    !Array.isArray(inventory.functions) ||
    !Array.isArray(inventory.commands) ||
    !isRpcValue(inventory.version)
  ) {
    throw new Error("Invalid Vim function inventory");
  }

  for (const fn of inventory.functions) {
    if (!isRecord(fn) || !Array.isArray(fn.path) || typeof fn.line !== "number") {
      throw new Error("Invalid Vim function origin");
    }

    const path = fn.path.map((part) => requireString(part, "Vim path"));
    nativePaths.add(path.join("."));

    if (fn.isCallableTable === true) {
      callableTables.add(path.join("."));
    }

    const source = requireString(fn.source, "Vim source");
    nativeSources.set(path.join("."), source);
    const origin = `${source  }:${  fn.line}`;
    nativeLocations.set(path.join("."), origin);
    nativeOrigins.set(origin, [...(nativeOrigins.get(origin) ?? []), path]);
  }

  return {
    nativePaths,
    nativeOrigins,
    nativeSources,
    nativeLocations,
    callableTables,
    commands: inventory.commands,
    version: inventory.version,
  };
};

export const collectLuaClasses = (definitions: LuaDefinition[]) => {
  const classes = new Map<string, LuaNode>();

  for (const definition of definitions) {
    const node = definition.value;
    if (!node) continue;

    const name = getLuaName(node.class ?? node.alias);
    const previous = classes.get(name);
    if (previous?.type === "doc.class" && node.type === "doc.class") {
      classes.set(name, {
        ...node,
        fields: [...(previous.fields ?? []), ...(node.fields ?? [])],
        hasInstanceMethods: previous.hasInstanceMethods || node.hasInstanceMethods,
        description: node.description ?? previous.description,
      });
    } else {
      classes.set(name, node);
    }
  }

  return classes;
};

export const collectVimDefinitions = (
  definitions: LuaDefinition[],
  native: ReturnType<typeof parseVimInventory>,
  classes: Map<string, LuaNode>,
) => {
  const { nativeOrigins, nativePaths, nativeLocations, callableTables } = native;
  const callableDefinitions = new Map<string, LuaDefinition>();

  for (const definition of definitions) {
    const isTypedAlias =
      definition.kind === "alias" &&
      definition.docs.some((doc) => resolveFunctionSignatures(doc, classes).length > 0);
    if (definition.kind !== "function" && !isTypedAlias) continue;

    const path = getFunctionPath(definition);
    const paths = [...(nativeOrigins.get(`${definition.path  }:${  definition.line}`) ?? [])];
    if (path && nativePaths.has(path.join("."))) {
      paths.push(path);
    }

    for (const candidate of paths) {
      const name = candidate.join(".");
      if (isTypedAlias && callableTables.has(name)) continue;

      const previous = callableDefinitions.get(name);
      const hasMetadataSource = previous?.path.includes("/_meta/");
      const hasPreviousSignature =
        previous &&
        (!hasUnannotatedParameters(
          getLuaSignature(
            previous,
            callableTables.has(name) && nativeLocations.get(name) === `${previous.path  }:${  previous.line}` ?
              "callable-table"
            : "ordinary",
          ),
          previous.docs,
        ) ||
          previous.docs.some((doc) => resolveFunctionSignatures(doc, classes).length > 0));
      if (
        !previous ||
        (!hasMetadataSource &&
          (definition.path.includes("/_meta/") ||
            (!hasPreviousSignature &&
              (isTypedAlias || !hasUnannotatedParameters(getLuaSignature(definition), definition.docs)))))
      ) {
        callableDefinitions.set(name, definition);
      }
    }
  }

  return callableDefinitions;
};

export const getVimCandidates = (input: unknown) =>
  parseLuaDefinitions(input)
    .filter((definition) => definition.kind === "function" || definition.kind === "alias")
    .flatMap((definition) => {
      const path = getFunctionPath(definition);
      return path ? [path] : [];
    });
