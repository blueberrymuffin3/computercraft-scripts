local eventHandler = require("eventHandler")

local label = os.getComputerLabel()
local networkId, nodeType, nodeName = string.match(label, "^(ea_%w+)_(%w+)_(.+)$")
if networkId == nil then
  error("Improper label " .. label)
end

print("netMan init:", "nid="..networkId, "type="..nodeType, "name="..nodeName)

local messageHandlers = {}

local eventHandlerMap = {
  rednet_message=function(senderId, message, protocol)
    if string.find(protocol, networkId.."_"..nodeType) == 1 then
      if type(message) ~= "table" then return end
      if type(message.kind) ~= "string" then return end

      for messageHandler, _ in pairs(messageHandlers) do
        messageHandler(message.kind, message.message)
      end
    end
  end
}

local function open(side)
  rednet.open(side)
  rednet.host(networkId.."_"..nodeType, label)
  eventHandler.addHandlerMap(eventHandlerMap)
end

local function openAll()
  local sides = {peripheral.find("modem")}
  for _, side in pairs(sides) do
    open(peripheral.getName(side))
  end
end

return {
  networkId=networkId,
  nodeType=nodeType,
  nodeName=nodeName,
  openAll=openAll,
  wakeupType=function(targetType)
    for _, pName in pairs(peripheral.getNames()) do
      if peripheral.hasType(pName, "computer") then
        local targetLabel = peripheral.call(pName, "getLabel")

        if targetLabel and string.find(targetLabel, networkId.."_"..targetType) == 1 then
          -- print("Waking up " .. targetLabel)
          peripheral.call(pName, "turnOn")
        end
      end
    end
  end,
  sendToType=function(targetType, kind, message)
    rednet.broadcast({
      kind=kind,
      message=message,
    }, networkId.."_"..targetType)
  end,
  addMessageHandler=function(handler)
    messageHandlers[handler] = true
  end,
  removeMessageHandler=function(handler)
    messageHandlers[handler] = nil
  end,
}
