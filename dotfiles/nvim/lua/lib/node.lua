local rpc = function(function_name)
  local nvim_function_name = "Node_" .. function_name:gsub("%.", "_")
  return function(...)
    return vim.fn[nvim_function_name](...)
  end
end

return {
  dev = {
    test = rpc("dev.test"),
  },
  chrono = {
    to_schedule = rpc("chrono.toSchedule"),
  },
}
