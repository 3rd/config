import API from "./api";
import * as modules from "./modules";
import type { NvimPlugin } from "neovim";

export default function myplugin(plugin: NvimPlugin) {
  plugin.setOptions({
    dev: false, // reload module on invocation
    alwaysInit: false, // init on each invocation
  });

  for (const [moduleName, mod] of Object.entries(modules)) {
    for (const [fnName, fn] of Object.entries(mod)) {
      const name = `Node_${moduleName}_${fnName}`;
      const isAsync = fn.constructor.name === "AsyncFunction";
      const api = new API(plugin);
      plugin.registerFunction(name, ([input]) => fn({ api, plugin, input }), { sync: !isAsync });
    }
  }
}
