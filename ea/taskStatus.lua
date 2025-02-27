local eventHandler = require("eventHandler")
local periodic = require("periodic")
local netMan = require("netMan")

local myTasks = {}

local function sendTasks()
  netMan.sendToType("console", "tasks", {
    type=netMan.nodeType,
    host=netMan.nodeType.." "..netMan.nodeName,
    tasks=myTasks
  })
end

local function addTask(task)
  table.insert(myTasks, task)
  sendTasks()
end

local function removeTask(task)
  for i, v in ipairs(myTasks) do
    if v == task then
      table.remove(myTasks, i)
      sendTasks()
      return
    end
  end
end

-- local updatePeriodic = periodic{
--   minDelay=0.1,
--   maxDelay=10,
--   action=function()
--     netMan.sendToType("console", "tasks", {
--       host=netMan.nodeType.." "..netMan.nodeName,
--       tasks=myTasks
--     })
--   end,
-- }

local function runAsTask(name, action)
  local taskData = {
    name=name
  }
  addTask(taskData)

  local function progress(done, total)
    taskData.done = done
    taskData.total = total
    sendTasks()
  end

  local status, err = pcall(action, progress)
  
  removeTask(taskData)

  if not status then
    error(err)
  end
end

eventHandler.schedule(sendTasks)

return {
  runAsTask=runAsTask,
  wrap=function(name, action)
    return function()
      runAsTask(name, function(progress)
        action(progress)
      end)
    end
  end
}
