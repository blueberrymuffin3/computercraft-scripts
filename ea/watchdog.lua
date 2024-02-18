local status, err = pcall(function() require('main') end)

local message
if status then
    print("Program exited with no error")
else
    print("Program exited with error: \n" .. err)
    print()
    print("Sending error report to evelyn")
    
    local url = require("secrets").webhookURL
    local body = {
        content="The storage system has crashed <@412111783441072138>\n```\n" .. err .. "\n```",
    }
    local headers = {
        ["Content-Type"]="application/json"
    }

    local response, resError, resFail = http.post(url, textutils.serializeJSON(body), headers)
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
