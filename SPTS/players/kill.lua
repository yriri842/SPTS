-- Kill, punch, kill-aura, and safe-respawn helpers.
-- Confirmed against the client source:
--   * punch fires { "Skill_Punch", "Right" } then { "Skill_Punch", "Left" }
--   * punch has NO range arg, server auto-hits whoever is near us, cd 0.5s
--   * attacks blocked on SafeZoneShield OR any ForceField
--   * respawn after death is FireServer({ "Respawn" })
local LP      = _G.LP
local Players = _G.Players
local killBusy = false

_G.currentKillSelection = { "All" }
_G.playerByLabel        = {}
_G.Settings.KillAura    = _G.Settings.KillAura or false
_G.Settings.SafeRespawn = _G.Settings.SafeRespawn or false

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
-- spread them in a small ring in front of us so they don't all overlap
-- into what looks like a single body, and stay in punch range
local function bringAndAnchorTargets(targets)
    local myRoot = getRoot(LP.Character)
    if not myRoot then return {} end
    local saved = {}
    local n = #targets
    for i, plr in ipairs(targets) do
        local char = plr.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        local root = char and getRoot(char)
        if hum and root and hum.Health > 0 then
            pcall(function()
                if hum.Sit then hum.Sit = false end
            end)
            -- ring layout: spread around a 4-stud circle in front of us
            local angle  = (i - 1) / math.max(n, 1) * math.pi * 2
            local offset = Vector3.new(math.cos(angle) * 4, 0, -3 + math.sin(angle) * 2)
            local placeCF = myRoot.CFrame * CFrame.new(offset)
            local savedCF = root.CFrame
            root.CFrame = placeCF
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            root.Anchored = true
            table.insert(saved, { root = root, cframe = savedCF, angle = angle })
        end
    end
    return saved
end

local function repinAnchored(saved)
    local myRoot = getRoot(LP.Character)
    if not myRoot then return end
    local n = #saved
    for i, entry in ipairs(saved) do
        local root = entry.root
        if root and root.Parent then
            local angle  = entry.angle or ((i - 1) / math.max(n, 1) * math.pi * 2)
            local offset = Vector3.new(math.cos(angle) * 4, 0, -3 + math.sin(angle) * 2)
            root.CFrame = myRoot.CFrame * CFrame.new(offset)
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

-- ── Fireball (Energy Sphere Punch, SkillTxt4 key) ─────────────
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

-- shared punch runner (used by keybind AND aura)
local function doPunchBurst(targets, rounds)
    local saved = bringAndAnchorTargets(targets)
    if #saved == 0 then return end
    task.wait(0.12)
    for i = 1, (rounds or 3) do
        firePunchCombo()
        task.wait(0.5)   -- punch cooldown from source
        repinAnchored(saved)
    end
    task.wait(0.15)
    restoreAnchored(saved)
end

local function runKeybindPunch()
    if killBusy then return end
    local targets = resolveKillTargets()
    if #targets == 0 then return end
    killBusy = true
    pcall(function() doPunchBurst(targets, 3) end)
    killBusy = false
end

local function runKillAuraTick()
    if killBusy then return end
    local targets = resolveKillTargets()
    if #targets == 0 then return end
    killBusy = true
    pcall(function() doPunchBurst(targets, 3) end)
    killBusy = false
end

-- ── Kill aura loop ────────────────────────────────────────────
task.spawn(function()
    while _G.SPTS_ALIVE ~= false do
        if _G.Settings.KillAura then
            runKillAuraTick()
        end
        task.wait(0.3)
    end
end)

-- ── Safe respawn ──────────────────────────────────────────────
-- watch our humanoid; when it dies and SafeRespawn is on, fire the
-- game's Respawn remote (same thing the SPAWN button does). this must
-- NOT be on at the same time as instant respawn.
local function fireRespawn()
    local re = getRemote()
    if re then pcall(function() re:FireServer({ "Respawn" }) end) end
end

local function hookRespawnWatcher(char)
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    hum.Died:Connect(function()
        if _G.Settings.SafeRespawn and not _G.Settings.InstantRespawn then
            -- small wait so the death sequence settles before we ask to spawn
            task.wait(3)
            if _G.Settings.SafeRespawn and not _G.Settings.InstantRespawn then
                fireRespawn()
            end
        end
    end)
end

if LP.Character then hookRespawnWatcher(LP.Character) end
LP.CharacterAdded:Connect(hookRespawnWatcher)

_G.killModule = {
    buildPlayerDropdownOptions = buildPlayerDropdownOptions,
    runKillWithFireball         = runKillWithFireball,
    runKeybindPunch             = runKeybindPunch,
    runKillAuraTick             = runKillAuraTick,
    formatPlayerLabel           = formatPlayerLabel,
    fireRespawn                 = fireRespawn,
}
