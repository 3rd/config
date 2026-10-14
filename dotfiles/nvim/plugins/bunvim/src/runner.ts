import { attach } from "neovim";
import { installConsole } from "./host/diagnostics";
import { createHost } from "./host/plugin-host";
import { formatError, isRecord } from "./rpc/protocol";
import { encodeRpcValue } from "./rpc/value-codec";

interface RpcResponse {
  send(value: unknown, isError?: boolean): void;
}

interface ResponseFrame {
  response: RpcResponse;
  isSettled: boolean;
  isError: boolean;
  result: unknown;
}

const isRpcResponse = (value: unknown): value is RpcResponse =>
  isRecord(value) && typeof value.send === "function";

const runHost = async () => {
  installConsole();
  const nvim = attach({ reader: process.stdin, writer: process.stdout });
  const ready = nvim.channelId.then((channel) => ({
    channel,
    host: createHost(nvim, channel),
  }));
  let isStopping = false;
  const responses: ResponseFrame[] = [];

  nvim.on("request", async (method: string, args: unknown[], response: unknown) => {
    if (!isRpcResponse(response)) {
      throw new Error("Invalid native RPC response");
    }

    const frame: ResponseFrame = {
      response,
      isSettled: false,
      isError: false,
      result: null,
    };
    responses.push(frame);
    try {
      const { host } = await ready;
      if (isStopping) {
        throw new Error("Bunvim is stopping");
      }

      if (method !== "bunvim:sync") {
        throw new Error(`Unknown synchronous operation: ${  method}`);
      }

      frame.result = encodeRpcValue(await host.invoke(args));
    } catch (error) {
      frame.isError = true;
      frame.result = formatError(error);
    }

    frame.isSettled = true;
    while (responses.at(-1)?.isSettled) {
      const settled = responses.pop();
      if (settled) {
        settled.response.send(settled.result, settled.isError);
      }
    }
  });

  nvim.on("notification", async (method: string, args: unknown[]) => {
    const { host } = await ready;
    if (method === "bunvim:shutdown") {
      if (isStopping) return;
      isStopping = true;
      host.shutdown().then(() => process.exit(0));
      return;
    }

    if (!isStopping && method.startsWith("bunvim:")) {
      host.dispatch(method, args);
    }
  });
  nvim.on("disconnect", () => process.exit(0));
  const { channel } = await ready;
  if (isStopping) return;
  nvim.notify("nvim_exec_lua", ["require('bunvim')._ready(...)", [channel]]);
};

await runHost();
