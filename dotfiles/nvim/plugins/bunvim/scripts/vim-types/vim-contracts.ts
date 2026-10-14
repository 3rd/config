import type { VimCallbackMetadata } from "../../src/vim/metadata";
import { type FunctionSignature, getLuaType, type LuaDefinition, type LuaNode } from "./luacats";

type CallbackContract = Omit<VimCallbackMetadata, "index" | "returns"> & {
  parameter: string;
  hasNoArguments?: boolean;
};

export const CALLBACK_CONTRACTS = new Map<string, CallbackContract>([
  ["vim.ui.input", { parameter: "on_confirm", result: "values" }],
  ["vim.ui.select", { parameter: "on_choice", result: "values" }],
  ["vim.schedule", { parameter: "fn", result: "values", hasErrorReturn: true }],
  [
    "vim.defer_fn",
    {
      parameter: "fn",
      result: "values",
      cancel: "close",
      hasNoArguments: true,
    },
  ],
  [
    "vim.lsp.buf_request_all",
    {
      parameter: "handler",
      result: "values",
      cancel: "function",
      dictionaries: [0],
      prerequisite: {
        path: ["lsp", "get_clients"],
        options: { bufnr: 0, method: 1 },
        message: "No LSP clients support this request",
      },
    },
  ],
  [
    "vim.uv.spawn",
    {
      parameter: "on_exit",
      result: "values",
      cancel: "process",
      hasErrorReturn: true,
    },
  ],
  ["vim.uv.random", { parameter: "callback", result: "uv", hasErrorReturn: true }],
  ["vim.treesitter.LanguageTree.parse", { parameter: "on_parse", result: "error-first", immediateResult: 0 }],
  [
    "vim.lsp.Client.request",
    {
      parameter: "handler",
      result: "values",
      cancel: "client-request",
      resourceIndex: 1,
      rejectOnFalse: "LSP client rejected this request",
    },
  ],
]);

export const UV_COMPLETION_REQUESTS = new Set(["uv.uv_fs_t", "uv.uv_getaddrinfo_t", "uv.uv_getnameinfo_t"]);

export const NATIVE_CLASSES = new Set([
  "TSNode",
  "TSQuery",
  "TSQueryMatch",
  "TSTree",
  "vim.lsp.Client",
  "vim.treesitter.LanguageTree",
  "vim.treesitter.Query",
]);

export const ITERATOR_METHODS = new Set([
  "TSNode.iter_children",
  "vim.treesitter.Query.iter_captures",
  "vim.treesitter.Query.iter_matches",
]);

const replaceStringWithBytes = (node: LuaNode): LuaNode => ({
  ...node,
  ...(node.type === "doc.type.name" && node.value === "string" ? { value: "BunvimBytes" } : {}),
  ...(node.types ? { types: node.types.map(replaceStringWithBytes) } : {}),
});

export const correctBinarySignature = (name: string, signature: FunctionSignature) => {
  const hasByteResult = [
    "TSNode.id",
    "vim.uv.fs_read",
    "vim.uv.random",
    "vim.uv.utf16_to_wtf8",
    "vim.uv.wtf8_to_utf16",
  ].includes(name);
  if (hasByteResult && signature.returns[0]) {
    signature.returns[0] = replaceStringWithBytes(signature.returns[0]);
  }

  if (/^vim\.uv\.(utf16|wtf8)_/.test(name) && signature.args[0]) {
    signature.args[0].extends = replaceStringWithBytes(getLuaType(signature.args[0]));
  }

  if (name !== "vim.uv.fs_read" && name !== "vim.uv.random") return;

  const callback = signature.args.find((arg) => arg.name?.value === "callback");
  if (!callback) return;

  const callbackType = getLuaType(callback);
  const functions =
    callbackType.type === "doc.type.function" ?
      [callbackType]
    : (callbackType.types ?? []).filter((node) => node.type === "doc.type.function");

  for (const fn of functions) {
    const value = fn.args?.[1];
    if (value) {
      value.extends = replaceStringWithBytes(getLuaType(value));
    }
  }
};

export const correctVimMetadata = (definitions: LuaDefinition[]) => {
  const predicateReturnCorrections = new Map<string, LuaNode>([
    ["vim.fn.browse", { type: "doc.type.name", value: "string" }],
    ["vim.fn.browsedir", { type: "doc.type.name", value: "string" }],
    ["vim.fn.char2nr", { type: "doc.type.name", value: "integer" }],
    [
      "vim.fn.exists",
      {
        type: "doc.type",
        types: [0, 1, 2, 3].map((value) => ({
          type: "doc.type.integer",
          value,
        })),
      },
    ],
    [
      "vim.fn.filewritable",
      {
        type: "doc.type",
        types: [0, 1, 2].map((value) => ({ type: "doc.type.integer", value })),
      },
    ],
  ]);

  for (const definition of definitions) {
    const name = definition.names.join(".");

    for (const doc of definition.docs) {
      const result = doc.type === "doc.return" && doc.returns?.length === 1 ? doc.returns[0] : undefined;
      if (result) {
        if (name === "TSNode.iter_children") {
          const iterator =
            result.type === "doc.type.function" ?
              result
            : result.types?.find((member) => member.type === "doc.type.function");
          const fieldName = iterator?.returns?.[1];
          if (fieldName) {
            fieldName.optional = true;
          }
        }

        const correction = predicateReturnCorrections.get(name);
        const isPredicateReturn =
          result.type === "doc.type" &&
          result.types?.length === 2 &&
          result.types.every(
            (member) => member.type === "doc.type.integer" && (member.value === 0 || member.value === 1),
          );
        if (correction && isPredicateReturn) {
          doc.returns = [correction];
        }

        if (name === "vim.fn.getenv" && result.types?.length === 1 && result.types[0]?.value === "string") {
          doc.returns = [
            {
              type: "doc.type",
              types: [...result.types, { type: "doc.type.name", value: "nil" }],
            },
          ];
        }

        if (
          name === "vim.fn.getftype" &&
          result.types?.every((member) => member.type === "doc.type.string") &&
          !result.types.some((member) => member.value === "")
        ) {
          doc.returns = [
            {
              ...result,
              types: [...result.types, { type: "doc.type.string", value: "" }],
            },
          ];
        }
      }

      if (name === "vim.uv.fs_lchown" && doc.type === "doc.param" && doc.param?.value === "fd") {
        doc.param.value = "path";
        doc.extends = { type: "doc.type.name", value: "string" };
        const argument = definition.args?.items?.find((item) => item.value === "fd");
        if (argument) {
          argument.value = "path";
        }
      }

      if (name === "vim.uv.fs_lchown" && doc.type === "doc.overload") {
        const argument = doc.overload?.args?.find((arg) => arg.name?.value === "fd");
        if (argument?.name) {
          argument.name.value = "path";
          argument.extends = { type: "doc.type.name", value: "string" };
        }
      }

      if (name === "vim.fn.printf" && doc.type === "doc.param" && doc.param?.value === "expr1") {
        doc.param.value = "...";
        doc.optional = false;
        const argument = definition.args?.items?.find((item) => item.value === "expr1");
        if (argument) {
          argument.type = "...";
          argument.value = "...";
        }
      }

      if (name === "vim.fn.sign_unplacelist" && doc.type === "doc.param" && doc.param?.value === "list") {
        const argument = getLuaType(doc);
        if (
          argument.types?.length === 1 &&
          argument.types[0]?.value === "vim.fn.sign_unplacelist.list.item"
        ) {
          doc.extends = { type: "doc.type.array", node: argument };
        }
      }
    }

    const value = definition.value;
    if (value?.alias?.value === "uv.buffer") {
      const chunk: LuaNode = {
        type: "doc.type",
        types: [
          { type: "doc.type.name", value: "string" },
          { type: "doc.type.name", value: "BunvimBytes" },
        ],
      };
      value.extends = {
        type: "doc.type",
        types: [...(chunk.types ?? []), { type: "doc.type.array", node: chunk }],
      };
    }

    if (value?.class?.value === "uv.interface_addresses.addresses") {
      const mac = value.fields?.find((field) => field.field?.value === "mac");
      if (mac) {
        mac.extends = replaceStringWithBytes(getLuaType(mac));
      }
    }

    if (name === "vim.uv.interface_addresses") {
      const result = definition.docs.find((doc) => doc.type === "doc.return")?.returns?.[0];
      const table = result?.type === "doc.type.sign" ? result : result?.types?.[0];
      const address = table?.signs?.[1];
      if (table?.node?.value === "table" && address) {
        table.signs = [
          table.signs?.[0] ?? { type: "doc.type.name", value: "string" },
          { type: "doc.type.array", node: address },
        ];
      }
    }

    if (value?.class?.value === "vim.fn.winlayout.empty" && !value.fields?.length) {
      definition.value = {
        type: "doc.alias",
        alias: { type: "doc.alias.name", value: value.class.value },
        extends: { type: "doc.type.table", isTuple: true, fields: [] },
      };
    }
  }
};
