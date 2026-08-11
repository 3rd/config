require("lib")

local picker_ui_loads = 0
local grep_renderer_loads = 0
local picker_opens = 0
local setup_opts = nil

local picker_ui = {
  state = {},
  calculate_layout_dimensions = function()
    return {}
  end,
  create_ui = function()
    return true
  end,
  relayout = function() end,
  update_results_sync = function() end,
  close = function() end,
}

local fff = {
  setup = function(opts)
    setup_opts = opts
  end,
  find_files = function()
    picker_opens = picker_opens + 1
  end,
  find_files_in_dir = function() end,
  live_grep = function() end,
  open_file_under_cursor = function() end,
}

package.preload["fff"] = function()
  return fff
end
package.preload["fff.picker_ui"] = function()
  picker_ui_loads = picker_ui_loads + 1
  return picker_ui
end
package.preload["fff.grep.grep_renderer"] = function()
  grep_renderer_loads = grep_renderer_loads + 1
  return {}
end
package.preload["fff.treesitter_hl"] = function()
  return {
    lang_from_filename = function() end,
    get_line_highlights = function()
      return {}
    end,
  }
end

local plugin = require("modules/workflow/fzf").plugins[3]
assert(plugin.lazy == true, "FFF is not lazy-loaded")
plugin.config(nil, plugin.opts)

assert(setup_opts.lazy_sync == true, "FFF setup did not enable lazy indexing")
assert(picker_ui_loads == 0, "FFF setup loaded the picker UI")
assert(grep_renderer_loads == 0, "FFF setup loaded the grep renderer")

fff.find_files()

assert(picker_ui_loads == 1, "first FFF picker use did not load the picker UI")
assert(grep_renderer_loads == 1, "first FFF picker use did not load the grep renderer")
assert(picker_opens == 1, "first FFF picker use did not open the picker")

print("ok: FFF defers picker initialization until first use")
