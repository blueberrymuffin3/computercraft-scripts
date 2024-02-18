items = {}
allStorages = {}
dropoffPeripheral = nil

function getItemKey(item)
  key = { name=item.name }
  if item.nbt then
    key.nbt = item.nbt
  end
  return textutils.serializeJSON(key)
end

function shouldScan(pName)
  return peripheral.hasType(pName, "inventory")
end

function getPMode(pName)
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

function insertLocation(pName, slot, key, count)
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

function updateLine(text)
  local x, y = term.getCursorPos()
  term.setCursorPos(1, y)
  term.clearLine()
  term.write(text)
end

function updateItems()
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
      local statusPrefix = "Scanning " .. pName .. " ("

      updateLine(statusPrefix)
      table.insert(allStorages, pName)
      local pWrap = peripheral.wrap(pName)
      local pList = pWrap.list()
      
      local statusSuffix = "/" .. table.getn(pList) .. ")"

      for slot, stack in pairs(pList) do
        if stack then
          updateLine(statusPrefix .. slot .. statusSuffix)
          insertLocation(pName, slot, getItemKey(stack), stack.count)
        end
      end
      print()
    end
  end
end

function importItems()
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

function showList(height, content, printEntry, selectedIndex, actions)
  local width, _ = term.getSize()

  local start = selectedIndex - math.floor(height / 2)
  if start < 1 then
    start = 1
  end

  for i=start,start+height-1 do
    if i == selectedIndex then
      term.setBackgroundColor(colors.blue)
    else
      term.setBackgroundColor(colors.black)
    end

    local contentEntry = content[i]

    if contentEntry ~= nil then
      printEntry(contentEntry)
    else
      print("~")
    end
  end

  term.setBackgroundColor(colors.black)
end

function home()
  local hotkeys = {
    q=function() triggerDrop(1) end,
    w=function() triggerDrop(16) end,
    e=function() triggerDrop(64) end,
    r=function() triggerRefresh() end,
    backspace=function() triggerClear() end,
  }

  local refreshTimerId = nil
  local controlHeld = false
  local itemsList = {}
  local selectedIndex = 1
  local query = ""

  function queryMatches(data)
    if string.sub(query, 1, 1) == "@" then
      return string.find(
        string.lower(data.details.name),
        string.lower(string.sub(query, 2))
      ) == 1
    end

    return string.find(
      string.lower(data.details.displayName),
      string.lower(query)
    ) ~= nil
  end

  function updateItemsList()
    local prevData = itemsList[selectedIndex]

    itemsList = {}
    for _, data in pairs(items) do
      if queryMatches(data) then
        table.insert(itemsList, data)
      end
    end
  
    table.sort(
      itemsList,
      function(a, b)
        return a.total > b.total
      end
    )

    selectedIndex = 1
    if prevData ~= nil then
      for i, data in ipairs(itemsList) do
        if data.key == prevData.key then
          selectedIndex = i
          break
        end
      end
    end
  end

  function renderHome()
    local width, height = term.getSize()

    term.clear()

    term.setCursorPos(1, 1)
    term.setBackgroundColor(colors.white)
    term.setTextColor(colors.black)
    print("Search: "..query.."_")
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)

    showList(
      height-3,
      itemsList,
      function(item)
        print(item.total, "x", item.details.displayName)
      end,
      selectedIndex
    )

    term.setBackgroundColor(colors.white)
    term.setTextColor(colors.black)
    term.setCursorPos(1, height-1)
    term.write("   ctrl-r:refresh and import                       ")
    term.setCursorPos(1, height)
    term.write("   ctrl-q:drop 1  ctrl-w:drop 16  ctrl-e:drop 64   ")
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
  end

  function triggerDrop(ammount)
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

    updateItemsList()
    renderHome()
  end

  function triggerSetSelectedIndex(newIndex)
    selectedIndex = math.floor(newIndex)
    local itemListN = table.getn(itemsList)
    if selectedIndex > itemListN then
      selectedIndex = itemListN
    end

    if selectedIndex < 1 then
      selectedIndex = 1
    end

    renderHome()
  end

  function triggerRefresh()
    term.clear()
    term.setCursorPos(1, 1)
    updateItems()
    importItems()
    updateItemsList()
    renderHome()
    refreshTimerId = os.startTimer(os.time() + 1)
  end

  function triggerClear()
    query = ""
    updateItemsList()
    renderHome()
  end

  triggerRefresh()
  while true do
    local eventData = {os.pullEvent()}
    local event = eventData[1]

    if event == "key" then
      keyName = keys.getName(eventData[2])
      if keyName == "leftCtrl" or keyName == "rightCtrl" then
        controlHeld = true
      elseif controlHeld then
        hotkey = hotkeys[keyName]
        if hotkey ~= nil then
          hotkey()
        end
      elseif keyName == "up" then
        triggerSetSelectedIndex(selectedIndex - 1)
      elseif keyName == "left" then
        triggerSetSelectedIndex(selectedIndex - 10)
      elseif keyName == "down" then
        triggerSetSelectedIndex(selectedIndex + 1)
      elseif keyName == "right" then
        triggerSetSelectedIndex(selectedIndex + 10)
      elseif keyName == "home" then
        triggerSetSelectedIndex(1)
      elseif keyName == "end" then
        triggerSetSelectedIndex(1/0) -- Infinity
      elseif keyName == "backspace" then
        query = string.sub(query, 1, -2)
        updateItemsList()
        renderHome()
      end
    elseif event == "mouse_scroll" then
      local direction = eventData[2]
      triggerSetSelectedIndex(selectedIndex + direction)
    elseif event == "key_up" then
      keyName = keys.getName(eventData[2])
      if keyName == "leftCtrl" or keyName == "rightCtrl" then
        controlHeld = false
      end
    elseif event == "char" then
      character = eventData[2]
      
      if not controlHeld then
        query = query..character
        updateItemsList()
        renderHome()
      end
    elseif event == "term_resize" then
      renderHome()
    elseif event == "peripheral" or event == "peripheral_detach" then
      triggerRefresh()
    elseif event == "timer" then
      local timerId = eventData[2]
      if timerId == refreshTimerId then
        triggerRefresh()
      end
    end
  end
end

home()
