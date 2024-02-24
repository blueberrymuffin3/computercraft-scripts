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
    defaults={
      autoStart=false,
      autoRestart=false,
    },
    types={
      action="function",
      -- duration="number", -- or nil
      -- autoStart="boolean", -- or number
      -- autoRestart="boolean", -- or number
    },
  })

  local activeId = nil

  local start
  local callback

  function callback()
    config.action()

    if config.autoRestart then
      start(config.autoRestart)
    end
  end

  function start(durationOveride)
    local duration = config.duration
    if type(durationOveride) == "number" then
      duration = durationOveride
    end
    if duration == nil then
      error("Either config.duration or durationOveride must be specified")
    end

    if activeId ~= nil then
      os.cancelTimer(activeId)
      activeCallbacks[activeId] = nil
    end
    activeId = os.startTimer(duration)
    activeCallbacks[activeId] = callback
  end

  if config.autoStart then
    start(config.autoStart)
  end

  return {
    start=start
  }
end
