return function(default)
  local handlerMaps = {}

  if default then
    handlerMaps[default] = true
  end

  return {
    handle=function(discriminator, ...)
      for handlerMap, _ in pairs(handlerMaps) do
        local handler = handlerMap[discriminator]
        if handler then
          handler(...)
        end
      end
    end,
    addHandlerMap=function(handlerMap)
      handlerMaps[handlerMap] = true
    end,
    removeHandlerMap=function(handlerMap)
      handlerMaps[handlerMap] = nil
    end,
  }
end
