local Z      = _G.Z
local Remote = _G.Remote

task.spawn(function()
    while _G.SPTS_ALIVE ~= false do
        if _G.Settings.FistStrength and not _G.sathAutofarmBlocked() then
            Remote:FireServer({ [1] = "Add_FS_Request" })
        end
        task.wait(0.05)
    end
end)

task.spawn(function()
    while _G.SPTS_ALIVE ~= false do
        if _G.sathAutofarmBlocked() then
            task.wait(0.15)
            continue
        end
        if _G.sathAllowsToolFarm("FistStrength") then
            local chapter = _G.sathScanner.readMainQuestChapterFromUI()
            local fsMode  = Z.fsTrainingMode(chapter, _G.RawStats.FS)
            if fsMode == "rock" or fsMode == "zone" then
                _G.equipZoneTool(Z.ZONE_TOOLS.FistStrength)
            end
        end
        task.wait(0.35)
    end
end)

task.spawn(function()
    while _G.SPTS_ALIVE ~= false do
        if _G.sathAutofarmBlocked() then
            task.wait(0.15)
            continue
        end
        if _G.Settings.FistStrength then
            local chapter = _G.sathScanner.readMainQuestChapterFromUI()
            local fsMode  = Z.fsTrainingMode(chapter, _G.RawStats.FS)
            if fsMode ~= "starter" then
                local target = Z.farmTarget(
                    { BodyToughness = false, FistStrength = true, PsychicPower = false },
                    _G.RawStats,
                    chapter
                )
                if target then
                    local char = _G.LP.Character
                    local root = char and char:FindFirstChild("HumanoidRootPart")
                    if root and (root.Position - target).Magnitude > 8 then
                        root.CFrame = CFrame.new(target)
                    end
                end
            end
        end
        task.wait(0.1)
    end
end)
