local eventHandler = require("eventHandler")
local taskStatus = require("taskStatus")

eventHandler.schedule(function()
  local netMan = require("netMan")
  local listView = require("listView")
  local delegator = require("delegator")

  local items = {}

  local function triggerDropAction(ammount)
    return function(item)
      if item then
        netMan.sendToType("server", "dropItems", {
          key=item.key,
          ammount=ammount,
        })
      end
    end
  end

  local function updateListView()
    local itemsList = {}
    for _, item in pairs(items) do
      table.insert(itemsList, item)
    end
    homeListView.setList(itemsList)
  end

  homeListView = listView{
    renderListItem=function(item) return item.total.." x "..item.details.displayName end,
    queryMatches=function(query, item)
      if string.sub(query, 1, 1) == "@" then
        return string.find(
          string.lower(item.details.name),
          string.lower(string.sub(query, 2))
        ) == 1
      end
    
      return string.find(
        string.lower(item.details.displayName),
        string.lower(query)
      ) ~= nil
    end,
    getItemKey=function(item)
      return item.key
    end,
    compare=function(a, b)
      return a.total > b.total
    end,
    hotkeys={
      [keys.q]={
        description="Drop 1",
        action=triggerDropAction(1),
      },
      [keys.w]={
        description="Drop 16",
        action=triggerDropAction(16),
      },
      [keys.e]={
        description="Drop 64",
        action=triggerDropAction(64),
      },
    },
  }

  netMan.wakeupType("server")
  netMan.openAll()
  netMan.addMessageHandler(delegator{
    itemsClear=function(message)
      items = {}
      updateListView()
    end,
    itemsUpdate=function(message)
      for key, item in pairs(message) do
        items[key] = item
      end
      updateListView()
    end,
  }.handle)
  netMan.sendToType("server", "refresh")
  homeListView.enableEvents()
end)

eventHandler.run()
