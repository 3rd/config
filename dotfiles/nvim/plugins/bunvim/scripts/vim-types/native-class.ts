import type { VimNativeClassMetadata } from "../../src/vim/metadata";
import {
  compareSignatureSpecificity,
  getLuaSignature,
  hasUnannotatedParameters,
  renderFunctionSignature,
  resolveFunctionSignatures,
} from "./function-signatures";
import { type FunctionSignature, getLuaType, type LuaDefinition, type LuaNode } from "./luacats";
import { type createTypeConverter, renderTypeDocumentation } from "./type-conversion";
import { CALLBACK_CONTRACTS } from "./vim-contracts";

interface NativeClassOptions {
  name: string;
  node: LuaNode;
  definitions: LuaDefinition[];
  classes: Map<string, LuaNode>;
  types: ReturnType<typeof createTypeConverter>;
}

export const renderNativeClass = ({ name, node, definitions, classes, types }: NativeClassOptions) => {
  const { findUnsupportedType, getValueDescriptor, renderFields } = types;
  const metadata: VimNativeClassMetadata = { methods: {}, fields: {} };
  const methods = new Map<string, FunctionSignature[]>();
  const methodDocs = new Map<string, LuaNode[]>();
  const publicFields: LuaNode[] = [];

  for (const field of node.fields ?? []) {
    const fieldName = field.field?.value;
    if (
      typeof fieldName !== "string" ||
      fieldName.startsWith("_") ||
      field.visible === "private" ||
      field.visible === "protected" ||
      field.visible === "package"
    ) {
      continue;
    }

    const signatures = resolveFunctionSignatures(getLuaType(field), classes);
    if (signatures.length > 0) {
      const instanceSignatures = signatures.filter((signature) => signature.args[0]?.name?.value === "self");
      if (instanceSignatures.length > 0) {
        methods.set(fieldName, instanceSignatures);
      }
    } else if (!findUnsupportedType(getLuaType(field))) {
      publicFields.push(field);
      metadata.fields[fieldName] = getValueDescriptor(getLuaType(field), new Set(), "native");
    }
  }

  for (const definition of definitions) {
    if (definition.ownerClass !== name) continue;

    const method = definition.names.at(-1);
    if (
      !method ||
      method.startsWith("_") ||
      definition.docs.some((doc) => doc.type === "doc.private" || doc.type === "doc.package")
    ) {
      continue;
    }

    const signature = getLuaSignature(definition);
    if (!hasUnannotatedParameters(signature, definition.docs)) {
      methods.set(method, [...(methods.get(method) ?? []), signature]);
    }

    for (const doc of definition.docs) {
      if (doc.type !== "doc.overload" || !doc.overload || doc.isIncomplete) {
        continue;
      }

      methods.set(method, [
        ...(methods.get(method) ?? []),
        {
          args: doc.overload.args ?? [],
          returns: doc.overload.returns ?? [],
          generics: doc.overload.signs ?? [],
        },
      ]);
    }

    methodDocs.set(method, definition.docs);
  }

  const members: string[] = [];

  for (const [method, signatures] of methods) {
    const normalized = signatures
      .map((signature) => ({
        ...signature,
        args: signature.args.filter((arg) => arg.name?.value !== "self"),
      }))
      .sort(compareSignatureSpecificity);
    const fullName = `${name  }.${  method}`;
    const rendered = normalized.map((signature) =>
      renderFunctionSignature({
        signature,
        name: fullName,
        signatures: normalized,
        classes,
        types,
      }),
    );
    const supported = rendered.filter((signature) => !signature.unsupported);
    const selected = supported.find((signature) => signature.callback) ?? supported[0] ?? rendered[0];
    if (!selected) continue;

    metadata.methods[method] = {
      returns: selected.returns,
      ...(selected.callback ? { callback: selected.callback } : {}),
      ...(selected.resultTypes ? { resultTypes: selected.resultTypes } : {}),
      ...(selected.unsupported ? { unsupported: selected.unsupported } : {}),
    };
    const type =
      supported.length > 0 ?
        [...new Set(supported.map((signature) => `(${signature.type})`))].join(" & ")
      : "never";
    members.push(
      `${renderTypeDocumentation(methodDocs.get(method) ?? [], CALLBACK_CONTRACTS.get(fullName)?.parameter)}${JSON.stringify(method)}: ${type};`,
    );
  }

  let operations = "";
  if (name === "TSNode") {
    operations = " & TreeSitterNodeOperations";
  } else if (name === "vim.treesitter.Query") {
    operations = " & TreeSitterQueryOperations<Lua_TSNode>";
  }

  return {
    metadata,
    body: `NativeReference<${renderFields(publicFields, new Set())}> & {\n${members.join("\n")}\n}${operations}`,
  };
};
