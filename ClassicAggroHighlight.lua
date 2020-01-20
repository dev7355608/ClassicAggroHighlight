if WOW_PROJECT_ID ~= WOW_PROJECT_CLASSIC then
    return
end

local UnitGUID = UnitGUID
local UnitExists = UnitExists

local groupMembers = {}

local ThreatLib = LibStub("LibThreatClassic2")

local floor = floor

local function GetThreat(unitGUID, targetGUID)
    local data = ThreatLib.threatTargets[unitGUID]
    return data and data[targetGUID]
end

local function GetMaxThreatOnTarget(targetGUID)
    local maxThreatValue
    local maxUnitGUID

    for unitGUID, data in pairs(ThreatLib.threatTargets) do
        local threatValue = data[targetGUID]

        if threatValue then
            if not maxThreatValue or threatValue > maxThreatValue then
                maxThreatValue = threatValue
                maxUnitGUID = unitGUID
            end
        end
    end

    return maxThreatValue, maxUnitGUID
end

local function UnitDetailedThreatSituation(unit, target)
    local isTanking, threatStatus, threatPercent, rawThreatPercent, threatValue = nil, nil, nil, nil, nil
    local unitGUID, targetGUID = UnitGUID(unit), UnitGUID(target)

    if not unitGUID or not targetGUID then
        return isTanking, threatStatus, threatPercent, rawThreatPercent, threatValue
    end

    threatValue = GetThreat(unitGUID, targetGUID)

    if not threatValue then
        return isTanking, threatStatus, threatPercent, rawThreatPercent, threatValue
    elseif threatValue < 0 then
        threatValue = 0
    end

    isTanking = false
    threatStatus = 0

    local targetTarget = target .. "-target"
    local targetTargetGUID = UnitGUID(targetTarget)
    local targetTargetThreatValue

    if targetTargetGUID then
        targetTargetThreatValue = GetThreat(targetTargetGUID, targetGUID)
    end

    if targetTargetThreatValue and targetTargetThreatValue > 0 then
        if threatValue >= targetTargetThreatValue then
            if unitGUID == targetTargetGUID then
                isTanking = true

                local _, maxUnitGUID = GetMaxThreatOnTarget(targetGUID)

                if unitGUID == maxUnitGUID then
                    threatStatus = 3
                else
                    threatStatus = 2
                end
            else
                threatStatus = 1
            end
        end

        rawThreatPercent = threatValue / targetTargetThreatValue * 100
    end

    threatValue = floor(threatValue)

    return isTanking, threatStatus, threatPercent, rawThreatPercent, threatValue
end

local function UnitThreatSituation(unit, target)
    if target then
        local _, threatStatus = UnitDetailedThreatSituation(unit, target)
        return threatStatus
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

    local threatStatus = nil

    for targetGUID in pairs(data) do
        local target = targetIDs[targetGUID]

        if target then
            local _, targetThreatStatus = UnitDetailedThreatSituation(unit, target)

            if not threatStatus then
                threatStatus = targetThreatStatus
            elseif targetThreatStatus and targetThreatStatus > threatStatus then
                threatStatus = targetThreatStatus
            end
        end
    end

    return threatStatus
end

local function GetThreatStatusColor(statusIndex)
    if statusIndex == 0 then
        return 0.69, 0.69, 0.69
    end

    if statusIndex == 1 then
        return 1, 1, 0.47
    end

    if statusIndex == 2 then
        return 1, 0.6, 0
    end

    if statusIndex == 3 then
        return 1, 0, 0
    end
end

local function CompactUnitFrame_UpdateAggroHighlight(frame)
    if not frame._CAH_aggroHighlight then
        return
    end

    if not frame.unit or frame.unit:find("target$") then
        frame._CAH_aggroHighlight:Hide()
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
        ["Raid-AggroFrame"] = {0.00781250, 0.55468750, 0.00781250, 0.27343750}
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

hooksecurefunc("CompactUnitFrame_UpdateAll", CompactUnitFrame_UpdateAggroHighlight)

local function updateCallbacks(frame)
    if not frame._CAH_aggroHighlight then
        return
    end

    if frame.unit then
        if not frame._CAH_callbacksRegistered then
            frame._CAH_callbacksRegistered = true

            ThreatLib.RegisterCallback(frame, "Activate", CompactUnitFrame_UpdateAggroHighlight, frame)
            ThreatLib.RegisterCallback(frame, "Deactivate", CompactUnitFrame_UpdateAggroHighlight, frame)
            ThreatLib.RegisterCallback(frame, "PartyChanged", CompactUnitFrame_UpdateAggroHighlight, frame)
            ThreatLib.RegisterCallback(frame, "ThreatUpdated", CompactUnitFrame_UpdateAggroHighlight, frame)
            ThreatLib.RegisterCallback(frame, "ThreatCleared", CompactUnitFrame_UpdateAggroHighlight, frame)
        end
    else
        if frame._CAH_callbacksRegistered then
            frame._CAH_callbacksRegistered = false

            ThreatLib.UnregisterCallback(frame, "Activate")
            ThreatLib.UnregisterCallback(frame, "Deactivate")
            ThreatLib.UnregisterCallback(frame, "PartyChanged")
            ThreatLib.UnregisterCallback(frame, "ThreatUpdated")
            ThreatLib.UnregisterCallback(frame, "ThreatCleared")
        end
    end
end

hooksecurefunc("CompactUnitFrame_RegisterEvents", updateCallbacks)

hooksecurefunc("CompactUnitFrame_UnregisterEvents", updateCallbacks)

hooksecurefunc(
    "CompactPartyFrame_Generate",
    function()
        local name = CompactPartyFrame:GetName()

        for i = 1, MEMBERS_PER_RAID_GROUP do
            updateCallbacks(_G[name .. "Member" .. i])
        end
    end
)

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
