import type { VimNativeClassMetadata } from "../../src/vim/metadata";
import { requireString } from "../../src/rpc/protocol";
import {
  compareSignatureSpecificity,
  getLuaSignature,
  hasUnannotatedParameters,
  renderFunctionSignature,
  resolveFunctionSignatures,
} from "./function-signatures";
import { getLuaName, getLuaType, parseLuaDefinitions } from "./luacats";
import { renderNativeClass } from "./native-class";
import {
  createTypeConverter,
  findNativeClassReason,
  getLuaTypeName,
  renderTypeDocumentation,
} from "./type-conversion";
import { CALLBACK_CONTRACTS, correctVimMetadata, NATIVE_CLASSES } from "./vim-contracts";

import {
  collectLuaClasses,
  collectVimDefinitions,
  getFunctionPath,
  parseVimInventory,
} from "./vim-inventory";
import { ensureVimNamespace, renderNamespace, type VimNamespace } from "./vim-namespace";

export const generateVimTypes = (input: unknown, inventory: unknown) => {
  const definitions = parseLuaDefinitions(input);
  correctVimMetadata(definitions);

  const native = parseVimInventory(inventory);
  const { nativePaths, nativeSources, nativeLocations, callableTables } = native;

  const classes = collectLuaClasses(definitions);
  const types = createTypeConverter(classes);
  const { referencedTypes, renderType, renderFields } = types;
  const missingTypes = new Set<string>();
  const root: VimNamespace = { children: new Map(), signatures: [] };
  const functions = new Map<string, ReturnType<typeof renderFunctionSignature>>();
  const callableDefinitions = collectVimDefinitions(definitions, native, classes);

  const commandOptions = renderType({ type: "doc.type.name", value: "vim.api.keyset.cmd" }, new Set());
  const commandArguments = `Omit<${commandOptions}, "cmd">`;
  const commandNamespace: VimNamespace = {
    children: new Map(),
    signatures: [`(command: string | ${commandOptions}) => Promise<string>`],
  };

  for (const value of native.commands) {
    const command = requireString(value, "Vim command");
    commandNamespace.children.set(command, {
      children: new Map(),
      signatures: [
        `(options: ${commandArguments}) => Promise<string>`,
        `(...args: (string | number)[]) => Promise<string>`,
      ],
    });
  }

  root.children.set("cmd", commandNamespace);

  const constants: Record<string, number | string> = {};

  for (const definition of definitions) {
    if (definition.kind !== "constant") continue;

    const path = getFunctionPath(definition);
    if (!path) continue;

    const namespace = ensureVimNamespace(root, path.slice(1));

    for (const [name, value] of Object.entries(definition.constants)) {
      namespace.children.set(name, {
        children: new Map(),
        signatures: [],
        value,
      });
      constants[[...path.slice(1), name].join(".")] = value;
    }
  }

  for (const [name, definition] of callableDefinitions) {
    const path = name.split(".");
    const isNativeCallableSignature =
      callableTables.has(name) && nativeLocations.get(name) === `${definition.path}:${definition.line}`;
    const signature = getLuaSignature(definition, isNativeCallableSignature ? "callable-table" : "ordinary");
    const declaredSignatures = definition.docs
      .filter((doc) => doc.type === "doc.type")
      .flatMap((doc) => resolveFunctionSignatures(doc, classes));

    const signatures = [
      ...(declaredSignatures.length > 0 ? declaredSignatures : [signature]),
      ...definition.docs
        .filter((doc) => doc.type === "doc.overload" && !doc.isIncomplete)
        .map((doc) => {
          if (!doc.overload) {
            throw new Error("Missing overload");
          }

          return {
            args: doc.overload.args ?? [],
            returns: doc.overload.returns ?? [],
            generics: doc.overload.signs ?? [],
          };
        }),
    ].sort(compareSignatureSpecificity);

    const namespace = ensureVimNamespace(root, path.slice(1));
    namespace.documentation = renderTypeDocumentation(
      definition.docs,
      CALLBACK_CONTRACTS.get(name)?.parameter,
    );

    if (name === "vim.cmd") continue;

    const isPrivateFunction = definition.docs.some(
      (doc) => doc.type === "doc.private" || doc.type === "doc.package",
    );
    const renderedSignatures = signatures.map((candidate) => {
      const rendered = renderFunctionSignature({
        signature: candidate,
        name,
        signatures,
        classes,
        types,
      });
      if (candidate === signature && hasUnannotatedParameters(signature, definition.docs)) {
        rendered.unsupported = "Function has no complete exported LuaCATS signature";
      }

      if (isPrivateFunction) {
        rendered.unsupported = "Function is private to its native Lua module";
      }

      return rendered;
    });

    const supportedSignatures = renderedSignatures.filter((item) => !item.unsupported);
    if (supportedSignatures.length === 0) {
      const unsupported = renderedSignatures[0];
      if (!unsupported?.unsupported) {
        throw new Error(`Missing unsupported signature: ${name}`);
      }

      namespace.unsupported = unsupported.unsupported;
      functions.set(name, unsupported);
      continue;
    }

    for (const rendered of supportedSignatures) {
      namespace.signatures.push(rendered.type);
      const previous = functions.get(name);
      if (
        !previous ||
        (rendered.callback && !previous.callback) ||
        rendered.returns === "all" ||
        (typeof rendered.returns === "number" &&
          typeof previous.returns === "number" &&
          rendered.returns > previous.returns &&
          !previous.callback)
      ) {
        functions.set(name, rendered);
      }
    }
  }

  for (const [name, source] of nativeSources) {
    if (functions.has(name) || name === "vim.cmd" || source !== "=[C]") {
      continue;
    }

    const unsupported = "Native function has no exported LuaCATS signature";
    const namespace = ensureVimNamespace(root, name.split(".").slice(1));
    namespace.unsupported = unsupported;
    functions.set(name, { type: "never", returns: 0, unsupported });
  }

  const nativeClasses: Record<string, VimNativeClassMetadata> = {};
  const nativeTypeBodies = new Map<string, string>();

  for (const [name, node] of classes) {
    if (!NATIVE_CLASSES.has(name)) continue;

    referencedTypes.add(name);
    const result = renderNativeClass({
      name,
      node,
      definitions,
      classes,
      types,
    });
    nativeClasses[name] = result.metadata;
    nativeTypeBodies.set(name, result.body);
  }

  const renderedTypes = new Map<string, string>();

  for (const name of referencedTypes) {
    const node = classes.get(name);
    if (!node) {
      missingTypes.add(name);
      renderedTypes.set(name, `type ${getLuaTypeName(name)} = never;`);
      continue;
    }

    const names = (node.signs ?? []).map(getLuaName);
    const generics = new Set(names);
    const parameters =
      names.length > 0 ? `<${names.map((generic) => `${generic} = RpcValue`).join(", ")}>` : "";
    const hasNativeClassState =
      node.type === "doc.class" && findNativeClassReason(node, classes) !== undefined;
    let body: string;
    const nativeBody = nativeTypeBodies.get(name);
    if (nativeBody) {
      body = nativeBody;
    } else if (hasNativeClassState) {
      body = "never";
    } else if (node.type === "doc.alias") {
      body = renderType(getLuaType(node), generics);
    } else {
      const fields = node.fields ?? [];
      const overriddenKeys = fields.flatMap((field) => {
        const key = field.field ?? field.name;
        return key?.type === "doc.field.name" ? [JSON.stringify(getLuaName(key))] : [];
      });
      body = [
        renderFields(fields, generics, node.hasInstanceMethods ? "optional" : "required"),
        ...(Array.isArray(node.extends) ?
          node.extends.map((parent) => {
            const inherited = renderType(parent, generics);
            return overriddenKeys.length > 0 ?
                `Omit<${inherited}, ${overriddenKeys.join(" | ")}>`
              : inherited;
          })
        : []),
      ].join(" & ");
    }

    renderedTypes.set(
      name,
      `${renderTypeDocumentation(node.description ? [{ type: "doc.comment", description: node.description }] : [])}export type ${getLuaTypeName(name)}${parameters} = ${body};`,
    );
  }

  const declarations =
    `import type { RpcValue } from "../../types";\n\n` +
    `import type { NativeReference, NativeIterator, TreeSitterNodeOperations, TreeSitterQueryOperations } from "../native-types";\n\n` +
    `import type { ScopedState } from "../scoped-state";\n\n${[...renderedTypes]
      .sort(([left], [right]) => left.localeCompare(right))
      .map(([_name, declaration]) => declaration)
      .join("\n\n")}\n\nexport type Vim = ${renderNamespace(root)} & ScopedState;\n`;
  const manifest = Object.fromEntries(
    [...functions]
      .sort(([left], [right]) => left.localeCompare(right))
      .map(([name, value]) => [
        name.slice(4),
        {
          returns: value.returns,
          ...(value.unsupported ? { unsupported: value.unsupported } : {}),
          ...(value.callback ? { callback: value.callback } : {}),
          ...(value.resultTypes ? { resultTypes: value.resultTypes } : {}),
        },
      ]),
  );

  if (missingTypes.size > 0) {
    throw new Error(`Unresolved LuaCATS types: ${[...missingTypes].sort().join(", ")}`);
  }

  return {
    declarations,
    manifest: {
      version: native.version,
      functions: manifest,
      constants,
      nativeClasses,
    },
    coverage: {
      supported: [
        ...new Set([
          "vim.cmd",
          ...[...functions].filter(([, value]) => !value.unsupported).map(([name]) => name),
          ...native.commands.map((command) => `vim.cmd.${requireString(command, "Vim command")}`),
        ]),
      ].sort(),
      unsupported: Object.fromEntries(
        [...functions]
          .filter(([, value]) => value.unsupported)
          .map(([name, value]) => [name, value.unsupported])
          .sort(([left], [right]) => (left ?? "").localeCompare(right ?? "")),
      ),
      omitted: [...nativePaths].filter((name) => !functions.has(name) && name !== "vim.cmd").sort(),
    },
  };
};
