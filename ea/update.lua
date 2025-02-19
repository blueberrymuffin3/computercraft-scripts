local LibDeflate = require "libs/LibDeflate"
local tar = require "libs/tar"
local pretty = require "cc.pretty"
local netMan = require "netMan"
local taskStatus = require "taskStatus"

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

  local commit, versionOk, myVersion
  taskStatus.runAsTask("Updating", function(progress)
    print("Checking for update...")
    progress(1, 6)
    local response, err = http.get("https://api.github.com/repos/blueberrymuffin3/computercraft-scripts/commits/main")
    if response == nil then
      print("Error checking for update: ", err)
      return
    end
    local json = response.readAll()
    json = textutils.unserializeJSON(json)
    commit = json.sha
    
    versionOk, myVersion = pcall(function() return require "version" end)
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
    progress(2, 6)
    local response, err = http.get("https://github.com/blueberrymuffin3/computercraft-scripts/archive/"..commit..".tar.gz")
    if response == nil then
      print("Error downloading update: ", err)
      return
    end
    local archive = response.readAll()

    print("Decompressing Update...")
    progress(3, 6)
    archive = LibDeflate:DecompressGzip(archive)
    archive = tar.load(archive, nil, true)
    local rootDirName = nil

    -- Get our subdirectory
    for k, v in pairs(archive) do rootDirName = k end
    archive = archive[rootDirName]["ea"]

    print("Applying Update...")
    progress(4, 6)
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

    progress(5, 6)
    print("Rebooting...")
    os.reboot()
    -- never return, task cleared on reboot
  end)
end

return doUpdate
