local SERVER_URL = "http://snowgirl.zki.lol/log"
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local LocalPlayer = Players.LocalPlayer
local jobId = (game.JobId ~= "") and game.JobId or "Studio-Testing-ID"

-- Use the executor's native request function instead of standard HttpService
local function sendWebhookPayload(payloadType, extraData)
    local data = {
        type = payloadType,
        jobId = jobId
    }
    
    if extraData then
        for k, v in pairs(extraData) do data[k] = v end
    end
    
    -- standard HttpService is fine just for encoding text locally
    local success, jsonPayload = pcall(function() 
        return game:GetService("HttpService"):JSONEncode(data) 
    end)
    if not success then return end

    -- Check for executor HTTP functions (request or http_request)
    local customRequest = (type(request) == "table" and request) or (type(request) == "function" and request) or http_request or syn.request
    
    if customRequest then
        task.spawn(function()
            pcall(function()
                customRequest({
                    Url = SERVER_URL,
                    Method = "POST",
                    Headers = {
                        ["Content-Type"] = "application/json"
                    },
                    Body = jsonPayload
                })
            end)
        end)
    else
        warn("[LOGGER ERROR] Your executor does not support outbound HTTP requests.")
    end
end

-- Fire the initial join log
sendWebhookPayload("join")

-- Clean up and format the chat log
local function processIncoming(textChatMessage)
    local rawText = textChatMessage.Text
    if not rawText or rawText == "" then return end
    
    local sender = nil
    if textChatMessage.TextSource then
        sender = Players:GetPlayerByUserId(textChatMessage.TextSource.UserId)
    end
    
    local formattedMessage
    if sender then
        formattedMessage = string.format("[%s] (@%s): %s", sender.DisplayName, sender.Name, rawText)
    else
        local cleanPrefix = string.gsub(textChatMessage.PrefixText or "System", "<[^>]*>", "")
        cleanPrefix = string.gsub(cleanPrefix, "[%[%]:%s]", "")
        formattedMessage = string.format("[%s]: %s", cleanPrefix, rawText)
    end
    
    sendWebhookPayload("chat", { message = formattedMessage })
end

-- Use MessageReceived (bulletproof on client when using executor requests)
if TextChatService and TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
    TextChatService.MessageReceived:Connect(processIncoming)
else
    local function hookPlayer(player)
        player.Chatted:Connect(function(message)
            local formattedMessage = string.format("[%s] (@%s): %s", player.DisplayName, player.Name, message)
            sendWebhookPayload("chat", { message = formattedMessage })
        end)
    end
    
    Players.PlayerAdded:Connect(hookPlayer)
    for _, player in ipairs(Players:GetPlayers()) do
        task.spawn(hookPlayer, player)
    end
end

print("[LOGGER ACTIVE] Client HTTP channel established via executor proxy.")
