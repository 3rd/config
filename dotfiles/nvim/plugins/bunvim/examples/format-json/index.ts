import { type PluginSetup, readBuffer, replaceBuffer } from "../../src";

const setup: PluginSetup = (plugin) => {
  plugin.registerCommand(
    {
      name: "FormatJSON",
      range: "%",
      desc: "Format JSON in the buffer or range",
    },
    async (context) => {
      const snapshot = await readBuffer(context, {
        start: context.line1 - 1,
        end: context.line2,
      });

      const value: unknown = JSON.parse(snapshot.lines.join("\n"));
      const lines = JSON.stringify(value, null, 2).split("\n");

      await replaceBuffer(context, snapshot, lines);
    },
  );
};

export default setup;
