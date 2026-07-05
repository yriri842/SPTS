-- Dashboard tab: executor info + live stat labels.
local Tabs = _G.Tabs

-- rank index -> image id (senin verdiğin sırayla)
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
    if _G.UseRawStats then
        SourceLabel:Set("getgc is supported, showing raw values")
    else
        SourceLabel:Set("getgc is not supported, showing values from the game UI")
    end
end)

Tabs.Dash:CreateSection("Live Stats")
local LabelFS    = Tabs.Dash:CreateLabel("Fist Strength: --",   2197020684)
local LabelBT    = Tabs.Dash:CreateLabel("Body Toughness: --",  2197021260)
local LabelMS    = Tabs.Dash:CreateLabel("Movement Speed: --",  2197021644)
local LabelJF    = Tabs.Dash:CreateLabel("Jump Force: --",      2197021850)
local LabelPP    = Tabs.Dash:CreateLabel("Psychic Power: --",   2197021455)
local LabelToken = Tabs.Dash:CreateLabel("Tokens: --",          2122205495)  -- token icon
local LabelAlive = Tabs.Dash:CreateLabel("Alive Time: --",      4483362458)
local LabelRank  = Tabs.Dash:CreateLabel("Rank: --",            RANK_IMAGES[1])
local LabelRep   = Tabs.Dash:CreateLabel("Status: --",          4483362458)

local lastRankIdx = -1

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
            LabelAlive:Set("Alive Time: "  .. (_G.Stats.AliveTime or "--") .. "s")

            -- Rank: metin + ikon güncelle
            local rankIdx = _G.RawStats.RankIndex or 0
            LabelRank:Set("Rank: " .. (_G.Stats.Rank or "--"))
            if rankIdx ~= lastRankIdx and RANK_IMAGES[rankIdx] then
                lastRankIdx = rankIdx
                pcall(function() LabelRank:SetIcon(RANK_IMAGES[rankIdx]) end)
            end

            -- Reputation status — renkli (Rayfield RichText destekliyorsa)
            local col = _G.Stats.RepColor or Color3.fromRGB(250,250,250)
            local hex = col:ToHex()
            LabelRep:Set(string.format(
                'Status: <font color="#%s">%s</font>',
                hex, _G.Stats.RepName or "--"
            ))
        end)
    end
end)
