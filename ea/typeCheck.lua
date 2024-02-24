return function(config, metaConfig)
  if metaConfig.defaults then
    for prop, default in pairs(metaConfig.defaults) do
      if config[prop] == nil then
        config[prop] = default
      end
    end
  end

  if metaConfig.types then
    for prop, requiredTypeOrTypes in pairs(metaConfig.types) do
      local requiredTypes
      local requiredTypesString
      if type(requiredTypeOrTypes) == "table" then
        requiredTypes = requiredTypeOrTypes
        requiredTypesString = textutils.serialise(requiredTypeOrTypes)
      else
        requiredTypes = {requiredTypeOrTypes}
        requiredTypesString = requiredTypeOrTypes
      end

      local actualType = type(config[prop])
      local matchFound = false

      for _, typeOption in pairs(requiredTypes) do
        if actualType == typeOption then
          matchFound = true
          break
        end
      end

      if not matchFound then
        error("config."..prop.." must be a "..requiredTypesString..", but was a "..actualType)
      end
    end
  end
end
