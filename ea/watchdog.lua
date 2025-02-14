local status, err = pcall(function() require("main") end)

local message
if status then
    print("Program exited with no error")
else
    print("Program exited with error: \n" .. err)
    print()
    print("Sending error report to admin")
    sleep(1) -- Allow quick user to cancel message
    
    local secrets = require("secrets")
    local body = {
        content="`"..os.getComputerLabel().."` has crashed <@"..secrets.pingUserId..">\n```\n"..err.."\n```",
        allowed_mentions={
            users={secrets.pingUserId}
        }
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

print("Restarting in 2 seconds")
sleep(2)
os.reboot()
