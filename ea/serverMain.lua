local eventHandler = require("eventHandler")

eventHandler.schedule(function()
  local netMan = require("netMan")
  local delegator = require("delegator")
  local periodic = require("periodic")
  local taskStatus = require("taskStatus")

  local items = {}
  local itemsDirtySet = {}
  local itemsDirtyAll = false
  local allStorages = {}
  local dropoffPName = nil

  local updateItemsPeriodic
  local importItemsPeriodic
  local updateListPeriodic

  local function getItemKey(item)
    return textutils.serializeJSON{
      name=item.name,
      nbt=item.nbt,
      damage=item.damage
    }
  end

  local function getPMode(pName)
    if string.find(pName, "create:item_vault_") == 1 then
      return "storage"
    -- elseif string.find(pName, "minecraft:chest_") == 1 then
    --   return "storage"
    elseif string.find(pName, "botania:open_crate_") == 1 then
      return "output"
    elseif peripheral.hasType(pName, "inventory") then
      return "import"
    end
    return nil
  end

  local function insertLocation(pName, slot, key, count)
    if not items[key] then
      items[key] = {
        key = key,
        details = peripheral.call(pName, "getItemDetail", slot),
        locations = {},
        total = 0
      }
    end

    local item = items[key]

    table.insert(
      item.locations,
      {
        pName=pName,
        slot=slot,
        count=count
      }
    )
    item.total = item.total + count
  end

  local function updateLine(text)
    local x, y = term.getCursorPos()
    term.setCursorPos(1, y)
    term.clearLine()
    term.write(text)
  end

  updateItemsPeriodic = periodic{
    maxDelay=35,
    minDelay=2,
    initialDelay=1,
    action=function()
      print("Scanning all storage")

      itemsDirtyAll = true

      for _, data in pairs(items) do
        data.locations = {}
        data.total = 0
      end

      allStorages = {}

      for _, pName in ipairs(peripheral.getNames()) do
        local pMode = getPMode(pName)
        if pMode == "output" then
          dropoffPName = pName
        elseif pMode == "storage" then
          local statusPrefix = "Scanning "..pName.." ("

          updateLine(statusPrefix)
          table.insert(allStorages, pName)
          local pWrap = peripheral.wrap(pName)
          local pList = pWrap.list()
          
          local statusSuffix = "/"..table.getn(pList)..")"

          for slot, stack in pairs(pList) do
            if stack then
              updateLine(statusPrefix..slot..statusSuffix)
              insertLocation(pName, slot, getItemKey(stack), stack.count)
            end
          end
          print()
        end
      end

      updateListPeriodic.trigger()
    end,
  }

  importItemsPeriodic = periodic{
    maxDelay=5,
    initialDelay=2,
    action=taskStatus.wrap("Importing", function(progress)
      print("Importing")

      local rescanRequired = false

      local imports = {}

      for _, pName in ipairs(peripheral.getNames()) do
        local pMode = getPMode(pName)

        if pMode == "import" then
          local pWrap = peripheral.wrap(pName)

          for slot, stack in pairs(pWrap.list()) do
            table.insert(imports, {
              pName=pName,
              slot=slot,
              stack=stack,
            })
          end
        end
      end

      for i, import in pairs(imports) do
        progress(i, #import)

        local pName = import.pName
        local slot = import.slot
        local stack = import.stack
        local key = getItemKey(stack)
        local remaining = stack.count

        if items[key] then
          for _, location in pairs(items[key].locations) do
            if remaining == 0 then
              break
            end

            local transfered = peripheral.call(pName, "pushItems", location.pName, slot, remaining, location.slot)
            remaining = remaining - transfered
            location.count = location.count + transfered
            items[key].total = items[key].total + transfered
            itemsDirtySet[key] = true
          end
        end

        if remaining > 0 then
          for _, storagePName in pairs(allStorages) do
            local transfered = peripheral.call(pName, "pushItems", storagePName, slot)
            remaining = remaining - transfered
            rescanRequired = true
          end
        end
      end

      if rescanRequired then
        updateItemsPeriodic.trigger()
      else
        updateListPeriodic.trigger()
      end
    end),
  }

  updateListPeriodic = periodic{
    minDelay=0.1,
    action=function()
      local packet = {}
      local itemsN = 0
      local packetN = 0
      local packetCount = 0
      
      local itemKeysTable
      if itemsDirtyAll then
        itemKeysTable = items
      else
        itemKeysTable = itemsDirtySet
      end

      for key, _ in pairs(itemKeysTable) do
        local item = items[key]

        packetN = packetN + 1
        itemsN = itemsN + 1
        packet[key] = {
          key=key,
          details=item.details,
          total=item.total,
        }

        if packetN >= 50 then
          netMan.sendToType("console", "itemsUpdate", packet)
          sleep(0)
          packetCount = packetCount + 1
          packetN = 0
          packet = {}
        end
      end

      if packetN > 0 then
        netMan.sendToType("console", "itemsUpdate", packet)
        sleep(0)
        packetCount = packetCount + 1
      end

      print("Broadcasted", packetCount, "packets with", itemsN, "items")

      itemsDirtyAll = false
      itemsDirtySet = {}
    end,
  }

  local function triggerDropItems(key, ammount, target)
    local data = items[key]
    local ammountLeft = ammount

    while ammountLeft > 0 and data.total > 0 do
      local location = data.locations[1]
      local ammountMoved = peripheral.call(target, "pullItems", location.pName, location.slot, ammountLeft)
      ammountLeft = ammountLeft - ammountMoved
      data.total = data.total - ammountMoved
      location.count = location.count - ammountMoved
      if location.count == 0 then
        table.remove(data.locations, 1)
      end

      itemsDirtySet[key] = true
    end

    updateListPeriodic.trigger()
  end

  eventHandler.addHandlerMap{
    peripheral=updateItemsPeriodic.trigger,
    peripheral_detach=updateItemsPeriodic.trigger,
  }

  netMan.openFirstWired()
  netMan.addMessageHandler(delegator{
    refresh=updateItemsPeriodic.trigger,
    dropItems=function(message)
      triggerDropItems(message.key, message.ammount, dropoffPName)
    end,
  }.handle)
  netMan.sendToType("console", "itemsClear")
end)

eventHandler.run()
