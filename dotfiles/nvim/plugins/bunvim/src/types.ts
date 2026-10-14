import type { NeovimClient } from "neovim";
import type { Vim } from "./vim/generated/vim-types";

export type RpcValue =
  | RpcValue[]
  | Uint8Array
  | { [key: string]: RpcValue }
  | boolean
  | number
  | string
  | null;

export type HandlerResult = RpcValue | void;
export type Dispose = () => Promise<void> | void;

export interface Registration {
  ready: Promise<void>;
  dispose(): Promise<void>;
}

export interface BufferSubscriptionOptions {
  buffer: number;
  maxQueued?: number;
}

export type BufferEvent =
  | { type: "changedtick"; buffer: number; changedtick: number }
  | { type: "detach"; buffer: number }
  | {
      type: "lines";
      buffer: number;
      changedtick: number;
      firstLine: number;
      lastLine: number;
      lines: string[];
      hasMore: boolean;
    }
  | { type: "snapshot"; buffer: number; changedtick: number; lines: string[] };

export interface BufferSubscriptionContext {
  signal: AbortSignal;
}

export type BufferHandler = (event: BufferEvent, context: BufferSubscriptionContext) => Promise<void> | void;

export type BufferSubscriptionResult =
  | { reason: "detached" | "disposed" | "overflow" }
  | { reason: "error"; error: Error };

export interface BufferSubscription extends Registration {
  closed: Promise<BufferSubscriptionResult>;
}

export interface InvocationContext {
  nvim: NeovimClient;
  vim: Vim;
  signal: AbortSignal;
  buffer: number;
  window: number;
  cwd: string;
}

export interface CommandContext extends InvocationContext {
  args: string;
  fargs: string[];
  bang: boolean;
  line1: number;
  line2: number;
  range: number;
  count: number;
  reg: string;
}

export interface AutocmdContext extends InvocationContext {
  event: string;
  match: string;
  file: string;
  data: unknown;
}

export interface CompletionContext extends InvocationContext {
  argLead: string;
  cmdLine: string;
  cursorPos: number;
}

export type CompletionHandler = (context: CompletionContext) => Promise<string[]> | string[];

export type FunctionHandler = (
  input: unknown,
  context: InvocationContext,
) => HandlerResult | Promise<HandlerResult>;
export type CommandHandler = (context: CommandContext) => HandlerResult | Promise<HandlerResult>;
export type AutocmdHandler = (context: AutocmdContext) => HandlerResult | Promise<HandlerResult>;
export type KeymapHandler = (context: InvocationContext) => HandlerResult | Promise<HandlerResult>;

export interface CommandOptions {
  name: string;
  nargs?: "?" | "*" | "+" | 0 | 1;
  bang?: boolean;
  range?: "%" | boolean;
  count?: number;
  complete?: CompletionHandler | string;
  desc?: string;
}

export interface AutocmdOptions {
  event: string[] | string;
  pattern?: string[] | string;
  buffer?: number;
  once?: boolean;
  desc?: string;
  execution?: "async" | "sync";
}

export interface KeymapOptions {
  mode: string[] | string;
  keys: string;
  buffer?: number;
  desc?: string;
  silent?: boolean;
  expr?: boolean;
}

export interface PluginContext {
  name: string;
  nvim: NeovimClient;
  vim: Vim;
  options: unknown;
  signal: AbortSignal;
  registerFunction(name: string, handler: FunctionHandler): Registration;
  registerCommand(options: CommandOptions, handler: CommandHandler): Registration;
  registerAutocmd(options: AutocmdOptions, handler: AutocmdHandler): Registration;
  registerKeymap(options: KeymapOptions, handler: KeymapHandler): Registration;
  subscribeBuffer(options: BufferSubscriptionOptions, handler: BufferHandler): BufferSubscription;
  onDispose(dispose: Dispose): void;
}

export type PluginSetup = (context: PluginContext) => Promise<void> | void;

export interface BufferSnapshot {
  buffer: number;
  changedtick: number;
  start: number;
  end: number;
  lines: string[];
}
