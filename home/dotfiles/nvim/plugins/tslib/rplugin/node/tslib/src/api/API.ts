// https://github.dev/neovim/node-client/tree/master/packages/neovim/src/api/Neovim.ts

import type { NvimPlugin } from "neovim";

class API {
  plugin: NvimPlugin;

  constructor(plugin: NvimPlugin) {
    this.plugin = plugin;
  }

  get nvim() {
    return this.plugin.nvim;
  }

  cmd(cmd: string) {
    return this.plugin.nvim.commandOutput(cmd);
  }

  fn: Record<string, (...args: unknown[]) => Promise<unknown>> = new Proxy(
    {},
    {
      get: (_, name: string) => {
        return (...args: unknown[]) => {
          return this.plugin.nvim.callFunction(name, args);
        };
      },
    }
  );

  fnAtomic(calls: [string, unknown[]][]): Promise<unknown[] | [number, string, string]> {
    return this.plugin.nvim.callAtomic(calls);
  }
}

export default API;
