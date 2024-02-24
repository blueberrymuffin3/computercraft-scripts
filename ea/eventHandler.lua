local delegator = require("delegator")

local eventDelegator = delegator()

local eventQueue = {}

local function run()
  local c = coroutine.create(function()
    while true do
      while #eventQueue > 0 do
        eventDelegator.handle(unpack(table.remove(eventQueue)))
      end
      coroutine.yield()
    end
  end)

  local filter = nil

  while true do
    local eventData = table.pack(os.pullEvent())
    table.insert(eventQueue, eventData)

    if filter == nil or filter == eventData[1] then
      local ok, ret = coroutine.resume(c, unpack(eventData, 1, eventData.n))
      
      if ok then
        filter = ret
      else
        error(ret, 0)
      end
    end

    if coroutine.status(c) == "dead" then
      return
    end
  end
end

return {
  run=run,
  addHandlerMap=eventDelegator.addHandlerMap,
  removeHandlerMap=eventDelegator.removeHandlerMap,
}
