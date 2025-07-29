local filePath = "rfsWhitelist.txt"
local rfsWhitelist = {}

local playSound = CreateClientConVar("cl_rfs_sound", '1', true, false)
local showSoundNames = CreateClientConVar("cl_show_sound_names", '0', true, false)

CreateConVar("sv_rfs_enable_ricochet", '1', { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "", 0, 1)
CreateConVar("sv_rfs_fragments", '250', { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "", 1, 3000)

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

local function rfsExplosion(sound)
    local soundFilename = sound.SoundName or ""
    local soundPosition = sound.Pos
    if not soundPosition then return end
    if showSoundNames:GetBool() then
        print("Sound Name:", soundFilename, "\n")
    end

    if not containsKeyword(explosionConditions, soundFilename) then
        loadWhitelist()
        if not containsKeyword(rfsWhitelist, soundFilename, true) then
            return
        end
    end

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

    if playSound:GetBool() and soundDistance <= 40 then
        local flybyChance = math.random(1, soundDistance)
        local fragMultiplier = GetConVar("sv_rfs_fragments"):GetInt() * 0.005

        if flybyChance - fragMultiplier <= 7 and not trace.Hit then
            LocalPlayer():EmitSound(flybySounds[math.random(#flybySounds)], 75, 100, 1, CHAN_STATIC)
        end
    end
end

hook.Add("EntityEmitSound", "rfsDetectExplosion", rfsExplosion)