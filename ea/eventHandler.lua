local delegator = require("delegator")

local eventDelegator = delegator()

return {
  run=function()
    while true do
      eventDelegator.handle(os.pullEvent())
    end
  end,
  addHandlerMap=eventDelegator.addHandlerMap,
  removeHandlerMap=eventDelegator.removeHandlerMap,
}
