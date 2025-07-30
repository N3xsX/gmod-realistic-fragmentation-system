AddCSLuaFile()

-- for dwr
hook.Add( "Initialize", "grenadeFragments", function()
    game.AddAmmoType({
        name = "grenadeFragments",
        dmgtype = DMG_BULLET,
        tracer = TRACER_LINE,
        plydmg = GetConVar("sv_rfs_damage"):GetInt(),
        npcdmg = GetConVar("sv_rfs_damage"):GetInt(),
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
                panel:Help(
                "Traces Only - The fastest option, up to 3x faster than using full bullets. Fragments are purely visual and dont interact with the environment (no prop pushing, no bullet holes)")
                panel:Help(
                "Bullets Only - The slowest and most performance-intensive mode. Fragments act like real bullets, fully interacting with the world")
                panel:Help(
                "Bullets w/Traces - A balanced option, roughly 1.5x to 2x faster than full bullets depending on set ratio. Combines traces and bullets to maintain some physical interaction while improving performance")
            panel:CheckBox("Enable Side-Biased fragments", "sv_rfs_fragment_direction")
            panel:ControlHelp("If enabled, fragments will spread more horizontally, reducing vertical spread")
            /*panel:CheckBox("Enable bullets batching ", "sv_rfs_batch_fragments")
            panel:ControlHelp("If enabled, bullets will spawn in smaller batches instead of all at once. May reduce lag spikes during explosion")*/
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
            panel:NumSlider("Fragment Count ", "sv_rfs_fragments", 1, 3000, 0)
            panel:ControlHelp("Selecting a number higher than 500 may cause lag spikes and is not recommended")
            panel:NumSlider("Fragment Damage ", "sv_rfs_damage", 1, 100, 0)
            panel:NumSlider("Max Fragment Damage ", "sv_rfs_max_fragment_damage", 1, 10000, 0)
            panel:ControlHelp("Maximum ammount of damage that fragments from one explosion can deal")
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