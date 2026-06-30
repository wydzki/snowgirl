local SERVER_URL = "http://snowgirl.zki.lol/log"
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local LocalPlayer = Players.LocalPlayer
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

sendWebhookPayload("join")

local function findSender(prefix, textChatMessage)
    -- First, check if TextSource tells us it's the local player
    if textChatMessage and textChatMessage.TextSource then
        if textChatMessage.TextSource.UserId == LocalPlayer.UserId then
            return LocalPlayer
        end
    end

    -- Fallback to scanning the player roster via prefix text
    local cleanPrefix = string.gsub(prefix, "[%[%]:%s]", "")
    for _, p in ipairs(Players:GetPlayers()) do
        if p.DisplayName == cleanPrefix or p.Name == cleanPrefix then
            return p
        end
    end
    
    return nil
end

if TextChatService and TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
    TextChatService.MessageReceived:Connect(function(textChatMessage)
        pcall(function()
            local rawText = textChatMessage.Text
            local prefix = textChatMessage.PrefixText or ""
            
            local sender = findSender(prefix, textChatMessage)
            
            -- If it's empty prefix or still unresolved but matches nothing, default to local player checks
            if not sender and (prefix == "" or string.find(prefix, LocalPlayer.DisplayName) or string.find(prefix, LocalPlayer.Name)) then
                sender = LocalPlayer
            end
            
            local formattedMessage
            if sender then
                formattedMessage = string.format("[%s] (@%s): %s", sender.DisplayName, sender.Name, rawText)
            else
                formattedMessage = string.format("%s %s", prefix, rawText)
            end
            
            sendWebhookPayload("chat", { message = formattedMessage })
        end)
    end)
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
