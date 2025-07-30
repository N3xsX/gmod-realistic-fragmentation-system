util.AddNetworkString("RFSExplosionPosition")
util.AddNetworkString("RFSSendWhitelist")
util.AddNetworkString("RFSUpdateWhitelist")

local filePath = "rfsWhitelist.txt"
local rfsWhitelist = {}

RFS = RFS or {}

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

local fragments = CreateConVar("sv_rfs_fragments", '500', { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "", 1, 3000)
local fragmentsType = CreateConVar("sv_rfs_fragments_type", '2', { FCVAR_ARCHIVE }, "", 0, 2)
local damage = CreateConVar("sv_rfs_damage", '15', { FCVAR_ARCHIVE }, "", 1, 100)
local ricochetEnabled = CreateConVar("sv_rfs_enable_ricochet", '1', { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "", 0, 1)
local isDebug = CreateConVar("sv_rfs_debug", '0', { FCVAR_ARCHIVE }, "", 0, 1)
local travelDistance = CreateConVar("sv_rfs_fragments_travel_distance", '100', { FCVAR_ARCHIVE }, "", 10, 1000)
local ricochetAngle = CreateConVar("sv_rfs_ricochet_angle", '50', { FCVAR_ARCHIVE }, "", 0, 90)
local ricochetChance = CreateConVar("sv_rfs_ricochet_chance", '50', { FCVAR_ARCHIVE }, "", 1, 100)
local directionEnabled = CreateConVar("sv_rfs_fragment_direction", "1", { FCVAR_ARCHIVE }, "", 0, 1)
local tracer = CreateConVar("sv_rfs_enable_bullet_traces", '1', { FCVAR_ARCHIVE }, "", 0, 1)
local TotalDamage = CreateConVar("sv_rfs_max_fragment_damage", "1000", { FCVAR_ARCHIVE }, "", 1, 10000)
local frgRatio = CreateConVar("sv_rfs_trtobl_ratio", '50', { FCVAR_ARCHIVE }, "", 1, 99)

local function isInWater(pos)
    return bit.band(util.PointContents(pos), CONTENTS_WATER) == CONTENTS_WATER
end

local function setDirection(isCloseToGround)
    local direction
    if isCloseToGround then
        if directionEnabled:GetBool() then
            direction = Vector(math.Rand(-1, 1), math.Rand(-1, 1), math.Rand(-0.05, 0.2)):GetNormalized()
        else
            direction = Vector(math.Rand(-1, 1), math.Rand(-1, 1), math.Rand(-0.1, 1)):GetNormalized()
        end
    else
        if directionEnabled:GetBool() then
            direction = Vector(math.Rand(-1, 1), math.Rand(-1, 1), math.Rand(-0.2, 0.2)):GetNormalized()
        else
            direction = VectorRand():GetNormalized()
        end
    end
    return direction
end

local function shootTraces(num, pos)
    local downTrace = util.TraceLine({
        start = pos,
        endpos = pos + Vector(0, 0, -10000)
    })

    local isCloseToGround = downTrace.Hit and pos:Distance(downTrace.HitPos) < 10
    local inWater = isInWater(pos)
    local maxDamage = TotalDamage:GetInt()
    if fragmentsType:GetInt() == 2 then
        maxDamage = maxDamage / 2
    end

    local applyDamage = damage:GetInt()
    local travelDist = travelDistance:GetInt()
    local allowRicochet = ricochetEnabled:GetBool()
    local ricochetAng = ricochetAngle:GetInt()
    local ricochetProb = ricochetChance:GetInt() * 0.01
    local debug = isDebug:GetBool()

    local hitCount, missCount, ricochetCount = 0, 0, 0
    local damageTracker = {}

    for i = 1, num do
        local direction = setDirection(isCloseToGround)
        local distance = math.random(travelDist / 2, travelDist) / 0.02
        if inWater then distance = distance * 0.2 end

        local traceStart = pos
        local traceEnd = pos + direction * distance
        local trace = util.TraceLine({ start = traceStart, endpos = traceEnd })

        if debug then
            if trace.Hit then hitCount = hitCount + 1 else missCount = missCount + 1 end
            debugoverlay.Line(traceStart, trace.HitPos, 20, Color(255, 0, 0), false)
            if IsValid(trace.Entity) and (trace.Entity:IsPlayer() or trace.Entity:IsNPC() or trace.Entity:GetClass():find("prop_")) then
                debugoverlay.Cross(trace.HitPos, 5, 20, Color(0, 255, 0), false)
                debugoverlay.Text(trace.HitPos, trace.Entity:GetClass(), 20)
            end
        end

        --apply damage if valid target
        if trace.Hit and IsValid(trace.Entity) and (trace.Entity:IsPlayer() or trace.Entity:IsNPC() or trace.Entity:IsNextBot()) then
            local target = trace.Entity
            damageTracker[target] = damageTracker[target] or 0
            local remaining = maxDamage - damageTracker[target]
            if remaining > 0 then
                local dmg = math.min(applyDamage, remaining)
                target:TakeDamage(dmg)
                damageTracker[target] = damageTracker[target] + dmg
            end
        end

        --ricochet
        if trace.Hit and allowRicochet and not (IsValid(trace.Entity) and (trace.Entity:IsPlayer() or trace.Entity:IsNPC() or trace.Entity:IsNextBot())) then
            local travelLen = (trace.HitPos - traceStart):Length()
            if travelLen >= 20 then
                local impactAngle = direction:Dot(trace.HitNormal) * -1
                if math.deg(math.acos(impactAngle)) > ricochetAng and math.random() <= ricochetProb then
                    local normal = trace.HitNormal
                    local ricochetDir = (direction - 2 * direction:Dot(normal) * normal):GetNormalized()
                    local offset = Vector(math.Rand(-0.1, 0.1), math.Rand(-0.1, 0.1), math.Rand(-0.1, 0.1))
                    ricochetDir = (ricochetDir + offset):GetNormalized()

                    local ricochetStart = trace.HitPos
                    local ricochetEnd = ricochetStart + ricochetDir * (distance / 2)
                    local ricochetTrace = util.TraceLine({ start = ricochetStart, endpos = ricochetEnd })

                    --sound
                    if math.random() > 0.8 then
                        local ricochetSound = "rico" .. math.random(1, 3) .. ".wav"
                        sound.Play(ricochetSound, trace.HitPos, 75, 100, 1)
                    end

                    --apply ricochet damage
                    if ricochetTrace.Hit and IsValid(ricochetTrace.Entity) and
                        (ricochetTrace.Entity:IsPlayer() or ricochetTrace.Entity:IsNPC() or ricochetTrace.Entity:IsNextBot()) then
                        local target = ricochetTrace.Entity
                        damageTracker[target] = damageTracker[target] or 0
                        local remaining = maxDamage - damageTracker[target]
                        if remaining > 0 then
                            local dmg = math.min(applyDamage, remaining)
                            target:TakeDamage(dmg)
                            damageTracker[target] = damageTracker[target] + dmg
                        end
                    end

                    if debug then
                        ricochetCount = ricochetCount + 1
                        debugoverlay.Line(ricochetStart, ricochetTrace.HitPos, 20, Color(255, 255, 0), false)
                        if IsValid(ricochetTrace.Entity) and (ricochetTrace.Entity:IsPlayer() or ricochetTrace.Entity:IsNPC() or ricochetTrace.Entity:GetClass():find("prop_")) then
                            debugoverlay.Cross(ricochetTrace.HitPos, 5, 20, Color(0, 255, 0), false)
                            debugoverlay.Text(ricochetTrace.HitPos, ricochetTrace.Entity:GetClass(), 20)
                        end
                    end
                end
            end
        end
    end
    if debug then
        print("[RFS DEBUG] Total traces: " .. num)
        print("[RFS DEBUG] Traces hit: " .. hitCount .. " Traces missed: " .. missCount .. " Ricochet traces: " .. ricochetCount)
    end
end

local function fireFragment(attacker, src, dir, distance, damage, tracer, spread, force)
    local fragment = {
        Num = 1,
        Src = src,
        Dir = dir,
        Distance = distance,
        Spread = spread,
        Tracer = tracer,
        Force = force,
        AmmoType = "grenadeFragments",
        Damage = damage
    }

    attacker:FireBullets(fragment)
end

local bulletAttackerEntity
local function shootBullets(num, pos)
    if not IsValid(bulletAttackerEntity) then
        bulletAttackerEntity = ents.Create("info_target")
        bulletAttackerEntity:SetPos(Vector(0, 0, 0))
        bulletAttackerEntity:Spawn()
        bulletAttackerEntity:SetNoDraw(true)
        bulletAttackerEntity:SetNotSolid(true)
    end

    local attacker = bulletAttackerEntity
    attacker:SetPos(pos)
    attacker.IsFragmentAttacker = true
    attacker.MaxFragmentDamage = TotalDamage:GetInt()
    attacker.DamageTracker = {}

    local inWater = isInWater(pos)
    local source = pos + Vector(0, 0, 5)

    local traceResult = util.TraceLine({
        start = pos,
        endpos = pos + Vector(0, 0, -10000)
    })
    local isCloseToGround = traceResult.Hit and pos:Distance(traceResult.HitPos) < 10

    local travelDist = travelDistance:GetInt()
    local fragDamage = damage:GetInt()
    local fragTracer = tracer:GetInt()
    local fragSpread = Vector(0.01, 0.01, 0)

    if fragmentsType:GetInt() == 2 then
        attacker.MaxFragmentDamage = attacker.MaxFragmentDamage / 2
    end

    for i = 1, num do
        local direction = setDirection(isCloseToGround)
        local distance = math.random(travelDist / 2, travelDist) / 0.02
        if inWater then
            distance = distance * 0.2
        end

        fireFragment(attacker, source, direction, distance, fragDamage, fragTracer, fragSpread, 2)
    end

    if isDebug:GetBool() then
        print("[RFS DEBUG] Total bullets: " .. num)
    end
end

hook.Add("EntityTakeDamage", "LimitBulletDamage_Global", function(target, dmgInfo)
    local attacker = dmgInfo:GetAttacker()
    if not IsValid(attacker) then return end
    if not attacker.IsFragmentAttacker then return end

    local maxTotalDamage = attacker.MaxFragmentDamage or 100
    attacker.DamageTracker = attacker.DamageTracker or {}

    if target:IsPlayer() or target:IsNPC() or target:IsNextBot() then
        local appliedDamage = dmgInfo:GetDamage()
        local tracker = attacker.DamageTracker
        tracker[target] = tracker[target] or 0
        local remainingDamage = maxTotalDamage - tracker[target]

        dmgInfo:SetAttacker(game.GetWorld())

        if remainingDamage > 0 then
            appliedDamage = math.min(appliedDamage, remainingDamage)
            tracker[target] = tracker[target] + appliedDamage
            dmgInfo:SetDamageType(DMG_BULLET)
            dmgInfo:SetDamage(appliedDamage)
        else
            dmgInfo:SetDamage(0)
        end
    end
end)

local function shootMixed(num, pos)
    local ratio = frgRatio:GetInt() / 100
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

function RFS:CreateShrapnell(num, pos, isBullets)
    if not isBullets then
        shootTraces(num, pos)
    else
        shootBullets(num, pos)
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
            if distance < travelDistance:GetInt() then
                return true
            end
        end
    end
    return false
end

local function rfsMultiplayer(explosionPosition, explosionName)
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

    if explosionPosition then
        if not checkDistance(explosionPosition) then return end
        local startTime = SysTime()
        if fragmentsType:GetInt() == 0 then
            shootTraces(fragments:GetInt(), explosionPosition)
        elseif fragmentsType:GetInt() == 1 then
            shootBullets(fragments:GetInt(), explosionPosition)
        elseif fragmentsType:GetInt() == 2 then
            shootMixed(fragments:GetInt(), explosionPosition)
        end
        if isDebug:GetBool() then
            local endTime = SysTime()
            local elapsed = endTime - startTime
            print("[RFS DEBUG] Explosion took: " .. math.Truncate(elapsed, 5) .. " seconds")
        end
    end
end

local function rfsSingleplayer(explosionPosition)
    if explosionPosition then
        if not checkDistance(explosionPosition) then return end
        local startTime = SysTime()
        if fragmentsType:GetInt() == 0 then
            shootTraces(fragments:GetInt(), explosionPosition)
        elseif fragmentsType:GetInt() == 1 then
            shootBullets(fragments:GetInt(), explosionPosition)
        elseif fragmentsType:GetInt() == 2 then
            shootMixed(fragments:GetInt(), explosionPosition)
        end
        if isDebug:GetBool() then
            local endTime = SysTime()
            local elapsed = endTime - startTime
            print("[RFS DEBUG] Explosion took: " .. math.Truncate(elapsed, 5) .. " seconds")
        end
    end
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

-- anti spam / anti lag
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
        print("[RFS] Player: " .. sender:Nick() .. " (" .. sender:SteamID() .. ") sent too many messages per second! Count: " .. #playerMessageTimestamps[sender])
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