local eventHandler = require("eventHandler")
local netMan = require("netMan")
local listView = require("listView")
local delegator = require("delegator")
local taskStatus = require("taskStatus")

local obj = {
  items={}
}

netMan.addMessageHandler(delegator{
  itemsClear=function(message)
    obj.items = {}
    os.queueEvent("items_changed")
  end,
  itemsUpdate=function(message)
    for key, item in pairs(message) do
      obj.items[key] = item
    end
    os.queueEvent("items_changed")
  end,
}.handle)

eventHandler.schedule(function() netMan.sendToType("server", "refresh") end)

return obj
