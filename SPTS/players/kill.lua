-- Kill, punch, and kill-aura helpers.
-- All confirmed against the game's client source:
--   * punch fires { "Skill_Punch", "Right" } then { "Skill_Punch", "Left" }
--   * punch has NO range/target arg, the server auto-hits whoever is near us
--   * punch cooldown is 0.5s (0.25s with x2 skill pass)
--   * attacks are blocked on players with a SafeZoneShield OR any ForceField
local LP      = _G.LP
local Players = _G.Players
local killBusy = false

_G.currentKillSelection = { "All" }
_G.playerByLabel        = {}
_G.Settings.KillAura    = _G.Settings.KillAura or false

-- resolve the RemoteEvent once. game keeps it at ReplicatedStorage.RemoteEvent
local function getRemote()
    if _G.Remote then return _G.Remote end
    local re = game:GetService("ReplicatedStorage"):FindFirstChild("RemoteEvent")
    _G.Remote = re
    return re
end

-- ── Helpers ───────────────────────────────────────────────────
local function getRoot(char)
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
        or char:FindFirstChild("Torso")
        or char.PrimaryPart
end

-- game blocks attacks on SafeZoneShield OR ForceField. skip those.
local function isProtected(char)
    if not char then return true end
    if char:FindFirstChild("SafeZoneShield") then return true end
    if char:FindFirstChildOfClass("ForceField") then return true end
    return false
end

local function formatPlayerLabel(plr)
    return string.format("%s (@%s)", plr.DisplayName, plr.Name)
end

local function buildPlayerDropdownOptions()
    local opts = { "All" }
    _G.playerByLabel = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP then
            local label = formatPlayerLabel(plr)
            _G.playerByLabel[label] = plr
            table.insert(opts, label)
        end
    end
    table.sort(opts, function(a, b)
        if a == "All" then return true end
        if b == "All" then return false end
        return a:lower() < b:lower()
    end)
    return opts
end

-- returns selected targets, already filtered for dead/protected players
local function resolveKillTargets()
    local raw = {}
    local pickAll = false
    for _, opt in ipairs(_G.currentKillSelection) do
        if opt == "All" then pickAll = true; break end
    end
    if pickAll then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LP then table.insert(raw, plr) end
        end
    else
        for _, opt in ipairs(_G.currentKillSelection) do
            local plr = _G.playerByLabel[opt]
            if plr and plr.Parent then table.insert(raw, plr) end
        end
    end

    -- drop protected / dead
    local targets = {}
    for _, plr in ipairs(raw) do
        local char = plr.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        if char and hum and hum.Health > 0 and not isProtected(char) then
            table.insert(targets, plr)
        end
    end
    return targets
end

-- ── Bring / anchor / restore ──────────────────────────────────
-- stack them a few studs in front of us so projectile skills connect too
local function bringAndAnchorTargets(targets)
    local myRoot = getRoot(LP.Character)
    if not myRoot then return {}, nil end
    local saved   = {}
    local stackCF = myRoot.CFrame * CFrame.new(0, 0, -3)
    for _, plr in ipairs(targets) do
        local char = plr.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        local root = char and getRoot(char)
        if hum and root and hum.Health > 0 then
            pcall(function()
                if hum.Sit then hum.Sit = false end
            end)
            local savedCF = root.CFrame
            root.CFrame = stackCF
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            root.Anchored = true
            table.insert(saved, { root = root, cframe = savedCF })
        end
    end
    return saved, myRoot
end

-- re-pin mid-combo so the game can't shove them out of range after a hit
local function repinAnchored(saved)
    local myRoot = getRoot(LP.Character)
    if not myRoot then return end
    local stackCF = myRoot.CFrame * CFrame.new(0, 0, -3)
    for _, entry in ipairs(saved) do
        local root = entry.root
        if root and root.Parent then
            root.CFrame = stackCF
            root.AssemblyLinearVelocity = Vector3.zero
        end
    end
end

local function restoreAnchored(saved)
    for _, entry in ipairs(saved) do
        local root = entry.root
        if root and root.Parent then
            root.Anchored = false
            root.CFrame   = entry.cframe
        end
    end
end

-- ── Punch remote ──────────────────────────────────────────────
-- the game does a Right then Left swing as a combo
local PUNCH_R = { "Skill_Punch", "Right" }
local PUNCH_L = { "Skill_Punch", "Left" }

local function firePunchCombo()
    local re = getRemote()
    if not re then return end
    pcall(function()
        re:FireServer(PUNCH_R)
        re:FireServer(PUNCH_L)
    end)
end

-- ── Skill key helpers (kept for the old fireball button) ──────
local function getSkillFrame()
    local sg   = LP:FindFirstChild("PlayerGui") and LP.PlayerGui:FindFirstChild("ScreenGui")
    local menu = sg and sg:FindFirstChild("MenuFrame")
    return menu and menu:FindFirstChild("SkillFrame")
end
local function getSkillDefaultKeyName(skillTxtName, txtBoxName)
    local skillFrame = getSkillFrame()
    if not skillFrame then return nil end
    local skillTxt = skillFrame:FindFirstChild(skillTxtName)
    local txtBox   = skillTxt and skillTxt:FindFirstChild(txtBoxName)
    local defKey   = txtBox and txtBox:FindFirstChild("DefaultKey")
    if defKey and defKey:IsA("StringValue") and defKey.Value ~= "" then
        return defKey.Value
    end
    return nil
end
local function pressSkillKey(keyName)
    if not keyName or keyName == "" then return false end
    local keyCode
    local ok = pcall(function() keyCode = Enum.KeyCode[keyName] end)
    if not ok or not keyCode then return false end
    pcall(function()
        local vim = game:GetService("VirtualInputManager")
        vim:SendKeyEvent(true,  keyCode, false, game)
        task.wait(0.05)
        vim:SendKeyEvent(false, keyCode, false, game)
    end)
    return true
end
local function pressFireballSkill()
    local key = getSkillDefaultKeyName("SkillTxt4", "Skill_4_TxtBox")
    return pressSkillKey(key)
end

-- ── Kill actions ──────────────────────────────────────────────
local function runKillWithFireball()
    if killBusy then return end
    local targets = resolveKillTargets()
    if #targets == 0 then
        _G.Rayfield:Notify({ Title = "Kill", Content = "No valid targets (dead or in safe zone).", Duration = 3, Image = "users" })
        return
    end
    killBusy = true
    pcall(function()
        local saved = bringAndAnchorTargets(targets)
        if #saved == 0 then
            _G.Rayfield:Notify({ Title = "Kill", Content = "Targets not available.", Duration = 3, Image = "users" })
            return
        end
        task.wait(0.15)
        local fired = false
        for i = 1, 3 do
            if pressFireballSkill() then fired = true end
            task.wait(0.35)
            repinAnchored(saved)
        end
        if not fired then
            _G.Rayfield:Notify({
                Title   = "Kill",
                Content = "Fireball hotkey not found in SkillFrame.",
                Duration = 4,
                Image    = "alert-circle",
            })
        end
        task.wait(0.6)
        restoreAnchored(saved)
    end)
    killBusy = false
end

local function runKeybindPunch()
    if not _G.Settings.AutoPunch then return end
    if killBusy then return end
    local targets = resolveKillTargets()
    if #targets == 0 then return end
    killBusy = true
    pcall(function()
        local saved = bringAndAnchorTargets(targets)
        if #saved == 0 then return end
        task.wait(0.12)
        -- punch cd is 0.5s, so pace combos around that. re-pin between hits.
        for i = 1, 3 do
            firePunchCombo()
            task.wait(0.5)
            repinAnchored(saved)
        end
        task.wait(0.15)
        restoreAnchored(saved)
    end)
    killBusy = false
end

-- ── Kill aura ─────────────────────────────────────────────────
local function runKillAuraTick()
    if killBusy then return end
    local targets = resolveKillTargets()
    if #targets == 0 then return end
    killBusy = true
    pcall(function()
        local saved = bringAndAnchorTargets(targets)
        if #saved == 0 then return end
        task.wait(0.1)
        for i = 1, 3 do
            firePunchCombo()
            task.wait(0.5)
            repinAnchored(saved)
        end
        task.wait(0.1)
        restoreAnchored(saved)
    end)
    killBusy = false
end

task.spawn(function()
    while _G.SPTS_ALIVE ~= false do
        if _G.Settings.KillAura then
            runKillAuraTick()
        end
        task.wait(0.3)
    end
end)

_G.killModule = {
    buildPlayerDropdownOptions = buildPlayerDropdownOptions,
    runKillWithFireball         = runKillWithFireball,
    runKeybindPunch             = runKeybindPunch,
    runKillAuraTick             = runKillAuraTick,
    formatPlayerLabel           = formatPlayerLabel,
}
