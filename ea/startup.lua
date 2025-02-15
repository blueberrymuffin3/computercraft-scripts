print("Starting EA in 3 seconds...")
sleep(3)

local networkId = string.match(os.getComputerLabel(), "^(ea_%w+)_.+$")
local diskLabel = networkId .. "_disk"

local function readFile(path)
  if not fs.exists(path) then
    return nil
  end
  f = fs.open(path, "r")
  data = f:readAll()
  f:close()
  return data
end

for _, name in ipairs(peripheral.getNames()) do
  if peripheral.hasType(name, "drive") and disk.getLabel(name) == diskLabel then
    local mountPath = disk.getMountPath(name)
    print("Found disk with label "..diskLabel..": "..name.." mounted at "..mountPath)

    if readFile("/startup") ~= readFile(fs.combine(mountPath, "ea/startup.lua")) then
      print("Updating startup file...")
      fs.copy(fs.combine(mountPath, "ea/startup.lua"), "/startup")
      print("Rebooting...")
      sleep(2)
      os.reboot()
    end

    shell.run(fs.combine(mountPath, "ea/watchdog.lua"))
    return
  end
end

error("No disk found with label "..diskLabel)
