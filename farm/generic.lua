local homeX, homeY, homeZ = 497, 68, 612
local farmY = 69
local farmX1, farmZ1 = 494, 604
local farmX2, farmZ2 = 501, 611

local myX, myY, myZ
local facingX, facingZ = 0, 0

local cropInfo = {
  ["minecraft:wheat"]={
    age=7,
    seeds="minecraft:wheat_seeds"
  },
  ["minecraft:beetroots"]={
    age=3,
    seeds="minecraft:beetroot_seeds"
  },
  ["cobblemon:red_mint"]={
    age=7,
    seeds="cobblemon:red_mint_seeds"
  },
  ["cobblemon:blue_mint"]={
    age=7,
    seeds="cobblemon:blue_mint_seeds"
  },
  ["cobblemon:cyan_mint"]={
    age=7,
    seeds="cobblemon:cyan_mint_seeds"
  },
  ["cobblemon:pink_mint"]={
    age=7,
    seeds="cobblemon:pink_mint_seeds"
  },
  ["cobblemon:green_mint"]={
    age=7,
    seeds="cobblemon:green_mint_seeds"
  },
  ["cobblemon:white_mint"]={
    age=7,
    seeds="cobblemon:white_mint_seeds"
  },
}

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

local function findItem(name)
  for i=1,15 do
    detail = turtle.getItemDetail(i)
    if detail.name == name then
      turtle.select(i)
      return true
    end
  end
  return false
end

local function checkCrop()
  exists, data = turtle.inspectDown()
  if not exists then return end
  info = cropInfo[data.name]
  if info then
    if info.age == data.state.age then
      turtle.select(1)
      turtle.digDown()
      if findItem(info.seeds) then
        turtle.placeDown()
      end
    end
  else
    print("Unknown crop", data.name)
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
    if targetZ == farmZ2 then break end
    for targetX=farmX2,farmX1,-1 do
      assert(goTo(targetX, farmY, targetZ + 1))
      checkCrop()
    end
  end
  assert(goTo(homeX, myY, myZ))
  assert(goTo(homeX, myY, homeZ))
  assert(goTo(homeX, homeY, homeZ))
  turnTo(-1, 0)

  print("Dumping items")
  for i=1,15 do
    turtle.select(i)
    turtle.drop()
  end
  
  turnTo(1, 0)
  while turtle.getFuelLevel() < 1000 do
    print("Refueling from tank")
    turtle.select(16)
    turtle.drop()
    sleep(1)
    turtle.suck()
    turtle.refuel()
  end

  print("Sleeping")
  sleep(4 * 60)
  assert(goTo(homeX, farmY, homeZ))
  assert(goTo(homeX, farmY, farmZ2))
end
