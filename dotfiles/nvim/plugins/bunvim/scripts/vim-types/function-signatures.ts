import type { VimCallbackMetadata, VimFunctionMetadata, VimValueDescriptor } from "../../src/vim/metadata";
import {
  type FunctionSignature,
  getLuaName,
  getLuaType,
  isNullableLuaType,
  isVariadicLuaType,
  type LuaDefinition,
  type LuaNode,
} from "./luacats";
import { type createTypeConverter, getTsParameterName } from "./type-conversion";
import {
  CALLBACK_CONTRACTS,
  correctBinarySignature,
  ITERATOR_METHODS,
  NATIVE_CLASSES,
  UV_COMPLETION_REQUESTS,
} from "./vim-contracts";

const countLiteralChoices = (node: LuaNode): number => {
  const optionalChoice = node.optional ? 1 : 0;

  if (node.type === "doc.type") {
    return (node.types ?? []).reduce((total, member) => total + countLiteralChoices(member), optionalChoice);
  }

  const isLiteral =
    ["doc.type.boolean", "doc.type.integer", "doc.type.string"].includes(node.type) || node.value === "nil";
  return isLiteral ? 1 + optionalChoice : Infinity;
};

export const compareSignatureSpecificity = (left: FunctionSignature, right: FunctionSignature) => {
  for (let index = 0; index < Math.min(left.args.length, right.args.length); index++) {
    const leftArg = left.args[index];
    const rightArg = right.args[index];
    if (!leftArg || !rightArg) continue;

    const leftChoices = countLiteralChoices(getLuaType(leftArg));
    const rightChoices = countLiteralChoices(getLuaType(rightArg));
    if (leftChoices !== rightChoices) return leftChoices - rightChoices;
  }

  return 0;
};

export const getLuaSignature = (
  definition: LuaDefinition,
  mode: "callable-table" | "ordinary" = "ordinary",
) => {
  let implementationArgs = (definition.args?.items ?? []).filter((arg) => arg.type !== "self");
  const receiver = mode === "callable-table" ? implementationArgs[0] : undefined;
  if (receiver) {
    implementationArgs = implementationArgs.slice(1);
  }

  const parameters = definition.docs.filter(
    (doc) => doc.type === "doc.param" && doc.param?.value !== receiver?.value,
  );
  const hasNamedPublicParameters =
    parameters.length > 0 && parameters.every((parameter) => parameter.param?.value !== "...");
  const isVariadicImplementation = implementationArgs.length === 1 && implementationArgs[0]?.type === "...";
  if (hasNamedPublicParameters && isVariadicImplementation) {
    implementationArgs = parameters.map((parameter) => ({
      type: "local",
      value: getLuaName(parameter.param),
    }));
  } else if (hasNamedPublicParameters && implementationArgs.length > parameters.length) {
    const prefix = implementationArgs.slice(0, parameters.length);
    const hasAnnotatedPrefix = prefix.every((argument) =>
      parameters.some((parameter) => parameter.param?.value === argument.value),
    );
    if (hasAnnotatedPrefix) {
      implementationArgs = prefix;
    }
  }

  return {
    args: implementationArgs.map((arg) => {
      const name = arg.type === "..." ? "..." : getLuaName(arg);
      const parameter = parameters.find((doc) => getLuaName(doc.param) === name);
      return {
        type: "doc.type.arg",
        name: { type: "doc.type.arg.name", value: name },
        optional: parameter?.optional,
        extends: parameter?.extends ?? {
          type: "doc.type.name",
          value: "any",
        },
      } satisfies LuaNode;
    }),
    returns: definition.docs.filter((doc) => doc.type === "doc.return").flatMap((doc) => doc.returns ?? []),
    generics: definition.docs
      .filter((doc) => doc.type === "doc.generic")
      .flatMap((doc) => doc.generics ?? []),
  } satisfies FunctionSignature;
};

export const resolveFunctionSignatures = (
  node: LuaNode,
  classes: Map<string, LuaNode>,
  visited = new Set<string>(),
): FunctionSignature[] => {
  if (node.isIncomplete) return [];

  if (node.type === "doc.type.function") {
    if (node.args?.some((arg) => !arg.extends)) return [];

    return [
      {
        args: node.args ?? [],
        returns: node.returns ?? [],
        generics: node.signs ?? [],
      },
    ];
  }

  if (node.type === "doc.type") {
    return (node.types ?? []).flatMap((member) =>
      resolveFunctionSignatures(member, classes, new Set(visited)),
    );
  }

  if (node.type !== "doc.type.name") return [];

  const name = getLuaName(node);
  if (visited.has(name)) return [];

  const definition = classes.get(name);
  if (definition?.type !== "doc.alias") return [];

  visited.add(name);
  return resolveFunctionSignatures(getLuaType(definition), classes, visited);
};

type CompletionSignatureOptions = {
  signature: FunctionSignature;
  signatures: FunctionSignature[];
  name: string;
  classes: Map<string, LuaNode>;
};

const adaptCompletionSignature = ({ signature, signatures, name, classes }: CompletionSignatureOptions) => {
  let contract = CALLBACK_CONTRACTS.get(name);
  const firstReturn = signature.returns[0];
  const returnTypes = firstReturn?.types ?? (firstReturn ? [firstReturn] : []);
  const hasUvCompletionRequest =
    name.startsWith("vim.uv.") &&
    returnTypes.some((node) => typeof node.value === "string" && UV_COMPLETION_REQUESTS.has(node.value)) &&
    signature.args.some((arg) => getLuaName(arg.name) === "callback");
  if (hasUvCompletionRequest) {
    contract = {
      parameter: "callback",
      result: "uv",
      cancel: "request",
      hasErrorReturn: true,
      ...(["vim.uv.fs_mkstemp", "vim.uv.fs_open"].includes(name) ? { discard: "close-fd" } : {}),
    };
  }

  if (!contract) return;

  const callbackName = contract.parameter;
  const callbackIndex = signature.args.findIndex((arg) => getLuaName(arg.name) === callbackName);
  const callback = signature.args[callbackIndex];
  if (!callback) return;

  const fn =
    resolveFunctionSignatures(getLuaType(callback), classes)[0] ??
    (contract.hasNoArguments ? { args: [] } : undefined);
  if (!fn) {
    throw new Error(`Missing callback signature: ${name}`);
  }

  const callbackResults = fn.args.map((arg) => {
    const type = getLuaType(arg);
    return { ...type, optional: arg.optional || type.optional };
  });
  const args = signature.args.filter((_arg, index) => index !== callbackIndex);
  let returns: LuaNode[] = callbackResults;
  if (contract.result === "error-first") {
    returns = callbackResults.slice(1);
  }

  if (contract.result === "uv") {
    const synchronous = signatures.find(
      (candidate) =>
        candidate.args.length === args.length &&
        candidate.args.every((arg, index) => getLuaName(arg.name) === getLuaName(args[index]?.name)),
    );
    if (!synchronous || synchronous.returns.length !== 3) return;

    returns = synchronous.returns;
  }

  return {
    args,
    returns,
    callbackResults,
    metadata: {
      index: callbackIndex,
      returns: returns.length,
      result: contract.result,
      ...(contract.cancel ? { cancel: contract.cancel } : {}),
      ...(contract.discard ? { discard: contract.discard } : {}),
      ...(contract.hasErrorReturn ? { hasErrorReturn: true } : {}),
      ...(contract.resourceIndex === undefined ? {} : { resourceIndex: contract.resourceIndex }),
      ...(contract.immediateResult === undefined ? {} : { immediateResult: contract.immediateResult }),
      ...(contract.rejectOnFalse ? { rejectOnFalse: contract.rejectOnFalse } : {}),
      ...(contract.dictionaries ? { dictionaries: contract.dictionaries } : {}),
      ...(contract.prerequisite ? { prerequisite: contract.prerequisite } : {}),
    } satisfies VimCallbackMetadata,
  };
};

export const hasUnannotatedParameters = (signature: FunctionSignature, docs: LuaNode[]) => {
  const parameterNames = new Set(
    docs.filter((doc) => doc.type === "doc.param").map((doc) => getLuaName(doc.param)),
  );
  return signature.args.some((arg) => !parameterNames.has(getLuaName(arg.name)));
};

interface SignatureOptions {
  signature: FunctionSignature;
  name: string;
  signatures: FunctionSignature[];
  classes: Map<string, LuaNode>;
  types: ReturnType<typeof createTypeConverter>;
}

export const renderFunctionSignature = ({
  signature,
  name,
  signatures,
  classes,
  types,
}: SignatureOptions) => {
  const { renderType, findUnsupportedType, findUnsupportedArgument, getValueDescriptor } = types;
  correctBinarySignature(name, signature);

  const originalGenericNames = signature.generics.map((generic) => getLuaName(generic.generic ?? generic));
  const genericNames = originalGenericNames.map((value) => value.replace(/\.{3}$/, ""));
  const generics = new Set(genericNames);
  const completion = adaptCompletionSignature({
    signature,
    signatures,
    name,
    classes,
  });
  const args = completion?.args ?? signature.args;
  const returns = completion?.returns ?? signature.returns;
  const isNativeMethod = NATIVE_CLASSES.has(name.slice(0, name.lastIndexOf(".")));
  const iterator =
    ITERATOR_METHODS.has(name) && returns[0] ? resolveFunctionSignatures(returns[0], classes)[0] : undefined;

  const renderedArgs = args.map((arg, index) => {
    const argName = getLuaName(arg.name);
    const type = renderType(getLuaType(arg), generics);

    if (argName === "...") {
      return `...args: ${isVariadicLuaType(getLuaType(arg)) ? type : `(${type})[]`}`;
    }

    const canOmit = arg.optional || isNullableLuaType(getLuaType(arg));
    const hasRequiredFollowing = args
      .slice(index + 1)
      .some(
        (next) => !next.optional && getLuaName(next.name) !== "..." && !isNullableLuaType(getLuaType(next)),
      );
    const parameterName = argName === "_" ? `arg${index + 1}` : getTsParameterName(argName);
    return `${parameterName}${canOmit && !hasRequiredFollowing ? "?" : ""}: ${type}${canOmit && hasRequiredFollowing ? " | undefined" : ""}`;
  });

  const renderResults = (values: LuaNode[]) => {
    const results = values.map((result) => renderType(result, generics));
    return results.length > 1 ?
        `[${results.map((type, index) => (values[index] && isVariadicLuaType(values[index]) ? `...${type}` : type)).join(", ")}]`
      : (results[0] ?? (completion ? "null" : "RpcValue"));
  };

  const unsupportedResult = [...(iterator?.returns ?? returns), ...(completion?.callbackResults ?? [])]
    .map((result) => {
      const unsupported = findUnsupportedType(result, generics);
      return isNullableLuaType(result) && (unsupported === "function" || unsupported === "Lua function") ?
          undefined
        : unsupported;
    })
    .find(Boolean);
  const unsupportedArgument = args.find((arg) => {
    const type = getLuaType(arg);
    if (arg.optional || isNullableLuaType(type)) return false;

    const needsNativeArgument =
      (isNativeMethod || getLuaName(arg.name) === "self") &&
      findUnsupportedType(type, generics) !== undefined;
    return needsNativeArgument || findUnsupportedArgument(type, generics) !== undefined;
  });
  let unsupported: string | undefined;
  if (unsupportedResult) {
    unsupported = `Return value requires native Lua: ${unsupportedResult}`;
  } else if (unsupportedArgument) {
    unsupported = `Required argument requires native Lua: ${getLuaName(unsupportedArgument.name)}`;
  }

  const hasVariadicReturn = returns.some(isVariadicLuaType);
  const result = iterator ? `NativeIterator<${renderResults(iterator.returns)}>` : renderResults(returns);
  const descriptorMode = isNativeMethod ? "native" : "ordinary";
  const resultTypes: VimValueDescriptor[] =
    iterator ?
      [
        {
          iterator: {
            returns: iterator.returns.length,
            resultTypes: iterator.returns.map((value) =>
              getValueDescriptor(value, new Set(), descriptorMode),
            ),
          },
        },
      ]
    : returns.map((value) => getValueDescriptor(value, new Set(), descriptorMode));
  const genericDeclarations = signature.generics.map((generic) => {
    const originalName = getLuaName(generic.generic ?? generic);
    const processedName = originalName.replace(/\.{3}$/, "");

    if (originalName.endsWith("...")) return `${processedName} extends unknown[]`;
    if (!generic.extends) return processedName;

    const constraint = getLuaType(generic);
    const isTableConstraint =
      constraint.type === "doc.type" &&
      constraint.types?.length === 1 &&
      constraint.types[0]?.value === "table";
    return `${processedName} extends ${isTableConstraint ? "object" : renderType(constraint, generics)}`;
  });
  const genericParameters = genericDeclarations.length > 0 ? `<${genericDeclarations.join(", ")}>` : "";
  const returnCount: VimFunctionMetadata["returns"] =
    hasVariadicReturn || name === "TSNode.range" ? "all" : returns.length;
  return {
    type: `${genericParameters}(${renderedArgs.join(", ")}) => Promise<${result}>`,
    returns: returnCount,
    ...(unsupported ? { unsupported } : {}),
    ...(completion ? { callback: completion.metadata } : {}),
    ...(resultTypes.some((descriptor) => descriptor !== null) ? { resultTypes } : {}),
  };
};
