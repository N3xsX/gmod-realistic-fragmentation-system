util.AddNetworkString("RFSExplosionPosition")
util.AddNetworkString("RFSSendWhitelist")
util.AddNetworkString("RFSUpdateWhitelist")

local filePath = "rfsWhitelist.txt"
local rfsWhitelist = {}

local playerMessageTimestamps = {}
local recentExplosions = {}

if file.Exists(filePath, "DATA") then
    rfsWhitelist = util.JSONToTable(file.Read(filePath, "DATA"))
    print("[RFS] Whitelist loaded")
else
    print("[RFS] No whitelist file found, creating a new one")
end

-- help me god i hate networking
local function sendWhitelistToClients()
    local rfsWhitelistJson = util.TableToJSON(rfsWhitelist)
    net.Start("RFSSendWhitelist")
    net.WriteString(rfsWhitelistJson)
    net.Broadcast()
    print("[RFS] Sent whitelist to clients")
end

net.Receive("RFSUpdateWhitelist", function(len, ply)
    if not ply:IsAdmin() then return end
    local updatedWhitelistJson = net.ReadString()
    local updatedWhitelist = util.JSONToTable(updatedWhitelistJson)
    rfsWhitelist = updatedWhitelist
    file.Write(filePath, updatedWhitelistJson)
    sendWhitelistToClients()
end)

local function shootTraces(num, pos)
    local directionEnabled = GetConVar("sv_rfs_fragment_direction"):GetBool()
    local downTraceData = {
        start = pos,
        endpos = pos + Vector(0, 0, -10000)
    }
    local traceResult = util.TraceLine(downTraceData)
    local isCloseToGround = traceResult.Hit and pos:Distance(traceResult.HitPos) < 10
    local damage = GetConVar("sv_rfs_damage"):GetInt()
    local ricochetEnabled = GetConVar("sv_rfs_enable_ricochet"):GetBool()
    local isDebug = GetConVar("sv_rfs_debug"):GetBool()
    local travelDistance = GetConVar("sv_rfs_fragments_travel_distance"):GetInt()
    local ricochetAngle = GetConVar("sv_rfs_ricochet_angle"):GetInt()
    local ricochetChance = GetConVar("sv_rfs_ricochet_chance"):GetInt() * 0.01
    for i = 1, num do
        local direction
        if isCloseToGround then 
            if directionEnabled then
                direction = Vector(math.Rand(-1, 1), math.Rand(-1, 1), math.Rand(-0.05, 0.2)):GetNormalized()
            else
                direction = Vector(math.Rand(-1, 1), math.Rand(-1, 1), math.Rand(-0.1, 1)):GetNormalized()
            end
        else
            if directionEnabled then
                direction = Vector(math.Rand(-1, 1), math.Rand(-1, 1), math.Rand(-0.2, 0.2)):GetNormalized()
            else
                direction = VectorRand():GetNormalized()
            end
        end
        local distance = math.random(travelDistance / 2, travelDistance) / 0.02
        local traceData = {
            start = pos,
            endpos = pos + direction * distance
        }
        local trace = util.TraceLine(traceData)
        if isDebug then
            debugoverlay.Line(traceData.start, trace.HitPos, 20, Color(255, 0, 0), false)
        end
        if trace.Hit and (trace.Entity:IsPlayer() or trace.Entity:IsNPC() or trace.Entity:IsNextBot()) then
            trace.Entity:TakeDamage(damage)
        end
        if trace.Hit and ricochetEnabled then
            if (trace.HitPos - trace.StartPos):Length() >= 20 then -- prevent creating shrapnel too close to the explosion position
                local impactAngle = direction:Dot(trace.HitNormal) * -1
                if math.deg(math.acos(impactAngle)) > ricochetAngle and math.random() <= ricochetChance then
                    local ricochetDirection = (direction - 2 * direction:Dot(trace.HitNormal) * trace.HitNormal):GetNormalized()
                    local randomOffset = Vector(math.random(-1, 1) * 0.1, math.random(-1, 1) * 0.1, math.random(-1, 1) * 0.1)
                    ricochetDirection = (ricochetDirection + randomOffset):GetNormalized()
                    local ricochetData = {
                        start = trace.HitPos,
                        endpos = trace.HitPos + ricochetDirection:GetNormalized() * distance / 2
                    }

                    if math.random() > 0.8 then
                        local ricochetSound = "rico" .. math.random(1, 3) .. ".wav"
                        sound.Play(ricochetSound, trace.HitPos, 75, 100, 1)
                    end
                
                    local ricochetTrace = util.TraceLine(ricochetData)
                    if ricochetTrace.Hit and (ricochetTrace.Entity:IsPlayer() or ricochetTrace.Entity:IsNPC() or ricochetTrace.Entity:IsNextBot()) then
                        ricochetTrace.Entity:TakeDamage(damage)
                    end
                    if isDebug then
                        debugoverlay.Line(ricochetData.start, ricochetTrace.HitPos, 20, Color(255, 255, 0), false)
                    end
                end
            end
        end
    end
end

local function shootBullets(num, pos)
    local name = ents.Create("prop_physics")
    name:SetModel("models/props_junk/PopCan01a.mdl")
    name:SetPos(pos)
    name:Spawn()
    name:SetRenderMode(RENDERMODE_TRANSCOLOR)
    name:SetColor(Color(255, 255, 255, 0))
    name:SetMoveType(MOVETYPE_NONE)
    name:SetSolid(SOLID_NONE)
    local effectData = EffectData()
    effectData:SetOrigin(pos)
    local batchFragmentsEnabled = GetConVar("sv_rfs_batch_fragments"):GetBool()
    local directionEnabled = GetConVar("sv_rfs_fragment_direction"):GetBool()
    local damage = GetConVar("sv_rfs_damage"):GetInt()
    local ricochetEnabled = GetConVar("sv_rfs_enable_ricochet"):GetBool()
    local tracer = GetConVar("sv_rfs_enable_bullet_traces"):GetInt()
    local travelDistance = GetConVar("sv_rfs_fragments_travel_distance"):GetInt()
    local ricochetAngle = GetConVar("sv_rfs_ricochet_angle"):GetInt()
    local ricochetChance = GetConVar("sv_rfs_ricochet_chance"):GetInt() * 0.01
    local source = name:GetPos() + Vector(0, 0, 5)
    local downTraceData = {
        start = pos,
        endpos = pos + Vector(0, 0, -10000)
    }
    local traceResult = util.TraceLine(downTraceData)
    local isCloseToGround = traceResult.Hit and pos:Distance(traceResult.HitPos) < 10

    if batchFragmentsEnabled then -- i dunno if this even improves something
        local fragmentsPerBatch = math.floor(num / 5)
        for batch = 1, 5 do
            timer.Simple(batch * 0.05, function()
                for i = 1, fragmentsPerBatch do
                    local fragment = {}
                    local direction
                    if isCloseToGround then 
                        if directionEnabled then
                            direction = Vector(math.Rand(-1, 1), math.Rand(-1, 1), math.Rand(-0.05, 0.2)):GetNormalized()
                        else
                            direction = Vector(math.Rand(-1, 1), math.Rand(-1, 1), math.Rand(-0.1, 1)):GetNormalized()
                        end
                    else
                        if directionEnabled then
                            direction = Vector(math.Rand(-1, 1), math.Rand(-1, 1), math.Rand(-0.2, 0.2)):GetNormalized()
                        else
                            direction = VectorRand():GetNormalized()
                        end
                    end
                    fragment.Num = 1
                    fragment.Src = source
                    fragment.Dir = direction
                    fragment.Distance = math.random(travelDistance / 2, travelDistance) / 0.02
                    fragment.Spread = Vector(0.01, 0.01, 0)
                    fragment.Tracer = 0
                    fragment.Force = 2
                    fragment.AmmoType = "grenadeFragments"
                    fragment.Damage = damage
                    if IsValid(name) then
                        name:FireBullets(fragment)
                        if ricochetEnabled then
                            local traceData = {
                                start = fragment.Src,
                                endpos = fragment.Src + fragment.Dir * fragment.Distance
                            }
                            local trace = util.TraceLine(traceData)
                            if trace.Hit then
                                if (trace.HitPos - trace.StartPos):Length() >= 20 then
                                    local impactAngle = fragment.Dir:Dot(trace.HitNormal) * -1
                                    if math.deg(math.acos(impactAngle)) > ricochetAngle and math.random() <= ricochetChance then
                                        local ricochetDirection = (fragment.Dir - 2 * fragment.Dir:Dot(trace.HitNormal) * trace.HitNormal):GetNormalized()
                                        local randomOffset = Vector(math.random(-1, 1) * 0.1, math.random(-1, 1) * 0.1, math.random(-1, 1) * 0.1)
                                        ricochetDirection = (ricochetDirection + randomOffset):GetNormalized()
                
                                        local ricochetFragment = {}
                                        ricochetFragment.Num = 1
                                        ricochetFragment.Src = trace.HitPos
                                        ricochetFragment.Dir = ricochetDirection
                                        ricochetFragment.Distance = fragment.Distance / 2
                                        ricochetFragment.Spread = fragment.Spread
                                        ricochetFragment.Tracer = fragment.Tracer
                                        ricochetFragment.Force = fragment.Force / 2
                                        ricochetFragment.AmmoType = fragment.AmmoType
                                        ricochetFragment.Damage = fragment.Damage / 2
                
                                        name:FireBullets(ricochetFragment)
                
                                        if math.random() > 0.8 then
                                            local ricochetSound = "rico" .. math.random(1, 3) .. ".wav"
                                            sound.Play(ricochetSound, trace.HitPos, 75, 100, 1)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end)
        end
    else
        for i = 1, num do
            local fragment = {}
            local direction
            if isCloseToGround then 
                if directionEnabled then
                    direction = Vector(math.Rand(-1, 1), math.Rand(-1, 1), math.Rand(-0.05, 0.2)):GetNormalized()
                else
                    direction = Vector(math.Rand(-1, 1), math.Rand(-1, 1), math.Rand(-0.1, 1)):GetNormalized()
                end
            else
                if directionEnabled then
                    direction = Vector(math.Rand(-1, 1), math.Rand(-1, 1), math.Rand(-0.2, 0.2)):GetNormalized()
                else
                    direction = VectorRand():GetNormalized()
                end
            end
            fragment.Num = 1
            fragment.Src = source
            fragment.Dir = direction
            fragment.Distance = math.random(travelDistance / 2, travelDistance) / 0.02
            fragment.Spread = Vector(0.01, 0.01, 0)
            fragment.Tracer = tracer
            fragment.Force = 2
            fragment.AmmoType = "grenadeFragments"
            fragment.Damage = damage
            if IsValid(name) then
                name:FireBullets(fragment)
                if ricochetEnabled then
                    local traceData = {
                        start = fragment.Src,
                        endpos = fragment.Src + fragment.Dir * fragment.Distance
                    }
                    local trace = util.TraceLine(traceData)
                    if trace.Hit then
                        if (trace.HitPos - trace.StartPos):Length() >= 20 then
                            local impactAngle = fragment.Dir:Dot(trace.HitNormal) * -1
                            if math.deg(math.acos(impactAngle)) > ricochetAngle and math.random() <= ricochetChance then
                                local ricochetDirection = (fragment.Dir - 2 * fragment.Dir:Dot(trace.HitNormal) * trace.HitNormal):GetNormalized()
                                local randomOffset = Vector(math.random(-1, 1) * 0.1, math.random(-1, 1) * 0.1, math.random(-1, 1) * 0.1)
                                ricochetDirection = (ricochetDirection + randomOffset):GetNormalized()
        
                                local ricochetFragment = {}
                                ricochetFragment.Num = 1
                                ricochetFragment.Src = trace.HitPos
                                ricochetFragment.Dir = ricochetDirection
                                ricochetFragment.Distance = fragment.Distance / 2
                                ricochetFragment.Spread = fragment.Spread
                                ricochetFragment.Tracer = fragment.Tracer
                                ricochetFragment.Force = fragment.Force / 2
                                ricochetFragment.AmmoType = fragment.AmmoType
                                ricochetFragment.Damage = fragment.Damage / 2
        
                                name:FireBullets(ricochetFragment)
        
                                if math.random() > 0.8 then
                                    local ricochetSound = "rico" .. math.random(1, 3) .. ".wav"
                                    sound.Play(ricochetSound, trace.HitPos, 75, 100, 1)
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    timer.Simple(0.3, function()
        if IsValid(name) then
            name:Remove()
        end
    end)
end

local function shootMixed(num, pos)
    local ratio = GetConVar("sv_rfs_trtobl_ratio"):GetInt() / 100
    ratio = math.Clamp(ratio, 0, 1)
    local numBullets = math.floor(num * ratio)
    local numTraces = num - numBullets
    if numBullets > 0 then
        shootBullets(numBullets, pos)
    end

    if numTraces > 0 then
        shootTraces(numTraces, pos)
    end
end

-- checking whitelist
local function containsKeyword(keywordsTable, inputString)
    if not inputString then return false end
    for _, keyword in pairs(keywordsTable) do
        if string.find(inputString, keyword, 1, true) then
            return true
        end
    end
    return false
end

local function checkDistance(pos)
    for _, v in ipairs(ents.GetAll()) do
        if IsValid(v) and (v:IsPlayer() or v:IsNPC() or v:IsNextBot()) then
            local distance = pos:Distance(v:GetPos()) * 0.02 -- changing hammer units to meters
            if distance < GetConVar("sv_rfs_fragments_travel_distance"):GetInt() then
                return true
            end
        end
    end
    return false
end

local function rfsMultiplayer(explosionPosition, explosionName)
    local fragments = GetConVar("sv_rfs_fragments"):GetInt()
    local fragmentsType = GetConVar("sv_rfs_fragments_type"):GetInt()
    --local explosionCondition = {"explode", "explosion", "explosions", "detonate", "weapons/explode", "weapons/debris1", "weapons/debris2", "weapons/debris3", "gredwitch/turret", "turret/turret_turn"}
    local explosionConditions = {
        "^weapons/explode", "explosions/doi", 
        "impactsounds/20mm", "gbombs_5/explosions", 
        "explosions/gbomb"
    }

    if not containsKeyword(explosionConditions, explosionName) then
        if file.Exists(filePath, "DATA") then
            rfsWhitelist = util.JSONToTable(file.Read(filePath, "DATA"))
        end
        if not containsKeyword(rfsWhitelist, explosionName) then
            return
        end
    end

    timer.Simple(0.11, function ()
        if explosionPosition then
            if not checkDistance(explosionPosition) then return end
            if fragmentsType == 0 then
                shootTraces(fragments, explosionPosition)
            elseif fragmentsType == 1 then
                shootBullets(fragments, explosionPosition)
            elseif fragmentsType == 2 then
                shootMixed(fragments, explosionPosition)
            end
        end
    end)
end

local function rfsSingleplayer(explosionPosition)
    local fragments = GetConVar("sv_rfs_fragments"):GetInt()
    local fragmentsType = GetConVar("sv_rfs_fragments_type"):GetInt()
    timer.Simple(0.001, function ()
        if explosionPosition then
            if not checkDistance(explosionPosition) then return end
            if fragmentsType == 0 then
                shootTraces(fragments, explosionPosition)
            elseif fragmentsType == 1 then
                shootBullets(fragments, explosionPosition)
            elseif fragmentsType == 2 then
                shootMixed(fragments, explosionPosition)
            end
        end
    end)
end

local function isExplosionDuplicate(explosionPosition)
    local currentTime = CurTime()
    for i = #recentExplosions, 1, -1 do
        if currentTime - recentExplosions[i].timestamp > 1 then
            table.remove(recentExplosions, i)
        end
    end
    for _, data in ipairs(recentExplosions) do
        if data.position == explosionPosition then
            print("[RFS] Explosion at " .. tostring(explosionPosition) .. " is duplicate, ignoring...")
            return true -- duplicate explosion, ignore it
        end
    end
    table.insert(recentExplosions, { position = explosionPosition, timestamp = currentTime })
    return false
end

-- anti spam
local function checkMessageRate(sender)
    local currentTime = CurTime()
    playerMessageTimestamps[sender] = playerMessageTimestamps[sender] or {}
    table.insert(playerMessageTimestamps[sender], currentTime)
    for i = #playerMessageTimestamps[sender], 1, -1 do
        if currentTime - playerMessageTimestamps[sender][i] > 1 then
            table.remove(playerMessageTimestamps[sender], i)
        end
    end
    if #playerMessageTimestamps[sender] > 5 then
        print(string.format(
            "[RFS] Player: %s (%s) sent too many messages per second! Count: %d",
            sender:Nick(), sender:SteamID(), #playerMessageTimestamps[sender]
        ))
        return false
    end
    return true
end

-- whitelist initialization
hook.Add("PlayerInitialSpawn", "RFSSendWhitelist", function(player)
    local jsonWhitelist = util.TableToJSON(rfsWhitelist)
    net.Start("RFSSendWhitelist")
    net.WriteString(jsonWhitelist)
    net.Send(player)
end)

net.Receive("RFSExplosionPosition", function(len, sender)
    if not IsValid(sender) or not sender:IsPlayer() then return end
    local hasAdmin = false
    for _, player in ipairs(player.GetAll()) do
        if player:IsAdmin() then
            hasAdmin = true
            break
        end
    end
    if not checkMessageRate(sender) then
        return
    end
    if hasAdmin and not sender:IsAdmin() then
        return
    end
    local explosionPosition = net.ReadVector(16)
    local explosionName = net.ReadString()
    if isExplosionDuplicate(explosionPosition) then
        return
    end
    if game.SinglePlayer() then
        rfsSingleplayer(explosionPosition)
    else
        rfsMultiplayer(explosionPosition, explosionName)
    end
end)