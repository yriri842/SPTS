local Tabs    = _G.Tabs
local Toggles = _G.Toggles
local Rayfield = _G.Rayfield

Tabs.Util:CreateSection("Respawn")
Toggles["IR"] = Tabs.Util:CreateToggle({
    Name         = "Instant Respawn",
    CurrentValue = false,
    Flag         = "Run_IR",
    Callback     = function(v) _G.Settings.InstantRespawn = v end,
})

Tabs.Util:CreateSection("Manual")
Tabs.Util:CreateButton({
    Name     = "Respawn Here",
    Callback = function() _G.doRespawn() end,
})

Tabs.Util:CreateSection("Script")
Tabs.Util:CreateButton({
    Name     = "Unload Script",
    Callback = function()
        Rayfield:Notify({
            Title    = "SPTS",
            Content  = "Unloading everything...",
            Duration = 2,
            Image    = "power",
        })
        task.spawn(function()
            if _G.SPTS_Unload then
                _G.SPTS_Unload()
            end
        end)
    end,
})
