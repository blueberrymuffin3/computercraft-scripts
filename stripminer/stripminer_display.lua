require("dump")

monitor = peripheral.find("monitor")
monitor.setTextScale(1)
monitor.clear()

function main()
  print("opening rednet")
  rednet.open("back")
  rednet.host("stripminer_display", "stripminer_display")

  monitor.setCursorPos(1,1)
  monitor.write("Waiting for message...")

  while true do
    id, msg, proto = rednet.receive()
    print("got message from id " .. tostring(id) .. " with proto " .. tostring(proto))
    print(dump(msg))

    if proto == "stripminer_display" then
      monitor.clear()
      for y, line in ipairs(msg) do
        monitor.setCursorPos(1,y)
        monitor.write(line)
      end
    elseif proto == "check_ok" then
      ok = redstone.getInput("left")
      rednet.send(id, ok, proto)
    else
      print("Unknown proto, ignoring")
    end
  end
end

status, err = pcall(main)
if err then
  print(err)
  monitor.clear()
  monitor.setCursorPos(1,1)
end
monitor.write("Program crashed, rebooting")
sleep(10)
os.reboot()
