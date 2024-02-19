return function(config, metaConfig)
  for prop, default in pairs(metaConfig.defaults) do
    if config[prop] == nil then
      config[prop] = default
    end
  end

  for prop, requiredType in pairs(metaConfig.types) do
    local actualType = type(config[prop])
    if actualType ~= requiredType then
      error("config."..prop.." must be a "..requiredType..", but was a "..actualType)
    end
  end
end
