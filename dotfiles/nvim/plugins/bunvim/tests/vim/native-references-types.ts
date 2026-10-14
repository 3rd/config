import type { RpcValue, TreeSitterCapture, TreeSitterNodeSnapshot, Vim } from "../../src";

const checkNativeReferenceTypes = async (vim: Vim) => {
  const parser = await vim.treesitter.get_string_parser("return 1", "lua");
  const trees = await parser.parse();
  if (!trees) return;

  const tree = Object.values(trees)[0];
  if (!tree) return;

  const root = await tree.root();
  const children = await root.iter_children();

  for await (const [, field] of children) {
    const fieldName: string | null = field;
    // @ts-expect-error A child without a field name returns null.
    const requiredField: string = field;
  }

  const nodeType: string = await root.type();
  const range: [number, number, number, number] = await root.range();
  const byteRange: [number, number, number, number, number, number] = await root.range(true);
  const bytes: Uint8Array = await root.id();
  const text: string = await vim.treesitter.get_node_text(root, "return 1");
  const walk = await root.walk({ direction: "ancestors", includeSelf: true });
  const batch = await walk.nextBatch({ limit: 10 });
  const nodes: TreeSitterNodeSnapshot[] = batch.items;
  const isDone: boolean = batch.isDone;
  const query = await vim.treesitter.query.parse("lua", "(number) @value");
  const names: string[] = await query.get("captures");
  const captures = await query.captureSnapshots(root, "return 1");
  const values: TreeSitterCapture[] = [];

  for await (const capture of captures) {
    values.push(capture);
  }

  const client = await vim.lsp.get_client_by_id(1);

  if (client) {
    const id: number = await client.get("id");
    const name: string = await client.get("name");
    const supportsHover: boolean = await client.supports_method("textDocument/hover");
    const [error, result, context] = await client.request("textDocument/hover", {});
    const requestError: string | undefined = error?.message;
    const response: RpcValue = result;
    const clientId: number = context.client_id;
    const notified: boolean = await client.notify("workspace/didChangeConfiguration", { settings: {} });
    await client.cancel_request(1);
    await client.dispose();
    // @ts-expect-error Native client fields are explicit and live.
    await client.get("unknown_field");
    // @ts-expect-error The completion callback is replaced by the request promise.
    await client.request("textDocument/hover", {}, () => {});
  }

  // @ts-expect-error Native references cannot be returned as serializable plugin results.
  const serialized: RpcValue = root;
  // @ts-expect-error Tree traversal direction is a named operation.
  await root.walk({ direction: "sideways" });
  // @ts-expect-error Native methods retain their input types.
  await root.named_child("first");
  // @ts-expect-error Query fields require asynchronous reads.
  const captureNames: string[] = query.captures;
  await query.dispose();
  await parser.dispose();
};
