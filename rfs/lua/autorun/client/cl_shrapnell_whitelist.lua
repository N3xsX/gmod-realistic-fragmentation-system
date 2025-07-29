local filePath = "rfsWhitelist.txt"
local rfsWhitelist = {}

if file.Exists(filePath, "DATA") then
    rfsWhitelist = util.JSONToTable(file.Read(filePath, "DATA"))
    print("[RFS] Whitelist loaded")
else
    print("[RFS] No whitelist file found, creating a new one")
end

local function updateWhitelistPanel(panel)
    panel:Clear()
    local textEntry = vgui.Create("DTextEntry")
    textEntry:SetPlaceholderText("Enter sound path...")
    panel:AddItem(textEntry)
    local addButton = vgui.Create("DButton")
    addButton:SetText("Add Sound")
    addButton.DoClick = function()
        local word = textEntry:GetValue()
        if word and word:match("%a") then -- no more empty entries 
            table.insert(rfsWhitelist, word)
            local jsonData = util.TableToJSON(rfsWhitelist)
            file.Write(filePath, jsonData)
            textEntry:SetValue("")
            updateWhitelistPanel(panel)
        else
            notification.AddLegacy("Please enter a valid sound path containing at least one letter", NOTIFY_ERROR, 5)
            surface.PlaySound("buttons/button10.wav")
        end
    end
    panel:AddItem(addButton)

    local whitelistLabel = vgui.Create("DLabel")
    whitelistLabel:SetText("Whitelisted Sounds:")
    whitelistLabel:SizeToContents()
    panel:AddItem(whitelistLabel)

    local wordList = vgui.Create("DListView")
    wordList:SetHeight(150)
    wordList:AddColumn("Sound Paths")
    for _, word in ipairs(rfsWhitelist) do
        wordList:AddLine(word)
    end
    panel:AddItem(wordList)

    local deleteButton = vgui.Create("DButton")
    deleteButton:SetText("Remove Selected Sound")
    deleteButton.DoClick = function()
        local selectedLine = wordList:GetSelectedLine()
        if selectedLine then
            local selectedWord = wordList:GetLine(selectedLine):GetValue(1)
            for i, word in ipairs(rfsWhitelist) do
                if word == selectedWord then
                    table.remove(rfsWhitelist, i)
                    break
                end
            end
            local jsonData = util.TableToJSON(rfsWhitelist)
            file.Write(filePath, jsonData)
            updateWhitelistPanel(panel)
        end
    end
    panel:AddItem(deleteButton)
    if not game.SinglePlayer() then
        local rfsWhitelistJson = util.TableToJSON(rfsWhitelist)
        net.Start("RFSUpdateWhitelist")
        net.WriteString(rfsWhitelistJson)
        net.SendToServer()
    end
end

hook.Add("PopulateToolMenu", "RFSWhitelist", function()
    spawnmenu.AddToolMenuOption("Options", "Realistic Fragmentation System", "RFS Whitelist", "Whitelist", "", "", function(panel)
        local isAdmin = LocalPlayer():IsAdmin()
        if game.SinglePlayer() then
            panel:Help("Manage the whitelist for RFS sounds")
            updateWhitelistPanel(panel)
        elseif not game.SinglePlayer() and isAdmin then
            panel:Help("Manage the whitelist for RFS sounds")
            updateWhitelistPanel(panel)
        elseif not game.SinglePlayer() and not isAdmin then
            panel:Help("You cannot edit the server whitelist")
        end
    end)
end)