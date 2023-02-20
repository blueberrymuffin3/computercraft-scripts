require("libdir")

local home = vector.new(164, 67, -203)

local dock_charger_pos = vector.new(164, 67, -202)
local dock_charger_face = ld.east

local dock_storage_pos = vector.new(164, 66, -202)
local dock_storage_face = ld.east

local dock_water_pos = vector.new(164, 65, -202)

local min_fuel_level = 5000
local refuel_storage_location = vector.new(182, 69, -221)
local refuel_checkpoint_1 = vector.new(home.x, 85, home.z)
local refuel_checkpoint_2 = vector.new(refuel_storage_location.x, 85, refuel_storage_location.z)

local paths = {
    {
        start = home + ld.east + ld.up,
        direction = ld.north,
        checks = { ld.down, ld.west },
    },
    {
        start = home + ld.west + ld.down,
        direction = ld.north,
        checks = { ld.up, ld.east },
    }
}

levels = 3
level_offset = ld.up * 3

local first_source_offset = 2
local last_source_offset = 10
local source_count = last_source_offset - first_source_offset + 1


local quartz_cluster_name = "ae2:quartz_cluster"
local source_l0 = "ae2:quartz_block"
local source_l1 = "ae2:damaged_budding_quartz"
local source_l2 = "ae2:chipped_budding_quartz"
local source_l3 = "ae2:flawed_budding_quartz"

local fuel = "minecraft:oak_log"
local block = "minecraft:cobbled_deepslate"
local certus_dust = "ae2:certus_quartz_dust"
local certus_crystal = "ae2:certus_quartz_crystal"
local certus_charged = "ae2:charged_certus_quartz_crystal"


last_unsorted_slot = 9

sorting_map = {
    [fuel] = 10,
    [block] = 11,
    [certus_dust] = 12,
    [source_l0] = 13,
    [source_l3] = 14,
    [certus_crystal] = 15,
    [certus_charged] = 16,
}

force_check_all_sources_every = 10

function main()
  generate_levels()

  print("Starting in 10 seconds")
  sleep(10)
  sort_inv()

  ld.localize()
  ld.orient()

  pathi = 1
  while true do
    for _ = 1, force_check_all_sources_every do
      for pathi = 1, #paths do
        refuel()
        print("Checking path " .. tostring(pathi))
        check_path(paths[pathi], false)
        sort_inv()
        charge_quartz()
        upgrade_source()
        dump_extra_certus()

        print("fuel is " .. turtle.getFuelLevel())
      end
    end

    for pathi = 1, #paths, 2 do
      refuel()
      print("Force checking path " .. tostring(pathi))
      check_path(paths[pathi], true)
      sort_inv()
    end
  end
end

function table.copy(t)
  local u = {}
  for k, v in pairs(t) do u[k] = v end
  return u
end

function generate_levels()
  local path_count = #paths
  for level = 1, levels - 1 do
    for path_i = 1, path_count do
      local new_i = path_i + level * path_count
      paths[new_i] = table.copy(paths[path_i])
      paths[new_i].start = paths[new_i].start + level_offset * level
    end
  end
end

function refuel()
  if turtle.getFuelLevel() < min_fuel_level and turtle.getItemCount(sorting_map[fuel]) > 0 then
    turtle.select(sorting_map[fuel])
    assert(turtle.refuel())
  end

  sort_inv()

  if turtle.getItemCount(sorting_map[fuel]) == 0 then
    print("Getting more fuel")
    go_to_zxy(refuel_checkpoint_1)
    go_to_zxy(refuel_checkpoint_2)
    go_to_zxy(refuel_storage_location)
    turtle.select(sorting_map[fuel])
    for i = 1, 4 do
      redstone.setOutput("bottom", true)
      sleep(0.25)
      redstone.setOutput("bottom", false)
      sleep(0.25)
    end
    go_to_zxy(refuel_checkpoint_2)
    go_to_zxy(refuel_checkpoint_1)
    go_to_zxy(home)
  end
end

function check_path(path, force_check)
  go_to_zxy(home)
  go_to_zxy(path.start)
  for i = 1, last_source_offset do
    assert(ld.go(path.direction))

    if i >= first_source_offset then
      local block_checked = false
      local block_dead = false

      for j, direction_check in ipairs(path.checks) do
        local exists, meta = ld.inspect(direction_check)
        local force_mine_this = force_check and j == 2 and not block_checked
        if exists and meta.name ~= quartz_cluster_name and not force_mine_this then
          -- print("(" .. tostring(i) .. "), (" .. tostring(direction_check) .. ") still growing")
        else
          if exists then
            assert(ld.dig(direction_check))
            print("crystal harvested")
          end

          if not block_checked and ld.go(direction_check) then
            block_checked = true
            local direction_source = path.checks[3 - j]

            local exists, meta = ld.inspect(direction_source)
            if not exists then
              print("source " .. tostring(i) .. " is missing")
              block_dead = true
            elseif meta.name == source_l0 then
              print("source " .. tostring(i) .. " is dead")
              assert(ld.dig(direction_source))
              block_dead = true
            elseif meta.name == source_l3 or
                meta.name == source_l2 or
                meta.name == source_l1 then
              print("source " .. tostring(i) .. " is ok")
            else
              print("Unexpected block " .. meta.name .. " found")
              assert(ld.dig(direction_source))
              block_dead = true
            end

            if block_dead and turtle.getItemCount(sorting_map[source_l3]) > 0 then
              assert(turtle.select(sorting_map[source_l3]))
              assert(ld.place(direction_source))
            end

            assert(ld.go( -direction_check))
          end
        end
      end

      if not block_checked then
        print("source " .. tostring(i) .. " is unknown")
      end
    end
  end
  go_to_zxy(home)
end

function merge_up(slot)
  meta = turtle.getItemDetail(slot)

  if meta then
    for target_slot = 1, math.min(slot - 1, last_unsorted_slot) do
      target_meta = turtle.getItemDetail(target_slot)
      free_space = turtle.getItemSpace(target_slot)
      if free_space > 0 and not target_meta or target_meta.name == meta.name then
        assert(turtle.select(slot))
        if turtle.transferTo(target_slot) then
          if turtle.getItemCount(slot) == 0 then
            return true
          end
        end
      end
    end
  end
end

function sort_inv()
  for slot = last_unsorted_slot + 1, 16 do
    local meta = turtle.getItemDetail(slot)

    if meta then
      correct_slot = sorting_map[meta.name]

      if not correct_slot or correct_slot ~= slot then
        assert(merge_up(slot))
      end
    end
  end

  for slot = 1, last_unsorted_slot do
    local meta = turtle.getItemDetail(slot)
    if meta then
      target_slot = sorting_map[meta.name]
      if target_slot then
        local target_meta = turtle.getItemDetail(target_slot)
        if target_meta and target_meta.name ~= meta.name then
          assert(merge_up(target_slot))
        end

        free_space = turtle.getItemSpace(target_slot)
        if free_space >= meta.count then
          assert(turtle.select(slot))
          assert(turtle.transferTo(target_slot))
        elseif free_space > 0 then
          assert(turtle.select(slot))
          assert(turtle.transferTo(target_slot, free_space))
        end

        merge_up(slot)
      end
    end
  end
end

function charge_quartz()
  local missing_charged_count = math.min(
          turtle.getItemSpace(sorting_map[certus_charged]),
          turtle.getItemCount(sorting_map[certus_crystal]))

  if missing_charged_count == 0 then return end

  print("Charging " .. tostring(missing_charged_count) .. " quartz")

  go_to_zxy(dock_charger_pos, dock_charger_face)

  for i = 1, missing_charged_count do
    turtle.select(sorting_map[certus_crystal])
    turtle.drop(1)

    repeat
      sleep(0.1)
      local meta = peripheral.call("front", "getItemDetail", 1)
    until meta.name == certus_charged

    turtle.select(sorting_map[certus_charged])
    turtle.suck()
  end
end

function upgrade_source()
  local missing_l3_source = math.min(
          turtle.getItemSpace(sorting_map[source_l3]) - 64 + source_count,
          turtle.getItemCount(sorting_map[source_l0]),
          math.floor(turtle.getItemCount(sorting_map[certus_charged]) / 3))

  local dust_to_convert = math.min(
          turtle.getItemCount(sorting_map[certus_dust]),
          turtle.getItemCount(sorting_map[certus_charged])
      )

  if missing_l3_source == 0 and dust_to_convert == 0 then return end


  go_to_zxy(dock_water_pos)
  assert(turtle.select(sorting_map[block]))
  assert(turtle.placeUp())
  assert(ld.go(ld.down))

  local check_l3_count = turtle.getItemCount(sorting_map[source_l3])

  if missing_l3_source > 0 then
    print("Upgrading " .. tostring(missing_l3_source) .. " sources")

    assert(turtle.select(sorting_map[source_l0]))
    assert(turtle.dropUp(missing_l3_source))
    assert(turtle.select(sorting_map[certus_charged]))
    assert(turtle.dropUp(missing_l3_source * 3))

    sleep(5)

    assert(turtle.select(sorting_map[source_l3]))
    while turtle.suckUp() do
    end

    check_l3_count = check_l3_count + missing_l3_source
    assert(check_l3_count == turtle.getItemCount(sorting_map[source_l3]))
  end

  if dust_to_convert > 0 then
    print("Converting " .. tostring(dust_to_convert) .. " certus dust")

    assert(turtle.select(sorting_map[certus_dust]))
    assert(turtle.dropUp(dust_to_convert))
    assert(turtle.select(sorting_map[certus_charged]))
    assert(turtle.dropUp(dust_to_convert))

    sleep(5)

    assert(turtle.select(sorting_map[certus_crystal]))
    while turtle.suckUp() do
    end
  end

  assert(ld.go(ld.up))
  assert(turtle.select(sorting_map[block]))
  assert(turtle.digUp())

  go_to_zxy(dock_charger_pos)
end

function dump_extra_certus()
  for slot = 1, last_unsorted_slot do
    meta = turtle.getItemDetail(slot)
    if meta and meta.name == certus_crystal then
      go_to_zxy(dock_storage_pos, dock_storage_face)
      assert(turtle.select(slot))
      assert(turtle.drop())
    end
  end
end

function go_to_zxy(target, face)
  local delta = target - ld.position
  print("going delta " .. tostring(delta) .. " to " .. tostring(target))

  if delta:length() ~= 0 then
    local xdirection = vector.new(delta.x, 0, 0):normalize()
    local ydirection = vector.new(0, delta.y, 0):normalize()
    local zdirection = vector.new(0, 0, delta.z):normalize()

    for _ = 1, math.abs(delta.z) do
      assert(ld.go(zdirection))
    end

    for _ = 1, math.abs(delta.x) do
      assert(ld.go(xdirection))
    end

    for _ = 1, math.abs(delta.y) do
      assert(ld.go(ydirection))
    end
  end

  if face then
    assert(ld.face(face))
  end
end

main()
