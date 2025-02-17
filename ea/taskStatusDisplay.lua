local eventHandler = require("eventHandler")
local delegator = require("delegator")
local netMan = require("netMan")

local allTasks = {}

local function writeLine(text, width, fg, bg1, bg2, percent)
  align = align or 0
  bg2 = bg2 or bg1
  percent = percent or 0

  local suffix = width - string.len(text)
  text = text..string.rep(" ", suffix)

  local fg = string.rep(colors.toBlit(fg), width)
  local bg = string.rep(colors.toBlit(bg1), width * percent)
  bg = bg..string.rep(colors.toBlit(bg2), width - string.len(bg))

  term.blit(text, fg, bg)
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
    local text = chosenHost..": "..chosenTask.name
    local progress = 0
    if chosenTask.done ~= nil then
      if chosenTask.total ~= nil and chosenTask.total > 0 then
        text = text.." ("..chosenTask.done.."/"..chosenTask.total..")"
        progress = chosenTask.done / chosenTask.total
      else
        text = text.." ("..chosenTask.done.."/?)"
      end
    end
    if taskCount > 1 then
      text = text.." [+"..(taskCount-1).."]"
    end
    writeLine(text, width, colors.black, colors.orange, colors.yellow, progress)
  else
    writeLine("Ready", width, colors.black, colors.green)
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
