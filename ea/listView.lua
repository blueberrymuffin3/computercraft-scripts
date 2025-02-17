--- Config Keys:
-- list?: table
-- renderListItem(item): string
-- queryMatches(query, item): boolean
-- compare?(a, b): boolean
-- getItemKey?(item): any
-- hotkeys: map from key to
--   action: function(item)
--   description?: string

local eventHandler = require("eventHandler")
local delegator = require("delegator")
local typeCheck = require("typeCheck")
taskStatusDisplay = require("taskStatusDisplay")

local controlHeld = false

function ListView(config)
  typeCheck(config, {
    defaults={
      list={},
      compare=function(a, b) return false end,
      getItemKey=function(item) return item end,
    },
    types={
      list="table",
      renderListItem="function",
      queryMatches="function",
      hotkeys="table",
      compare="function",
      getItemKey="function",
    }
  })

  local list = nil
  local listFiltered = {}
  local selectedIndex = 1
  local query = ""

  local function writeLine(text, width, align)
    align = align or 0

    local textLen = string.len(text)

    local prefix = math.floor((width - textLen) * align)
    for i=1,prefix do
      text = " "..text
    end
    
    local suffix = width - textLen - prefix
    for i=1,suffix do
      text = text.." "
    end
    
    term.write(text)
  end

  local function renderHotkeys()
    local width, height = term.getSize()
  
    local lines = {}
    local seperator = "  "
    local line = nil

    for key, data in pairs(config.hotkeys) do
      local keyName = keys.getName(key)
      local entry = "ctrl-"..keyName..":"..data.description
      if line ~= nil then
        local newLine = line..seperator..entry
        if string.len(newLine) > width then
          table.insert(lines, line)
          line = entry
        else
          line = newLine
        end
      else
        line = entry
      end
    end

    if line ~= nil then
      table.insert(lines, line)
    end

    return lines
  end

  local function render()
    local width, height = term.getSize()

    -- Render header lines
    local headerLinesN = taskStatusDisplay.render() + 1
    term.setBackgroundColor(colors.white)
    term.setTextColor(colors.black)
    term.setCursorPos(1, headerLinesN)
    writeLine("Search: "..query.."_", width, 0.5)
    
    -- Render footer lines
    local footerLines = renderHotkeys()
    local footerLinesN = table.getn(footerLines)
    term.setBackgroundColor(colors.white)
    term.setTextColor(colors.black)
    for i, footerLine in pairs(footerLines) do
      term.setCursorPos(1, height - footerLinesN + i)
      writeLine(footerLine, width, 0.5)
    end

    local listHeight = height - headerLinesN - footerLinesN
    local iStart = selectedIndex - math.floor(listHeight / 2)
    if iStart < 1 then
      iStart = 1
    end
    local iEnd = iStart + listHeight - 1
    term.setTextColor(colors.white)
    for i=iStart,iEnd do
      local y = 1 + headerLinesN + i - iStart
      term.setCursorPos(1, y)
      
      if i == selectedIndex then
        term.setBackgroundColor(colors.blue)
      else
        term.setBackgroundColor(colors.black)
      end
  
      local item = listFiltered[i]
  
      if item ~= nil then
        writeLine(config.renderListItem(item), width)
      else
        writeLine("~", width)
      end
    end

    -- Reset colors
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

  local keyControlDelegator = delegator{
    [keys.backspace]=function()
      query = ""
      refreshListFiltered()
    end,
  }

  local function hotkeysToHandlerMap()
    map = {}
    for key, hotkey in pairs(config.hotkeys) do
      map[key] = function()
        hotkey.action(listFiltered[selectedIndex])
      end
    end
    return map
  end
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
        keyControlDelegator.handle(...)
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
    tasks_changed=render,
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
