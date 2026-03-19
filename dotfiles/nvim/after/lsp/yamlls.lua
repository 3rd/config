local schemas = {}
local ok, schemastore = pcall(require, "schemastore")
if ok then
  schemas = schemastore.yaml.schemas()
end

return {
  settings = {
    yaml = {
      schemas = schemas,
    },
  },
}
