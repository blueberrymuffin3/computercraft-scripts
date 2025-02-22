local homeX, homeY, homeZ = 498, 72, 611
local farmY = 73
local farmX1, farmZ1 = 494, 604
local farmX2, farmZ2 = 496, 611

local myX, myY, myZ
local facingX, facingZ = 0, 0

local function goUp()
  if turtle.up() then
    myY = myY + 1
    return true
  else
    return false
  end
end

local function goDown()
  if turtle.down() then
    myY = myY - 1
    return true
  else
    return false
  end
end

local function goForward()
  if turtle.forward() then
    myX = myX + facingX
    myZ = myZ + facingZ
    return true
  else
    return false
  end
end

local function turnLeft()
  assert(turtle.turnLeft())
  facingX, facingZ = facingZ, -facingX
end

local function turnRight()
  assert(turtle.turnRight())
  facingX, facingZ = -facingZ, facingX
end

local function turnTo(targetX, targetZ)
  if targetX * facingX + targetZ * facingZ < 0 then
    turnLeft()
    turnLeft()
  elseif targetX * facingX + targetZ * facingZ == 0 then
    if targetX * facingZ - targetZ * facingX > 0 then
      turnLeft()
    else
      turnRight()
    end
  end
end

local function goTo(targetX, targetY, targetZ)
  while myY < targetY do
    while not goUp() do turtle.digUp() end
  end
  while myY > targetY do
    while not goDown() do turtle.digDown() end
  end

  if myZ ~= targetZ then
    turnTo(0, targetZ - myZ)
    while myZ ~= targetZ do
      while not goForward() do turtle.dig() end
    end
  end

  if myX ~= targetX then
    turnTo(targetX - myX, 0)
    while myX ~= targetX do
      while not goForward() do turtle.dig() end
    end
  end

  return true
end

local function locate()
  while true do
    ::loop::
    print("Locating turtle...")
    initialX, initialY, initialZ = gps.locate()
    if initialX == nil then goto loop end
    
    local moveOk = false
    for i=1,4 do
      if turtle.forward() then
        moveOk = true
        break
      end
      turtle.turnLeft()
    end

    if not moveOk then
      assert(turtle.up())
      assert(turtle.forward())
    end

    myX, myY, myZ = gps.locate()
    if myX == nil then goto loop end

    facingX, facingZ = myX - initialX, myZ - initialZ
    return
  end
end

locate()
print("Turtle is at", myX, myY, myZ, "facing", facingX, 0, facingZ)

while true do
  print("Checking field")
  turtle.select(1)
  assert(goTo(myX, farmY, myZ))
  assert(goTo(farmX1, farmY, farmZ1))
  for targetZ=farmZ1,farmZ2,2 do
    for targetX=farmX1,farmX2,1 do
      assert(goTo(targetX, farmY, targetZ))
    end
    for targetX=farmX2,farmX1,-1 do
      assert(goTo(targetX, farmY, targetZ + 1))
    end
  end
  assert(goTo(homeX, farmY, homeZ))
  assert(goTo(homeX, homeY, homeZ))
  turnTo(1, 0)

  print("Dumping items")
  for i=1,15 do
    turtle.select(i)
    turtle.drop()
  end
  
  turnTo(0, 1)
  while turtle.getFuelLevel() < 1000 do
    print("Refueling from tank")
    turtle.select(16)
    turtle.drop()
    sleep(1)
    turtle.suck()
    turtle.refuel()
  end

  print("Sleeping")
  sleep(2 * 60)
  assert(goTo(farmX1, homeY, homeZ))
end
