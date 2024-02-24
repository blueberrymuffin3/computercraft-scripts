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
    types = {
      minDelay = {"number", "nil"},
      maxDelay = {"number", "nil"},
      initialDelay = {"number", "nil"},
      action = "function",
    },
  })

  local lastRun = os.clock()
  local actionInProgress = false
  local newDelay = nil
  local currentTimerId = nil
  local currentTimerDelay = nil

  local callback
  local setTimer

  function callback()
    currentTimerId = nil
    currentTimerDelay = nil
    actionInProgress = true
    newDelay = nil

    config.action()

    actionInProgress = false
    lastRun = os.clock()
    if newDelay then
      setTimer(newDelay)
    elseif config.maxDelay then
      setTimer(config.maxDelay)
    end
  end

  function setTimer(delay)

    if delay == currentTimerDelay then
      return
    end

    if currentTimerId then
      os.cancelTimer(currentTimerId)
      activeCallbacks[currentTimerId] = nil
    end

    local elapsedSoFar = os.clock() - lastRun
    currentTimerId = os.startTimer(delay - elapsedSoFar)
    activeCallbacks[currentTimerId] = callback
    currentTimerDelay = delay
  end

  if config.initialDelay or config.maxDelay then
    setTimer(config.initialDelay or config.maxDelay)
  end

  return {
    trigger = function()
      local delay = config.minDelay or 0
      if actionInProgress then
        newDelay = delay
      elseif currentTimerDelay == nil or delay < currentTimerDelay then
        setTimer(delay)
      end
    end
  }
end
