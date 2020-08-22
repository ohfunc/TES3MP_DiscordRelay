local DiscordRelay = {}

DiscordRelay.scriptName = "DiscordRelay"

DiscordRelay.defaultConfig = {
    use_tes3mp_getName = true,
    send_ping_on_startup = false,
    discord = {
        webhook_url = "",
        usePlayerName = true,
        botUsername = "" -- Not used if usePlayerNameForBot is true
    }
}

DiscordRelay.config = DataManager.loadConfiguration(DiscordRelay.scriptName, DiscordRelay.defaultConfig)

json = require("dkjson")
https = require("ssl.https")

local lastMessage = ""
local lastMessageSenderPID = 0
local lastGotMessageID = 0

function DiscordRelay.OnServerPostInit()
    if (DiscordRelay.config.discord.webhook_url == "" or DiscordRelay.config.discord.webhook_url == nil) then
        tes3mp.LogMessage(enumerations.log.ERROR, "[DiscordRelay] " .. "webhook_url is blank or empty.")
    end
    if not (DiscordRelay.config.use_tes3mp_getName == true or DiscordRelay.config.use_tes3mp_getName == false) then
        tes3mp.LogMessage(enumerations.log.ERROR, "[DiscordRelay] " .. "use_tes3mp_getName can only be true/false.")
    end
    if not (DiscordRelay.config.send_ping_on_startup == true or DiscordRelay.config.send_ping_on_startup == false) then
        tes3mp.LogMessage(enumerations.log.ERROR, "[DiscordRelay] " .. "send_ping_on_startup can only be true/false.")
    end
end

function DiscordRelay.Discord_CheckMessage(code)
    if not (code == 204) then
        tes3mp.LogMessage(enumerations.log.WARN, "[DiscordRelay] " .. "Failed to send message, Responce was " .. code)
        return false
    else
        return true
    end
end

function DiscordRelay.Discord_PingTest()
    if (DiscordRelay.config.send_ping_on_startup == true) then
        local message = "Pong!"
        local BotName = "DiscordRelay"
        local t = {
            ["content"] = tostring(message),
            ["username"] = tostring(BotName)
        }
        local data = json.encode(t)
        local response_body = {}
        local res, code, responce_headers, status =
            https.request {
            url = DiscordRelay.config.discord.webhook_url,
            method = "POST",
            protocol = "tlsv1_2",
            headers = {
                ["Content-Type"] = "application/json",
                ["Content-Length"] = string.len(data)
            },
            source = ltn12.source.string(data),
            sink = ltn12.sink.table(response_body)
        }
        if (DiscordRelay.Discord_CheckMessage(code) == true) then
            tes3mp.LogMessage(enumerations.log.INFO, "[DiscordRelay] " .. "Pinged Discord Successfully")
        else
            return false
        end
    end
end

function DiscordRelay.Discord_SendMessage(eventStatus, pid, message)
    if message:sub(1, 1) == "/" then
        return
    else
        local Playername = ""

        if (DiscordRelay.config.discord.usePlayerName == true) then
            if (DiscordRelay.config.use_tes3mp_getName == true) then
                Playername = tes3mp.GetName(pid)
            else
                Playername = Players[pid].data.login.name
            end
        else
            Playername = DiscordRelay.config.discord.botUsername
        end

        local t = {
            ["content"] = tostring(message),
            ["username"] = tostring(Playername)
        }
        if tostring(message) ~= lastMessage or Players[pid].data.settings.staffRank > 0 then
            if (lastMessageSenderPID == pid and lastMessage == tostring(message) and (Players[pid].data.settings.staffRank < 0)) then
                print("Assuming is spam, Blocking message to discord.")
                lastMessage = tostring(message)
                lastMessageSenderPID = pid    
            else
                lastMessage = tostring(message)
                lastMessageSenderPID = pid  
                local data = json.encode(t)
                local response_body = {}
                local res, code, responce_headers, status =
                    https.request {
                    url = DiscordRelay.config.discord.webhook_url,
                    method = "POST",
                    protocol = "tlsv1_2",
                    headers = {
                        ["Content-Type"] = "application/json",
                        ["Content-Length"] = string.len(data)
                    },
                    source = ltn12.source.string(data),
                    sink = ltn12.sink.table(response_body)
                }
                if (DiscordRelay.Discord_CheckMessage(code) == true) then
                    tes3mp.LogMessage(enumerations.log.INFO, "[DiscordRelay] " .. "Message Send Successfully")
                else
                    tes3mp.LogMessage(enumerations.log.INFO, "[DiscordRelay] " .. "Message Did not send Successfully")
                    tes3mp.LogMessage(enumerations.log.INFO, "[DiscordRelay] " .. "\n" .. data)
                end
            end
        end
    end
end

function DiscordRelay.Discord_SendDeathMessage(eventStatus, pid)
    local deathReason = "committed suicide"

    if tes3mp.DoesPlayerHavePlayerKiller(pid) then
        local killerPid = tes3mp.GetPlayerKillerPid(pid)

        if pid ~= killerPid then
            deathReason = "was killed by player " .. logicHandler.GetChatName(killerPid)
        end
    else
        local killerName = tes3mp.GetPlayerKillerName(pid)

        if killerName ~= "" then
            deathReason = "was killed by " .. killerName
        end
    end

    local message = logicHandler.GetChatName(pid) .. " " .. deathReason .. ".\n"

    DiscordRelay.Discord_SendMessage(eventStatus, pid, message)
end

function DiscordRelay.Discord_SendConnectMessage(eventStatus, pid)
    local message = logicHandler.GetChatName(pid) .. " has connected to the server! :)"
    DiscordRelay.Discord_SendMessage(eventStatus, pid, message)
end

function DiscordRelay.Discord_SendDisconnectMessage(eventStatus, pid)
    local message = logicHandler.GetChatName(pid) .. " has disconnected from the server :("
    DiscordRelay.Discord_SendMessage(eventStatus, pid, message)
end

customEventHooks.registerValidator("OnPlayerSendMessage", DiscordRelay.Discord_SendMessage)
customEventHooks.registerValidator("OnPlayerDisconnect", DiscordRelay.Discord_SendDisconnectMessage)
customEventHooks.registerHandler("OnPlayerDeath", DiscordRelay.Discord_SendDeathMessage)
customEventHooks.registerHandler("OnPlayerAuthentified", DiscordRelay.Discord_SendConnectMessage)
customEventHooks.registerHandler("OnServerPostInit", DiscordRelay.OnServerPostInit)
customEventHooks.registerHandler("OnServerPostInit", DiscordRelay.Discord_PingTest)
