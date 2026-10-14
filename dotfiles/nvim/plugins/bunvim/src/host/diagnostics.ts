import { AsyncLocalStorage } from "node:async_hooks";
import { Console } from "node:console";
import { Writable } from "node:stream";
import { formatError } from "../rpc/protocol";

interface DiagnosticContext {
  plugin: string;
  operation: string;
}

export const diagnosticContext = new AsyncLocalStorage<DiagnosticContext>();

export const formatPluginError = (error: unknown, context: DiagnosticContext) =>
  `[${context.plugin}:${context.operation}] ${formatError(error)}`;

export const installConsole = () => {
  const output = new Writable({
    write(chunk: Buffer, _encoding, done) {
      const context = diagnosticContext.getStore();
      const prefix = context ? `[${context.plugin}:${context.operation}] ` : "[host] ";
      process.stderr.write(prefix + chunk.toString());
      done();
    },
  });
  const logger = new Console(output, output);
  Object.assign(console, logger, {
    write: (...values: string[]) => output.write(values.join("")),
  });
};
