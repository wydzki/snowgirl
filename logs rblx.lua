-- Local Script (Delta Executor)
local LogService = game:GetService("LogService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local VPS_URL = "https://snowgirl.zki.lol/log"
local JobId = game.JobId

-- Notify VPS that a new server was joined
local function notifyServerJoin()
    local payload = {
        type = "join",
        jobId = JobId,
        placeId = game.PlaceId
    }
    
    pcall(function()
        request({
            Url = VPS_URL,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(payload)
        })
    end)
end

-- Listen to chat messages via LogService (captures standard chat)
LogService.MessageOut:Connect(function(message, messageType)
    if messageType == Enum.MessageType.MessageOutput or string.find(message, ":") then
        -- Simple check to filter out system spam if needed, or grab everything
        local payload = {
            type = "chat",
            jobId = JobId,
            message = message
        }
        
        pcall(function()
            request({
                Url = VPS_URL,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = HttpService:JSONEncode(payload)
            })
        end)
    end
end)

-- Run on startup
notifyServerJoin()