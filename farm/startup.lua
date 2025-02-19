local homeX, homeY, homeZ = 76, 72, 368
local farmY = 73
local farmX1, farmZ1 = 77, 367
local farmX2, farmZ2 = 84, 372

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
    if not goUp() then return false end
  end
  while myY > targetY do
    if not goDown() then return false end
  end

  if myZ ~= targetZ then
    turnTo(0, targetZ - myZ)
    while myZ ~= targetZ do
      if not goForward() then return false end
    end
  end

  if myX ~= targetX then
    turnTo(targetX - myX, 0)
    while myX ~= targetX do
      if not goForward() then return false end
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

local function checkCrop()
  exists, data = turtle.inspectDown()
  if exists and data.name == "minecraft:potatoes" and data.state.age == 7 then
    turtle.digDown()
    turtle.placeDown()
  end
end

while true do
  print("Checking field")
  turtle.select(1)
  assert(goTo(myX, farmY, myZ))
  assert(goTo(farmX1, farmY, farmZ1))
  for targetZ=farmZ1,farmZ2,2 do
    for targetX=farmX1,farmX2,1 do
      assert(goTo(targetX, farmY, targetZ))
      checkCrop()
    end
    for targetX=farmX2,farmX1,-1 do
      assert(goTo(targetX, farmY, targetZ + 1))
      checkCrop()
    end
  end
  assert(goTo(farmX1, farmY, homeZ))
  assert(goTo(farmX1, homeY, homeZ))
  assert(goTo(homeX, homeY, homeZ))
  turnTo(0, -1)

  print("Dumping items")
  for i=2,15 do
    turtle.select(i)
    turtle.drop(i)
  end
  
  while turtle.getFuelLevel() < 1000 do
    print("Refueling from tank")
    turtle.select(16)
    turtle.dropDown()
    sleep(1)
    turtle.suckDown()
    turtle.refuel()
  end

  print("Sleeping")
  sleep(4 * 60)
  assert(goTo(farmX1, homeY, homeZ))
end
