--- Config Keys:
-- list?: table
-- renderListItem(item): string
-- queryMatches?(query, item): boolean
-- compare?(a, b): boolean
-- getItemKey?(item): any
-- hotkeys: map from key to
--   action: function(item)
--   description?: string

local eventHandler = require("eventHandler")
local delegator = require("delegator")
local controlHeld = false

function ListView(config)
  for prop, default in pairs({
    list={},
    compare=function(a, b) return false end,
    getItemKey=function(item) return item end,
  }) do
    if config[prop] == nil then
      config[prop] = default
    end
  end

  for prop, requiredType in pairs({
    list="table",
    renderListItem="function",
    -- queryMatches="function"
    hotkeys="table",
  }) do
    local actualType = type(config[prop])
    if actualType ~= requiredType then
      error("[ListView] config."..prop.." must be a "..requiredType..", but was a "..actualType)
    end
  end

  local list = nil
  local listFiltered = {}
  local selectedIndex = 1
  local query = ""

  local function render()
    local width, height = term.getSize()

    term.clear()

    term.setCursorPos(1, 1)
    term.setBackgroundColor(colors.white)
    term.setTextColor(colors.black)
    print("Search: "..query.."_")
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)

    local iStart = selectedIndex - math.floor(height / 2)
    if iStart < 1 then
      iStart = 1
    end
    local iEnd = iStart+height-3

    for i=iStart,iEnd do
      -- local y = i-iStart + 2
      -- term.setCursorPos(1, y)

      if i == selectedIndex then
        term.setBackgroundColor(colors.blue)
      else
        term.setBackgroundColor(colors.black)
      end
  
      local item = listFiltered[i]
  
      if item ~= nil then
        print(config.renderListItem(item))
      else
        print("~")
      end
    end

    -- TODO: Render help from hotkeys
    term.setBackgroundColor(colors.white)
    term.setTextColor(colors.black)
    term.setCursorPos(1, height-1)
    term.write("   ctrl-r:refresh and import                       ")
    term.setCursorPos(1, height)
    term.write("   ctrl-q:drop 1  ctrl-w:drop 16  ctrl-e:drop 64   ")
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
  end

  local function setSelectedIndex(index)
    selectedIndex = index
    local listN = table.getn(listFiltered)
    if selectedIndex > listN then
      selectedIndex = listN
    end
    if selectedIndex < 1 then
      selectedIndex = 1
    end

    render()
  end

  local function refreshListFiltered()
    -- Save the previous selected item
    local prevKey
    if listFiltered[selectedIndex] then
      prevKey = config.getItemKey(listFiltered[selectedIndex])
    end

    -- Filter by the query
    listFiltered = {}
    for _, item in pairs(list) do
      if config.queryMatches(query, item) then
        table.insert(listFiltered, item)
      end
    end

    -- Sort
    table.sort(listFiltered, config.compare)

    -- Update so that the same item is selected
    local newSelectedIndex = 1 -- If no match
    for i, item in ipairs(listFiltered) do
      if config.getItemKey(item) == prevKey then
        newSelectedIndex = i
        break
      end
    end

    setSelectedIndex(newSelectedIndex)
  end

  local function setList(newList)
    list = newList
    refreshListFiltered()
  end

  local function hotkeyHandler(key, ...)
    local hotkey = config.hotkeys[key]
    if hotkey then
      hotkey.action(...)
    end
  end

  config.hotkeys[keys.backspace] = {
    action=function()
      query = ""
      refreshListFiltered()
    end
  }

  local function hotkeysToHandlerMap()
    map = {}
    for key, hotkey in pairs(config.hotkeys) do
      map[key] = hotkey.action
    end
    return map
  end

  local keyControlDelegator = delegator{
    [keys.backspace]=function()
      query = ""
      refreshListFiltered()
    end,
  }

  keyControlDelegator.addHandlerMap(hotkeysToHandlerMap())

  local keyNoControlDelegator = delegator{
    [keys.leftCtrl]=function() controlHeld = true end,
    [keys.rightCtrl]=function() controlHeld = true end,
    [keys.backspace]=function()
      query = string.sub(query, 1, -2)
      refreshListFiltered()
    end,
    [keys.up]=function() setSelectedIndex(selectedIndex - 1) end,
    [keys.left]=function() setSelectedIndex(selectedIndex - 10) end,
    [keys.down]=function() setSelectedIndex(selectedIndex + 1) end,
    [keys.right]=function() setSelectedIndex(selectedIndex + 10) end,
    [keys.home]=function() setSelectedIndex(1) end,
    [keys["end"]]=function() setSelectedIndex(1/0) end,
  }

  local eventHandlerMap = {
    key=function(...)
      if controlHeld then
        hotkeyHandler(...)
      else
        keyNoControlDelegator.handle(...)
      end
    end,
    key_up=delegator{
      [keys.leftCtrl]=function() controlHeld = false end,
      [keys.rightCtrl]=function() controlHeld = false end,
    }.handle,
    char=function(character)
      if not controlHeld then
        query = query..character
        refreshListFiltered()
      end
    end,
    mouse_scroll=function(direction) setSelectedIndex(selectedIndex + direction) end,
    term_resize=render,
  }

  setList(config.list)

  return {
    setList=setList,
    enableEvents=function()
      eventHandler.addHandlerMap(eventHandlerMap)
    end,
    disableEvents=function()
      eventHandler.removeHandlerMap(eventHandlerMap)
    end,
  }
end

return ListView
