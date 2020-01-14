if WOW_PROJECT_ID ~= WOW_PROJECT_CLASSIC then
    return
end

local UnitGUID = UnitGUID
local UnitIsUnit = UnitIsUnit
local UnitExists = UnitExists

local groupMembers = {}

local ThreatLib = LibStub("LibThreatClassic2")

-- ThreatLib.DebugEnabled = true
-- ThreatLib:RequestActiveOnSolo()

local function UnitDetailedThreatSituation(unit, target)
    if unit and UnitIsUnit(unit, "player") then
        unit = "player"
    end

    local unitGUID, targetGUID = UnitGUID(unit), UnitGUID(target)

    if not unitGUID or not targetGUID then
        return nil
    end

    local threatValue = ThreatLib:GetThreat(unitGUID, targetGUID)

    if not threatValue then
        return nil
    end

    return ThreatLib:UnitDetailedThreatSituation(unit, target)
end

local function UnitThreatSituation(unit, target)
    if target then
        return (select(2, UnitDetailedThreatSituation(unit, target)))
    end

    local unitGUID = UnitGUID(unit)

    if not unitGUID then
        return nil
    end

    local data = ThreatLib.threatTargets[unitGUID]

    if not data then
        return nil
    end

    local targetIDs = {}

    for _, target in pairs(groupMembers) do
        local targetGUID = UnitGUID(target)

        if targetGUID then
            targetIDs[targetGUID] = target
        end
    end

    local status = nil

    for targetGUID in pairs(data) do
        local target = targetIDs[targetGUID]

        if target then
            local _, targetStatus = UnitDetailedThreatSituation(unit, target)

            if not status then
                status = targetStatus
            elseif targetStatus and targetStatus > status then
                status = targetStatus
            end
        end
    end

    return status
end

local GetThreatStatusColor = function(statusIndex)
    return ThreatLib:GetThreatStatusColor(statusIndex)
end

-- local function IsPlayerEffectivelyTank()
--     if not IsInRaid() then
--         return false
--     end

--     local role = select(10, GetRaidRosterInfo(UnitInRaid("player")))
--     return role == "MAINTANK"
-- end

-- local function IsOnThreatList(threatStatus)
--     return threatStatus ~= nil
-- end

-- local function SetBorderColor(frame, r, g, b, a)
--     frame.healthBar.border:SetVertexColor(r, g, b, a)

--     if frame.castBar and frame.castBar.border then
--         frame.castBar.border:SetVertexColor(r, g, b, a)
--     end
-- end

-- local function CompactUnitFrame_IsOnThreatListWithPlayer(unit)
--     local _, threatStatus = UnitDetailedThreatSituation("player", unit)
--     return IsOnThreatList(threatStatus)
-- end

local function CompactUnitFrame_UpdateAggroHighlight(frame)
    if not frame._CAH_aggroHighlight then
        return
    end

    local status = UnitThreatSituation(frame.displayedUnit)

    if status and status > 0 then
        frame._CAH_aggroHighlight:SetVertexColor(GetThreatStatusColor(status))
        frame._CAH_aggroHighlight:Show()
    else
        frame._CAH_aggroHighlight:Hide()
    end
end

-- local function CompactUnitFrame_UpdateAggroFlash(frame)
--     if not frame._CAH_aggroHighlight or not frame._CAH_LoseAggroAnim then
--         return
--     end

--     if not IsPlayerEffectivelyTank() then
--         return
--     end

--     local isTanking = UnitDetailedThreatSituation("player", frame.displayedUnit)

--     if frame.isTanking ~= isTanking then
--         if frame.isTanking and not isTanking then
--             frame._CAH_aggroHighlight:Show()
--             frame._CAH_LoseAggroAnim:Play()
--         end

--         frame.isTanking = isTanking
--     end

--     if not frame._CAH_LoseAggroAnim:IsPlaying() then
--         frame._CAH_aggroHighlight:Hide()
--     end
-- end

local function OnThreatUpdated(frame, event, unitGUID, targetGUID, threat)
    if unitGUID == UnitGUID(frame.unit) or unitGUID == UnitGUID(frame.displayedUnit) then
        CompactUnitFrame_UpdateAggroHighlight(frame)
    -- CompactUnitFrame_UpdateAggroFlash(frame)
    -- CompactUnitFrame_UpdateHealthBorder(frame)
    end
end

do
    local function getTexture(frame, name)
        while not frame:GetName() do
            frame = frame:GetParent()
        end

        name = name and string.gsub(name, "%$parent", frame:GetName())
        return name and _G[name] and _G["_CAH_" .. name]
    end

    local function createTexture(frame, name, layer, subLayer)
        return getTexture(frame, name) or frame:CreateTexture(name and "_CAH_" .. name, layer, nil, subLayer)
    end

    local texCoords = {
        ["Raid-AggroFrame"] = {0.00781250, 0.55468750, 0.00781250, 0.27343750},
        ["Raid-TargetFrame"] = {0.00781250, 0.55468750, 0.28906250, 0.55468750}
    }

    local function setUpFunc(frame)
        if frame:IsForbidden() or frame._CAH_aggroHighlight then
            return
        end

        frame._CAH_aggroHighlight = createTexture(frame, "$parentAggroHighlight", "ARTWORK")
        frame._CAH_aggroHighlight:SetTexture("Interface\\RaidFrame\\Raid-FrameHighlights")
        frame._CAH_aggroHighlight:SetTexCoord(unpack(texCoords["Raid-AggroFrame"]))
        frame._CAH_aggroHighlight:SetAllPoints(frame)
    end

    hooksecurefunc("DefaultCompactUnitFrameSetup", setUpFunc)
    hooksecurefunc("DefaultCompactMiniFrameSetup", setUpFunc)

    local compactRaidFrameReservation_GetFrame

    hooksecurefunc(
        "CompactRaidFrameReservation_GetFrame",
        function(self, key)
            compactRaidFrameReservation_GetFrame = self.reservations[key]
        end
    )

    local frameCreationSpecifiers = {
        raid = {mapping = UnitGUID, setUpFunc = setUpFunc},
        pet = {setUpFunc = setUpFunc},
        flagged = {mapping = UnitGUID, setUpFunc = setUpFunc},
        target = {setUpFunc = setUpFunc}
    }

    hooksecurefunc(
        "CompactRaidFrameContainer_GetUnitFrame",
        function(self, unit, frameType)
            if not compactRaidFrameReservation_GetFrame then
                local info = frameCreationSpecifiers[frameType]
                local mapping

                if info.mapping then
                    mapping = info.mapping(unit)
                else
                    mapping = unit
                end

                local frame = self.frameReservations[frameType].reservations[mapping]
                info.setUpFunc(frame)
            end
        end
    )
end

-- hooksecurefunc(
--     "CompactUnitFrame_SetUnit",
--     function(frame, unit)
--         if not frame._CAH_aggroHighlight then
--             return
--         end

--         if not unit then
--             frame.isTanking = nil
--         end
--     end
-- )

hooksecurefunc(
    "CompactUnitFrame_UpdateAll",
    function(frame)
        if not frame._CAH_aggroHighlight then
            return
        end

        if frame.displayedUnit then
            CompactUnitFrame_UpdateAggroHighlight(frame)
        -- CompactUnitFrame_UpdateAggroFlash(frame)
        end
    end
)

hooksecurefunc(
    "CompactUnitFrame_UpdateUnitEvents",
    function(frame)
        if not frame._CAH_aggroHighlight then
            return
        end

        ThreatLib.RegisterCallback(frame, "Activate", OnThreatUpdated, frame)
        ThreatLib.RegisterCallback(frame, "Deactivate", OnThreatUpdated, frame)
        ThreatLib.RegisterCallback(frame, "PartyChanged", OnThreatUpdated, frame)
        ThreatLib.RegisterCallback(frame, "ThreatUpdated", OnThreatUpdated, frame)
        ThreatLib.RegisterCallback(frame, "ThreatCleared", OnThreatUpdated, frame)
    end
)

hooksecurefunc(
    "CompactUnitFrame_UnregisterEvents",
    function(frame)
        if not frame._CAH_aggroHighlight then
            return
        end

        ThreatLib.UnregisterCallback(frame, "Activate")
        ThreatLib.UnregisterCallback(frame, "Deactivate")
        ThreatLib.UnregisterCallback(frame, "PartyChanged")
        ThreatLib.UnregisterCallback(frame, "ThreatUpdated")
        ThreatLib.UnregisterCallback(frame, "ThreatCleared")
    end
)

-- hooksecurefunc(
--     "CompactUnitFrame_UpdateHealthBorder",
--     function(frame)
--         if not frame._CAH_aggroHighlight then
--             return
--         end

--         if frame.optionTable.selectedBorderColor and UnitIsUnit(frame.displayedUnit, "target") then
--             SetBorderColor(frame, frame.optionTable.selectedBorderColor:GetRGBA())
--             return
--         end

--         if frame.optionTable.tankBorderColor and IsInGroup() and IsPlayerEffectivelyTank() then
--             local isTanking, threatStatus = UnitDetailedThreatSituation("player", frame.displayedUnit)
--             local showTankingColor = not isTanking and IsOnThreatList(threatStatus) and IsInGroup()

--             if showTankingColor then
--                 SetBorderColor(frame, frame.optionTable.tankBorderColor:GetRGBA())
--                 return
--             end
--         end

--         if frame.optionTable.defaultBorderColor then
--             SetBorderColor(frame, frame.optionTable.defaultBorderColor:GetRGBA())
--             return
--         end
--     end
-- )

do
    local petIDs = {["player"] = "pet"}

    for i = 1, MAX_PARTY_MEMBERS do
        petIDs["party" .. i] = "partypet" .. i
    end

    for i = 1, MAX_RAID_MEMBERS do
        petIDs["raid" .. i] = "raidpet" .. i
    end

    local groupNone = {"player"}
    local groupParty = {"player"}
    local groupRaid = {}

    for i = 1, MAX_PARTY_MEMBERS do
        tinsert(groupParty, "party" .. i)
    end

    for i = 1, MAX_RAID_MEMBERS do
        tinsert(groupRaid, "raid" .. i)
    end

    local eventHandlers = {}
    local eventFrame = CreateFrame("Frame")

    eventFrame:SetScript(
        "OnEvent",
        function(self, event, ...)
            eventHandlers[event](...)
        end
    )

    local wipe = wipe

    local IsInRaid = IsInRaid
    local GetNumGroupMembers = GetNumGroupMembers

    function eventHandlers.GROUP_ROSTER_UPDATE()
        local group

        if GetNumGroupMembers() == 0 then
            group = groupNone
        elseif not IsInRaid() then
            group = groupParty
        else
            group = groupRaid
        end

        wipe(groupMembers)

        for _, unit in ipairs(group) do
            if UnitExists(unit) then
                groupMembers[unit] = unit .. "target"

                local pet = petIDs[unit]

                if UnitExists(pet) then
                    groupMembers[pet] = pet .. "target"
                end
            end
        end
    end

    function eventHandlers.UNIT_PET(unit)
        if groupMembers[unit] then
            local pet = petIDs[unit]

            if UnitExists(pet) then
                groupMembers[pet] = pet .. "target"
            else
                groupMembers[pet] = nil
            end
        end
    end

    function eventHandlers.PLAYER_ENTERING_WORLD()
        eventFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")

        eventHandlers.GROUP_ROSTER_UPDATE()
    end

    function eventHandlers.PLAYER_LOGIN()
        eventFrame:UnregisterEvent("PLAYER_LOGIN")

        eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
        eventFrame:RegisterEvent("UNIT_PET")
    end

    do
        if not IsLoggedIn() then
            eventFrame:RegisterEvent("PLAYER_LOGIN")
        else
            eventHandlers.PLAYER_LOGIN()
        end
    end
end
