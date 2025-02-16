local LibDeflate = require "libs/LibDeflate"
local tar = require "libs/tar"
local pretty = require "cc.pretty"
local netMan = require("netMan")

settings.define("ea.update.enabled", {
  description = "Whether to enable automatic updates on boot",
  type = "boolean",
})

function doUpdate()
  local updateEnabled = settings.get("ea.update.enabled", true)
  if not updateEnabled then
    print("Skipping update check")
    return
  end

  print("Checking for update...")
  local response, err = http.get("https://api.github.com/repos/blueberrymuffin3/computercraft-scripts/commits/main")
  if response == nil then
    print("Error checking for update: ", err)
    return
  end
  local json = response.readAll()
  json = textutils.unserializeJSON(json)

  versionOk, myVersion = pcall(function() return require "version" end)
  commit = json.sha
  print("Current Version:", myVersion)
  print("Latest Version:", commit)

  if versionOk and commit == myVersion then
    print("EA is up to date "..commit)
    return
  end

  local eaPath = fs.getDir(debug.getinfo(1, "S").source:sub(2))
  local ea2Path = fs.combine(fs.getDir(eaPath), fs.getName(eaPath).."-update")
  local eaOldPath = fs.combine(fs.getDir(eaPath), fs.getName(eaPath).."-old")

  print("Downloading Update...")
  local response, err = http.get("https://github.com/blueberrymuffin3/computercraft-scripts/archive/"..commit..".tar.gz")
  if response == nil then
    print("Error downloading update: ", err)
    return
  end
  local archive = response.readAll()

  print("Decompressing Update...")
  archive = LibDeflate:DecompressGzip(archive)
  archive = tar.load(archive, nil, true)
  local rootDirName = nil

  -- Get our subdirectory
  for k, v in pairs(archive) do rootDirName = k end
  archive = archive[rootDirName]["ea"]

  print("Applying Update...")
  fs.delete(ea2Path)
  tar.extract(archive, ea2Path)
  local versionFile = fs.open(fs.combine(ea2Path, "version.lua"), "w")
  versionFile.write("return "..textutils.serialise(commit))
  versionFile.close()

  fs.delete(eaOldPath)
  fs.move(eaPath, eaOldPath)
  fs.move(ea2Path, eaPath)
  fs.delete(eaOldPath)
  fs.delete("/startup.lua")
  fs.copy(fs.combine(eaPath, "startup.lua"), "/startup.lua")

  if netMan.nodeType == "server" then
    print("Restarting consoles...")
    netMan.sendToType("console", "reboot")
  end

  print("Rebooting in 2 seconds...")
  sleep(2)
  os.reboot()
end

return doUpdate
