local files = require("files")

local copy_type
copy_type = function(source)
  if type(source) ~= "table" then return source end

  if not source.type then
    local items = {}
    for index, item in ipairs(source) do
      items[index] = copy_type(item)
    end
    return items
  end

  local result = {}
  for _, key in ipairs({
    "type",
    "optional",
    "isTuple",
    "extends",
    "types",
    "fields",
    "args",
    "returns",
    "node",
    "signs",
    "name",
    "param",
    "field",
    "alias",
    "class",
    "overload",
    "generics",
    "generic",
    "vararg",
    "visible",
  }) do
    local is_type_link = key == "generic" and source.type ~= "doc.generic.object"
      or key == "class" and source.type ~= "doc.class"
    if not is_type_link then result[key] = copy_type(source[key]) end
  end

  if type(source[1]) ~= "table" then result.value = source[1] end

  local descriptions = {}
  for _, comment in ipairs(source.bindComments or {}) do
    if comment.comment then table.insert(descriptions, (comment.comment.text:gsub("^%s*%-%s?", ""))) end
  end

  if source.comment and type(source.comment.text) == "string" then
    local description = source.comment.text
    if source.type == "doc.comment" then description = description:gsub("^%s*%-%s?", "") end
    local is_generic_suffix = source.type == "doc.class" and description:match("^<[%w_, .]+>$")
    local is_type_annotation = source.type == "doc.field"
      or source.type == "doc.alias"
      or source.type == "doc.overload"
    local is_type_suffix = is_type_annotation and (description:match("^&") or description:match("^in keyof "))
    if not is_generic_suffix and not is_type_suffix then table.insert(descriptions, description) end
    if is_type_suffix then result.isIncomplete = true end

    local key_type = description:match("^&%s*keyof%s+([%a_][%w_]*)%)%s*|%s*fun")
    if source.type == "doc.field" and key_type then
      result.extends = {
        type = "doc.type",
        types = {
          {
            type = "doc.type.intersection",
            types = {
              { type = "doc.type.name", value = "string" },
              { type = "doc.type.keyof", node = { type = "doc.generic.name", value = key_type } },
            },
          },
          { type = "doc.type.function" },
        },
      }
      result.isIncomplete = nil
    end
  end

  if #descriptions > 0 then result.description = table.concat(descriptions, "\n") end

  if source.type == "funcargs" then
    result.items = {}
    for index, item in ipairs(source) do
      result.items[index] = copy_type(item)
    end
  end

  return result
end

local function get_names(source)
  local names = {}
  local current = source
  while current do
    local name = guide.getKeyName(current)
    if type(name) ~= "string" then return nil end

    table.insert(names, 1, name)
    if current.type == "getlocal" or current.type == "getglobal" then break end
    current = current.node
  end

  return names
end

export.makeDocs = function()
  local result = {}
  for uri in files.eachFile() do
    local path = export.getLocalPath(uri)
    local state = files.getState(uri)
    local is_uv_metadata = path == "uv/_meta.lua"
    if path:sub(1, 4) == "vim/" or path == "vim.lua" or is_uv_metadata then
      local owner_classes = {}
      guide.eachSourceType(state.ast, "doc.class", function(source)
        if not source.bindSource then return end

        local owner = guide.getKeyName(source.bindSource)
        if type(owner) == "string" then owner_classes[owner] = source.class[1] end
      end)

      local memoize_names = {}
      guide.eachSourceType(state.ast, "local", function(source)
        local names = source.value and get_names(source.value)
        if names and table.concat(names, ".") == "vim.func._memoize" then
          memoize_names[guide.getKeyName(source)] = true
        end
      end)

      guide.eachSourceType(state.ast, "function", function(source)
        local parent = source.parent
        local names = {}
        if parent.type == "setfield" or parent.type == "setmethod" or parent.type == "setindex" then
          names = get_names(parent) or {}
        end

        local call = parent.type == "callargs" and parent.parent
        local assignment = call and call.parent
        while assignment and assignment.type == "select" do
          assignment = assignment.parent
        end

        if
          assignment
          and assignment.type == "setfield"
          and call.args[2] == source
          and memoize_names[guide.getKeyName(call.node)]
        then
          names = get_names(assignment) or {}
        end

        if is_uv_metadata then
          if names[1] ~= "uv" then return end

          table.insert(names, 1, "vim")
        end

        local docs, seen = {}, {}
        for _, owner in ipairs({ parent, source }) do
          for _, doc in ipairs(owner.bindDocs or {}) do
            if not seen[doc] then
              seen[doc] = true
              table.insert(docs, doc)
            end
          end
        end

        table.sort(docs, function(left, right)
          return left.start < right.start
        end)

        table.insert(result, {
          kind = "function",
          path = path,
          line = select(1, guide.rowColOf(source.start)) + 1,
          names = names,
          ownerClass = parent.type == "setmethod" and owner_classes[names[1]] or nil,
          docs = copy_type(docs),
          args = copy_type(source.args),
        })
      end)
      guide.eachSourceType(state.ast, "setfield", function(source)
        local names = get_names(source)
        local module_name = path:match("([^/]+)%.lua$")
        local is_module_field = names and (names[1] == "vim" or names[1] == "M" or names[1] == module_name)
        if is_module_field and source.value and source.value.type ~= "function" then
          local docs = copy_type(source.bindDocs or {})
          local signatures = {}
          for node in vm.compileNode(source.value):eachObject() do
            if node.type == "doc.type.function" then table.insert(signatures, copy_type(node)) end
          end

          if names[1] ~= "vim" and #signatures == 0 then return end

          if #signatures > 0 then table.insert(docs, { type = "doc.type", types = signatures }) end

          table.insert(result, {
            kind = "alias",
            path = path,
            line = select(1, guide.rowColOf(source.start)) + 1,
            names = names,
            docs = docs,
          })
        end
      end)
    end

    if state then
      guide.eachSourceTypes(state.ast, { "doc.class", "doc.alias", "doc.enum" }, function(source)
        local value = copy_type(source)
        if source.type == "doc.class" and source.bindSource then
          local owner = guide.getKeyName(source.bindSource)
          guide.eachSourceType(state.ast, "setmethod", function(method)
            local names = get_names(method)
            if names and names[1] == owner then value.hasInstanceMethods = true end
          end)

          local initializer = source.bindSource.type == "table" and source.bindSource or source.bindSource.value
          if initializer and initializer.type == "table" then
            for _, field in ipairs(initializer) do
              if field.value and field.value.type == "function" then value.hasInstanceMethods = true end
            end
          end
        end

        if source.type == "doc.alias" then
          local row = guide.rowColOf(source.start)
          local offset = guide.positionToOffset(state, guide.positionOf(row, 0))
          local line = state.lua:sub(offset + 1, offset + guide.getLineRange(state, row))
          local key, base = line:match("{ *%[([%a_][%w_]*) +in +keyof +([%a_][%w_]*)%]: *%2%[%1%] *| *nil *}")
          if key then
            value.isIncomplete = nil
            value.extends = {
              type = "doc.type.mapped",
              name = { type = "doc.generic.name", value = key },
              node = { type = "doc.generic.name", value = base },
            }
          end
        end

        if source.type == "doc.enum" then
          local enum_source = source.bindSource
          if not enum_source then
            local name = source.enum[1]:match("[^.]+$")
            guide.eachSourceType(state.ast, "setfield", function(candidate)
              local is_enum_table = guide.getKeyName(candidate) == name
                and candidate.start > source.finish
                and candidate.value
                and candidate.value.type == "table"
              if is_enum_table and (not enum_source or candidate.value.start < enum_source.start) then
                enum_source = candidate.value
              end
            end)
          end

          if not enum_source then error("Unbound enum: " .. source.enum[1]) end

          local types = {}
          local constants = {}
          for _, field in ipairs(enum_source) do
            local literal = field.value
            if literal and (literal.type == "integer" or literal.type == "number" or literal.type == "string") then
              table.insert(types, {
                type = literal.type == "string" and "doc.type.string" or "doc.type.integer",
                value = literal[1],
              })
              local name = guide.getKeyName(field)
              if type(name) == "string" then constants[name] = literal[1] end
            else
              error("Unsupported enum literal: " .. source.enum[1])
            end
          end
          value = {
            type = "doc.alias",
            alias = { type = "doc.alias.name", value = source.enum[1] },
            extends = { type = "doc.type", types = types },
          }
          local names = get_names(enum_source.parent)
          if names and next(constants) then
            table.insert(result, {
              kind = "constant",
              path = path,
              line = select(1, guide.rowColOf(source.start)) + 1,
              names = names,
              constants = constants,
            })
          end
        end

        table.insert(result, {
          kind = "type",
          path = path,
          line = select(1, guide.rowColOf(source.start)) + 1,
          value = value,
        })
      end)
    end
  end

  table.sort(result, function(left, right)
    if left.path ~= right.path then return left.path < right.path end
    return left.line < right.line
  end)
  return result
end

export.serializeAndExport = function(docs, output_dir)
  local path = output_dir .. "/vim-metadata.json"
  local ok, err = util.saveFile(path, jsonb.beautify(docs))
  return ok, { path }, { err }
end
