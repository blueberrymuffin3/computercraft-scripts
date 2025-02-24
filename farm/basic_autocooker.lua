local recipes = {
  { -- Hp Up
    "minecraft:sugar",
    "cobblemon:pomeg_berry",
    "cobblemon:white_mint_leaf",
  },
  { -- Protein
    "minecraft:chicken",
    "cobblemon:kelpsy_berry",
    "cobblemon:red_mint_leaf",
  },
  { -- Iron
    "minecraft:beetroot",
    "cobblemon:qualot_berry",
    "cobblemon:blue_mint_leaf",
  },
  { -- Calcium
    "minecraft:bone_meal",
    "cobblemon:hondew_berry",
    "cobblemon:cyan_mint_leaf",
  },
  { -- Zinc
    "farmersdelight:cod_slice",
    -- "farmersdelight:salmon_slice",
    "cobblemon:grepa_berry",
    "cobblemon:pink_mint_leaf",
  },
  { -- Carbos
    "minecraft:wheat",
    "cobblemon:tamato_berry",
    "cobblemon:green_mint_leaf",
  },
  { -- Sugar
    "minecraft:sugar_cane",
  },
  { -- Cod Slice
    "minecraft:cod",
  },
}

local source = "left"
local dest = "bottom"
local destSlotCount = 27

while true do
  print("Checking Recipes...")
  local items = peripheral.call(source, "list") or {}
  local itemsMap = {}

  for slot, item in pairs(items) do
    itemsMap[item.name] = {
      slot=slot,
      item=item,
    }
  end

  local destItems = peripheral.call(dest, "list") or {}
  local destFreeSlots = destSlotCount
  local destItemSet = {}
  for _, item in pairs(destItems) do
    destFreeSlots = destFreeSlots - 1
    destItemSet[item.name] = true
  end

  for recipeI, recipe in ipairs(recipes) do
    if destFreeSlots >= #recipe then
      local minQuantity = 64
      for _, ingredient in ipairs(recipe) do
        local info = itemsMap[ingredient]
        if destItemSet[ingredient] then
          minQuantity = 0
        elseif info then
          if info.item.count < minQuantity then
            minQuantity = info.item.count
          end
        else
          print("Missing", ingredient)
          minQuantity = 0
        end
      end

      if minQuantity > 0 then
        for _, ingredient in ipairs(recipe) do
          local actualQuantity = peripheral.call(source, "pushItems", dest, itemsMap[ingredient].slot, minQuantity)
          itemsMap[ingredient].item.count = itemsMap[ingredient].item.count - actualQuantity
          if actualQuantity ~= minQuantity then
            print("WARNING: tried to transfer", minQuantity, ingredient, "but only did", actualQuantity)
          end
          destFreeSlots = destFreeSlots - 1
        end
      end
    end
  end

  sleep(3)
end
