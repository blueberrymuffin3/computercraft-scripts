local eventHandler = require("eventHandler")

eventHandler.schedule(function()
  local netMan = require("netMan")
  local listView = require("listView")
  local delegator = require("delegator")
  local taskStatus = require("taskStatus")
  local settingsUtil = require("settingsUtil")

  settings.define("ea.console.drop_target", {
    description = "Peripheral name to send dropped items to. Must be an inventory.",
    type = "string",
  })
  local dropTarget = settingsUtil.getRequired("ea.console.drop_target")

  local items = {}

  local function triggerDropAction(ammount)
    return function(item)
      if item then
        netMan.sendToType("server", "dropItems", {
          key=item.key,
          ammount=ammount,
          target=dropTarget
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

  local function renderListItem(item)
    local text = {item.total.." x "..item.details.displayName}
    -- Whether to tell the user this item has NBT data
    -- We don't do this when displaying damage or enchants
    local addNbt = item.details.nbt ~= nil

    if item.details.maxDamage ~= nil then
      table.insert(text, " ("..(item.details.maxDamage-item.details.damage).."/"..(item.details.maxDamage)..")")
      addNbt = false
    end

    if item.details.enchantments ~= nil then
      table.insert(text, " [")
      for _, enchantment in ipairs(item.details.enchantments) do
        table.insert(text, enchantment.displayName.." "..enchantment.level)
        table.insert(text, ", ")
      end
      table.remove(text) -- Remove final comma
      table.insert(text, "]")
      addNbt = false
    end

    if addNbt then
      table.insert(text, " [+NBT]")
    end

    return table.concat(text)
  end

  homeListView = listView{
    renderListItem=renderListItem,
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
