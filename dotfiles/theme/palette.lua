local read_file = function(path)
  local file = io.open(path, "r")
  if not file then return nil end

  local content = file:read("*a")
  file:close()
  return content
end

local validate_palette = function(palette, path)
  for name, value in pairs(palette) do
    if type(value) ~= "string" or not value:match("^#%x%x%x%x%x%x$") then
      error("Theme palette color " .. name .. " in " .. path .. " is not a six-digit hex color")
    end
  end

  return palette
end

local resolve_palette = function(colors, aliases, path)
  local resolving = {}
  local resolve
  resolve = function(name)
    if colors[name] then return colors[name] end
    if resolving[name] then error("Circular theme palette alias " .. name .. " in " .. path) end

    local target = aliases[name]
    if not target then error("Theme palette alias " .. name .. " in " .. path .. " has no target") end

    resolving[name] = true
    colors[name] = resolve(target)
    resolving[name] = nil
    return colors[name]
  end

  for name in pairs(aliases) do
    resolve(name)
  end

  return validate_palette(colors, path)
end

local load_json = function(path, decode)
  local content = read_file(path)
  if not content then return nil end

  local decoded_ok, palette = pcall(decode, content)
  if not decoded_ok then error("Could not decode theme palette at " .. path .. ": " .. palette) end
  return validate_palette(palette, path)
end

local load_nix = function(path)
  local content = read_file(path)
  if not content then return nil end

  local block = content:match("colors%s*=%s*rec%s*{(.-)%s*};%s*\n%s*xdg%.configFile")
  if not block then error("Could not find the recursive colors block in " .. path) end

  local colors = {}
  local aliases = {}
  for name, expression in block:gmatch("([%w-]+)%s*=%s*([^;]+);") do
    expression = expression:match("^%s*(.-)%s*$")
    local color = expression:match('^"(#%x%x%x%x%x%x)"$')
    local alias = expression:match("^([%w-]+)$")

    if color then
      colors[name] = color
    elseif alias then
      aliases[name] = alias
    else
      error("Unsupported theme palette expression for " .. name .. " in " .. path)
    end
  end

  if not next(colors) then error("Theme palette in " .. path .. " has no colors") end
  return resolve_palette(colors, aliases, path)
end

return {
  load_json = load_json,
  load_nix = load_nix,
}
