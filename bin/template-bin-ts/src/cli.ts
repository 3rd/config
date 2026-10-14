import { basename, dirname } from "node:path";
import cli from "gunsmith";
import { version } from "../package.json";
import { registerGreetCommand } from "./commands/greet";

const CLI_NAME = basename(dirname(import.meta.dir));

export const createCli = () =>
  registerGreetCommand(
    cli.create(CLI_NAME, {
      version,
      description: "A starter Bun TypeScript CLI.",
      features: {
        mcp: false,
        schema: false,
        llms: false,
      },
    })
  );

export const runCli = async (argv = process.argv.slice(2)) => {
  await createCli().serve(argv);
};
