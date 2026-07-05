task.spawn(function()
    local questConfig = {
        DLQ = { "FS", "BT", "PP", "MS", "JF" },
        WLQ = { "FS", "BT", "PP" },
    }
    while _G.SPTS_ALIVE ~= false do
        if _G.Settings.AutoQuest then
            for qtype, stats in pairs(questConfig) do
                for _, stat in ipairs(stats) do
                    if _G.Settings.AutoQuest then
                        _G.Remote:FireServer({ [1] = qtype, [2] = stat, [3] = "Claim" })
                        task.wait(0.5)
                    end
                end
            end
        end
        task.wait(8)
    end
end)

task.spawn(function()
    while _G.SPTS_ALIVE ~= false do
        if _G.Settings.AutoSathQuest then
            if _G.sathScanner.needsQuestPickupFromSath() then
                if not _G.sathDialogBusy then
                    _G.tryAdvanceSathQuest()
                end
                task.wait(2)
            else
                local tasks = _G.sathScanner.scanMainQuestUI()
                if tasks and #tasks > 0 then
                    tasks = _G.sathScanner.enrichTasksFromQuestDef(tasks)
                end
                if tasks and #tasks > 0 then
                    local sg      = _G.guiUtils.getScreenGui()
                    local talkBtn = sg and sg:FindFirstChild("QuestTalkBtn")
                    if _G.isReadyForSathTalk(tasks, talkBtn) then
                        _G.tryAdvanceSathQuest()
                        task.wait(2)
                    else
                        _G.sathTalkMode = false
                        if _G.needsSathFarm(tasks) then
                            _G.applySathFarmPhase(tasks)
                        elseif _G.hasPendingKillTask(tasks) then
                            _G.clearSathFarmFlagsOnly()
                            _G.unequipAllTools()
                            _G.lastSathFarmFlag = nil
                            _G.syncFarmToggles()
                        else
                            _G.applySathFarmPhase(tasks)
                        end
                    end
                else
                    _G.sathTalkMode = false
                end
            end
        elseif _G.sathFarmLock then
            _G.sathTalkMode = false
            _G.restoreConflictingFarms()
            _G.syncFarmToggles()
        else
            _G.sathTalkMode = false
        end
        task.wait(0.35)
    end
end)
