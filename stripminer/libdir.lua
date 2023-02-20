ld = {}

ld.up = vector.new(0, 1, 0)
ld.down = -ld.up
ld.east = vector.new(1, 0, 0)
ld.south = vector.new(0, 0, 1)
ld.west = -ld.east
ld.north = -ld.south

ld.cardinal_directions = {ld.north, ld.east, ld.south, ld.west}
ld.all_directions = {ld.up, ld.down, ld.north, ld.east, ld.south, ld.west}

ld.stack = { vector.new(0, 0, 0) }
ld.stacki = 1
ld.heading = ld.north

ld.inspect_dotup = {}
ld.inspect_dotup[ld.up:dot(ld.up)] = turtle.inspectUp
ld.inspect_dotup[ld.up:dot(ld.east)] = turtle.inspect
ld.inspect_dotup[ld.up:dot(ld.down)] = turtle.inspectDown

ld.move_dotup = {}
ld.move_dotup[ld.up:dot(ld.up)] = turtle.up
ld.move_dotup[ld.up:dot(ld.east)] = turtle.forward
ld.move_dotup[ld.up:dot(ld.down)] = turtle.down

ld.dig_dotup = {}
ld.dig_dotup[ld.up:dot(ld.up)] = turtle.digUp
ld.dig_dotup[ld.up:dot(ld.east)] = turtle.dig
ld.dig_dotup[ld.up:dot(ld.down)] = turtle.digDown

function ld.face(direction)
  if direction == ld.heading then
    return true
  elseif direction == ld.up then
    return true
  elseif direction == ld.down then
    return true
  end

  status = false
  
  if direction == ld.heading:cross(ld.up) then
    status = turtle.turnRight()
  elseif direction == ld.heading:cross(ld.down) then
    status = turtle.turnLeft()
  elseif direction == -ld.heading then
    status = turtle.turnRight() and turtle.turnRight()
  else
    error("Illegal direction,heading combo: " .. tostring(direction) .. "/" .. tostring(ld.heading))
  end

  if status then
    ld.heading = direction
  end

  return status
end

function ld.go(direction)
  dh = direction:dot(ld.heading)
  du = direction:dot(ld.up)

  if dh == -1 then
    return turtle.back()
  else
    return ld.face(direction) and ld.move_dotup[du]()
  end
end

function ld.go_dig(direction)
  while not ld.go(direction) do
    if not ld.dig(direction) then
      return false
    end
  end
  return true
end

function ld.push_go_dig(direction)
  success = ld.go_dig(direction)

  if success then
    ld.stacki = ld.stacki + 1
    ld.stack[ld.stacki] = ld.stack[ld.stacki - 1] + direction
  end

  return success
end

function ld.pop_go_dig()
  success = ld.go_dig(ld.stack[ld.stacki - 1] - ld.stack[ld.stacki])

  if success then
    ld.stacki = ld.stacki - 1
  end

  return success
end

function ld.pop_all()
  while ld.stacki > 0 do
    if not ld.pop_go_dig() then
      return false
    end
  end

  return true
end

function ld.dig(direction)
  ld.face(direction)
  du = direction:dot(ld.up)
  return ld.dig_dotup[du]()
end

function ld.inspect(direction)
  ld.face(direction)
  du = direction:dot(ld.up)
  return ld.inspect_dotup[du]()
end

function ld.get_position()
  return ld.stack[ld.stacki]
end

function ld.localize()
  ld.stack[ld.stacki] = vector.new(gps.locate())

  print("GPS location is " .. tostring(ld.stack[ld.stacki]))
end

function ld.orient()
  for _, direction in ipairs(ld.cardinal_directions) do
    is_clear = not ld.inspect(direction)
    if is_clear then
      assert(ld.go(direction))
      p2 = vector.new(gps.locate())
      assert(ld.go(-direction))
      ld.face(direction)

      ld.heading = p2 - ld.stack[ld.stacki]
      print("GPS heading is " .. tostring(ld.heading))
      assert(ld.heading:length() == 1 or not ld.heading:dot(ld.up) == 0, "invalid gps orientation")
      return
    end
  end

  error("Turtle is trapped, cannot determine orientation")
end

return ld
