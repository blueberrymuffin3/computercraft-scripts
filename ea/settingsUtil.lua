return {
  getRequired=function(name)
    info = settings.getDetails(name)
    if info.value == nil then
      message = "Setting "..name.." is required."
      if info.description ~= nil then
        message = message.." Description: "..info.description
      end
      error(message)
    end
    return info.value
  end
}
