import type { PluginSetup } from "../../src";
import { requireString } from "../../src/rpc/protocol";

const setup: PluginSetup = async (plugin) => {
  const setupBuffer = await plugin.vim.api.nvim_get_current_buf();
  plugin.registerFunction("roundtrip", async (_input, { vim }) => {
    const buffer = await vim.api.nvim_get_current_buf();
    await vim.api.nvim_buf_set_lines(buffer, 0, -1, true, ["alpha", "beta"]);
    await vim.lsp.util.apply_text_edits(
      [
        {
          range: {
            start: { line: 0, character: 0 },
            end: { line: 0, character: 5 },
          },
          newText: "changed",
        },
      ],
      buffer,
      "utf-8",
    );

    return {
      buffer,
      setupBuffer,
      lines: await vim.api.nvim_buf_get_lines(buffer, 0, -1, true),
      cwd: await vim.fn.getcwd(),
      basename: await vim.fs.basename("/tmp/report.txt"),
      width: await vim.fn.strdisplaywidth("abc"),
      filetype: await vim.filetype.match({ filename: "report.ts" }),
      level: vim.log.levels.INFO,
      description: await vim.inspect({ name: "example" }),
      version: await vim.version(),
      parsedVersion: await vim.version.parse("1.2.3"),
      nodeRange: await vim.treesitter.get_node_range([1, 2, 3, 4]),
      layout: await vim.fn.winlayout(),
      configPath: await vim.fn.stdpath("config"),
      converted: await vim.iconv("text", "utf-8", "utf-8"),
      diagnosticFloat: await vim.diagnostic.open_float({}),
      difference: await vim.text.diff("same\n", "same\n", {
        result_type: "indices",
      }),
      canLog: await vim.lsp.log.debug(),
      logged: await vim.lsp.log.debug("bunvim synthetic log entry"),
      codelensRefresh: await vim.lsp.codelens.on_refresh(null, null, {
        method: "workspace/codeLens/refresh",
        client_id: 0,
      }),
    };
  });
  plugin.registerFunction("configureLsp", async (_input, { vim }) => {
    await vim.lsp.config("bunvim_fixture", { cmd: ["unused"] });
    return true;
  });
  plugin.registerFunction("metadataErrata", async (input, { vim }) => {
    const directory = requireString(input, "Fixture directory");
    return {
      isLetter: (await vim.fn.char2nr("A")) === 65,
      isCommand: (await vim.fn.exists(":edit")) === 2,
      isWritableDirectory: (await vim.fn.filewritable(directory)) === 2,
      missingEnvironment: await vim.fn.getenv("BUNVIM_MISSING_FIXTURE"),
      isMissingFile: (await vim.fn.getftype(`${directory  }/missing-file`)) === "",
      formatted: await vim.fn.printf("%s %s", "one", "two"),
      unplaced: await vim.fn.sign_unplacelist([]),
      emptyLayout: await vim.fn.winlayout(999),
    };
  });
  plugin.registerFunction("uv", async (input, { vim }) => {
    const path = requireString(input, "Fixture path");
    const [descriptor, openError] = await vim.uv.fs_open(path, "r", 0);
    if (descriptor === null) {
      throw new Error(requireString(openError, "File open error"));
    }

    try {
      return {
        cwd: await vim.uv.cwd(),
        version: await vim.uv.version_string(),
        stat: await vim.uv.fs_stat(path),
        descriptorStat: await vim.uv.fs_fstat(descriptor),
        missing: await vim.uv.fs_stat(`${path  }.missing`),
        missingOwner: await vim.uv.fs_lchown(`${path  }.missing`, -1, -1),
      };
    } finally {
      const [hasClosed, closeError] = await vim.uv.fs_close(descriptor);
      if (!hasClosed) {
        throw new Error(requireString(closeError, "File close error"));
      }
    }
  });
  plugin.registerFunction("input", (prompt, { vim }) =>
    vim.ui.input({
      prompt: requireString(prompt, "Prompt"),
      default: undefined,
    }),
  );
  plugin.registerFunction("command", async (_input, { vim }) => {
    await vim.cmd("normal! gg");
    await vim.cmd.normal({ args: ["j"], bang: true });
    return vim.api.nvim_win_get_cursor(0);
  });
  plugin.registerFunction("select", (_input, { vim }) =>
    vim.ui.select([{ id: 1 }, { id: 2 }], { prompt: "Pick an item" }),
  );
  plugin.registerFunction("listeners", () => plugin.nvim.listenerCount("notification"));
  plugin.registerFunction("fail", (_input, { vim }) => vim.api.nvim_buf_get_lines(-999, 0, -1, true));
  plugin.registerFunction("invalidArgument", async (_input, { vim }) => {
    try {
      await Reflect.apply(vim.fn.string, undefined, [() => null]);
    } catch (error) {
      if (error instanceof Error) return error.message;

      throw error;
    }

    throw new Error("Fixture invalid argument was accepted");
  });
  plugin.registerFunction("argumentGetterFailure", async (_input, { vim }) => {
    const value = {
      get field(): never {
        throw new TypeError("fixture getter failed");
      },
    };

    try {
      await vim.fn.string(value);
    } catch (error) {
      if (error instanceof Error) return error.message;

      throw error;
    }

    throw new Error("Fixture argument getter did not fail");
  });
  plugin.registerFunction("nativeOnly", (input, { vim }) => {
    const name = requireString(input, "Function name");
    let method: unknown = Reflect.get(vim, name);
    if (name === "range.new") {
      method = vim.range.new;
    } else if (name === "range.has") {
      method = vim.range.has;
    } else if (name === "uv.new_timer") {
      method = vim.uv.new_timer;
    }

    if (typeof method !== "function") {
      throw new TypeError("Expected a proxy function");
    }

    return method(name === "regex" ? "abc" : ["true"]);
  });
};

export default setup;
