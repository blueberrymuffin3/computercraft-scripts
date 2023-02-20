require("libdir")

home = vector.new(241, 47, -249)

mining_level = 20
mining_level_max = 30
mining_level_min = 10
mining_recursion_limit = 25

mining_home = vector.new(home.x, mining_level, home.z) + ld.north:mul(8)
mining_direction = ld.west
mining_length = 500

safe_fuel_buffer = 50

inventory_fill = nil

display_id = -1

function equip_modem()
  if not peripheral.hasType("right", "modem") then
    assert(turtle.select(1))
    assert(turtle.equipRight()) -- Equip modem
    assert(peripheral.hasType("right", "modem"))
  end
end

function equip_pickaxe()
  if peripheral.hasType("right", "modem") then
    assert(turtle.select(1))
    assert(turtle.equipRight()) -- Equip pickaxe
    assert(not peripheral.hasType("right", "modem"))
  end
end

function update_display(task_name)
  equip_modem()

  if not rednet.isOpen() then
    rednet.open("right")
  end

  if display_id < 0 then
    sleep(1)
     _display_id = rednet.lookup("stripminer_display", "stripminer_display")
    if _display_id then
      display_id = _display_id
    else
      print("Display did not resolve " .. tostring(_display_id))
    end
  end

  lines = {
    "Strip Miner v0.1 status:",
    "  inventory: " .. tostring(inventory_fill) .. "/16",
    "  fuel:      " .. tostring(turtle.getFuelLevel()) .. "/" .. tostring(turtle.getFuelLimit()),
    "  distance:  " .. tostring(ld.stacki),
    "  location:  " .. tostring(ld.get_position()),
    "  active task:",
    "    " .. task_name,
  }

  assert(rednet.isOpen())

  sleep(0.1)
  -- best effort, but we don't care if it fails
  ok, err = pcall(rednet.send, display_id, lines, "stripminer_display")
  
  if not ok then
    print("Error sending to display")
    print(err)
  end

  rednet.close("right")
end

function should_mine(direction)
  if direction == ld.up and ld.get_position().y >= mining_level_max then
    print("hit virtual ceiling")
    return false
  elseif direction == ld.dowm and ld.get_position().y <= mining_level_min then
    print("hit virtual floor")
    return false
  end

  exists, meta = ld.inspect(direction)

  if not exists then
    return false
  elseif meta.name == "minecraft:raw_iron_block"
      or meta.name == "minecraft:raw_copper_block"
      or meta.name == "minecraft:raw_gold_block"
      or meta.name == "minecraft:andesite" then
    return true
  elseif meta.tags["forge:ores"] then
    return true
  end
  return false
end

check_ok_delay = 0
function check_ok()
  check_ok_delay = check_ok_delay - 1
  if check_ok_delay <= 0 then
    check_ok_delay = 15
  else
    return
  end

  turtle.select(1)
  while turtle.getItemCount() > 0 and turtle.getSelectedSlot() < 16 do
    turtle.select(turtle.getSelectedSlot() + 1)
  end
  if turtle.getSelectedSlot() == 16 then
    error("Inventory Full")
  end

  inventory_fill = turtle.getSelectedSlot() - 1
  turtle.select(1)

  if ld.stacki - safe_fuel_buffer > turtle.getFuelLimit() then
    error("Not enough fuel")
  end

  equip_modem()

  if not rednet.isOpen() then
    rednet.open("right")
  end

  rednet.send(display_id, "check_ok", "check_ok")
  id, msg = rednet.receive("check_ok", 5)
  if id then
    if not msg then
      error("Manual stop requested")
    end
  else
    error("Timeout checking manual stop status")
  end
end

function mine_vein()
  -- TODO: cache calls to should_mine to speed up mining
  cache = {}
  total = 0

  function recursive_mine(limit)
    if limit <= 0 then
      print("mining recursion limit reached")
    end

    for _, direction in ipairs(ld.all_directions) do
      if should_mine(direction) then
        check_ok()
        if total % 10 == 1 then
          update_display("mining vein (" .. tostring(total) .. ")")
        end

        equip_pickaxe()
        if ld.push_go_dig(direction) then
          total = total + 1
          recursive_mine(limit - 1)
          equip_pickaxe()
          assert(ld.pop_go_dig())
        else
          print("Failed to mine @ " .. tostring(ld.get_position() + direction))
        end
      end
    end
  end

  recursive_mine(mining_recursion_limit)
  return total
end

function stripmine()
  turtle.select(1)

  go_to_dig(mining_home)

  for i = 1, mining_length, 1 do
    check_ok()
    if i % 10 == 1 then
      update_display("advancing (" .. tostring(i) .. "/" .. tostring(mining_length) .. ")")
    end
    equip_pickaxe()
    assert(ld.push_go_dig(mining_direction))
    count = mine_vein()
    if count > 0 then
      print("Mined a vein of " .. tostring(count))
    end
  end
end

function dump_inventory()
  assert(ld.face(ld.west))

  for i = 2, 16 do
    turtle.select(i)
    if turtle.getItemCount() > 0 then
      if turtle.getItemDetail().name == "minecraft:cobblestone" then
        turtle.drop()
      else
        turtle.dropUp()
      end
    end
  end
end

function go_to_dig(target)
  delta = target - ld.get_position()

  -- follows y,z,x in order to hopefully reuse existing tunnels
  xdirection = vector.new(delta.x, 0, 0):normalize()
  ydirection = vector.new(0, delta.y, 0):normalize()
  zdirection = vector.new(0, 0, delta.z):normalize()

  for i = 1, math.abs(delta.y) do
    check_ok()
    if i % 10 == 1 then
      update_display("going to " .. tostring(target))
    end
    equip_pickaxe()
    assert(ld.push_go_dig(ydirection))
  end

  for i = 1, math.abs(delta.z) do
    check_ok()
    if i % 10 == 1 then
      update_display("going to " .. tostring(target))
    end
    equip_pickaxe()
    assert(ld.push_go_dig(zdirection))
  end

  for i = 1, math.abs(delta.x) do
    check_ok()
    if i % 10 == 1 then
      update_display("going to " .. tostring(target))
    end
    equip_pickaxe()
    assert(ld.push_go_dig(xdirection))
  end
end

function emergency_go_to_dig(target)
  delta = target - ld.get_position()
  -- follows y,z,x in order to hopefully reuse existing tunnels
  xdirection = vector.new(delta.x, 0, 0):normalize()
  ydirection = vector.new(0, delta.y, 0):normalize()
  zdirection = vector.new(0, 0, delta.z):normalize()

  equip_pickaxe()
  for _ = 1, math.abs(delta.y) do
    assert(ld.push_go_dig(ydirection))
  end

  for _ = 1, math.abs(delta.z) do
    assert(ld.push_go_dig(zdirection))
  end

  for _ = 1, math.abs(delta.x) do
    assert(ld.push_go_dig(xdirection))
  end
end

function emergency_return()
  home_delta = home - ld.get_position()

  if home_delta:length() == 0 then
    print("welcome home!")
    equip_modem()
    ld.orient()
    return false
  end

  update_display("emergency return")
  print("Emergency return, home_delta = " .. tostring(home_delta))

  if home_delta:length() == 1 then
    equip_modem()
    ld.orient()
    assert(ld.go(home_delta))
    return true
  end

  if home_delta.x == 0 and home_delta.z == 0 then
    print("returning home (vertical, move only)")
    update_display("emergency ascend")
    equip_pickaxe()
    emergency_go_to_dig(home)
    equip_modem()
    ld.orient()
    return true
  elseif ld.get_position().y > mining_level_max or ld.get_position().y < mining_level_min then
    error("stranded outside of a nominal position")
  else
    print("Emergency return to")
    update_display("emergency return")
    equip_modem()
    ok = pcall(ld.orient)
    if not ok then
      equip_pickaxe()
      assert(ld.push_go_dig(ld.heading)) -- We are probably trapped, this should help
      assert(ld.pop_go_dig())
      equip_modem()
      ld.orient()
    end

    equip_pickaxe()
    emergency_go_to_dig(vector.new(home.x, mining_level, home.z))

    -- ascend
    return emergency_return()
  end
end

function main()
  update_display("initializing...")
  
  equip_modem()
  ld.localize()
  if emergency_return() then
    return
  end

  status, err = pcall(stripmine)
  if err then
    print(err)
    equip_modem()
    ld.localize()
    ld.orient()
  end
  for i = 2, ld.stacki do
    if i % 10 == 2 then
      update_display("returning home")
    end
    equip_pickaxe()
    assert(ld.pop_go_dig())
  end

  update_display("dumping inventory")
  dump_inventory()
end

ok, err = pcall(main)
if not ok then
  print(err)
  pcall(update_display, "crashed, rebooting")
  print("main() function crashed, rebooting in 10 seconds")
  sleep(10)
  os.reboot()
else
  update_display("idle")
end
