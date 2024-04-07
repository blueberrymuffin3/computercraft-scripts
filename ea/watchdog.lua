local status, err = pcall(function() require("main") end)

local message
if status then
    print("Program exited with no error")
else
    print("Program exited with error: \n" .. err)
    print()
    print("Sending error report to admin")
    
    local secrets = require("secrets")
    local body = {
        content="`".. os.getComputerLabel() .."` has crashed <@"..secrets.pingUserId..">\n```\n"..err. "\n```",
    }
    local headers = {
        ["Content-Type"]="application/json"
    }

    local response, resError, resFail = http.post(secrets.webhookURL, textutils.serializeJSON(body), headers)
    if response == nil then
        print("Failed to send error report:", resError)
        if resFail ~= nil then
            resFail.close()
        end
    else
        response.close()
    end
end

print("Restarting in 3 seconds")
sleep(3)
os.reboot()
