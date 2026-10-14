import type { PluginSetup, Registration } from "../../src";
import { captureTheme } from "./theme-preview";

interface ColorschemePicker {
  buffer: number;
  window?: number;
  colorschemes: string[];
  previewedTheme?: string;
  restoreTheme: Awaited<ReturnType<typeof captureTheme>>["restore"];
  registrations: Registration[];
}

const setup: PluginSetup = (plugin) => {
  const { vim, nvim } = plugin;
  let picker: ColorschemePicker | undefined;
  let pendingAction = Promise.resolve();

  const queuePickerAction = (action: () => Promise<void>) => {
    const result = pendingAction.then(action, action);
    pendingAction = result;
    return result;
  };

  const closePicker = async (current: ColorschemePicker, outcome: "accept" | "cancel") => {
    if (picker !== current) return;

    picker = undefined;

    try {
      if (outcome === "cancel") {
        await current.restoreTheme();
      }
    } finally {
      try {
        if (!plugin.signal.aborted) {
          await Promise.all(current.registrations.map((handle) => handle.dispose()));
        }
      } finally {
        const handles = [current.buffer];

        if (current.window !== undefined) {
          handles.push(current.window);
        }

        await nvim.executeLua(
          `
          local buffer, window = ...
          if window and vim.api.nvim_win_is_valid(window) then
            vim.api.nvim_win_close(window, true)
          end

          if vim.api.nvim_buf_is_valid(buffer) then
            vim.api.nvim_buf_delete(buffer, { force = true })
          end
        `,
          handles,
        );
      }
    }
  };

  const previewSelection = async (current: ColorschemePicker) => {
    const { window } = current;
    const isOpen = picker === current && window !== undefined;
    if (!isOpen) return;
    if (!(await vim.api.nvim_win_is_valid(window))) return;

    const [row] = await vim.api.nvim_win_get_cursor(window);

    const colorscheme = current.colorschemes[row - 1];
    const shouldSkipPreview = colorscheme === undefined || colorscheme === current.previewedTheme;
    if (shouldSkipPreview) return;

    try {
      await vim.cmd.colorscheme(colorscheme);
      current.previewedTheme = colorscheme;
    } catch (error) {
      await closePicker(current, "cancel");
      throw error;
    }
  };

  plugin.onDispose(() =>
    queuePickerAction(async () => {
      if (!picker) return;

      await closePicker(picker, "cancel");
    }),
  );

  plugin.registerCommand(
    {
      name: "PickColorscheme",
      desc: "Preview and choose an installed colorscheme",
    },
    (context) =>
      queuePickerAction(async () => {
        context.signal.throwIfAborted();
        const existingWindow = picker?.window;
        const canFocusPicker =
          existingWindow !== undefined && (await vim.api.nvim_win_is_valid(existingWindow));
        if (canFocusPicker) {
          await vim.api.nvim_set_current_win(existingWindow);
          return;
        }

        if (picker) {
          await closePicker(picker, "cancel");
        }

        const colorschemes = await vim.fn.getcompletion("", "color");
        if (colorschemes.length === 0) {
          throw new Error("No colorschemes found");
        }

        const theme = await captureTheme(nvim);
        const buffer = await vim.api.nvim_create_buf(false, true);
        const current: ColorschemePicker = {
          buffer,
          colorschemes,
          previewedTheme: theme.name ?? undefined,
          restoreTheme: theme.restore,
          registrations: [],
        };
        picker = current;

        try {
          await vim.api.nvim_buf_set_lines(buffer, 0, -1, true, colorschemes);
          await vim.bo.at(buffer).set("modifiable", false);
          await vim.bo.at(buffer).set("bufhidden", "wipe");

          const columns = await vim.api.nvim_win_get_width(context.window);
          const rows = await vim.api.nvim_win_get_height(context.window);
          const width = Math.max(1, Math.min(42, columns - 4));
          const height = Math.max(1, Math.min(12, colorschemes.length, rows - 4));

          current.window = await vim.api.nvim_open_win(buffer, false, {
            relative: "win",
            win: context.window,
            row: 1,
            col: Math.max(0, columns - width - 2),
            width,
            height,
            style: "minimal",
            border: "rounded",
            title: " Colorschemes ",
            footer: " j/k preview | Enter keep | Esc cancel ",
          });

          await vim.wo.at(current.window).local.set("cursorline", true);
          await vim.api.nvim_win_set_cursor(current.window, [
            Math.max(0, colorschemes.indexOf(theme.name ?? "")) + 1,
            0,
          ]);

          const cancel = () => queuePickerAction(() => closePicker(current, "cancel"));
          current.registrations.push(
            plugin.registerKeymap({ mode: "n", keys: "<CR>", buffer }, () =>
              queuePickerAction(async () => {
                await previewSelection(current);
                await closePicker(current, "accept");
              }),
            ),
            ...["<Esc>", "q", "<C-c>"].map((keys) =>
              plugin.registerKeymap({ mode: "n", keys, buffer }, cancel),
            ),
            plugin.registerAutocmd({ event: "CursorMoved", buffer }, () =>
              queuePickerAction(() => previewSelection(current)),
            ),
            plugin.registerAutocmd({ event: ["BufLeave", "BufWipeout"], buffer }, cancel),
          );
          await Promise.all(current.registrations.map((handle) => handle.ready));
          context.signal.throwIfAborted();

          await vim.api.nvim_set_current_win(current.window);
          await previewSelection(current);
          context.signal.throwIfAborted();
        } catch (error) {
          await closePicker(current, "cancel");
          throw error;
        }
      }),
  );
};

export default setup;
