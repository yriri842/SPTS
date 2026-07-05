local Remote = _G.Remote
task.spawn(function()
    while _G.SPTS_ALIVE ~= false do
        if _G.Settings.MovementSpeed and not _G.sathAutofarmBlocked() then
            Remote:FireServer({ [1] = "Add_MS_Request" })
        end
        task.wait(0.25)
    end
end)

task.spawn(function()
    while _G.SPTS_ALIVE ~= false do
        if _G.Settings.JumpForce and not _G.sathAutofarmBlocked() then
            Remote:FireServer({ [1] = "Add_JF_Request" })
        end
        task.wait(0.25)
    end
end)

task.spawn(function()
    while _G.SPTS_ALIVE ~= false do
        local w = _G.Settings.ActiveWeight
        if w > 0 then
            Remote:FireServer({ [1] = "EquipWeight_Request", [2] = w })
        end
        task.wait(3)
    end
end)
