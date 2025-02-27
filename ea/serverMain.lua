local eventHandler = require("eventHandler")

eventHandler.schedule(function()
  local netMan = require("netMan")
  local delegator = require("delegator")
  local periodic = require("periodic")
  local taskStatus = require("taskStatus")
  local checkForUpdate = require("update")
  local falliblePeripheral = require("falliblePeripheral")

  local items = {}
  local itemsDirtySet = {}
  local itemsDirtyAll = false
  local allStoragesLowPrio = {}
  local allStoragesHighPrio = {}
  local requestedExtraTurtleImports = {}
  local requestedExtraPersonalImports = {}

  local updateItemsPeriodic
  local importItemsPeriodic
  local updateListPeriodic

  local function getItemKey(item)
    return textutils.serializeJSON{
      name=item.name,
      nbt=item.nbt,
    }
  end

  local function getPMode(pName)
    if string.find(pName, "minecraft:barrel_") == 1 then
      return "import"
    elseif string.find(pName, "turtle_") == 1 then
      return nil -- Require manual import
    elseif string.find(pName, "enderstorage:ender_chest_") == 1 then
      return nil -- Require manual import
    elseif peripheral.hasType(pName, "inventory") then
      return "storage"
    end
    return nil
  end

  local function isHighPrioStorage(pName)
    if string.find(pName, "storagedrawers") == 1 then
      return true
    else
      return false
    end
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
    action=taskStatus.wrap("Scanning", function(progress)
      print("Scanning all storage")

      itemsDirtyAll = true

      for _, data in pairs(items) do
        data.locations = {}
        data.total = 0
      end

      allStoragesLowPrio = {}
      allStoragesHighPrio = {}

      local peripheralNames = peripheral.getNames()
      local storagePeripheralNames = {}
      for _, pName in ipairs(peripheralNames) do
        if getPMode(pName) == "storage" then
          table.insert(storagePeripheralNames, pName)
        end
      end

      for i, pName in ipairs(storagePeripheralNames) do
        progress(i, #storagePeripheralNames)
        local statusPrefix = "Scanning "..pName.." ("

        updateLine(statusPrefix)
        if isHighPrioStorage(pName) then
          table.insert(allStoragesHighPrio, pName)
        else
          table.insert(allStoragesLowPrio, pName)
        end
        local pList = falliblePeripheral.call(pName, "list")
        
        local statusSuffix = "/"..table.getn(pList)..")"

        for slot, stack in pairs(pList) do
          if stack then
            updateLine(statusPrefix..slot..statusSuffix)
            insertLocation(pName, slot, getItemKey(stack), stack.count)
          end
        end
        print()
      end

      updateListPeriodic.trigger()
    end),
  }

  importItemsPeriodic = periodic{
    maxDelay=5,
    initialDelay=2,
    action=taskStatus.wrap("Importing", function(progress)
      print("Importing")

      local rescanRequired = false

      local imports = {}
      local function scanPeripheral(pName, list)
        for slot, stack in pairs(list) do
          table.insert(imports, {
            pName=pName,
            slot=slot,
            stack=stack,
          })
        end
      end

      local thisRequestedExtraTurtleImports = requestedExtraTurtleImports
      requestedExtraTurtleImports = {}
      for pName, list in pairs(thisRequestedExtraTurtleImports) do
        scanPeripheral(pName, list)
      end

      local thisRequestedExtraPersonalImports = requestedExtraPersonalImports
      requestedExtraPersonalImports = {}
      for pName, _ in pairs(thisRequestedExtraPersonalImports) do
        local list = falliblePeripheral.call(pName, "list")
        scanPeripheral(pName, list)
      end

      for _, pName in ipairs(peripheral.getNames()) do
        local pMode = getPMode(pName)

        if pMode == "import" then
          local list = falliblePeripheral.call(pName, "list")

          scanPeripheral(pName, list)
        end
      end

      for i, import in pairs(imports) do
        progress(i, #imports)

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

            local transferred = peripheral.call(location.pName, "pullItems", pName, slot, remaining, location.slot) or 0
            remaining = remaining - transferred
            location.count = location.count + transferred
            items[key].total = items[key].total + transferred
            itemsDirtySet[key] = true
          end
        end

        if remaining > 0 then
          for _, allStorages in ipairs({allStoragesHighPrio, allStoragesLowPrio}) do
            for _, storagePName in pairs(allStorages) do
              local transferred = peripheral.call(storagePName, "pullItems", pName, slot) or 0
              remaining = remaining - transferred
              rescanRequired = true
              if remaining == 0 then break end
            end
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
    action=taskStatus.wrap("Loading", function(progress)
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
    end),
  }

  local function triggerDropItems(key, amount, target)
    local data = items[key]
    local amountLeft = amount

    while amountLeft > 0 and data.total > 0 do
      local location = data.locations[1]
      local amountMoved = peripheral.call(location.pName, "pushItems", target, location.slot, amountLeft) or 0
      amountLeft = amountLeft - amountMoved
      data.total = data.total - amountMoved
      location.count = location.count - amountMoved
      if location.count == 0 then
        table.remove(data.locations, 1)
      end

      if amountMoved == 0 then
        break
      end

      itemsDirtySet[key] = true
    end

    updateListPeriodic.trigger()
  end

  local function triggerTurtleImport(target, list)
    requestedExtraTurtleImports[target] = list
    importItemsPeriodic.trigger()
  end

  local function triggerPersonalImport(target)
    requestedExtraPersonalImports[target] = true
    importItemsPeriodic.trigger()
  end

  eventHandler.addHandlerMap{
    peripheral=updateItemsPeriodic.trigger,
    peripheral_detach=updateItemsPeriodic.trigger,
  }

  netMan.openAll()
  netMan.addMessageHandler(delegator{
    refresh=function()
      itemsDirtyAll = true
      updateListPeriodic.trigger()
    end,
    dropItems=function(message)
      triggerDropItems(message.key, message.amount, message.target)
    end,
    importFrom=function(message)
      if message.list then
        triggerTurtleImport(message.target, message.list)
      else
        triggerPersonalImport(message.target)
      end
    end,
  }.handle)
  netMan.sendToType("console", "itemsClear")

  checkForUpdate()
end)

eventHandler.run()
