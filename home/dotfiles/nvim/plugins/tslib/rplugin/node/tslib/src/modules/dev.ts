import { RPCFunction } from "../types";

export const test: RPCFunction<string> = ({ plugin, api }) => {
  return api.fn.bufnr("%");
};
