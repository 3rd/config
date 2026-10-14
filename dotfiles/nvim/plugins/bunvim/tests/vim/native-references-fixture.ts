import type { PluginSetup, Vim } from "../../src";
import { requireInteger } from "../../src/rpc/protocol";

type Parser = Awaited<ReturnType<Vim["treesitter"]["get_string_parser"]>>;
type Client = NonNullable<Awaited<ReturnType<Vim["lsp"]["get_client_by_id"]>>>;

const requireClient = async (vim: Vim, input: unknown) => {
  const client = await vim.lsp.get_client_by_id(requireInteger(input, "Client ID"));
  if (!client) {
    throw new Error("Fixture client is missing");
  }

  return client;
};

const readRoot = async (parser: Parser) => {
  const trees = await parser.parse();
  if (!trees) {
    throw new Error("Fixture parser returned no trees");
  }

  const tree = Object.values(trees)[0];
  if (!tree) {
    throw new Error("Fixture parser returned an empty tree list");
  }

  return tree.root();
};

const setup: PluginSetup = (plugin) => {
  let retainedParser: Parser | undefined;
  let retainedClient: Client | undefined;

  plugin.registerFunction("barrier", (_input, { vim }) => vim.api.nvim_get_current_buf());
  plugin.registerFunction("syntax", async (_input, { vim }) => {
    const source = "local value = 7\nreturn value";
    const parser = await vim.treesitter.get_string_parser(source, "lua");
    const root = await readRoot(parser);
    const tree = await root.tree();
    const children = await root.iter_children();
    const childFields: (string | null)[] = [];

    for await (const [, field] of children) {
      childFields.push(field);
    }

    const node = await root.named_descendant_for_range(0, 6, 0, 11);
    if (!node) {
      throw new Error("Fixture identifier is missing");
    }

    const parent = await node.parent();
    if (!parent) {
      throw new Error("Fixture identifier has no parent");
    }

    const ancestors = await node.walk({
      direction: "ancestors",
      includeSelf: true,
    });
    const firstAncestors = await ancestors.nextBatch({ limit: 2 });
    const ancestorTypes = firstAncestors.items.map((item) => item.type);

    for await (const ancestor of ancestors) {
      ancestorTypes.push(ancestor.type);
    }

    const descendants = await root.walk({
      direction: "descendants",
      namedOnly: true,
    });
    const descendantTypes: string[] = [];

    for await (const descendant of descendants) {
      descendantTypes.push(descendant.type);
    }

    const earlyExit = await root.walk({ direction: "descendants" });
    const earlyExitTypes: string[] = [];

    for await (const descendant of earlyExit) {
      earlyExitTypes.push(descendant.type);
      break;
    }

    let earlyExitError = "";

    try {
      await earlyExit.nextBatch();
    } catch (error) {
      earlyExitError = error instanceof Error ? error.message : String(error);
    }

    const query = await vim.treesitter.query.parse(
      "lua",
      '((identifier) @name (#set! priority 120) (#set! @name conceal "x"))',
    );
    const queryInfo = await query.get("info");
    const captures = await query.captureSnapshots(root, source);
    const firstCaptures = await captures.nextBatch({ limit: 1 });
    const captureValues = [...firstCaptures.items];

    for await (const capture of captures) {
      captureValues.push(capture);
    }

    const nativeCaptures = await query.iter_captures(root, source);
    const firstNativeCapture = (await nativeCaptures.nextBatch({ limit: 1 })).items[0];
    if (!firstNativeCapture) {
      throw new Error("Fixture query has no native capture");
    }

    const [captureId, capturedNode, metadata, match, capturedTree] = firstNativeCapture;
    const [, pattern] = await match.info();
    const matchNodes = await match.captures();
    const capturedMatchNodes = matchNodes[captureId];
    if (!capturedMatchNodes) {
      throw new Error("Fixture match has no capture group");
    }

    const matchedNode = capturedMatchNodes[0];
    if (!matchedNode) {
      throw new Error("Fixture match has no captured node");
    }

    const rawCapture = {
      id: captureId,
      type: await capturedNode.type(),
      treeType: await (await capturedTree.root()).type(),
      matchedType: await matchedNode.type(),
      pattern,
      metadata,
    };

    await nativeCaptures.dispose();
    let iteratorError = "";

    try {
      await nativeCaptures.nextBatch();
    } catch (error) {
      iteratorError = error instanceof Error ? error.message : String(error);
    }

    const result = {
      rootType: await root.type(),
      includedRanges: await tree.included_ranges(false),
      includedByteRanges: await tree.included_ranges(true),
      childFields,
      nodeType: await node.type(),
      nodeRange: await node.range(),
      nodeText: await vim.treesitter.get_node_text(node, source),
      parentType: await parent.type(),
      ancestorTypes,
      hasMoreAncestors: !firstAncestors.isDone,
      descendantTypes,
      earlyExitTypes,
      earlyExitError,
      captureNames: await query.get("captures"),
      hasMoreCaptures: !firstCaptures.isDone,
      captures: captureValues.map(({ name, type, range, text, metadata }) => ({
        name,
        type,
        range,
        text,
        metadata,
      })),
      queryPatterns: queryInfo.patterns,
      nodeId: await node.id(),
      rawCapture,
      iteratorError,
    };

    await root.dispose();
    let releasedError = "";

    try {
      await root.type();
    } catch (error) {
      releasedError = error instanceof Error ? error.message : String(error);
    }

    return { ...result, releasedError };
  });
  plugin.registerFunction("rememberBufferParser", async (input) => {
    const [parser, error] = await plugin.vim.treesitter.get_parser(requireInteger(input, "Buffer"), "lua");
    if (!parser) {
      throw new Error(error ?? "Fixture buffer parser is missing");
    }

    retainedParser = parser;
    return (await readRoot(parser)).sexpr();
  });
  plugin.registerFunction("rememberInvocationParser", async (_input, { vim }) => {
    retainedParser = await vim.treesitter.get_string_parser("return 9", "lua");
    return null;
  });
  plugin.registerFunction("readRetainedParser", async () => {
    if (!retainedParser) {
      throw new Error("Fixture has no retained parser");
    }

    return (await readRoot(retainedParser)).sexpr();
  });
  plugin.registerFunction("readRetainedRange", async (_input, { vim }) => {
    if (!retainedParser) {
      throw new Error("Fixture has no retained parser");
    }

    return vim.treesitter.get_node_range(await readRoot(retainedParser));
  });
  plugin.registerFunction("disposeRetainedParser", async () => {
    if (!retainedParser) {
      throw new Error("Fixture has no retained parser");
    }

    await retainedParser.dispose();
    return null;
  });
  plugin.registerFunction("clients", async (_input, { vim }) => {
    const clients = await vim.lsp.get_clients({
      name: "bunvim-native-fixture",
    });
    return Promise.all(
      clients.map(async (client) => ({
        id: await client.get("id"),
        name: await client.get("name"),
      })),
    );
  });
  plugin.registerFunction("rememberClient", async (input) => {
    retainedClient = await requireClient(plugin.vim, input);
    return retainedClient.get("id");
  });
  plugin.registerFunction("clientSupportsHover", async () => {
    if (!retainedClient) {
      throw new Error("Fixture has no retained client");
    }

    return retainedClient.supports_method("textDocument/hover", 0);
  });
  plugin.registerFunction("clientCapabilities", async (input, { vim }) => {
    const client = await requireClient(vim, input);
    return client.get("server_capabilities");
  });
  plugin.registerFunction("request", async (input, { vim }) => {
    const client = await requireClient(vim, input);
    return client.request("textDocument/hover", {}, 0);
  });
  plugin.registerFunction("notify", async (input, { vim }) => {
    const client = await requireClient(vim, input);
    return client.notify("workspace/didChangeConfiguration", {
      settings: { fixture: "notification" },
    });
  });
  plugin.registerFunction(
    "missingClient",
    async (_input, { vim }) => (await vim.lsp.get_client_by_id(-1)) === null,
  );
};

export default setup;
