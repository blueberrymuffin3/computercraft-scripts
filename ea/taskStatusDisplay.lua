local eventHandler = require("eventHandler")
local delegator = require("delegator")
local netMan = require("netMan")
local typeCheck = require("typeCheck")

local hostStatus = {}

local function writeLine(text, width, fg, bg1, bg2, percent)
  align = align or 0
  bg2 = bg2 or bg1
  percent = percent or 0

  local suffix = width - string.len(text)
  text = text..string.rep(" ", suffix)
  text = string.sub(text, 1, width)

  local fg = string.rep(colors.toBlit(fg), width)
  local bg = string.rep(colors.toBlit(bg1), width * percent)
  bg = bg..string.rep(colors.toBlit(bg2), width - string.len(bg))

  term.blit(text, fg, bg)
end

local function get_task(host_type)
  local chosenHost = nil
  local chosenTask = nil
  local taskCount = 0

  for host, status in pairs(hostStatus) do
    if status.type == host_type then
      if not chosenTask then
        chosenHost = host
      end
      for _, task in ipairs(status.tasks) do
        if not chosenTask then
          chosenTask = task
        end
        taskCount = taskCount + 1
      end
    end
  end

  return chosenHost, chosenTask, taskCount
end

local function render_line(config)
  typeCheck(config, {
    types={
      y="number",
      type="string",
      bg1="number",
      bg2="number",
    }
  })

  chosenHost, chosenTask, taskCount = get_task(config.type)

  local width, height = term.getSize()

  term.setCursorPos(1, config.y)
  if not chosenHost then
    writeLine("Waiting for "..config.type, width, colors.black, colors.red)
  elseif taskCount > 0 then
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
    writeLine(text, width, colors.black, config.bg1, config.bg2, progress)
  else
    writeLine(config.type.." ready", width, colors.black, colors.green)
  end

  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.white)
end

local lines = {
  {
    y=1,
    type="server",
    bg1=colors.orange,
    bg2=colors.yellow,
  },
  {
    y=2,
    type="crafter",
    bg1=colors.blue,
    bg2=colors.lightBlue,
  },
}

local function render()
  for _, line in ipairs(lines) do
    render_line(line)
  end
  return #lines
end

netMan.addMessageHandler(delegator{
  tasks=function(message)
    hostStatus[message.host] = message
    render()
  end
}.handle)

return {
  render=render,
}
