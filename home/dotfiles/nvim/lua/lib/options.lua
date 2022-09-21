local module = {
  set = function(key, value)
    vim.opt[key] = value
  end,
  set_bulk = function(options)
    for k, v in pairs(options) do
      vim.opt[k] = v
    end
  end,
}

return module
