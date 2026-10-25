return {
  before_init = function(_, config)
    local ok, schemastore = pcall(require, "schemastore")
    if ok then config.settings.yaml.schemas = schemastore.yaml.schemas() end
  end,
  settings = {
    yaml = {
      schemas = {},
    },
  },
}
