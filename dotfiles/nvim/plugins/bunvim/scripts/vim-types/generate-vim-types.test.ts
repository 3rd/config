import { expect, test } from "bun:test";
import ts from "typescript";
import coverage from "../../src/vim/generated/vim-coverage.json";
import metadata from "../../src/vim/generated/vim-functions.json";
import { generateVimTypes } from "./generate-vim-types";

const commandType = {
  kind: "type",
  path: "vim/_meta/api_keysets.gen.lua",
  line: 1,
  value: {
    type: "doc.class",
    class: { type: "doc.class.name", value: "vim.api.keyset.cmd" },
    fields: [
      {
        type: "doc.field",
        field: { type: "doc.field.name", value: "cmd" },
        extends: { type: "doc.type.name", value: "string" },
      },
    ],
  },
};

test("preserves optional tuple fields without making their containing argument optional", () => {
  const result = generateVimTypes(
    [
      commandType,
      {
        kind: "function",
        path: "vim/_meta/api.gen.lua",
        line: 2,
        names: ["vim", "api", "example"],
        args: { type: "funcargs", items: [{ type: "local", value: "chunks" }] },
        docs: [
          {
            type: "doc.param",
            param: { type: "doc.param.name", value: "chunks" },
            extends: {
              type: "doc.type.array",
              node: {
                type: "doc.type.table",
                isTuple: true,
                fields: [
                  {
                    type: "doc.type.field",
                    extends: { type: "doc.type.name", value: "string" },
                  },
                  {
                    type: "doc.type.field",
                    optional: true,
                    extends: {
                      type: "doc.type.name",
                      value: "integer",
                      optional: true,
                    },
                  },
                ],
              },
            },
          },
        ],
      },
    ],
    {
      version: "fixture",
      commands: [],
      functions: [{ path: ["vim", "api", "example"], source: "=[C]", line: -1 }],
    },
  );

  expect(result.declarations).toContain(
    '"example": ((chunks: ([(string), ((number) | null)?])[]) => Promise<RpcValue>)',
  );
});

test("promisifies a callback using its declared result rather than accepting a function argument", () => {
  const result = generateVimTypes(
    [
      commandType,
      {
        kind: "function",
        path: "vim/ui.lua",
        line: 10,
        names: ["M", "input"],
        args: {
          type: "funcargs",
          items: [
            { type: "local", value: "opts" },
            { type: "local", value: "on_confirm" },
          ],
        },
        docs: [
          {
            type: "doc.param",
            optional: true,
            param: { type: "doc.param.name", value: "opts" },
            extends: { type: "doc.type.name", value: "table" },
          },
          {
            type: "doc.param",
            param: { type: "doc.param.name", value: "on_confirm" },
            description: "The confirmed text or nil on cancellation.",
            extends: {
              type: "doc.type",
              types: [
                {
                  type: "doc.type.function",
                  args: [
                    {
                      type: "doc.type.arg",
                      optional: true,
                      name: { type: "doc.type.arg.name", value: "value" },
                      extends: { type: "doc.type.name", value: "string" },
                    },
                  ],
                },
              ],
            },
          },
        ],
      },
    ],
    {
      version: "fixture",
      commands: [],
      functions: [{ path: ["vim", "ui", "input"], source: "vim/ui.lua", line: 10 }],
    },
  );

  expect(result.declarations).toContain(
    '"input": ((opts?: Record<string, RpcValue> | RpcValue[]) => Promise<(string) | null>)',
  );
  expect(result.manifest.functions["ui.input"]).toEqual({
    returns: 1,
    callback: { index: 1, returns: 1, result: "values" },
  });
  expect(result.declarations).toContain("@returns The confirmed text or nil on cancellation.");
});

test("keeps a variadic return tail and resolves an exported alias by native source identity", () => {
  const result = generateVimTypes(
    [
      commandType,
      {
        kind: "function",
        path: "vim/tuple.lua",
        line: 4,
        names: ["M", "collect"],
        args: { type: "funcargs", items: [] },
        docs: [
          {
            type: "doc.return",
            returns: [
              { type: "doc.type.name", value: "boolean" },
              {
                type: "doc.type",
                name: { type: "doc.return.name", value: "..." },
                types: [{ type: "doc.type.name", value: "unknown" }],
              },
            ],
          },
        ],
      },
    ],
    {
      version: "fixture",
      commands: [],
      functions: [{ path: ["vim", "collect"], source: "vim/tuple.lua", line: 4 }],
    },
  );

  expect(result.declarations).toContain('"collect": (() => Promise<[boolean, ...(RpcValue)[]]>)');
  expect(result.manifest.functions).toEqual({ collect: { returns: "all" } });
});

test("derives a libuv completion contract from an aliased callback and retains its synchronous result tuple", () => {
  const result = generateVimTypes(
    [
      commandType,
      {
        kind: "type",
        path: "uv/_meta.lua",
        line: 1,
        value: {
          type: "doc.class",
          class: { type: "doc.class.name", value: "uv.uv_fs_t" },
          extends: [{ type: "doc.extends.name", value: "userdata" }],
        },
      },
      {
        kind: "type",
        path: "uv/_meta.lua",
        line: 2,
        value: {
          type: "doc.alias",
          alias: { type: "doc.alias.name", value: "UVCompletion" },
          extends: {
            type: "doc.type.function",
            args: [
              {
                type: "doc.type.arg",
                name: { type: "doc.type.arg.name", value: "err" },
                extends: {
                  type: "doc.type.name",
                  value: "string",
                  optional: true,
                },
              },
              {
                type: "doc.type.arg",
                name: { type: "doc.type.arg.name", value: "value" },
                extends: {
                  type: "doc.type.name",
                  value: "integer",
                  optional: true,
                },
              },
            ],
          },
        },
      },
      {
        kind: "function",
        path: "uv/_meta.lua",
        line: 3,
        names: ["vim", "uv", "fs_probe"],
        args: { type: "funcargs", items: [{ type: "local", value: "path" }] },
        docs: [
          {
            type: "doc.param",
            param: { type: "doc.param.name", value: "path" },
            extends: { type: "doc.type.name", value: "string" },
          },
          {
            type: "doc.return",
            returns: [
              { type: "doc.type.name", value: "integer", optional: true },
              { type: "doc.type.name", value: "string", optional: true },
              { type: "doc.type.name", value: "string", optional: true },
            ],
          },
          {
            type: "doc.overload",
            overload: {
              type: "doc.type.function",
              args: [
                {
                  type: "doc.type.arg",
                  name: { type: "doc.type.arg.name", value: "path" },
                  extends: { type: "doc.type.name", value: "string" },
                },
                {
                  type: "doc.type.arg",
                  name: { type: "doc.type.arg.name", value: "callback" },
                  extends: { type: "doc.type.name", value: "UVCompletion" },
                },
              ],
              returns: [{ type: "doc.type.name", value: "uv.uv_fs_t" }],
            },
          },
        ],
      },
    ],
    {
      version: "fixture",
      commands: [],
      functions: [{ path: ["vim", "uv", "fs_probe"], source: "=[C]", line: -1 }],
    },
  );

  expect(result.declarations).toContain(
    '"fs_probe": ((path: string) => Promise<[(number) | null, (string) | null, (string) | null]>)',
  );
  expect(result.manifest.functions["uv.fs_probe"]).toEqual({
    returns: 3,
    callback: {
      index: 1,
      returns: 3,
      result: "uv",
      cancel: "request",
      hasErrorReturn: true,
    },
  });
});

test("rejects native results through aliases and nested fields instead of advertising a serializable object", () => {
  const result = generateVimTypes(
    [
      commandType,
      {
        kind: "type",
        path: "vim/native.lua",
        line: 1,
        value: {
          type: "doc.class",
          class: { type: "doc.class.name", value: "NativeHandle" },
          extends: [{ type: "doc.extends.name", value: "userdata" }],
        },
      },
      {
        kind: "type",
        path: "vim/native.lua",
        line: 2,
        value: {
          type: "doc.alias",
          alias: { type: "doc.alias.name", value: "HandleAlias" },
          extends: { type: "doc.type.name", value: "NativeHandle" },
        },
      },
      {
        kind: "function",
        path: "vim/native.lua",
        line: 3,
        names: ["M", "start"],
        args: { type: "funcargs", items: [] },
        docs: [
          {
            type: "doc.return",
            returns: [
              {
                type: "doc.type.table",
                fields: [
                  {
                    type: "doc.type.field",
                    field: { type: "doc.field.name", value: "handle" },
                    extends: { type: "doc.type.name", value: "HandleAlias" },
                  },
                ],
              },
            ],
          },
        ],
      },
    ],
    {
      version: "fixture",
      commands: [],
      functions: [{ path: ["vim", "native", "start"], source: "vim/native.lua", line: 3 }],
    },
  );

  expect(result.declarations).toContain('"start": never');
  expect(result.manifest.functions["native.start"]).toMatchObject({
    unsupported: expect.stringContaining("userdata"),
  });
  expect(result.coverage.unsupported["vim.native.start"]).toContain("userdata");
  expect(result.coverage.omitted).toEqual([]);
});

test("generates native instance methods and iterator results without exposing native storage", () => {
  const result = generateVimTypes(
    [
      commandType,
      {
        kind: "type",
        path: "vim/treesitter/_meta/tsnode.lua",
        line: 1,
        value: {
          type: "doc.class",
          class: { type: "doc.class.name", value: "TSNode" },
          hasInstanceMethods: true,
          extends: [{ type: "doc.extends.name", value: "userdata" }],
        },
      },
      {
        kind: "function",
        path: "vim/treesitter/_meta/tsnode.lua",
        line: 2,
        names: ["TSNode", "parent"],
        ownerClass: "TSNode",
        args: { type: "funcargs", items: [{ type: "self" }] },
        docs: [
          {
            type: "doc.return",
            returns: [{ type: "doc.type.name", value: "TSNode", optional: true }],
          },
        ],
      },
      {
        kind: "function",
        path: "vim/treesitter/_meta/tsnode.lua",
        line: 3,
        names: ["TSNode", "iter_children"],
        ownerClass: "TSNode",
        args: { type: "funcargs", items: [{ type: "self" }] },
        docs: [
          {
            type: "doc.return",
            returns: [
              {
                type: "doc.type.function",
                returns: [
                  { type: "doc.type.name", value: "TSNode" },
                  { type: "doc.type.name", value: "string" },
                ],
              },
            ],
          },
        ],
      },
      {
        kind: "type",
        path: "vim/treesitter/_meta/misc.lua",
        line: 1,
        value: {
          type: "doc.class",
          class: { type: "doc.class.name", value: "TSQueryMatch" },
          extends: [{ type: "doc.extends.name", value: "userdata" }],
          fields: [
            {
              type: "doc.field",
              field: { type: "doc.field.name", value: "captures" },
              extends: {
                type: "doc.type.function",
                args: [
                  {
                    type: "doc.type.arg",
                    name: { type: "doc.type.arg.name", value: "self" },
                    extends: { type: "doc.type.name", value: "TSQueryMatch" },
                  },
                ],
                returns: [
                  {
                    type: "doc.type.sign",
                    node: { type: "doc.type.name", value: "table" },
                    signs: [
                      { type: "doc.type.name", value: "integer" },
                      {
                        type: "doc.type.array",
                        node: { type: "doc.type.name", value: "TSNode" },
                      },
                    ],
                  },
                ],
              },
            },
          ],
        },
      },
      {
        kind: "function",
        path: "vim/treesitter.lua",
        line: 1,
        names: ["M", "get_node"],
        args: { type: "funcargs", items: [] },
        docs: [
          {
            type: "doc.return",
            returns: [{ type: "doc.type.name", value: "TSNode", optional: true }],
          },
        ],
      },
    ],
    {
      version: "fixture",
      commands: [],
      functions: [
        {
          path: ["vim", "treesitter", "get_node"],
          source: "vim/treesitter.lua",
          line: 1,
        },
      ],
    },
  );

  expect(result.manifest.functions["treesitter.get_node"]).toEqual({
    returns: 1,
    resultTypes: [{ native: "TSNode" }],
  });
  const node = result.manifest.nativeClasses.TSNode;
  const match = result.manifest.nativeClasses.TSQueryMatch;
  if (!node || !match) {
    throw new Error("Missing generated native class metadata");
  }

  expect(node.methods.parent).toEqual({
    returns: 1,
    resultTypes: [{ native: "TSNode" }],
  });
  expect(node.methods.iter_children).toEqual({
    returns: 1,
    resultTypes: [{ iterator: { returns: 2, resultTypes: [{ native: "TSNode" }, null] } }],
  });
  expect(match.methods.captures).toEqual({
    returns: 1,
    resultTypes: [{ dictionary: { array: { native: "TSNode" } } }],
  });
  expect(result.declarations).toContain("NativeReference<{}>");
  expect(result.declarations).toContain('"parent": (() => Promise<(Lua_TSNode) | null>)');
  expect(result.declarations).toContain('"captures": (() => Promise<{ [key: number]: (Lua_TSNode)[] }>)');
  expect(result.declarations).toContain("NativeIterator<[Lua_TSNode, (string) | null]>");
});

test("retains byte, native completion, and live-field contracts in generated runtime metadata", () => {
  expect(metadata.functions["uv.fs_read"]).toMatchObject({
    callback: { result: "uv", index: 3 },
    resultTypes: ["bytes", null, null],
  });
  expect(metadata.functions["uv.random"]).toMatchObject({
    callback: { result: "uv", index: 2 },
    resultTypes: ["bytes", null, null],
  });
  expect(metadata.functions["uv.interface_addresses"].resultTypes).toEqual([
    { dictionary: { array: { fields: { mac: "bytes" } } } },
    null,
    null,
  ]);
  expect(metadata.nativeClasses["vim.treesitter.LanguageTree"].methods.parse).toEqual({
    returns: 1,
    callback: {
      result: "error-first",
      index: 1,
      returns: 1,
      immediateResult: 0,
    },
    resultTypes: [{ dictionary: { native: "TSTree" } }],
  });
  expect(metadata.nativeClasses["vim.lsp.Client"].methods.request.callback).toEqual({
    cancel: "client-request",
    index: 2,
    rejectOnFalse: "LSP client rejected this request",
    resourceIndex: 1,
    result: "values",
    returns: 4,
  });
  expect(metadata.nativeClasses.TSNode.methods.range.returns).toBe("all");
  expect(metadata.nativeClasses.TSTree.methods.included_ranges).toEqual({
    returns: 1,
  });
  expect(metadata.nativeClasses["vim.lsp.Client"].fields.server_capabilities).toBeNull();
  expect(metadata.nativeClasses.TSNode.methods.id.resultTypes).toEqual(["bytes"]);
  expect(metadata.nativeClasses["vim.treesitter.Query"].fields.query).toEqual({
    native: "TSQuery",
  });
  expect(metadata.functions["treesitter.query.parse"]).toEqual({
    returns: 1,
    resultTypes: [{ native: "vim.treesitter.Query" }],
  });
  expect(metadata.nativeClasses["vim.treesitter.Query"].fields.info).toEqual({
    fields: { patterns: { dictionary: null } },
  });
  expect(metadata.nativeClasses["vim.treesitter.Query"].methods.iter_captures.resultTypes).toEqual([
    {
      iterator: {
        returns: 5,
        resultTypes: [
          null,
          { native: "TSNode" },
          { dictionary: null },
          { native: "TSQueryMatch" },
          { native: "TSTree" },
        ],
      },
    },
  ]);
  expect(metadata.functions["treesitter.query.parse.clear"].unsupported).toBe(
    "Required argument requires native Lua: self",
  );
});

test("discovers callable tables by origin, removes implicit self, and retains upstream documentation", () => {
  const result = generateVimTypes(
    [
      commandType,
      {
        kind: "function",
        path: "vim/describe.lua",
        line: 10,
        names: [],
        args: {
          type: "funcargs",
          items: [
            { type: "local", value: "_" },
            { type: "local", value: "text" },
          ],
        },
        docs: [
          { type: "doc.comment", description: "Describes a value. */" },
          { type: "doc.comment", description: "```lua\n  print(value)\n```" },
          {
            type: "doc.param",
            param: { type: "doc.param.name", value: "text" },
            extends: { type: "doc.type.name", value: "string" },
            description: "Text in UTF-8 bytes.",
          },
          {
            type: "doc.return",
            returns: [{ type: "doc.type.name", value: "string" }],
            description: "The description.",
          },
          { type: "doc.deprecated", description: "Use the replacement." },
        ],
      },
    ],
    {
      version: "fixture",
      commands: [],
      functions: [
        {
          path: ["vim", "describe"],
          source: "vim/describe.lua",
          line: 10,
          isCallableTable: true,
        },
        { path: ["vim", "missing"], source: "vim/missing.lua", line: 1 },
        { path: ["vim", "undocumented"], source: "=[C]", line: -1 },
      ],
    },
  );

  expect(result.declarations).toContain('"describe": ((text: string) => Promise<string>)');
  expect(result.declarations).toContain("Describes a value. *\\/");
  expect(result.declarations).toContain(" *   print(value)");
  expect(result.declarations).toContain("@param text Text in UTF-8 bytes.");
  expect(result.declarations).toContain("@returns The description.");
  expect(result.declarations).toContain("@deprecated Use the replacement.");
  expect(result.coverage.supported).toContain("vim.describe");
  expect(result.coverage.omitted).toEqual(["vim.missing"]);
  expect(result.coverage.unsupported["vim.undocumented"]).toBe(
    "Native function has no exported LuaCATS signature",
  );
});

test("prefers an annotated exported alias over its unannotated closure", () => {
  const result = generateVimTypes(
    [
      commandType,
      {
        kind: "function",
        path: "vim/logger.lua",
        line: 10,
        names: [],
        args: { type: "funcargs", items: [{ type: "...", value: "..." }] },
        docs: [],
      },
      {
        kind: "alias",
        path: "vim/example.lua",
        line: 20,
        names: ["M", "write"],
        docs: [
          {
            type: "doc.type",
            types: [
              {
                type: "doc.type.function",
                args: [
                  {
                    type: "doc.type.arg",
                    name: { type: "doc.type.arg.name", value: "..." },
                    extends: { type: "doc.type.name", value: "any" },
                  },
                ],
                returns: [{ type: "doc.type.name", value: "boolean", optional: true }],
              },
              {
                type: "doc.type.function",
                args: [
                  {
                    type: "doc.type.arg",
                    name: { type: "doc.type.arg.name", value: "..." },
                  },
                ],
              },
            ],
          },
        ],
      },
    ],
    {
      version: "fixture",
      commands: [],
      functions: [
        {
          path: ["vim", "example", "write"],
          source: "vim/logger.lua",
          line: 10,
        },
      ],
    },
  );

  expect(result.declarations).toContain('"write": ((...args: (RpcValue)[]) => Promise<(boolean) | null>)');
  expect(result.manifest.functions["example.write"]).toEqual({ returns: 1 });
  expect(result.coverage.unsupported).toEqual({});
});

test("uses the annotated wrapped function for memoized callable tables", () => {
  const result = generateVimTypes(
    [
      commandType,
      {
        kind: "function",
        path: "vim/memoize.lua",
        line: 10,
        names: [],
        args: {
          type: "funcargs",
          items: [
            { type: "local", value: "self" },
            { type: "...", value: "..." },
          ],
        },
        docs: [
          {
            type: "doc.param",
            param: { type: "doc.param.name", value: "self" },
            extends: { type: "doc.type.name", value: "table" },
          },
        ],
      },
      {
        kind: "function",
        path: "vim/example.lua",
        line: 20,
        names: ["M", "parse"],
        args: { type: "funcargs", items: [{ type: "local", value: "source" }] },
        docs: [
          {
            type: "doc.param",
            param: { type: "doc.param.name", value: "source" },
            extends: { type: "doc.type.name", value: "string" },
          },
          {
            type: "doc.return",
            returns: [{ type: "doc.type.name", value: "integer" }],
          },
        ],
      },
    ],
    {
      version: "fixture",
      commands: [],
      functions: [
        {
          path: ["vim", "example", "parse"],
          source: "vim/memoize.lua",
          line: 10,
          isCallableTable: true,
        },
      ],
    },
  );

  expect(result.declarations).toContain('"parse": ((source: string) => Promise<number>)');
  expect(result.manifest.functions["example.parse"]).toEqual({ returns: 1 });
});

test("uses an authoritative function type alias instead of unannotated implementation parameters", () => {
  const result = generateVimTypes(
    [
      commandType,
      {
        kind: "type",
        path: "vim/example.lua",
        line: 1,
        value: {
          type: "doc.alias",
          alias: { type: "doc.alias.name", value: "ExampleHandler" },
          extends: {
            type: "doc.type.function",
            args: [
              {
                type: "doc.type.arg",
                name: { type: "doc.type.arg.name", value: "text" },
                extends: { type: "doc.type.name", value: "string" },
              },
            ],
            returns: [{ type: "doc.type.name", value: "boolean" }],
          },
        },
      },
      {
        kind: "function",
        path: "vim/example.lua",
        line: 2,
        names: ["M", "handle"],
        args: { type: "funcargs", items: [{ type: "local", value: "_" }] },
        docs: [
          {
            type: "doc.type",
            types: [{ type: "doc.type.name", value: "ExampleHandler" }],
          },
        ],
      },
    ],
    {
      version: "fixture",
      commands: [],
      functions: [
        {
          path: ["vim", "example", "handle"],
          source: "vim/example.lua",
          line: 2,
        },
      ],
    },
  );

  expect(result.declarations).toContain('"handle": ((text: string) => Promise<boolean>)');
  expect(result.manifest.functions["example.handle"]).toEqual({ returns: 1 });
  expect(result.coverage.supported).toContain("vim.example.handle");
});

test("preserves serializable overloads when another overload requires a native callback", () => {
  const result = generateVimTypes(
    [
      commandType,
      {
        kind: "function",
        path: "vim/_meta/vimfn.gen.lua",
        line: 1,
        names: ["vim", "fn", "get"],
        args: {
          type: "funcargs",
          items: [{ type: "local", value: "callback" }],
        },
        docs: [
          {
            type: "doc.param",
            param: { type: "doc.param.name", value: "callback" },
            extends: { type: "doc.type.name", value: "function" },
          },
          {
            type: "doc.overload",
            overload: {
              type: "doc.type.function",
              args: [
                {
                  type: "doc.type.arg",
                  name: { type: "doc.type.arg.name", value: "items" },
                  extends: {
                    type: "doc.type.array",
                    node: { type: "doc.type.name", value: "string" },
                  },
                },
              ],
              returns: [{ type: "doc.type.name", value: "string" }],
            },
          },
        ],
      },
    ],
    {
      version: "fixture",
      commands: [],
      functions: [{ path: ["vim", "fn", "get"], source: "=[C]", line: -1 }],
    },
  );

  expect(result.declarations).toContain('"get": ((items: (string)[]) => Promise<string>)');
  expect(result.manifest.functions["fn.get"]).toEqual({ returns: 1 });
  expect(result.coverage.supported).toContain("vim.fn.get");
});

test("attaches field documentation to the property TypeScript exposes in IntelliSense", () => {
  const result = generateVimTypes(
    [
      commandType,
      {
        kind: "type",
        path: "vim/options.lua",
        line: 1,
        value: {
          type: "doc.class",
          class: { type: "doc.class.name", value: "Options" },
          description: "@inlinedoc\nDisplay options.",
          fields: [
            {
              type: "doc.field",
              field: { type: "doc.field.name", value: "row" },
              extends: { type: "doc.type.name", value: "integer" },
              description: "Zero-based row.",
            },
            {
              type: "doc.field",
              field: { type: "doc.field.name", value: "column" },
              extends: { type: "doc.type.name", value: "integer" },
              description: "Byte column.",
            },
          ],
        },
      },
      {
        kind: "function",
        path: "vim/options.lua",
        line: 2,
        names: ["M", "show"],
        args: {
          type: "funcargs",
          items: [{ type: "local", value: "options" }],
        },
        docs: [
          {
            type: "doc.param",
            param: { type: "doc.param.name", value: "options" },
            extends: { type: "doc.type.name", value: "Options" },
          },
        ],
      },
    ],
    {
      version: "fixture",
      commands: [],
      functions: [
        {
          path: ["vim", "options", "show"],
          source: "vim/options.lua",
          line: 2,
        },
      ],
    },
  );
  const source = ts.createSourceFile("vim-types.ts", result.declarations, ts.ScriptTarget.Latest, true);
  const options = source.statements.find(
    (statement) => ts.isTypeAliasDeclaration(statement) && statement.name.text === "Lua_Options",
  );
  if (!options || !ts.isTypeAliasDeclaration(options) || !ts.isTypeLiteralNode(options.type)) {
    throw new Error("Missing generated options type");
  }

  expect(ts.getJSDocCommentsAndTags(options).map((doc) => doc.comment)).toEqual(["Display options."]);
  expect(
    options.type.members.map((field) => ts.getJSDocCommentsAndTags(field).map((doc) => doc.comment)),
  ).toEqual([["Zero-based row."], ["Byte column."]]);
});

test("keeps every generated callable and unsupported path aligned with the coverage report and runtime metadata", async () => {
  const source = ts.createSourceFile(
    "vim-types.ts",
    await Bun.file(new URL("../../src/vim/generated/vim-types.ts", import.meta.url)).text(),
    ts.ScriptTarget.Latest,
    true,
  );
  const definition = source.statements.find(
    (statement) => ts.isTypeAliasDeclaration(statement) && statement.name.text === "Vim",
  );
  if (!definition || !ts.isTypeAliasDeclaration(definition)) {
    throw new Error("Missing generated Vim type");
  }

  const supported = new Set<string>();
  const unsupported = new Set<string>();
  const properties = new Map<string, ts.PropertySignature>();
  const visitNamespace = (node: ts.TypeNode, path: string) => {
    if (ts.isParenthesizedTypeNode(node)) {
      visitNamespace(node.type, path);
    } else if (ts.isIntersectionTypeNode(node)) {
      for (const member of node.types) {
        visitNamespace(member, path);
      }
    } else if (ts.isFunctionTypeNode(node)) {
      supported.add(path);
    } else if (node.kind === ts.SyntaxKind.NeverKeyword) {
      unsupported.add(path);
    } else if (ts.isTypeLiteralNode(node)) {
      if (Object.hasOwn(coverage.unsupported, path)) {
        unsupported.add(path);
      }

      for (const member of node.members) {
        if (
          !ts.isPropertySignature(member) ||
          !member.type ||
          (!ts.isIdentifier(member.name) && !ts.isStringLiteral(member.name))
        ) {
          throw new Error(`Unexpected Vim namespace member: ${  member.getText(source)}`);
        }

        const child = `${path  }.${  member.name.text}`;
        properties.set(child, member);
        visitNamespace(member.type, child);
      }
    }
  };

  visitNamespace(definition.type, "vim");
  expect([...supported].sort()).toEqual(coverage.supported);
  expect([...unsupported].sort()).toEqual(Object.keys(coverage.unsupported).sort());
  expect(coverage.omitted).toEqual([]);

  const deprecated = properties.get("vim.api.nvim_get_option");
  if (!deprecated) {
    throw new Error("Missing deprecated API fixture");
  }

  expect(ts.getJSDocDeprecatedTag(deprecated)).toBeDefined();

  for (const [name, value] of Object.entries(metadata.functions)) {
    expect(("unsupported" in value ? unsupported : supported).has(`vim.${  name}`)).toBe(true);
  }
});
