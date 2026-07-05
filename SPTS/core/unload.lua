_G.SPTS_ALIVE = _G.SPTS_ALIVE
if _G.SPTS_ALIVE == nil then _G.SPTS_ALIVE = true end

_G.SPTS_Unload = function()
    if _G.SPTS_UNLOADING then return end
    _G.SPTS_UNLOADING = true

    -- 1. flip the flag first, this makes every loop exit on its next wait
    _G.SPTS_ALIVE = false

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

    -- 2. give loops enough time to actually notice and stop.
    -- longest wait in the codebase is the weight loop at 3s, but the
    -- ui loops are 1s. 1.2s is enough for the ones that touch the ui
    task.wait(1.2)

    -- 3. clean gameplay side
    pcall(function() if _G.stopFlyMode then _G.stopFlyMode() end end)
    pcall(function() if _G.unequipAllTools then _G.unequipAllTools() end end)
    pcall(function() if _G.espModule then _G.espModule.setPlayerEspEnabled(false) end end)

    -- 4. disconnect stashed conns
    pcall(function()
        if _G.SPTS_bodyConns then
            for _, c in ipairs(_G.SPTS_bodyConns) do pcall(function() c:Disconnect() end) end
            _G.SPTS_bodyConns = {}
        end
    end)
    pcall(function()
        if _G.SPTS_conns then
            for _, c in ipairs(_G.SPTS_conns) do pcall(function() c:Disconnect() end) end
            _G.SPTS_conns = {}
        end
    end)

    -- 5. destroy the UI. wrap hard because rayfield internals get grumpy
    pcall(function()
        if _G.RayfieldWindow and _G.RayfieldWindow.Hide then
            pcall(function() _G.RayfieldWindow.Hide() end)
        end
    end)
    task.wait(0.3)
    pcall(function()
        if _G.Rayfield and _G.Rayfield.Destroy then _G.Rayfield:Destroy() end
    end)
    task.wait(0.2)
    pcall(function()
        local cg = game:GetService("CoreGui")
        for _, name in ipairs({ "LoaderUI", "Rayfield" }) do
            local g = cg:FindFirstChild(name)
            if g then g:Destroy() end
        end
        for _, g in ipairs(cg:GetChildren()) do
            if g:IsA("ScreenGui") and g.Name == "Rayfield" then g:Destroy() end
        end
    end)

    -- 6. now that everything is stopped + UI gone, wipe globals.
    -- big delay so any straggler loop already broke out before we nil stuff
    task.delay(2, function()
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
