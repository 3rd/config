import { type PluginSetup, readBuffer } from "../../src";

const setup: PluginSetup = (plugin) => {
  plugin.registerCommand(
    { name: "TodoList", desc: "List this buffer's TODO and FIXME markers" },
    async (context) => {
      const snapshot = await readBuffer(context);

      const items = snapshot.lines.flatMap((line, index) => {
        const match = /\b(TODO|FIXME)\b/.exec(line);
        if (!match) return [];

        return [
          {
            bufnr: snapshot.buffer,
            lnum: index + 1,
            col: Buffer.byteLength(line.slice(0, match.index), "utf8") + 1,
            text: line.trim(),
          },
        ];
      });

      const result = await context.vim.fn.setqflist([], " ", {
        title: "TODO/FIXME",
        items,
      });
      if (result !== 0) {
        throw new Error("Could not create the TODO list");
      }

      if (items.length === 0) {
        await context.vim.notify("No TODO or FIXME markers in this buffer.");
        return;
      }

      await context.vim.cmd.copen();
    },
  );
};

export default setup;
