import type API from "./api";
import type { NvimPlugin } from "neovim";

export type RPCFunction<T, U = unknown> = (args: { plugin: NvimPlugin; input: T; api: API }) => Promise<U> | U;
