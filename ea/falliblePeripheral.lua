return {
  call=function(pName, func, ...)
    for i=1,10 do
      local list = peripheral.call(pName, func, ...)
      if list then
        return list
      end
      print("Failed to call", func, "on", pName, ", retrying")
      sleep(0.1)
    end
    error("Failed to call "..func.." on "..pName, 1)
  end
}
