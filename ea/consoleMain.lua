local eventHandler = require("eventHandler")

eventHandler.schedule(function()
  local netMan = require("netMan")
  local listView = require("listView")
  local delegator = require("delegator")
  local taskStatus = require("taskStatus")
  local settingsUtil = require("settingsUtil")
  local checkForUpdate = require("update")
  local itemsListener = require("itemsListener")
  checkForUpdate()

  local dropTarget
  if turtle then
    dropTarget = peripheral.find("modem").getNameLocal() or error("Could not determine console's peripheral name")
  else
    settings.define("ea.console.drop_target", {
      description = "Peripheral name to send dropped items to. Must be an inventory.",
      type = "string",
    })
    dropTarget = settingsUtil.getRequired("ea.console.drop_target")
  end

  local function triggerDropAction(amount)
    return function(item)
      if item then
        netMan.sendToType("server", "dropItems", {
          key=item.key,
          amount=amount,
          target=dropTarget
        })
      end
    end
  end

  local function triggerImportAction()
    return function(item)
      if turtle then
        local list = {}
        for slot=1,16 do
          list[slot] = turtle.getItemDetail(slot)
        end

        netMan.sendToType("server", "importFrom", {
          target=dropTarget,
          list=list
        })
      else
        netMan.sendToType("server", "importFrom", {
          target=dropTarget,
        })
      end
    end
  end

  local function triggerCraft()
    return function(item)
      netMan.sendToType("crafter", "do_craft", {name=item.details.name, nbt=item.details.nbt})
    end
  end

  eventHandler.addHandlerMap{
    items_changed=function()
      local itemsList = {}
      for _, item in pairs(itemsListener.items) do
        table.insert(itemsList, item)
      end
      homeListView.setList(itemsList)
    end
  }

  local function renderListItem(item)
    local text = {item.total.." x "..item.details.displayName}
    -- Whether to tell the user this item has NBT data
    -- We don't do this when displaying damage or enchants
    local addNbt = item.details.nbt ~= nil

    if item.details.maxDamage ~= nil then
      if item.details.damage ~= 0 then
        table.insert(text, " ("..(item.details.maxDamage-item.details.damage).."/"..(item.details.maxDamage)..")")
      end
      addNbt = false
    end

    if item.details.enchantments ~= nil then
      table.insert(text, " [")
      for _, enchantment in ipairs(item.details.enchantments) do
        table.insert(text, enchantment.displayName)
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
    
      local match = string.find(
        string.lower(item.details.displayName),
        string.lower(query)
      ) ~= nil

      if item.details.enchantments ~= nil then
        for _, enchantment in ipairs(item.details.enchantments) do
          match = match or string.find(
            string.lower(enchantment.displayName),
            string.lower(query)
          ) ~= nil
        end
      end

      return match
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
      [keys.d]={
        description="Import",
        action=triggerImportAction(),
      },
      [keys.r]={
        description="craft",
        action=triggerCraft(),
      }
    },
  }

  netMan.wakeupType("server")
  netMan.openAll()
  netMan.addMessageHandler(delegator{
    reboot=function()
      term.clear()
      term.setCursorPos(1, 1)
      print("Reboot requested, rebooting in 2 seconds...")
      sleep(2)
      os.reboot()
    end,
  }.handle)
  homeListView.enableEvents()
end)

eventHandler.run()
