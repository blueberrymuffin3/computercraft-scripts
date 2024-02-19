local eventHandler = require("eventHandler")
local listView = require("listView")

local items = {}
local allStorages = {}
local dropoffPeripheral = nil
local refreshTimerId = nil
local homeListView

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

  table.insert(
    items[key].locations,
    {
      pName=pName,
      slot=slot,
      count=count
    }
  )
  items[key].total = items[key].total + count
end

local function updateLine(text)
  local x, y = term.getCursorPos()
  term.setCursorPos(1, y)
  term.clearLine()
  term.write(text)
end

local function updateItems()
  print("Scanning all storage")

  for _, data in pairs(items) do
    data.locations = {}
    data.total = 0
  end

  allStorages = {}

  for _, pName in ipairs(peripheral.getNames()) do
    local pMode = getPMode(pName)
    if pMode == "output" then
      dropoffPeripheral = peripheral.wrap(pName)
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
end

local function importItems()
  print("Importing all import")
  local itemsDirty = false

  for _, pName in ipairs(peripheral.getNames()) do
    local pMode = getPMode(pName)

    if pMode == "import" then
      print("Importing", pName)
      local pWrap = peripheral.wrap(pName)

      for slot, stack in pairs(pWrap.list()) do
        if stack then
          local key = getItemKey(stack)
          local remaining = stack.count

          if items[key] then
            for _, location in pairs(items[key].locations) do
              if remaining == 0 then
                break
              end

              local transfered = pWrap.pushItems(location.pName, slot, remaining, location.slot)
              remaining = remaining - transfered
              location.count = location.count + transfered
              items[key].total = items[key].total + transfered
            end
          end

          if remaining > 0 then
            for _, storagePName in pairs(allStorages) do
              local transfered = pWrap.pushItems(storagePName, slot)
              remaining = remaining - transfered
              itemsDirty = true
            end
          end
        else
          table.insert(emptySlots, { pName=pName, slot=slot })
        end
      end
    end
  end

  if itemsDirty then
    updateItems()
  end
end

local function triggerDropAction(ammount)
  return function()
    data = itemsList[selectedIndex]
    if data == nil then
      return
    end

    while ammount > 0 and data.total > 0 do
      location = data.locations[1]
      local ammountMoved = dropoffPeripheral.pullItems(location.pName, location.slot, ammount)
      ammount = ammount - ammountMoved
      data.total = data.total - ammountMoved
      location.count = location.count - ammountMoved
      if location.count == 0 then
        table.remove(data.locations, 1)
      end
    end

    
  end
end

local function updateList()
  itemsList = {}
  for _, item in pairs(items) do
    table.insert(itemsList, item)
  end

  homeListView.setList(itemsList)
end

local function triggerRefresh()
  term.clear()
  term.setCursorPos(1, 1)
  updateItems()
  importItems()
  updateList()

  if refreshTimerId then
    os.cancelTimer(refreshTimerId)
  end
  refreshTimerId = os.startTimer(20)
end

eventHandler.addHandlerMap{
  peripheral=triggerRefresh,
  peripheral_detach=triggerRefresh,
  timer=function(timerId)
    if timerId == refreshTimerId then
      triggerRefresh()
    end
  end
}

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
  compare=function(a, b)
    return a.total > b.total
  end,
  hotkeys={
    [keys.q]={
      description="My Action",
      action=triggerDropAction(1),
    },
    [keys.w]={
      description="My Action",
      action=triggerDropAction(16),
    },
    [keys.e]={
      description="My Action",
      action=triggerDropAction(64),
    },
    [keys.r]={
      description="My Action",
      action=triggerRefresh,
    },
  },
}

homeListView.enableEvents()
triggerRefresh()
eventHandler.run()
