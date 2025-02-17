local eventHandler = require("eventHandler")
local delegator = require("delegator")
local netMan = require("netMan")

local allTasks = {}

local function writeLine(text, width)
  align = align or 0

  local suffix = width - string.len(text)
  for i=1,suffix do
    text = text.." "
  end
  
  term.write(text)
end

local function render()
  local chosenHost = nil
  local chosenTask = nil
  local taskCount = 0
  for host, tasks in pairs(allTasks) do
    for _, task in ipairs(tasks) do
      chosenHost = host
      chosenTask = task
      taskCount = taskCount + 1
    end
  end

  local width, height = term.getSize()

  term.setCursorPos(1, 1)
  if taskCount > 0 then
    term.setBackgroundColor(colors.orange)
    term.setTextColor(colors.black)
    local text = chosenHost..": "..chosenTask.name
    if chosenTask.total ~= nil and chosenTask.done ~= nil then
      text = text.." ("..chosenTask.done.."/"..chosenTask.total..")"
    end
    if taskCount > 1 then
      text = text.." [+"..(taskCount-1).."]"
    end
    writeLine(text, width)
  else
    term.setBackgroundColor(colors.green)
    term.setTextColor(colors.black)
    writeLine("Ready", width)
  end

  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.white)
end

netMan.addMessageHandler(delegator{
  tasks=function(message)
    allTasks[message.host] = message.tasks
    render()
  end
}.handle)
