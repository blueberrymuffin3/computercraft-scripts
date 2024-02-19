local eventHandler = require('eventHandler')
local typeCheck = require('typeCheck')

local activeCallbacks = {}

eventHandler.addHandlerMap{
  timer=function(id)
    local activeCallback = activeCallbacks[id]
    if activeCallback then
      activeCallbacks[id] = nil
      activeCallback()
    end
  end
}

return function(config)
  typeCheck(config, {
    defaults={},
    types={
      action="function",
      duration="number",
    },
  })

  local activeId = nil

  return {
    start=function()
      if activeId ~= nil then
        os.cancelTimer(activeId)
        activeCallbacks[activeId] = nil
      end
      activeId = os.startTimer(config.duration)
      activeCallbacks[activeId] = config.action
    end
  }
end
