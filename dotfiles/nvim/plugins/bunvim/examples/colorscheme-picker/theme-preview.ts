import type { NeovimClient } from "../../src";

interface CapturedTheme {
  name: string | null;
  snapshot: string;
}

const isCapturedTheme = (value: unknown): value is CapturedTheme =>
  typeof value === "object" &&
  value !== null &&
  "name" in value &&
  (typeof value.name === "string" || value.name === null) &&
  "snapshot" in value &&
  typeof value.snapshot === "string";

export const captureTheme = async (nvim: NeovimClient) => {
  const value: unknown = await nvim.executeLua(
    `
    local palette = {}

    for index = 0, 15 do
      local name = "terminal_color_" .. index
      palette[name] = vim.g[name]
    end

    local name = vim.g.colors_name
    return {
      name = name or vim.NIL,
      snapshot = vim.json.encode({
        name = name,
        background = vim.o.background,
        highlights = vim.api.nvim_get_hl(0, {}),
        palette = palette,
      }),
    }
  `,
    [],
  );
  if (!isCapturedTheme(value)) {
    throw new Error("Could not capture the current theme");
  }
  const { name, snapshot } = value;

  const restore = async () => {
    await nvim.executeLua(
      `
      local snapshot = vim.json.decode(...)
      vim.g.colors_name = nil
      vim.o.background = snapshot.background
      vim.cmd("highlight clear")

      for name, highlight in pairs(snapshot.highlights) do
        vim.api.nvim_set_hl(0, name, highlight)
      end

      vim.g.colors_name = snapshot.name

      for index = 0, 15 do
        local name = "terminal_color_" .. index
        vim.g[name] = snapshot.palette[name]
      end

      vim.api.nvim_exec_autocmds("ColorScheme", { pattern = snapshot.name or "", modeline = false })
    `,
      [snapshot],
    );
  };

  return { name, restore };
};
