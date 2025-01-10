AddCSLuaFile()

if CLIENT then
    include("client/cl_shrapnell.lua")
    include("client/cl_shrapnell_whitelist.lua")
    CreateClientConVar("cl_rfs_sound", '1', true, false)
    CreateClientConVar("cl_show_sound_names", '0', true, false)
end

if SERVER then
    AddCSLuaFile("client/cl_shrapnell.lua")
    AddCSLuaFile("client/cl_shrapnell_whitelist.lua")
    CreateConVar("sv_rfs_damage", '20', {FCVAR_ARCHIVE} , "", 1, 100 )
    CreateConVar("sv_rfs_batch_fragments", '0', {FCVAR_ARCHIVE} , "", 0, 1 )
    CreateConVar("sv_rfs_trtobl_ratio", '50', {FCVAR_ARCHIVE} , "", 1, 99 )
    CreateConVar("sv_rfs_fragments_type", '2', {FCVAR_ARCHIVE} , "", 0, 2 )
    CreateConVar("sv_rfs_enable_bullet_traces", '1', {FCVAR_ARCHIVE} , "", 0, 1 )
    CreateConVar("sv_rfs_ricochet_angle", '60', {FCVAR_ARCHIVE} , "", 0, 90 )
    CreateConVar("sv_rfs_ricochet_chance", '25', {FCVAR_ARCHIVE} , "", 1, 100 )
    CreateConVar("sv_rfs_fragments_travel_distance", '100', {FCVAR_ARCHIVE} , "", 10, 1000 )
    CreateConVar("sv_rfs_debug", '0', {FCVAR_ARCHIVE} , "", 0, 1 )
end

CreateConVar("sv_rfs_enable_ricochet", '1', {FCVAR_ARCHIVE, FCVAR_REPLICATED} , "", 0, 1 )
CreateConVar("sv_rfs_fragments", '250', {FCVAR_ARCHIVE, FCVAR_REPLICATED} , "", 1, 1500 )

-- for dwr
hook.Add( "Initialize", "grenadeFragments", function()
    game.AddAmmoType({
        name = "grenadeFragments",
        dmgtype = DMG_BULLET,
        tracer = TRACER_LINE,
        plydmg = sv_rfs_damage,
        npcdmg = sv_rfs_damage,
    })
end)

hook.Add("PopulateToolMenu", "RFSOptions", function()
    spawnmenu.AddToolMenuOption("Options", "Realistic Fragmentation System", "RFS Options", "Settings", "", "", function(panel)
        local isAdmin = LocalPlayer():IsAdmin()
        panel:CheckBox("Enable shrapnell flyby SFX ", "cl_rfs_sound")
        panel:CheckBox("Show sound names in console ", "cl_show_sound_names")
        if isAdmin then
            panel:Help("")
            local selectFragments = panel:ComboBox("Select Fragments", "sv_rfs_fragments_type")
            selectFragments:AddChoice("Traces", 0)
            selectFragments:AddChoice("Bullets", 1)
            selectFragments:AddChoice("Bullets w/ traces", 2)
            local currentValue = GetConVar("sv_rfs_fragments_type"):GetInt()
            panel:Help("Traces: The least resource-intensive option. Fragments don’t physically interact with the world (e.g., they won’t push props or leave bullet holes). In short, no visual effects but gets the job done")
            panel:Help("Bullets: The most resource-heavy method. Fragments behave like normal bullets, interacting with the world in all possible ways")
            panel:Help("Bullets w/ traces: A middle ground. Combines traces and bullets based on the set ratio. This option allows some of the physical interaction effects, while maintaining a better performance balance than pure bullets")
            panel:CheckBox("Enable bullets batching ", "sv_rfs_batch_fragments")
            panel:ControlHelp("If enabled, bullets will spawn in smaller batches instead of all at once. May reduce lag spikes during explosion")
            panel:CheckBox("Enable bullets traces ", "sv_rfs_enable_bullet_traces")
            panel:ControlHelp("If enabled, some bullets will leave a trace, allowing you to see fragments fly by")
            if currentValue == 0 then
                selectFragments:ChooseOptionID(1)
            elseif currentValue == 1 then
                selectFragments:ChooseOptionID(2)
            elseif currentValue == 2 then
                selectFragments:ChooseOptionID(3)
            else
                selectFragments:ChooseOptionID(1)
            end
            selectFragments.OnSelect = function(_, index, value, data)
                RunConsoleCommand("sv_rfs_fragments_type", data)
            end
            panel:NumSlider("Fragment travel distance (m) ", "sv_rfs_fragments_travel_distance", 10, 1000, 0)
            panel:ControlHelp("Sets the maximum fragment travel distance in meters. If the distance between the explosion and the player or NPC exceeds this value, the fragments will not spawn to save performance")
            panel:NumSlider("Fragment Count ", "sv_rfs_fragments", 1, 1500, 0)
            panel:ControlHelp("Selecting a number higher than 500 may cause lag spikes and is not recommended.")
            panel:NumSlider("Fragment Damage ", "sv_rfs_damage", 1, 100, 0)
            panel:NumSlider("Bullets to traces ratio (%) ", "sv_rfs_trtobl_ratio", 1, 99, 0)
            panel:ControlHelp("Lower number, less bullets")
            panel:Help("")
            panel:Help("")
            panel:CheckBox("Enable random ricochets ", "sv_rfs_enable_ricochet")
            panel:ControlHelp("If enabled, some fragments will ricochet if they hit at an appropriate angle (depending on settings may reduce performance)")
            panel:NumSlider("Ricochet angle  ", "sv_rfs_ricochet_angle", 0, 90, 0)
            panel:ControlHelp("Sets the minimum angle required for fragments to ricochet. 0 = perpendicular to the surface. Default is 60")
            panel:NumSlider("Ricochet chance  ", "sv_rfs_ricochet_chance", 1, 100, 0)
            panel:ControlHelp("Sets the percentage chance for a fragment to ricochet upon impact if all conditions are met. Larger values may affect performance")
            panel:Help("")
            panel:Help("")
            panel:CheckBox("Show traces ", "sv_rfs_debug")
            panel:ControlHelp("Shows traces trajectory. You need to enable developer mode in console; eg. developer 1")
        end
    end)
end)