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

sendWebhookPayload("join")

local function formatAndSendChat(player, rawMessage)
    if not player then return end
    local formattedMessage = "[" .. tostring(player.DisplayName) .. "] (@" .. tostring(player.Name) .. "): " .. tostring(rawMessage)
    sendWebhookPayload("chat", { message = formattedMessage })
end

local isModernChat = false
pcall(function()
    if TextChatService and TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
        isModernChat = true
    end
end)

if isModernChat then
    TextChatService.MessageReceived:Connect(function(textChatMessage)
        pcall(function()
            local textSource = textChatMessage.TextSource
            if textSource then
                local player = Players:GetPlayerByUserId(textSource.UserId)
                formatAndSendChat(player, textChatMessage.Text)
            end
        end)
    end)
else
    local function hookPlayer(player)
        player.Chatted:Connect(function(message)
            formatAndSendChat(player, message)
        end)
    end
    Players.PlayerAdded:Connect(hookPlayer)
    for _, player in ipairs(Players:GetPlayers()) do
        task.spawn(hookPlayer, player)
    end
end
