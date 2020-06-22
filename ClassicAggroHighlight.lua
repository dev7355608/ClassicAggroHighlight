if WOW_PROJECT_ID ~= WOW_PROJECT_CLASSIC then
    return
end

local UnitGUID = UnitGUID
local UnitExists = UnitExists
local GetTime = GetTime
local pairs = pairs
local wipe = wipe

local unitIDs = {}

local weaktable = {__mode = "k"}
local aggroHighlight = setmetatable({}, weaktable)
local callbacksRegistered = setmetatable({}, weaktable)

local ThreatLib
local UnitThreatSituation = _G.UnitThreatSituation

if not _G.UnitThreatSituation then
    ThreatLib = LibStub("LibThreatClassic2")

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

    function UnitThreatSituation(unit)
        local status = nil

        local unitGUID = UnitGUID(unit)

        if not unitGUID then
            return status
        end

        local data = ThreatLib.threatTargets[unitGUID]

        if not data then
            return status
        end

        local targets = {}
        local current, currentTarget = next(unitIDs)

        for targetGUID in pairs(data) do
            local target = targets[targetGUID]

            while not target and current do
                local currentTargetGUID = UnitGUID(currentTarget)

                if currentTargetGUID then
                    if currentTargetGUID == targetGUID then
                        target = currentTarget
                    else
                        targets[currentTargetGUID] = currentTarget
                    end
                end

                current, currentTarget = next(unitIDs, current)
            end

            if target then
                local threatValue = GetThreat(unitGUID, targetGUID)

                if threatValue then
                    local threatStatus = 0

                    local targetTarget = target .. "-target"
                    local targetTargetGUID = UnitGUID(targetTarget)
                    local targetTargetThreatValue

                    if targetTargetGUID then
                        targetTargetThreatValue = GetThreat(targetTargetGUID, targetGUID)
                    end

                    if targetTargetThreatValue and targetTargetThreatValue > 0 then
                        if threatValue >= targetTargetThreatValue then
                            if unitGUID == targetTargetGUID then
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
                    end

                    if not status then
                        status = threatStatus
                    elseif threatStatus > status then
                        status = threatStatus
                    end
                end
            end
        end

        return status
    end
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
    local aggroHighlight = aggroHighlight[frame]

    if not aggroHighlight then
        return
    end

    local displayedUnit = frame.displayedUnit

    if not UnitExists(displayedUnit) or displayedUnit:find("target$") then
        aggroHighlight:Hide()
        return
    end

    local status = UnitThreatSituation(displayedUnit)

    if status and status > 0 then
        aggroHighlight:SetVertexColor(GetThreatStatusColor(status))
        aggroHighlight:Show()
    else
        aggroHighlight:Hide()
    end
end

local deferredFrames = {}
local lastFrameTime = -1

local function defer_CompactUnitFrame_UpdateAggroHighlight(frame)
    if GetTime() > lastFrameTime then
        deferredFrames[frame] = true
    else
        CompactUnitFrame_UpdateAggroHighlight(frame)
    end
end

if not _G.UnitThreatSituation then
    local deferFrame = CreateFrame("Frame")
    deferFrame:SetScript(
        "OnUpdate",
        function(self, elapsed)
            for frame in pairs(deferredFrames) do
                CompactUnitFrame_UpdateAggroHighlight(frame)
            end

            wipe(deferredFrames)

            lastFrameTime = GetTime()
        end
    )
end

do
    local texCoords = {
        ["Raid-AggroFrame"] = {0.00781250, 0.55468750, 0.00781250, 0.27343750}
    }

    local function setUpFunc(frame)
        if frame:IsForbidden() or aggroHighlight[frame] then
            return
        end

        aggroHighlight[frame] = frame:CreateTexture(nil, "ARTWORK")
        aggroHighlight[frame]:SetTexture("Interface\\RaidFrame\\Raid-FrameHighlights")
        aggroHighlight[frame]:SetTexCoord(unpack(texCoords["Raid-AggroFrame"]))
        aggroHighlight[frame]:SetAllPoints(frame)
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

if _G.UnitThreatSituation then
    hooksecurefunc(
        "CompactUnitFrame_OnEvent",
        function(self, event, ...)
            if event == self.updateAllEvent and (not self.updateAllFilter or self.updateAllFilter(self, event, ...)) then
                return
            end

            local unit = ...

            if unit == self.unit or unit == self.displayedUnit then
                if event == "UNIT_THREAT_SITUATION_UPDATE" then
                    CompactUnitFrame_UpdateAggroHighlight(self)
                end
            end
        end
    )

    hooksecurefunc("CompactUnitFrame_UpdateAll", CompactUnitFrame_UpdateAggroHighlight)
else
    hooksecurefunc("CompactUnitFrame_UpdateAll", defer_CompactUnitFrame_UpdateAggroHighlight)
end

if _G.UnitThreatSituation then
    hooksecurefunc(
        "CompactUnitFrame_UpdateUnitEvents",
        function(frame)
            if not aggroHighlight[frame] then
                return
            end

            local unit = frame.unit
            local displayedUnit

            if unit ~= frame.displayedUnit then
                displayedUnit = frame.displayedUnit
            end

            frame:RegisterUnitEvent("UNIT_THREAT_SITUATION_UPDATE", unit, displayedUnit)
        end
    )

    hooksecurefunc(
        "CompactPartyFrame_Generate",
        function()
            local name = CompactPartyFrame:GetName()

            for i = 1, MEMBERS_PER_RAID_GROUP do
                CompactUnitFrame_RegisterEvents(_G[name .. "Member" .. i])
            end
        end
    )
else
    local function updateCallbacks(frame)
        if not aggroHighlight[frame] then
            return
        end

        if frame.unit then
            if not callbacksRegistered[frame] then
                callbacksRegistered[frame] = true

                ThreatLib.RegisterCallback(frame, "Activate", defer_CompactUnitFrame_UpdateAggroHighlight, frame)
                ThreatLib.RegisterCallback(frame, "Deactivate", defer_CompactUnitFrame_UpdateAggroHighlight, frame)
                ThreatLib.RegisterCallback(frame, "PartyChanged", defer_CompactUnitFrame_UpdateAggroHighlight, frame)
                ThreatLib.RegisterCallback(frame, "ThreatUpdated", defer_CompactUnitFrame_UpdateAggroHighlight, frame)
                ThreatLib.RegisterCallback(frame, "ThreatCleared", defer_CompactUnitFrame_UpdateAggroHighlight, frame)
            end
        else
            if callbacksRegistered[frame] then
                callbacksRegistered[frame] = false

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
end

if not _G.UnitThreatSituation then
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

        wipe(unitIDs)

        for _, unit in ipairs(group) do
            if UnitExists(unit) then
                unitIDs[unit] = unit .. "target"

                local pet = petIDs[unit]

                if UnitExists(pet) then
                    unitIDs[pet] = pet .. "target"
                end
            end
        end
    end

    function eventHandlers.UNIT_PET(unit)
        if unitIDs[unit] then
            local pet = petIDs[unit]

            if UnitExists(pet) then
                unitIDs[pet] = pet .. "target"
            else
                unitIDs[pet] = nil
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
