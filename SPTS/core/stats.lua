local Z = _G.Z

local cpd = nil
local function findClientPlrData()
    if cpd and cpd.FistStrength then return cpd end

    local okRenv, renv = pcall(function() return getrenv and getrenv() end)
    if okRenv and renv and renv._G and renv._G.ClientPlrData then
        cpd = renv._G.ClientPlrData
        return cpd
    end
    if _G.ClientPlrData and _G.ClientPlrData.FistStrength then
        cpd = _G.ClientPlrData
        return cpd
    end
    if getgc then
        for _, obj in pairs(getgc(false)) do
            if type(obj) == "table" and rawget(obj, "FistStrength")
                and rawget(obj, "QuestData") and rawget(obj, "Inventory") then
                cpd = obj
                return cpd
            end
        end
    end
    return nil
end

findClientPlrData()
_G.UseRawStats = (cpd ~= nil)

local function commas(n)
    local s = string.format("%.0f", n)
    local sign = ""
    if s:sub(1, 1) == "-" then sign = "-"; s = s:sub(2) end
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    out = out:gsub("^,", "")
    return sign .. out
end

local RANK_NAMES = { "F","E","D","C","B","A","S","SS","SSS","X","XX" }

local RepFolder = game:GetService("ReplicatedStorage"):FindFirstChild("Rep_ChatNameColors")
local function repColor(side, index)
    if not RepFolder then return Color3.fromRGB(250,250,250) end
    local folder = RepFolder:FindFirstChild(side)
    local entry  = folder and folder:FindFirstChild(tostring(index))
    local txt    = entry and entry:FindFirstChild("NameTxt")
    return (txt and txt.TextColor3) or Color3.fromRGB(250,250,250)
end

local function repStatus(rep)
    rep = rep or 0
    local HERO = {
        {1,10,"Protector",1},{10,40,"Guardian",2},{40,100,"Superhero",3},
        {100,200,"Punisher",4},{200,300,"Lightbringer",5},{300,400,"Saint",6},
        {400,500,"Paragon",7},{500,600,"Lionheart",8},{600,800,"Chosen One",9},
        {800,1000,"Liberator",10},{1000,1500,"One With Glory",11},{1500,2000,"Wonderbringer",12},
        {2000,2500,"Benefactor",13},{2500,3500,"Executioner",14},{3500,5000,"Morningstar",15},
        {5000,7500,"Flames of Fire",16},{7500,10000,"Blinding Lights",17},{10000,20000,"Peace Dominion",18},
        {20000,30000,"Constellations",19},{30000,50000,"Supreme Unknown",20},{50000,100000,"Eternal Life",21},
        {100000,math.huge,"Savior of Worlds",22},
    }
    local VILLAIN = {
        {-10,0,"Lawbreaker",1},{-40,-10,"Criminal",2},{-100,-40,"Supervillain",3},
        {-200,-100,"Devilish",4},{-300,-200,"Satanic",5},{-400,-300,"Hellish",6},
        {-500,-400,"Death",7},{-600,-500,"Archdemon",8},{-800,-600,"The Devourer",9},
        {-1000,-800,"Wicked Revengers",10},{-1500,-1000,"Soulcounter",11},{-2000,-1500,"The Dark Sun",12},
        {-2500,-2000,"Infernal Judge",13},{-3500,-2500,"The Last Nemesis",14},{-5000,-3500,"Minister of Chaos",15},
        {-7500,-5000,"Great Disaster",16},{-10000,-7500,"Ruler Of All Evil",17},{-20000,-10000,"Inferno Furies",18},
        {-30000,-20000,"Warmaster",19},{-50000,-30000,"Lord of Calamity",20},{-100000,-50000,"False God",21},
        {-math.huge,-100000,"Harbringer of Doom",22},
    }
    if rep == 0 then
        return "Innocent", Color3.fromRGB(250,250,250)
    elseif rep > 0 then
        for _, e in ipairs(HERO) do
            if rep >= e[1] and rep < e[2] then return e[3], repColor("Hero", e[4]) end
        end
    else
        for _, e in ipairs(VILLAIN) do
            if rep > e[1] and rep <= e[2] then return e[3], repColor("Villain", e[4]) end
        end
    end
    return "Innocent", Color3.fromRGB(250,250,250)
end

local function tokenFromUI()
    local ok, val = pcall(function()
        return _G.LP.PlayerGui.ScreenGui.CurrentGemImgBtn.AmountTxtBtn.Text
    end)
    return (ok and val ~= "" and val) or "0"
end

local function rankFromUI()
    local ok, val = pcall(function()
        return _G.LP.PlayerGui.ScreenGui.MenuFrame.InfoFrame.RankTxt.Text
    end)
    if ok and val then
        local letter = val:match("Rank%s*:%s*(%S+)")
        if letter then return letter end
    end
    return "?"
end

task.spawn(function()
    while _G.SPTS_ALIVE ~= false do
        findClientPlrData()
        _G.UseRawStats = (cpd ~= nil)

        if cpd then
            local fs = cpd.FistStrength  or 0
            local bt = cpd.BodyToughness or 0
            local ms = cpd.MovementSpeed or 0
            local jf = cpd.JumpForce     or 0
            local pp = cpd.PsychicPower  or 0

            _G.RawStats.FS = fs; _G.Stats.FS = commas(fs)
            _G.RawStats.BT = bt; _G.Stats.BT = commas(bt)
            _G.RawStats.MS = ms; _G.Stats.MS = commas(ms)
            _G.RawStats.JF = jf; _G.Stats.JF = commas(jf)
            _G.RawStats.PP = pp; _G.Stats.PP = commas(pp)

            _G.Stats.Token     = commas(cpd.Token or 0)
            _G.Stats.AliveTime = tostring(cpd.AliveTime or 0) -- minute

            local rankIdx = cpd.Rank or 0
            _G.RawStats.RankIndex = rankIdx
            _G.Stats.Rank = RANK_NAMES[rankIdx] or "?"

            local name, col = repStatus(cpd.Reputation or 0)
            _G.Stats.RepName  = name
            _G.Stats.RepColor = col
            _G.RawStats.Rep   = cpd.Reputation or 0

            task.wait(0.2)
        else
            local gui   = _G.LP:FindFirstChild("PlayerGui")
            local frame = gui and gui:FindFirstChild("ScreenGui")
                and gui.ScreenGui:FindFirstChild("MenuFrame")
                and gui.ScreenGui.MenuFrame:FindFirstChild("InfoFrame")
            if frame then
                local function txt(key)
                    local obj = frame:FindFirstChild(key)
                    return obj and obj.Text:match(":%s*(.+)") or "0"
                end
                local fs, bt, ms, jf, pp =
                    txt("FSTxt"), txt("BTTxt"), txt("MSTxt"), txt("JFTxt"), txt("PPTxt")
                _G.RawStats.FS = Z.parseNum(fs); _G.Stats.FS = fs
                _G.RawStats.BT = Z.parseNum(bt); _G.Stats.BT = bt
                _G.RawStats.MS = Z.parseNum(ms); _G.Stats.MS = ms
                _G.RawStats.JF = Z.parseNum(jf); _G.Stats.JF = jf
                _G.RawStats.PP = Z.parseNum(pp); _G.Stats.PP = pp
            end

            _G.Stats.Token = tokenFromUI()

            local letter = rankFromUI()
            _G.Stats.Rank = letter
            for i, n in ipairs(RANK_NAMES) do
                if n == letter then _G.RawStats.RankIndex = i; break end
            end

            _G.Stats.AliveTime = _G.Stats.AliveTime or "--"
            _G.Stats.RepName   = _G.Stats.RepName  or "Innocent"
            _G.Stats.RepColor  = _G.Stats.RepColor or Color3.fromRGB(250,250,250)

            task.wait(0.8)
        end
    end
end)
