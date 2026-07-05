local Tabs    = _G.Tabs
local Players = game:GetService("Players")
local LP      = Players.LocalPlayer

_G.SPTS_WebhookEnabled  = false
_G.SPTS_WebhookURL      = ""
_G.SPTS_WebhookInterval = 5

local function getAvatarURL(userId)
    return "https://www.roblox.com/headshot-thumbnail/image?userId=" .. tostring(userId) .. "&width=420&height=420&format=png"
end

local function getProfileURL(userId)
    return "https://www.roblox.com/users/" .. tostring(userId) .. "/profile"
end

local function buildPayload()
    local s      = _G.Stats    or {}
    local rs     = _G.RawStats or {}
    local userId = LP.UserId
    local name   = LP.Name
    local disp   = LP.DisplayName

    local now    = os.time()
    local iso    = os.date("!%Y-%m-%dT%H:%M:%SZ", now)

    local fields = {
        { name = "👤 Player",          value = string.format("[%s (%s)](https://www.roblox.com/users/%d/profile)", disp, name, userId), inline = false },
        { name = "⏱️ Alive Time",       value = tostring(s.AliveTime or "--"),  inline = false },
        { name = "👊 Fist Strength",    value = tostring(s.FS    or "--"),       inline = true  },
        { name = "🛡️ Body Toughness",   value = tostring(s.BT    or "--"),       inline = true  },
        { name = "💨 Movement Speed",   value = tostring(s.MS    or "--"),       inline = true  },
        { name = "🦘 Jump Force",       value = tostring(s.JF    or "--"),       inline = true  },
        { name = "🔮 Psychic Power",    value = tostring(s.PP    or "--"),       inline = true  },
        { name = "🪙 Tokens",           value = tostring(s.Token or "--"),       inline = true  },
    }

    local payload = {
        username   = "SPTS Tracker",
        avatar_url = getAvatarURL(userId),
        embeds     = {
            {
                title       = "📊 SPTS — Live Stats Report",
                url         = getProfileURL(userId),
                color       = 5793266,
                thumbnail   = { url = getAvatarURL(userId) },
                fields      = fields,
                footer      = { text = "SPTS • " .. name },
                timestamp   = iso,
            }
        }
    }

    local ok, encoded = pcall(function()
        return game:GetService("HttpService"):JSONEncode(payload)
    end)
    return ok and encoded or nil
end

local function sendWebhook()
    local url = _G.SPTS_WebhookURL
    if not url or url == "" then return end
    local body = buildPayload()
    if not body then return end
    pcall(function()
        game:GetService("HttpService"):PostAsync(url, body, Enum.HttpContentType.ApplicationJson, false)
    end)
end

task.spawn(function()
    local lastInterval = _G.SPTS_WebhookInterval
    local elapsed      = 0
    local tick_dt      = 1

    while _G.SPTS_ALIVE ~= false do
        task.wait(tick_dt)
        if not _G.SPTS_WebhookEnabled then
            elapsed = 0
            lastInterval = _G.SPTS_WebhookInterval
            continue
        end

        local currentInterval = _G.SPTS_WebhookInterval
        if currentInterval ~= lastInterval then
            elapsed      = 0
            lastInterval = currentInterval
        end

        elapsed = elapsed + tick_dt
        if elapsed >= currentInterval * 60 then
            elapsed = 0
            task.spawn(sendWebhook)
        end
    end
end)

Tabs.Webhook:CreateSection("Configuration")

Tabs.Webhook:CreateInput({
    Name        = "Webhook URL",
    PlaceholderText = "https://discord.com/api/webhooks/...",
    RemoveTextAfterFocusLost = false,
    Callback    = function(val)
        _G.SPTS_WebhookURL = val
    end,
})

Tabs.Webhook:CreateToggle({
    Name    = "Enable Auto-Send",
    Default = false,
    Callback = function(val)
        _G.SPTS_WebhookEnabled = val
    end,
})

Tabs.Webhook:CreateSlider({
    Name    = "Send Interval (minutes)",
    Range   = { 1, 120 },
    Increment = 1,
    Default = 5,
    Callback = function(val)
        _G.SPTS_WebhookInterval = val
    end,
})

Tabs.Webhook:CreateSection("Manual")

Tabs.Webhook:CreateButton({
    Name     = "Send Now",
    Callback = function()
        if not _G.SPTS_WebhookURL or _G.SPTS_WebhookURL == "" then return end
        task.spawn(sendWebhook)
    end,
})
