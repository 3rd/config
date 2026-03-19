local schemas = {}
local ok, schemastore = pcall(require, "schemastore")
if ok then
  schemas = schemastore.json.schemas()
end

return {
  filetypes = { "json", "jsonc" },
  root_markers = { ".git" },
  init_options = {
    provideFormatter = true,
  },
  settings = {
    json = {
      schemas = schemas,
      validate = { enable = true },
    },
  },
}
