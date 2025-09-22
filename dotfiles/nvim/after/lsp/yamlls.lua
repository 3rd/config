local schemastore = require("schemastore")

return {
  settings = {
    yaml = {
      schemas = require("schemastore").yaml.schemas(),
    },
  },
}
