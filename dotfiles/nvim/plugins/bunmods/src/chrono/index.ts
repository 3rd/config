import type { PluginSetup } from "bunvim";
import { parseSchedule } from "./schedule";
import { setSchedule } from "./schedule-action";

const setup: PluginSetup = (plugin) => {
  plugin.registerFunction("toSchedule", (input) => {
    if (typeof input !== "string") {
      throw new TypeError("Schedule input must be a string");
    }

    return parseSchedule(input);
  });

  plugin.registerFunction("setSchedule", (_input, context) => setSchedule(context));
};

export default setup;
