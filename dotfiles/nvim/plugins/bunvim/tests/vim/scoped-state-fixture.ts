import type { PluginSetup } from "../../src";
import { requireInteger, requireString } from "../../src/rpc/protocol";

const setup: PluginSetup = (plugin) => {
  plugin.registerFunction("variables", async (_input, { vim, buffer, window }) => {
    const tab = await vim.api.nvim_get_current_tabpage();
    await vim.g.set("bunvim_value", { items: [false, null, "text"] });
    await vim.b.at(buffer).set("bunvim_value", "buffer");
    await vim.w.at(window).set("bunvim_value", "window");
    await vim.t.at(tab).set("bunvim_value", "tab");
    await vim.v.set("errmsg", "scoped-state fixture");
    await vim.env.set("BUNVIM_SCOPED_STATE", "environment");
    const values = {
      global: await vim.g.get("bunvim_value"),
      buffer: await vim.b.get("bunvim_value"),
      window: await vim.w.get("bunvim_value"),
      tab: await vim.t.get("bunvim_value"),
      predefined: await vim.v.get("errmsg"),
      environment: await vim.env.get("BUNVIM_SCOPED_STATE"),
    };
    await vim.g.set("bunvim_null", null);
    await vim.g.set("bunvim_empty_list", []);
    await vim.g.set("bunvim_empty_map", {});
    await vim.g.delete("bunvim_value");
    await vim.b.at(buffer).delete("bunvim_value");
    await vim.w.at(window).delete("bunvim_value");
    await vim.t.at(tab).delete("bunvim_value");
    await vim.env.delete("BUNVIM_SCOPED_STATE");
    return {
      values,
      missing: await vim.g.get("bunvim_value"),
      environmentMissing: await vim.env.get("BUNVIM_SCOPED_STATE"),
      nullValue: await vim.g.get("bunvim_null"),
      emptyList: await vim.g.get("bunvim_empty_list"),
      emptyMap: await vim.g.get("bunvim_empty_map"),
    };
  });

  plugin.registerFunction("targets", async (input, { vim, buffer, window }) => {
    const nextWindow = requireInteger(input, "Next window");
    const boundBuffer = vim.b.at(buffer);
    const boundWindow = vim.w.at(window);
    const currentBuffer = vim.b.at(0);
    await vim.api.nvim_set_current_win(nextWindow);
    await boundBuffer.set("bunvim_target", "captured buffer");
    await boundWindow.set("bunvim_target", "captured window");
    await currentBuffer.set("bunvim_target", "current buffer");
    await vim.w.set("bunvim_target", "current window");
    await vim.bo.at(buffer).set("shiftwidth", 3);
    await vim.bo.set("shiftwidth", 5);
    await vim.wo.at(window).local.set("number", true);
    await vim.wo.local.set("number", false);
    return {
      capturedBuffer: await boundBuffer.get("bunvim_target"),
      capturedWindow: await boundWindow.get("bunvim_target"),
      currentBuffer: await currentBuffer.get("bunvim_target"),
      currentWindow: await vim.w.get("bunvim_target"),
      capturedWidth: await vim.bo.at(buffer).get("shiftwidth"),
      currentWidth: await vim.bo.get("shiftwidth"),
      capturedNumber: await vim.wo.at(window).get("number"),
      currentNumber: await vim.wo.get("number"),
    };
  });

  plugin.registerFunction("options", async (_input, { vim }) => {
    await vim.go.set("number", false);
    await vim.wo.local.set("number", true);
    const localNumberDefault = await vim.go.get("number");
    await vim.wo.set("number", true);
    const windowNumberDefault = await vim.go.get("number");
    await vim.go.set("makeprg", "global-build");
    await vim.bo.set("makeprg", "");
    const inherited = await vim.opt_local.get("makeprg");
    await vim.opt_local.set("makeprg", "local-build");
    const localGlobal = await vim.go.get("makeprg");
    await vim.o.set("makeprg", "both-build");
    const both = {
      effective: await vim.o.get("makeprg"),
      global: await vim.go.get("makeprg"),
      local: await vim.bo.get("makeprg"),
    };
    await vim.opt_global.set("makeprg", "global-only");
    await vim.opt_global.append("makeprg", "-suffix");
    return {
      localNumberDefault,
      windowNumberDefault,
      inherited,
      localGlobal,
      both,
      effective: await vim.opt.get("makeprg"),
      global: await vim.opt_global.get("makeprg"),
    };
  });

  plugin.registerFunction("structured", async (_input, { vim }) => {
    await vim.opt.set("wildignore", ["*.o", "*.a"]);
    await Promise.all([
      vim.opt.append("wildignore", ["node_modules"]),
      vim.opt.append("wildignore", ["cache"]),
    ]);
    await vim.opt.prepend("wildignore", ["build"]);
    await vim.opt.remove("wildignore", ["*.a"]);
    await vim.opt_local.set("listchars", { space: "_", tab: ">~" });
    await vim.opt_local.append("listchars", { eol: "$" });
    await vim.opt_local.remove("listchars", ["space"]);
    await vim.opt_local.set("formatoptions", { j: true });
    await vim.opt_local.append("formatoptions", "r");
    await vim.opt_local.remove("formatoptions", "j");
    const values = {
      list: await vim.opt.get("wildignore"),
      map: await vim.opt_local.get("listchars"),
      flags: await vim.opt_local.get("formatoptions"),
    };
    await vim.opt.set("wildignore", []);
    await vim.opt.set("listchars", {});
    await vim.opt_local.set("formatoptions", {});
    return {
      values,
      emptyList: await vim.opt.get("wildignore"),
      emptyMap: await vim.opt_local.get("listchars"),
      emptyFlags: await vim.opt_local.get("formatoptions"),
    };
  });

  plugin.registerFunction("failure", async (input, { vim }) => {
    const operation = requireString(input, "Operation");
    if (operation === "buffer") return vim.b.at(-999).get("missing");
    if (operation === "option") return vim.o.get("bunvim_unknown_option");
    if (operation === "scope") return vim.bo.get("number");
    if (operation === "type") return vim.bo.set("shiftwidth", "wrong");
    if (operation === "fixed") return vim.v.delete("errmsg");

    throw new Error("Unknown failure operation");
  });
};

export default setup;
