local Z = _G.Z

local function DEFS()        return _G.SATH_QUEST_DEFS  end
local function FLAG_LABELS() return _G.SATH_FLAG_LABELS end
local function guiUtils()    return _G.guiUtils          end

local function getMainQuestNo()
    if _G.ClientPlrData
        and _G.ClientPlrData.QuestData
        and _G.ClientPlrData.QuestData.MainQuest
    then
        return _G.ClientPlrData.QuestData.MainQuest.No
    end
    return nil
end

local function hasFinishedAllQuests()
    local sg = guiUtils().getScreenGui()
    local menu = sg and sg:FindFirstChild("MenuFrame")
    local skillFrame = menu and menu:FindFirstChild("SkillFrame")
    if not skillFrame then return false end
    local txt12 = skillFrame:FindFirstChild("SkillTxt12")
    local box = txt12 and txt12:FindFirstChild("Skill_12_TxtBox")
    local nameVal = box and box:FindFirstChild("SkillName")
    if nameVal and nameVal:IsA("StringValue") then
        return nameVal.Value == "KillingIntentAura"
    end
    return false
end

local function hasFlyUnlocked()
    local sg = guiUtils().getScreenGui()
    local menu = sg and sg:FindFirstChild("MenuFrame")
    local skillFrame = menu and menu:FindFirstChild("SkillFrame")
    if not skillFrame then return false end
    local txt8 = skillFrame:FindFirstChild("SkillTxt8")
    if txt8 and txt8.Text and string.find(string.lower(txt8.Text), "fly") then
        return true
    end
    return false
end

local function parseProgTxt(text)
    if not text or text == "" then return 0, 0 end
    local left, right = text:match("^%s*(.-)%s*/%s*(.+)%s*$")
    if not left then return 0, 0 end
    return Z.parseNum(left), Z.parseNum(right)
end

local function questTxtToMeta(questTxt)
    local t = string.lower(questTxt or "")
    if t:find("villain") or t:find("hero") or t:find("killed") then
        return nil, "KILLS", true
    end
    if t:find("fist")     then return "FistStrength",  "FS", false end
    if t:find("body")     then return "BodyToughness",  "BT", false end
    if t:find("movement") then return "MovementSpeed",  "MS", false end
    if t:find("jump")     then return "JumpForce",      "JF", false end
    if t:find("psychic")  then return "PsychicPower",   "PP", false end
    return nil, nil, false
end

local function taskMatchesQuestDef(t, dt)
    if t.isKill then return dt.key == "KILLS" end
    return t.key == dt.key and t.target == dt.target
end

local function detectQuestId(tasks)
    if not tasks or #tasks == 0 then return nil end
    local sig = {}
    for _, t in ipairs(tasks) do
        if t.key and not t.isKill then
            table.insert(sig, { key = t.key, target = t.target })
        end
    end
    table.sort(sig, function(a, b) return a.key < b.key end)
    for id = 1, 13 do
        local def    = DEFS()[id]
        local defSig = {}
        for _, dt in ipairs(def.tasks) do
            if dt.key ~= "KILLS" and dt.farm ~= false then
                table.insert(defSig, { key = dt.key, target = dt.target })
            end
        end
        table.sort(defSig, function(a, b) return a.key < b.key end)
        if #sig == #defSig then
            local ok = true
            for i = 1, #sig do
                if sig[i].key ~= defSig[i].key or sig[i].target ~= defSig[i].target then
                    ok = false; break
                end
            end
            if ok then return id end
        end
    end
    local hasKill, hasPP = false, false
    for _, t in ipairs(tasks) do
        if t.isKill      then hasKill = true end
        if t.key == "PP" then hasPP   = true end
    end
    if hasKill and hasPP then return 13 end
    return nil
end

local function normalizeQuestTasks(tasks)
    if not tasks or #tasks == 0 then return tasks end
    local no       = getMainQuestNo()
    local defToUse = (no and no > 0) and DEFS()[no] or nil
    if not defToUse then
        local qid = detectQuestId(tasks)
        defToUse  = qid and DEFS()[qid] or nil
    end
    if defToUse then
        local filtered = {}
        for _, t in ipairs(tasks) do
            for _, dt in ipairs(defToUse.tasks) do
                if taskMatchesQuestDef(t, dt) then
                    table.insert(filtered, t); break
                end
            end
        end
        table.sort(filtered, function(a, b) return (a.index or 0) < (b.index or 0) end)
        return filtered
    end
    local filtered = {}
    for _, t in ipairs(tasks) do
        if t.isKill or (t.flag and t.target > 0) then
            table.insert(filtered, t)
        end
    end
    table.sort(filtered, function(a, b) return (a.index or 0) < (b.index or 0) end)
    return filtered
end

local function scanMainQuestUI()
    -- was: if getMainQuestNo() == 0 then return {} end
    -- problem: right after finishing a quest the game briefly reports No=0
    -- before it flips to the next one, so we'd bail with empty {} and the
    -- loop thinks we need a fresh quest = the whole "0/13 talk to sath" thing
    local no = getMainQuestNo()
    if no == 0 then
        -- double check the UI actually has no visible task rows before giving up
        local mqfCheck = guiUtils().getMainQuestFrame()
        local anyVisible = false
        if mqfCheck then
            for i = 1, 5 do
                local f = mqfCheck:FindFirstChild("MaxFrame" .. i)
                if f and f.Visible and f:FindFirstChild("QuestTxt")
                    and f.QuestTxt.Text ~= "" then
                    anyVisible = true; break
                end
            end
        end
        if not anyVisible then return {} end
        -- UI still shows tasks so No=0 is just a transient, keep scanning
    end

    local mqf = guiUtils().getMainQuestFrame()
    if not mqf then return nil end
    local tasks = {}
    for i = 1, 5 do
        local frame = mqf:FindFirstChild("MaxFrame" .. i)
        if frame and frame.Visible == true then
            local questLbl = frame:FindFirstChild("QuestTxt")
            local progLbl  = frame:FindFirstChild("ProgTxt")
            local claimBtn = frame:FindFirstChild("ClaimBtn")
            local qt = questLbl and questLbl.Text or ""
            local pt = progLbl  and progLbl.Text  or ""
            if qt ~= "" then
                local flag, key, isKill = questTxtToMeta(qt)
                if flag or isKill then
                    local cur, tgt = parseProgTxt(pt)
                    if tgt > 0 then
                        table.insert(tasks, {
                            index     = i,
                            questTxt  = qt,
                            progTxt   = pt,
                            current   = cur,
                            target    = tgt,
                            flag      = flag,
                            key       = key,
                            isKill    = isKill,
                            claimable = claimBtn and claimBtn.Visible == true,
                            complete  = cur >= tgt,
                        })
                    end
                end
            end
        end
    end
    return normalizeQuestTasks(tasks)
end

local function enrichTasksFromQuestDef(tasks)
    if not tasks then return tasks end
    local no  = getMainQuestNo()
    local qid = (no and no > 0) and no or detectQuestId(tasks)
    if not qid or not DEFS()[qid] then return tasks end
    local byKey = {}
    for _, t in ipairs(tasks) do
        if t.key then byKey[t.key] = t end
    end
    local enriched = {}
    for _, dt in ipairs(DEFS()[qid].tasks) do
        if dt.farm == false or dt.key == "KILLS" then
            if byKey[dt.key] then table.insert(enriched, byKey[dt.key]) end
        else
            local raw = _G.RawStats[dt.key] or 0
            local t   = byKey[dt.key]
            if t then
                t.flag    = t.flag   or dt.flag
                t.target  = t.target or dt.target
                t.current = math.max(t.current or 0, raw)
                t.complete = t.complete or (t.current >= t.target)
                table.insert(enriched, t)
            else
                local raw2 = _G.RawStats[dt.key] or 0
                table.insert(enriched, {
                    key      = dt.key,
                    flag     = dt.flag,
                    target   = dt.target,
                    current  = raw2,
                    complete = raw2 >= dt.target,
                    isKill   = false,
                    questTxt = FLAG_LABELS()[dt.flag] or dt.flag,
                    progTxt  = tostring(raw2) .. " / " .. tostring(dt.target),
                })
            end
        end
    end
    return enriched
end

local function needsQuestPickupFromSath()
    -- only trust No==0 if the UI genuinely has no tasks showing
    -- otherwise we get the false "0/13 go to sath" right after a turn-in
    local no = getMainQuestNo()
    if no ~= nil and no > 0 then return false end

    local tasks = scanMainQuestUI()
    if tasks and #tasks > 0 then return false end

    -- one more confirm pass, quest data lags a frame or two sometimes
    task.wait(0.15)
    local no2 = getMainQuestNo()
    if no2 ~= nil and no2 > 0 then return false end
    local tasks2 = scanMainQuestUI()
    return not tasks2 or #tasks2 == 0
end

local function readMainQuestChapterFromUI()
    local no = getMainQuestNo()
    if no ~= nil then return no end
    local mqf = guiUtils().getMainQuestFrame()
    if mqf then
        for _, d in ipairs(mqf:GetDescendants()) do
            if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text then
                local cur = d.Text:match("(%d+)%s*/%s*13")
                if cur then return tonumber(cur) end
            end
        end
    end
    local sg   = guiUtils().getScreenGui()
    local menu = sg and sg:FindFirstChild("MenuFrame")
    if menu then
        for _, d in ipairs(menu:GetDescendants()) do
            if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text then
                local cur = d.Text:match("(%d+)%s*/%s*13")
                if cur then return tonumber(cur) end
            end
        end
    end
    local tasks = scanMainQuestUI()
    return tasks and detectQuestId(tasks) or nil
end

_G.sathScanner = {
    getMainQuestNo             = getMainQuestNo,
    detectQuestId              = detectQuestId,
    scanMainQuestUI            = scanMainQuestUI,
    enrichTasksFromQuestDef    = enrichTasksFromQuestDef,
    needsQuestPickupFromSath   = needsQuestPickupFromSath,
    readMainQuestChapterFromUI = readMainQuestChapterFromUI,
    hasFinishedAllQuests       = hasFinishedAllQuests,
    hasFlyUnlocked             = hasFlyUnlocked,
}
