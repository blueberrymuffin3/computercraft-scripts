args = {...}
if not args[1] then
        print("Usage: cat [file]")
        return
end
local f = fs.open(args[1], "r") or error("Error while opening file!")
print(f.readAll())
f.close()
