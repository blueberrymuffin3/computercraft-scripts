local function getItemKey(item)
  return textutils.serializeJSON{
    name=item.name,
    nbt=item.nbt,
  }
end

return {
  getItemKey=getItemKey
}
