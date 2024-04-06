local eventHandler = require("eventHandler")
local delegator = require("delegator")
local netMan = require("netMan")

local allTasks = {}

netMan.addMessageHandler(delegator{
  tasks=function(message)
    allTasks[message.host] = message.tasks
    os.queueEvent("tasks_changed")
  end
}.handle)

local function render()
  term.setBackgroundColor(colors.orange)
  term.setTextColor(colors.black)

  local width, height = term.getSize()
  local y = height - 4
  local x = 10

  for host, tasks in pairs(allTasks) do
    for _, task in ipairs(tasks) do
      local line = host..": "..task.name
      if task.done and task.total then
        line = line.." ("..task.done.."/"..task.total..")"
      end
      
      term.setCursorPos(x, y)
      term.write(" "..line.." ")
    end
  end

  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.black)
end

return {
  render=render
}
