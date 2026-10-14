import type { RpcValue } from "../types";

export interface NativeReference<Fields extends object> {
  get<Key extends keyof Fields>(field: Key): Promise<Fields[Key]>;
  dispose(): Promise<void>;
}

export interface NativeBatchOptions {
  limit?: number;
}

export interface NativeBatch<Item> {
  items: Item[];
  isDone: boolean;
}

export interface NativeIterator<Item> extends AsyncIterable<Item> {
  nextBatch(options?: NativeBatchOptions): Promise<NativeBatch<Item>>;
  dispose(): Promise<void>;
}

export interface TreeSitterWalkOptions {
  direction: "ancestors" | "descendants";
  includeSelf?: boolean;
  namedOnly?: boolean;
}

export interface TreeSitterNodeSnapshot {
  type: string;
  range: [number, number, number, number];
  depth: number;
}

export interface TreeSitterNodeOperations {
  walk(options: TreeSitterWalkOptions): Promise<NativeIterator<TreeSitterNodeSnapshot>>;
}

export interface TreeSitterCaptureOptions {
  startRow?: number;
  endRow?: number;
}

export interface TreeSitterCapture {
  id: number;
  name: string;
  type: string;
  range: [number, number, number, number];
  text: string;
  metadata: RpcValue;
}

export interface TreeSitterQueryOperations<Node> {
  captureSnapshots(
    node: Node,
    source: number | string,
    options?: TreeSitterCaptureOptions,
  ): Promise<NativeIterator<TreeSitterCapture>>;
}
