local eventHandler = require("eventHandler")

eventHandler.schedule(function()
  local netMan = require("netMan")
  local delegator = require("delegator")
  local settingsUtil = require("settingsUtil")
  local itemsListener = require("itemsListener")
  local taskStatus = require("taskStatus")
  local falliblePeripheral = require("falliblePeripheral")
  local itemUtils = require("itemUtils")

  settings.define("ea.crafter.storage", { type="string" })
  local storageName = settingsUtil.getRequired("ea.crafter.storage")
  assert(peripheral.hasType(storageName, "inventory"))
  local crafterName = peripheral.getName(peripheral.find("minecraft:crafter"))
  local crafterPos = "bottom"

  local craftDb = {
    recipes={
      {
        machine="minecraft:crafter",
        batchSize=64,
        ingredients={
          { name="minecraft:iron_ingot", count=1 },
        },
        results={
          { name="minecraft:iron_nugget", count=9 },
        },
      },
      {
        machine="minecraft:crafter",
        batchSize=64,
        ingredients={
          { name="minecraft:iron_nugget", count=1 },
          { name="minecraft:iron_nugget", count=1 },
          { name="minecraft:iron_nugget", count=1 },
          { name="minecraft:iron_nugget", count=1 },
          { name="minecraft:iron_nugget", count=1 },
          { name="minecraft:iron_nugget", count=1 },
          { name="minecraft:iron_nugget", count=1 },
          { name="minecraft:iron_nugget", count=1 },
          { name="minecraft:iron_nugget", count=1 },
        },
        results={
          { name="minecraft:iron_ingot", count=1 },
        },
      },
    }
  }

  local function findIngredient(list, item)
    local countFound = 0
    local matchingSlots = {}

    for slot, slotItem in pairs(list) do
      if slotItem.name == item.name and slotItem.nbt == item.nbt and slotItem.count > 0 then
        countFound = countFound + slotItem.count
        table.insert(matchingSlots, slot)
      end
    end

    return matchingSlots
  end

  local function emptyCrafterLeftovers()
    local leftoverItems = falliblePeripheral.call(crafterName, "list")
    for slot, item in pairs(leftoverItems) do
      local moved = peripheral.call(crafterName, "pushItems", storageName, slot)
      assert(moved == item.count)
    end
  end

  local function importStorage()
    netMan.sendToType("server", "importFrom", {
      target=storageName,
    })
  end

  local function doCrafterCraft(recipe, recipeCount)
    local list = falliblePeripheral.call(storageName, "list")

    for i, ingredient in pairs(recipe.ingredients) do
      local wanted = ingredient.count * recipeCount
      local slots = findIngredient(list, ingredient)
      if slots == nil then
        print("Missing ingredient", ingredient.name)
        return false
      end

      local missing = wanted
      local mainSlot = nil

      for _, slot in ipairs(slots) do
        if mainSlot == nil and list[slot].count > 0 then
          mainSlot = slot
          missing = missing - list[mainSlot].count
        else
          if list[slot].count > 0 then
            local moved = peripheral.call(storageName, "pullItems", storageName, slot, missing, mainSlot) or 0
            missing = missing - moved
            list[slot].count = list[slot].count - moved
            list[mainSlot].count = list[mainSlot].count + moved
          end
        end

        if missing <= 0 then
          break
        end
      end

      if missing > 0 then
        print("Couldn't collect ingredient", ingredient.name, "to slot", mainSlot, "missing", missing)
        return false
      end

      local moved = peripheral.call(crafterName, "pullItems", storageName, mainSlot, wanted, i) or 0
      list[mainSlot].count = list[mainSlot].count - moved
      if moved ~= wanted then
        print("Failed to move", wanted, ingredient.name, "to slot", i)
        emptyCrafterLeftovers()
        return false
      end
    end

    for i=1,recipeCount do
      redstone.setOutput(crafterPos, true)
      sleep(0.1)
      redstone.setOutput(crafterPos, false)
      sleep(0.1)
    end
    sleep(0.1) -- Delay the next craft

    emptyCrafterLeftovers()
    print("Crafted", recipeCount * recipe.results[1].count, recipe.results[1].name)

    return true
  end

  netMan.openAll()
  netMan.addMessageHandler(delegator{
    do_craft=taskStatus.wrap("Crafting", function(progress, item)
      for _, recipe in ipairs(craftDb.recipes) do
        if recipe.machine == "minecraft:crafter" and recipe.results[1].name == item.name and recipe.results[1].nbt == item.nbt then
          for _, ingredient in ipairs(recipe.ingredients) do
            netMan.sendToType("server", "dropItems", {
              key=itemUtils.getItemKey(ingredient),
              amount=ingredient.count,
              target=storageName,
            })
          end
          sleep(1)
          doCrafterCraft(recipe, 1)
          importStorage()
        end
      end
    end)
  }.handle)

  emptyCrafterLeftovers()
  importStorage()
end)

eventHandler.run()
