return {
  filetypes = { "json", "jsonc" },
  root_markers = { ".git" },
  init_options = {
    provideFormatter = true,
  },
  settings = {
    json = {
      schemas = {},
      validate = { enable = true },
    },
  },
  on_new_config = function(new_config)
    local ok, schemastore = pcall(require, "schemastore")
    if not ok then return end
    new_config.settings = new_config.settings or {}
    new_config.settings.json = new_config.settings.json or {}
    new_config.settings.json.schemas = schemastore.json.schemas()
  end,
}
