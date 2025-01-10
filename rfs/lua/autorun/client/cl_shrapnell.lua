local filePath = "rfsWhitelist.txt"
local rfsWhitelist = {}

local function loadWhitelist()
    if game.SinglePlayer() then
        if file.Exists(filePath, "DATA") then
            rfsWhitelist = util.JSONToTable(file.Read(filePath, "DATA"))
        end
    else
        net.Receive("RFSSendWhitelist", function()
            local jsonWhitelist = net.ReadString()
            rfsWhitelist = util.JSONToTable(jsonWhitelist)
        end)
    end
end

loadWhitelist()

local function containsKeyword(keywordsTable, inputString, exactMatch)
    if not inputString then return false end
    for _, keyword in pairs(keywordsTable) do
        if exactMatch then
            if inputString == keyword then
                return true
            end
        else
            if string.find(inputString, keyword, 1, true) then
                return true
            end
        end
    end
    return false
end

local function rfsExplosion(sound)
    local soundFilename = sound.SoundName or ""
    local explosionConditions = {
        "^weapons/explode", "explosions/doi", 
        "impactsounds/20mm", "gbombs_5/explosions", 
        "explosions/gbomb"
    }
    local flybySounds = {
        "flyby1.wav", "flyby2.wav", 
        "flyby3.wav", "flyby4.wav", 
        "flyby5.wav", "flyby6.wav"
    }

    if GetConVar("cl_show_sound_names"):GetBool() then
        print("\nSound Name:", soundFilename, "\n")
    end

    if not containsKeyword(explosionConditions, soundFilename) then
        loadWhitelist()
        if not containsKeyword(rfsWhitelist, soundFilename, true) then
            return
        end
    end

    local soundPosition = sound.Pos
    if not soundPosition then return end

    net.Start("RFSExplosionPosition")
    net.WriteVector(soundPosition)
    net.WriteString(soundFilename)
    net.SendToServer()

    local playerPos = LocalPlayer():GetViewEntity():GetPos()
    local soundDistance = soundPosition:Distance(playerPos) * 0.02

    local traceData = {
        start = soundPosition,
        endpos = playerPos + Vector(0, 0, 70),
        filter = LocalPlayer()
    }
    local trace = util.TraceLine(traceData)

    if GetConVar("cl_rfs_sound"):GetBool() and soundDistance <= 40 then
        local flybyChance = math.random(1, soundDistance)
        local fragMultiplier = GetConVar("sv_rfs_fragments"):GetInt() * 0.005

        if flybyChance - fragMultiplier <= 7 and not trace.Hit then
            LocalPlayer():EmitSound(flybySounds[math.random(#flybySounds)], 75, 100, 1, CHAN_STATIC)
        end
    end
end

hook.Add("EntityEmitSound", "rfsDetectExplosion", rfsExplosion)