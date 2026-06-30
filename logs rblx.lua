local SERVER_URL = "http://snowgirl.zki.lol/log"
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local jobId = (game.JobId ~= "") and game.JobId or "Studio-Testing-ID"

local function sendWebhookPayload(payloadType, extraData)
    local data = {type = payloadType, jobId = jobId}
    if extraData then
        for k, v in pairs(extraData) do data[k] = v end
    end
    local success, jsonPayload = pcall(function() return HttpService:JSONEncode(data) end)
    if not success then return end
    task.spawn(function()
        pcall(function() HttpService:PostAsync(SERVER_URL, jsonPayload, Enum.HttpContentType.ApplicationJson) end)
    end)
end

-- Initialize server log
sendWebhookPayload("join")

-- Helper function to find a player by their display name or name
local function findSender(prefix)
    -- Clean up prefix characters commonly added by chat prefixes
    local cleanPrefix = string.gsub(prefix, "[%[%]:%s]", "")
    for _, p in ipairs(Players:GetPlayers()) do
        if p.DisplayName == cleanPrefix or p.Name == cleanPrefix then
            return p
        end
    end
    return nil
end

-- Hook into TextChatService optimized for LocalScripts
if TextChatService and TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
    TextChatService.MessageReceived:Connect(function(textChatMessage)
        pcall(function()
            local rawText = textChatMessage.Text
            local prefix = textChatMessage.PrefixText -- This is usually "[DisplayName]:"
            
            local sender = findSender(prefix)
            local formattedMessage
            
            if sender then
                formattedMessage = string.format("[%s] (@%s): %s", sender.DisplayName, sender.Name, rawText)
            else
                -- Fallback if player object isn't resolved instantly
                formattedMessage = string.format("%s %s", prefix, rawText)
            end
            
            sendWebhookPayload("chat", { message = formattedMessage })
        end)
    end)
else
    -- Legacy Chat Engine Hook (Always works perfectly on client)
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
