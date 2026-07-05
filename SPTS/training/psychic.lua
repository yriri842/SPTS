local Z              = _G.Z
local LP             = _G.LP
local UserInputService = _G.UserInputService

_G.isFlying = function()
    if _G.Flying == true then return true end
    local char = LP.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root then
        if root:FindFirstChildOfClass("BodyVelocity") or root:FindFirstChildOfClass("BodyGyro") then
            return true
        end
    end
    return false
end

_G.hasMeditateEquipped = function()
    local char = LP.Character
    return char and char:FindFirstChild("Meditate") ~= nil
end

local function unequipMeditateTool()
    if not _G.hasMeditateEquipped() then return end
    local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if hum then pcall(function() hum:UnequipTools() end) end
end

local function waitUntilMeditateGone(maxSec)
    local t0 = os.clock()
    while _G.hasMeditateEquipped() and os.clock() - t0 < (maxSec or 2) do
        unequipMeditateTool()
        task.wait(0.1)
    end
end

_G.stopFlyMode = function()
    if not _G.isFlying() and not _G.hasMeditateEquipped() then return end
    unequipMeditateTool()
    waitUntilMeditateGone(2)
    if _G.isFlying() then
        pcall(function() UserInputService:JumpRequest() end)
        task.wait(0.5)
    end
end

local function doJump()
    local vim = game:GetService("VirtualInputManager")
    vim:SendKeyEvent(true,  Enum.KeyCode.Space, false, game)
    task.wait(0.05)
    vim:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
end

local function getHumAndRoot()
    local char = LP.Character
    if not char then return nil, nil end
    return char:FindFirstChildOfClass("Humanoid"), char:FindFirstChild("HumanoidRootPart")
end

-- game sets _G.CanFly to true once we're in freefall.
-- so instead of a blind wait we watch for it, then press again.
-- this kills the double-jump / low-altitude weirdness.
local function waitForFreefall(maxSec)
    local hum = select(1, getHumAndRoot())
    local t0 = tick()
    while tick() - t0 < (maxSec or 1.2) do
        if _G.CanFly == true then return true end
        if hum and hum:GetState() == Enum.HumanoidStateType.Freefall then return true end
        task.wait(0.03)
    end
    return _G.CanFly == true
end

local function tryEnterFlyMode()
    if _G.isFlying() then return true end
    local hum, root = getHumAndRoot()
    if not hum or not root or hum.Health <= 0 then return false end

    -- first jump gets us airborne
    doJump()
    -- wait for actual freefall instead of a fixed 0.8s guess
    if not waitForFreefall(1.2) then
        -- didn't reach freefall (probably too low / on ground). bail, loop retries.
        return false
    end
    task.wait(0.08)
    -- second press in freefall = fly
    doJump()

    local t0 = tick()
    while tick() - t0 < 1.5 do
        if _G.isFlying() then return true end
        task.wait(0.05)
    end
    return _G.isFlying()
end

local function equipMeditateTool()
    if _G.sathAutofarmBlocked() then return end
    local char = LP.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if not char or not hum or hum.Health <= 0 then return end
    if char:FindFirstChild("Meditate") then return end
    local tool = LP.Backpack:FindFirstChild("Meditate")
    if tool then hum:EquipTool(tool) end
end

-- guard so we don't spam fly attempts every 0.4s while one is in flight
local flyAttemptBusy = false

task.spawn(function()
    while _G.SPTS_ALIVE ~= false do
        if _G.sathAutofarmBlocked() then
            if not _G.Settings.PsychicPower then
                _G.unequipAllTools()
            end
            task.wait(0.15)
            continue
        end
        if _G.Settings.PsychicPower then
            local chapter = _G.sathScanner.readMainQuestChapterFromUI()
            local useFly  = Z.canFlyMeditateFarm(chapter, _G.RawStats, _G.sathScanner.hasFlyUnlocked())
            if not _G.ppTeleported then
                local target = Z.smartTarget({ PsychicPower = true }, _G.RawStats, chapter)
                if target then
                    local char = LP.Character
                    local root = char and char:FindFirstChild("HumanoidRootPart")
                    if root then
                        _G.unequipAllTools()
                        root.CFrame = CFrame.new(target)
                        _G.ppTeleported = true
                        local waited = 0
                        while waited < 4 do
                            if not _G.Settings.PsychicPower then
                                _G.unequipAllTools()
                                _G.ppTeleported = false
                                break
                            end
                            task.wait(0.1)
                            waited = waited + 0.1
                        end
                    end
                else
                    _G.ppTeleported = true
                end
            end
            if not _G.Settings.PsychicPower then
                task.wait(0.4)
                continue
            end
            if useFly then
                _G.ppUseFlyMode = true
                if _G.isFlying() then
                    equipMeditateTool()
                elseif not flyAttemptBusy then
                    flyAttemptBusy = true
                    task.spawn(function()
                        if tryEnterFlyMode() then
                            task.wait(0.2)
                            equipMeditateTool()
                        end
                        flyAttemptBusy = false
                    end)
                end
            else
                if _G.ppUseFlyMode or _G.isFlying() then
                    _G.stopFlyMode()
                    _G.ppUseFlyMode = false
                end
                equipMeditateTool()
            end
        else
            if _G.ppTeleported or _G.ppUseFlyMode then
                _G.unequipAllTools()
                _G.stopFlyMode()
            end
            _G.ppTeleported = false
            _G.ppUseFlyMode = false
        end
        task.wait(0.4)
    end
end)
