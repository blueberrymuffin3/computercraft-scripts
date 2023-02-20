ld = {}

ld.up = vector.new(0, 1, 0)
ld.down = -ld.up
ld.east = vector.new(1, 0, 0)
ld.south = vector.new(0, 0, 1)
ld.west = -ld.east
ld.north = -ld.south

ld.cardinal_directions = {ld.north, ld.east, ld.south, ld.west}
ld.all_directions = {ld.up, ld.down, ld.north, ld.east, ld.south, ld.west}

ld.position = vector.new(0, 0, 0)
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

ld.place_dotup = {}
ld.place_dotup[ld.up:dot(ld.up)] = turtle.placeUp
ld.place_dotup[ld.up:dot(ld.east)] = turtle.place
ld.place_dotup[ld.up:dot(ld.down)] = turtle.placeDown

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

  success = false
  if dh == -1 then
    success = turtle.back()
  else
    success = ld.face(direction) and ld.move_dotup[du]()
  end

  if success then
    ld.position = ld.position + direction
  end

  return success
end

function ld.dig(direction)
  ld.face(direction)
  du = direction:dot(ld.up)
  return ld.dig_dotup[du]()
end

function ld.place(direction)
  ld.face(direction)
  du = direction:dot(ld.up)
  return ld.place_dotup[du]()
end

function ld.inspect(direction)
  ld.face(direction)
  du = direction:dot(ld.up)
  return ld.inspect_dotup[du]()
end

function ld.localize()
  ld.position = vector.new(gps.locate())
  print("GPS location is " .. tostring(ld.position))
  
  assert(not (ld.position == vector.new(0, 0, 0)))
end

function ld.orient()
  for _, direction in ipairs(ld.cardinal_directions) do
    is_clear = not ld.inspect(direction)
    if is_clear then
      assert(ld.go(direction))
      p2 = vector.new(gps.locate())
      assert(ld.go(-direction))
      ld.face(direction)

      ld.heading = p2 - ld.position
      print("GPS heading is " .. tostring(ld.heading))
      assert(ld.heading:length() == 1 or not ld.heading:dot(ld.up) == 0, "invalid gps orientation")
      return
    end
  end

  error("Turtle is trapped, cannot determine orientation")
end

return ld
