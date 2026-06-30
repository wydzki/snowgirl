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

-- Log the initial connection heartbeat
sendWebhookPayload("join")

local function processIncoming(textChatMessage)
    pcall(function()
        local rawText = textChatMessage.Text
        if not rawText or rawText == "" then return end
        
        local sender = nil
        
        -- Pull UserID safely from the text message properties
        if textChatMessage.TextSource then
            sender = Players:GetPlayerByUserId(textChatMessage.TextSource.UserId)
        end
        
        local formattedMessage
        if sender then
            formattedMessage = string.format("[%s] (@%s): %s", sender.DisplayName, sender.Name, rawText)
        else
            -- Clean fallback using whatever visual prefix Roblox rendered
            local cleanPrefix = string.gsub(textChatMessage.PrefixText or "System", "<[^>]*>", "") -- Strip rich text tags
            cleanPrefix = string.gsub(cleanPrefix, "[%[%]:%s]", "")
            formattedMessage = string.format("[%s]: %s", cleanPrefix, rawText)
        end
        
        sendWebhookPayload("chat", { message = formattedMessage })
    end)
end

-- Dual-hook both incoming render channels and legacy message hooks
if TextChatService and TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
    -- OnIncomingMessage captures messages *exactly* as they hit the local client layout
    TextChatService.OnIncomingMessage = function(textChatMessage)
        processIncoming(textChatMessage)
        return nil -- Return nil so we don't accidentally modify the actual visible chat bubble
    end
end

-- Always maintain the legacy connection fallback (works perfectly for player streams)
local function hookPlayer(player)
    player.Chatted:Connect(function(message)
        -- Only process if modern chat isn't running to avoid double logs
        if not (TextChatService and TextChatService.ChatVersion == Enum.ChatVersion.TextChatService) then
            local formattedMessage = string.format("[%s] (@%s): %s", player.DisplayName, player.Name, message)
            sendWebhookPayload("chat", { message = formattedMessage })
        end
    end)
end

Players.PlayerAdded:Connect(hookPlayer)
for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(hookPlayer, player)
end
