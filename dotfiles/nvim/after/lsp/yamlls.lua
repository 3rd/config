return {
  settings = {
    yaml = {
      schemas = {},
    },
  },
  on_new_config = function(new_config)
    local ok, schemastore = pcall(require, "schemastore")
    if not ok then return end
    new_config.settings = new_config.settings or {}
    new_config.settings.yaml = new_config.settings.yaml or {}
    new_config.settings.yaml.schemas = schemastore.yaml.schemas()
  end,
}
