local Z = _G.Z

local function findClientPlrData()
    local okRenv, renv = pcall(function() return getrenv and getrenv() end)
    if okRenv and renv and renv._G and renv._G.ClientPlrData then
        return renv._G.ClientPlrData
    end

    if _G.ClientPlrData and _G.ClientPlrData.FistStrength then
        return _G.ClientPlrData
    end

    if getgc then
        for _, obj in pairs(getgc(false)) do
            if type(obj) == "table" and rawget(obj, "FistStrength")
                and rawget(obj, "QuestData") and rawget(obj, "Inventory") then
                return obj
            end
        end
    end

    return nil
end

local cpd = findClientPlrData()
_G.UseRawStats = (cpd ~= nil)

local function commas(n)
    local s = string.format("%.0f", n)
    local sign = ""
    if s:sub(1, 1) == "-" then sign = "-"; s = s:sub(2) end
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    out = out:gsub("^,", "")
    return sign .. out
end

task.spawn(function()
    while _G.SPTS_ALIVE ~= false do
        cpd = findClientPlrData()
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

            task.wait(0.2)
        else
            local gui   = _G.LP:FindFirstChild("PlayerGui")
            local frame = gui
                and gui:FindFirstChild("ScreenGui")
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
            task.wait(0.8)
        end
    end
end)
