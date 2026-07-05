-- full teardown. flip the alive flag so every while loop exits,
-- kill conns, nuke UI, wipe the globals. basically make it disappear.
_G.SPTS_ALIVE = _G.SPTS_ALIVE
if _G.SPTS_ALIVE == nil then _G.SPTS_ALIVE = true end

_G.SPTS_Unload = function()
    if _G.SPTS_UNLOADING then return end
    _G.SPTS_UNLOADING = true

    -- 1. stop every loop
    _G.SPTS_ALIVE = false

    -- 2. turn all farming off so nothing fires one last time mid-teardown
    if _G.Settings then
        _G.Settings.FistStrength   = false
        _G.Settings.BodyToughness  = false
        _G.Settings.MovementSpeed  = false
        _G.Settings.JumpForce      = false
        _G.Settings.PsychicPower   = false
        _G.Settings.DeathGrinding  = false
        _G.Settings.AutoQuest      = false
        _G.Settings.AutoSathQuest  = false
        _G.Settings.PlayerEsp      = false
        _G.Settings.AutoPunch      = false
        _G.Settings.ActiveWeight   = 0
    end

    -- give the loops a tick to notice the flag and bail
    task.wait(0.2)

    -- 3. stop fly + drop any equipped tool
    pcall(function() if _G.stopFlyMode then _G.stopFlyMode() end end)
    pcall(function() if _G.unequipAllTools then _G.unequipAllTools() end end)

    -- 4. kill ESP
    pcall(function()
        if _G.espModule then _G.espModule.setPlayerEspEnabled(false) end
    end)

    -- 5. disconnect body respawn conns
    pcall(function()
        if _G.SPTS_bodyConns then
            for _, c in ipairs(_G.SPTS_bodyConns) do
                pcall(function() c:Disconnect() end)
            end
            _G.SPTS_bodyConns = {}
        end
    end)

    -- 6. anything we stashed in the global conn bag
    pcall(function()
        if _G.SPTS_conns then
            for _, c in ipairs(_G.SPTS_conns) do
                pcall(function() c:Disconnect() end)
            end
            _G.SPTS_conns = {}
        end
    end)

    -- 7. destroy rayfield window + loader gui if still around
    pcall(function()
        if _G.Rayfield and _G.Rayfield.Destroy then
            _G.Rayfield:Destroy()
        end
    end)
    pcall(function()
        local cg = game:GetService("CoreGui")
        for _, name in ipairs({ "LoaderUI", "Rayfield" }) do
            local g = cg:FindFirstChild(name)
            if g then g:Destroy() end
        end
        -- rayfield sometimes parents under a random gui too, sweep just in case
        for _, g in ipairs(cg:GetChildren()) do
            if g:IsA("ScreenGui") and g:FindFirstChild("Main") and g.Name == "Rayfield" then
                g:Destroy()
            end
        end
    end)

    -- 8. wipe our globals so a re-inject starts clean
    task.defer(function()
        for _, k in ipairs({
            "Toggles","Tabs","RayfieldWindow","Rayfield","Loader","Z",
            "espModule","killModule","sathScanner","guiUtils","trainingTools",
            "SATH_QUEST_DEFS","SATH_FARM_FLAGS","SATH_PHYSICAL_FLAGS","SATH_FLAG_LABELS",
            "isFlying","hasMeditateEquipped","stopFlyMode","unequipAllTools",
            "useStarterTraining","equipZoneTool","setToggleVisual","syncFarmToggles",
            "setTrainingUiLocked","setSathEquipWeight","tryAdvanceSathQuest",
            "applySathFarmPhase","pauseConflictingFarms","restoreConflictingFarms",
            "clearSathFarmFlagsOnly","prepareForSathTalk","sathAllowsToolFarm",
            "buildSathInfoText","isReadyForSathTalk","needsSathFarm","hasPendingKillTask",
            "farmTaskSatisfied","doRespawn","bodyModule","SPTS_bodyConns","SPTS_conns",
        }) do
            _G[k] = nil
        end
        _G.SPTS_UNLOADING = false
    end)
end
