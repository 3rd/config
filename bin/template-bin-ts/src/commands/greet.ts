import type { Cli } from "gunsmith";
import { z } from "zod";
import { createGreeting } from "../greeting";

const greetOutputSchema = z.object({
  message: z.string(),
});

export const registerGreetCommand = (app: Cli) =>
  app.command("greet", {
    description: "Print a greeting.",
    args: z.object({
      name: z.string().trim().min(1).describe("Name to greet"),
    }),
    options: z.object({
      excited: z.boolean().optional().meta({ alias: "e" }).describe("Add enthusiasm"),
    }),
    outputSchema: greetOutputSchema,
    examples: [
      { command: `${app.name} greet Ada` },
      { command: `${app.name} greet Ada --excited` },
    ],
    run: ({ args, options }) => {
      const greeting = createGreeting(args.name, options.excited);
      console.log(greeting.message);
      return greeting;
    },
  });
