local Tabs = _G.Tabs

local RANK_IMAGES = {
    2202371788, 2202372021, 2202372271, 2202372528, 2202372756,
    2202375168, 2202375400, 2202375611, 2202375849, 2202376193, 2202378137,
}

Tabs.Dash:CreateSection("System")
Tabs.Dash:CreateLabel("Executor: " .. (_G.ExecutorName or "Unknown"), 4483362458)

local SourceLabel = Tabs.Dash:CreateLabel("Stat source: checking...", 4483362458)
task.spawn(function()
    for _ = 1, 50 do
        if _G.UseRawStats ~= nil then break end
        task.wait(0.1)
    end
    SourceLabel:Set(_G.UseRawStats
        and "getgc is supported, showing raw values"
        or  "getgc is not supported, showing values from the game UI")
end)

Tabs.Dash:CreateSection("Live Stats")
local LabelFS    = Tabs.Dash:CreateLabel("Fist Strength: --",   2197020684)
local LabelBT    = Tabs.Dash:CreateLabel("Body Toughness: --",  2197021260)
local LabelMS    = Tabs.Dash:CreateLabel("Movement Speed: --",  2197021644)
local LabelJF    = Tabs.Dash:CreateLabel("Jump Force: --",      2197021850)
local LabelPP    = Tabs.Dash:CreateLabel("Psychic Power: --",   2197021455)
local LabelToken = Tabs.Dash:CreateLabel("Tokens: --",          2122205495)
local LabelAlive = Tabs.Dash:CreateLabel("Alive Time: --",      "hourglass")
local LabelRep   = Tabs.Dash:CreateLabel("Status: --",          "info")

local LabelRank
task.spawn(function()
    for _ = 1, 100 do
        if _G.RawStats and _G.RawStats.RankIndex and _G.RawStats.RankIndex > 0 then break end
        task.wait(0.1)
    end
    local idx = (_G.RawStats and _G.RawStats.RankIndex) or 1
    local icon = RANK_IMAGES[idx] or RANK_IMAGES[1]
    LabelRank = Tabs.Dash:CreateLabel("Rank: " .. (_G.Stats.Rank or "--"), icon)
end)

task.spawn(function()
    while _G.SPTS_ALIVE ~= false do
        task.wait(0.3)
        if _G.SPTS_ALIVE == false then break end
        pcall(function()
            LabelFS:Set("Fist Strength: "  .. (_G.Stats.FS or "--"))
            LabelBT:Set("Body Toughness: " .. (_G.Stats.BT or "--"))
            LabelMS:Set("Movement Speed: " .. (_G.Stats.MS or "--"))
            LabelJF:Set("Jump Force: "     .. (_G.Stats.JF or "--"))
            LabelPP:Set("Psychic Power: "  .. (_G.Stats.PP or "--"))
            LabelToken:Set("Tokens: "      .. (_G.Stats.Token or "--"))
            LabelAlive:Set("Alive Time: "  .. (_G.Stats.AliveTime or "--"))

            if LabelRank then
                LabelRank:Set("Rank: " .. (_G.Stats.Rank or "--"))
            end

            local col = _G.Stats.RepColor or Color3.fromRGB(250,250,250)
            LabelRep:Set(string.format(
                'Status: <font color="#%s">%s</font>',
                col:ToHex(), _G.Stats.RepName or "--"
            ))
        end)
    end
end)
